//SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/Address.sol";

import "../security/Ownable.sol";

contract PaymentManagement is Ownable {
	using Address for address payable;

	uint256 ownerFee;

	struct Bet {
		address player;
		uint256 amount;
	}

	constructor(uint256 _ownerFee) {
		setOwnerFee(_ownerFee);
	}
	
	function _payToWinnersBasedOnTheirBet(Bet[] calldata _winners, uint256 _winningPool, uint256 _totalPool) internal returns (uint256) {
		uint256 comission = _totalPool * ownerFee / 100;
		uint256 prizePool = _totalPool - comission;

		if(_winners.length > 0 && prizePool > _winningPool) {
			for(uint256 i = 0; i < _winners.length; i++) {
				Bet memory bet = _winners[i];

				payable(bet.player).sendValue(prizePool * bet.amount / _winningPool + bet.amount);
        	}
		}

		return prizePool;
	}

	function setOwnerFee(uint256 _newOwnerFee) onlyOwner public {
		ownerFee = _newOwnerFee;
	}

	function collectFees() onlyOwner external {
		payable(owner).sendValue(address(this).balance);
	}
}