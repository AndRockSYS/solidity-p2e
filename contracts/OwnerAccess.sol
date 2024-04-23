//SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/Address.sol";

contract OwnerAccess {
	using Address for address payable;

	address public owner;
  	uint256 public ownerFee;

	constructor(uint256 _ownerFee) {
		owner = msg.sender;
		setOwnerFee(_ownerFee);
	}

	function setOwnerFee(uint256 _newOwnerFee) onlyOwner public {
		ownerFee = _newOwnerFee;
	}

	function collectFees() onlyOwner external {
		payable(owner).sendValue(address(this).balance);
	}

	modifier onlyOwner {
		require(msg.sender == owner, "You are not an owner");
		_;
	}
}