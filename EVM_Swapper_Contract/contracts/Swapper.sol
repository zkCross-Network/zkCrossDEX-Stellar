// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
    address public allowanceHolder ; // 0X new exchange address
    address public  swapAdmin;


    event Swapped(
        address indexed user,
        address indexed inputToken,
        address indexed outputToken,
        uint256 inputAmount,
        uint256  outputAmount
        //uint256 fee
    );

    event AdminUpdated(address indexed admin);
    event SwapFeeUpdated(uint256 newFeePercentage);

    modifier onlyAdmin() {
        require( msg.sender == swapAdmin , "Caller is not an admin");
        _;
    }

    function initialize(address _swapAdmin)
        external
        initializer
    {
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

      uint256 swapOutput= _swap(swapDesc );
     
        emit Swapped(
            _swapper,
            swapDesc.srcToken,
            swapDesc.dstToken,
            swapDesc.amount,
            swapOutput
           
        );
    }

 function withdrawTokens(address _token, uint256 _amount) external onlyOwner {
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
        (bool success, ) = allowanceHolder.call{value: msg.value}(_swapDesc.data);
        require(success, "swap failed");
        uint256 balanceAfterSwap = getBalance(_swapDesc.dstToken);
        uint256 swapOutput = balanceAfterSwap - balanceBeforeSwap;
    
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