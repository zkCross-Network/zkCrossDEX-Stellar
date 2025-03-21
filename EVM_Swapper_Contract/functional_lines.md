# Functional Lines of Code - Swapper Contract

This document lists all the functional lines of code from the `Swapper.sol` contract. These lines actively contribute to the execution logic, including state changes, function calls, and external contract interactions.

---

## **Contract Variables**
```solidity
address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
```

---

## **Modifiers**
```solidity
require(msg.sender == swapAdmin, "Caller is not an admin");
```

---

## **Initialize Function**
```solidity
swapAdmin = _swapAdmin;
```

---

## **Swap Function**
```solidity
require(swapDesc.amount != 0, "amount == 0");
require(swapDesc.srcToken != address(0) && swapDesc.dstToken != address(0), "invalid tokens");
require(swapDesc.srcToken != swapDesc.dstToken, "src token == dst token");

if (msg.sender != address(this)) {
    require(msg.sender == _swapper, "caller != swapper");
}

if (swapDesc.srcToken == NATIVE_TOKEN) {
    require(msg.value == swapDesc.amount, "msg.value != amount");
} else {
    require(msg.value == 0, "msg.value != 0");
    require(swapDesc.amount <= IERC20(swapDesc.srcToken).balanceOf(_swapper), "insufficient balance");
    _transferFrom(swapDesc.srcToken, _swapper, swapDesc.amount);
    _approve(swapDesc.srcToken, allowanceHolder, swapDesc.amount);
}

require(allowanceHolder != address(0), "invalid exchange address");
require(swapAdmin != address(0), "invalid admin address");

uint256 swapOutput = _swap(swapDesc);

emit Swapped(_swapper, swapDesc.srcToken, swapDesc.dstToken, swapDesc.amount, swapOutput);
```

---

## **Withdraw Function**
```solidity
if (_token == NATIVE_TOKEN) {
    payable(swapAdmin).transfer(_amount);
} else {
    IERC20(_token).safeTransfer(swapAdmin, _amount);
}
```

---

## **Get Balance Function**
```solidity
if (_token == NATIVE_TOKEN) {
    return address(this).balance;
}
return IERC20(_token).balanceOf(address(this));
```

---

## **Update Admin Function**
```solidity
swapAdmin = _admin;
emit AdminUpdated(_admin);
```

---

## **Set Allowance Holder Function**
```solidity
allowanceHolder = _allowanceHolder;
```

---

## **Swap Execution (_swap Function)**
```solidity
uint256 balanceBeforeSwap = getBalance(_swapDesc.dstToken);
(bool success, ) = allowanceHolder.call{value: msg.value}(_swapDesc.data);
require(success, "swap failed");
uint256 balanceAfterSwap = getBalance(_swapDesc.dstToken);
uint256 swapOutput = balanceAfterSwap - balanceBeforeSwap;
```

---

## **Token Approvals**
```solidity
uint256 allowance = IERC20(_token).allowance(address(this), _spender);
if (allowance < _amount) {
    IERC20(_token).forceApprove(_spender, _amount);
}
```

---

## **Token Transfers**
```solidity
IERC20(_token).safeTransfer(_to, _amount);
IERC20(_token).safeTransferFrom(_from, address(this), _amount);
```

---

## **Pause/Unpause Contract**
```solidity
_pause();
_unpause();
```

---

## **Conclusion**
The above lines represent the **functional code** that directly contributes to the contract’s behavior. Non-functional lines, such as comments, event declarations, and struct definitions, are excluded.
