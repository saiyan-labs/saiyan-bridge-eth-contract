pragma solidity ^0.8.9;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface Token is IERC20 {}

contract TokenCustody is Ownable {
    bool public IsFrozen;
    mapping(bytes32 => bool) internal _unlocked;

    event Locked(uint256 amount, address tokenAddress, string aptosAddress, address indexed ethereumAddress);
    event Unlocked(uint256 amount, address tokenAddress, address indexed ethereumAddress, string aptosHash);

    modifier notFrozen() {
        require(
            !IsFrozen,
            "contract is frozen by owner"
        );
        _;
    }

    function lock(uint256 amount, address tokenAddress, string calldata aptosAddress) public payable notFrozen {
        require(
            tx.origin == msg.sender,
            "contract can't call this function"
        );
        if (tokenAddress == address(0)) {
            require(msg.value != 0, "no ether sent");
            emit Locked(msg.value, tokenAddress, aptosAddress, msg.sender);
        } else {
            require(amount != 0, "no tokens sent");
            Token(tokenAddress).transferFrom(msg.sender, address(this), amount);
            emit Locked(amount, tokenAddress, aptosAddress, msg.sender);
        }
    }

    // unlock should manage by multi-signature contracts, now is a normal address.
    function unlock(uint256 amount, address tokenAddress, address ethereumAddress, string calldata aptosHash) public notFrozen onlyOwner {
        require(ethereumAddress != address(0), "ethereumAddress is the zero address");
        bytes32 hash = keccak256(abi.encode(aptosHash));
        require(!_unlocked[hash], "same unlock hash has been executed");

        _unlocked[hash] = true;

        if (tokenAddress == address(0)) {
            payable(ethereumAddress).transfer(amount);
            emit Unlocked(amount, tokenAddress, ethereumAddress, aptosHash);
        } else {
            Token(tokenAddress).transfer(ethereumAddress, amount);
            emit Unlocked(amount, tokenAddress, ethereumAddress, aptosHash);
        }
    }

    function freeze() public onlyOwner {
        IsFrozen = true;
    }

    function unfreeze() public onlyOwner {
        IsFrozen = false;
    }

    // should migrate to multi-signature contracts in the future
    function migrate(address tokenAddress, address newContractAddress) public onlyOwner {
        if (tokenAddress == address(0)) {
            payable(newContractAddress).transfer(address(this).balance);
        } else {
            Token(tokenAddress).transfer(newContractAddress, Token(tokenAddress).balanceOf(address(this)));
        }
    }
}