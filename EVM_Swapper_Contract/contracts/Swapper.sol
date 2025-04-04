// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Swapper is
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    struct SwapDescription {
        address srcToken; //sellToken
        address dstToken; //buyToken
        uint256 amount; //amountIN
        bytes data; //0x calldata
    }

    address public constant NATIVE_TOKEN =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address public bridgeLiquidityToken;
    address public allowanceHolder; // 0X new exchange address
    address public swapAdmin;
    address public bridgeAdmin;
    mapping(string => bool) public processed;

    event Swapped(
        address indexed user,
        address indexed inputToken,
        address indexed outputToken,
        uint256 inputAmount,
        uint256 outputAmount
    );

    event Lock(
        address indexed user,
        bytes32 indexed destChain,
        address srcToken,
        address destToken,
        string toToken,
        string recipient,
        uint256 inputAmount,
        uint256 outputAmount,
        uint64 bridgeID
    );
    event Release(
        address indexed user,
        address token,
        string lockHash,
        uint256 inputAmount,
        uint256 outputAmount
    );

    event AdminUpdated(address indexed admin);
    event SwapFeeUpdated(uint256 newFeePercentage);

    modifier onlyAdmin() {
        require(msg.sender == swapAdmin, "Caller is not an admin");
        _;
    }

    function initialize(address _swapAdmin) external initializer {
        __Ownable_init(msg.sender);
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        swapAdmin = _swapAdmin;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    receive() external payable {}

    ///@notice This function is used to swap tokens from one to another
    ///@param _data : It is the encoded data of 0x warpped by zkcross API with swapDescription
    ///@param _swapper : It is the address of the user who is swapping the tokens

    function swap(bytes calldata _data, address _swapper)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        SwapDescription memory swapDesc = _decode(_data);
        require(swapDesc.amount != 0, "amount == 0");
        require(
            swapDesc.srcToken != address(0) && swapDesc.dstToken != address(0),
            "invalid tokens"
        );
        require(
            swapDesc.srcToken != swapDesc.dstToken,
            "src token == dst token"
        );
        // It checks that if the caller is not a contract then msg.send should be the user whos address is passed in params, to ensure funds is trasfered to caller
        if (msg.sender != address(this)) {
            require(msg.sender == _swapper, "caller != swapper");
        }
        if (swapDesc.srcToken == NATIVE_TOKEN) {
            require(msg.value == swapDesc.amount, "msg.value != amount");
        } else {
            require(msg.value == 0, "msg.value != 0");
            require(
                swapDesc.amount <=
                    IERC20(swapDesc.srcToken).balanceOf(_swapper),
                "insufficient balance"
            );
            _transferFrom(swapDesc.srcToken, _swapper, swapDesc.amount);
            _approve(swapDesc.srcToken, allowanceHolder, swapDesc.amount);
        }
        require(allowanceHolder != address(0), "invalid exchange address");
        require(swapAdmin != address(0), "invalid admin address");

        uint256 swapOutput = _swap(swapDesc);

        emit Swapped(
            _swapper,
            swapDesc.srcToken,
            swapDesc.dstToken,
            swapDesc.amount,
            swapOutput
        );
    }

    /**
     * @notice lock tokens for briding
     * @param _data 0x swap calldata
     * @param _destChain dest chain
     */
    function lock(
        bytes calldata _data,
        bytes32 _destChain,
        string memory _toToken,
        string memory recipientAddress,
        uint64 bridgeID
    ) public payable whenNotPaused nonReentrant returns (uint256 swapOutput) {
        address user = msg.sender;
        SwapDescription memory swapDesc = _decode(_data);
        require(swapDesc.amount != 0, "amount = 0");
        require(
            swapDesc.dstToken == bridgeLiquidityToken,
            "dstination token != Bridge liquidity token"
        );
        if (swapDesc.srcToken == NATIVE_TOKEN) {
            require(msg.value == swapDesc.amount, "msg.value != amount");
        } else {
            require(msg.value == 0, "msg.value != 0");
            _transferFrom(swapDesc.srcToken, user, swapDesc.amount);
            _approve(swapDesc.srcToken, allowanceHolder, swapDesc.amount);
        }
        if (swapDesc.srcToken == swapDesc.dstToken) {
            // no swap for liquidity token bridging
            swapOutput = swapDesc.amount;
        } else {
            swapOutput = _swap(swapDesc);
        }

        // Transfer funds to bridge admin
        if (swapDesc.dstToken == NATIVE_TOKEN) {
            // Transfer ETH to bridgeAdmin
            require(
                address(this).balance >= swapOutput,
                "Insufficient contract balance for transfer"
            );
            require(bridgeAdmin != address(0), "Bridge admin cannot be 0");
            payable(bridgeAdmin).transfer(swapOutput);
        } else {
            // Transfer ERC20 tokens to bridgeAdmin
            require(
                IERC20(swapDesc.dstToken).balanceOf(address(this)) >=
                    swapOutput,
                "Insufficient contract token balance for transfer"
            );
            require(
                bridgeAdmin != address(0),
                "Bridge admin cannot be address 0"
            );
            bool success = IERC20(swapDesc.dstToken).transfer(
                bridgeAdmin,
                swapOutput
            );
            require(success, "Token transfer to admin failed");
        }

        emit Lock(
            user,
            _destChain,
            swapDesc.srcToken,
            swapDesc.dstToken,
            _toToken,
            recipientAddress,
            swapDesc.amount,
            swapOutput,
            bridgeID
        );
    }

    /**
     * @notice swap and release
     * @param _data 0x swap calldata
     * @param _to release address
     * @param _lockHash lock hash
     */

    function release(
        bytes calldata _data,
        address _to,
        string calldata _lockHash
    )
        external
        payable
        whenNotPaused
        nonReentrant
        onlyAdmin
        returns (uint256 swapOutput)
    {
        address user = msg.sender;
        SwapDescription memory swapDesc = _decode(_data);
        require(swapDesc.amount != 0, "amount == 0");
        require(
            swapDesc.srcToken == bridgeLiquidityToken,
            "src token != liquidity token"
        );
        require(!processed[_lockHash], "processed");
        processed[_lockHash] = true;
        if (swapDesc.srcToken == swapDesc.dstToken) {
            _transferFrom(swapDesc.srcToken, user, swapDesc.amount);
            swapOutput = swapDesc.amount;
        } else {
            _transferFrom(swapDesc.srcToken, user, swapDesc.amount);
            _approve(swapDesc.srcToken, allowanceHolder, swapDesc.amount);
            swapOutput = _swap(swapDesc);
        }

        if (swapDesc.dstToken == NATIVE_TOKEN) {
            (bool success, ) = payable(_to).call{value: swapOutput}("");
            require(success, "Transfer to recipient failed");
        } else {
            _transfer(swapDesc.dstToken, _to, swapOutput);
        }

        emit Release(
            _to,
            swapDesc.dstToken,
            _lockHash,
            swapDesc.amount,
            swapOutput
        );
    }

    /**
     * Set bridge admin for release
     * @notice only owner
     * @param _newAdmin admin address
     */
    function setBridgeAdmin(address _newAdmin) external onlyOwner {
        require(_newAdmin != address(0), "zero address params");
        bridgeAdmin = _newAdmin;
        require(bridgeAdmin == _newAdmin, "invalid admin");
    }

    /**
     * Set liquidity token address for bridging
     * @notice only owner
     * @param _newToken token address
     */
    function setBridgeLiquidityToken(address _newToken) external onlyOwner {
        require(_newToken != address(0), "zero address params");
        bridgeLiquidityToken = _newToken;
    }

    function withdrawTokens(address _token, uint256 _amount)
        external
        onlyOwner
    {
        if (_token == NATIVE_TOKEN) {
            payable(swapAdmin).transfer(_amount);
        } else {
            IERC20(_token).safeTransfer(swapAdmin, _amount);
        }
    }

    function getBalance(address _token) public view returns (uint256) {
        if (_token == NATIVE_TOKEN) {
            return address(this).balance;
        }
        return IERC20(_token).balanceOf(address(this));
    }

    function updateAdmin(address _admin) external onlyOwner {
        require(_admin != address(0), "Invalid admin address");
        swapAdmin = _admin;
        emit AdminUpdated(_admin);
    }

    function setallowanceHolder(address _allowanceHolder) external onlyOwner {
        require(_allowanceHolder != address(0), "zero address params");
        allowanceHolder = _allowanceHolder;
    }

    //Decoding the Wrapped 0X call data
    function _decode(bytes calldata _data)
        private
        pure
        returns (SwapDescription memory)
    {
        (address a, address b, uint256 c, bytes memory d) = abi.decode(
            _data,
            (address, address, uint256, bytes)
        );
        return SwapDescription(a, b, c, d);
    }

    function _swap(SwapDescription memory _swapDesc) private returns (uint256) {
        uint256 balanceBeforeSwap = getBalance(_swapDesc.dstToken);
        (bool success, ) = allowanceHolder.call{value: msg.value}(
            _swapDesc.data
        );
        require(success, "swap failed");
        uint256 balanceAfterSwap = getBalance(_swapDesc.dstToken);
        uint256 swapOutput = balanceAfterSwap - balanceBeforeSwap;
        require(swapOutput != 0, "SwapOutput was zero");
        return swapOutput;
    }

    function _approve(
        address _token,
        address _spender,
        uint256 _amount
    ) private {
        uint256 allowance = IERC20(_token).allowance(address(this), _spender);
        if (allowance < _amount) {
            IERC20(_token).forceApprove(_spender, _amount);
        }
    }

    function _transfer(
        address _token,
        address _to,
        uint256 _amount
    ) private {
        IERC20(_token).safeTransfer(_to, _amount);
    }

    function _transferFrom(
        address _token,
        address _from,
        uint256 _amount
    ) private {
        IERC20(_token).safeTransferFrom(_from, address(this), _amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
