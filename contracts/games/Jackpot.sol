// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../chainlink/NumberGenerator.sol";

import "../utils/PaymentManagement.sol";

contract Jackpot is PaymentManagement {
    NumberGenerator public Generator;

    uint256 minBet = 0.005 ether;
    uint256 maxBet = 1000 ether;
    uint256 roundTime = 1 minutes;

    uint256 public roundId;
	uint256 public requestId;

    struct Round {
        address winner;
        uint256 pool;
        uint256 timestamp;
    }

    mapping(uint256 => Round) public rounds;

    event CreateJackpot(uint256 roundId);
    event EnterJackpot(address indexed player, uint256 bet);
    event CloseJackpot(address indexed winner, uint256 winningAmount);

    constructor(uint256 _ownerFee, address _numberGenerator) PaymentManagement(_ownerFee) {
		Generator = NumberGenerator(_numberGenerator);
    }

    function createJackpot() onlyOwner external {
        require(rounds[roundId].timestamp == 0, "Previous round is still going");

        rounds[roundId].timestamp = block.timestamp;

        emit CreateJackpot(roundId);
    }

    function enterJackpot() payable external returns (Bet memory) {
        require(rounds[roundId].timestamp + roundTime > block.timestamp, "Round is closed");
		require(msg.value >= minBet, "Your bet is too low");
        require(msg.value <= maxBet, "Your bet is too high");

        rounds[roundId].pool += msg.value;

        emit EnterJackpot(msg.sender, msg.value);

		return Bet(msg.sender, msg.value);
    }

    function sendRequestForNumber() onlyOwner external {
        require(rounds[roundId].timestamp + roundTime < block.timestamp, "Round is not closed");
        requestId = Generator.generateRandomNumber();
    }

    function closeJackpot(Bet[] calldata _bets) external onlyOwner {
        require(rounds[roundId].timestamp + roundTime < block.timestamp, "Round is not closed");

        (bool isFullFilled, uint256 randomNumber) = Generator.getRequestStatus(requestId);
        require(isFullFilled, "The request was not fulfilled");

        uint256 winningNumber; 
		
		unchecked {
			uint16 newRange = uint16(randomNumber);
        	winningNumber = uint256(newRange) * 10000 / 65536;
		}

        address winner = _calculateAWinner(_bets, winningNumber, rounds[roundId].pool);
		rounds[roundId].winner = winner;

		uint256 prizePool = _payToWinnedTheWholeSum(winner, rounds[roundId].pool, true);
        
        emit CloseJackpot(winner, prizePool);

        unchecked {
            roundId++;
			requestId = 0;
        }
    }

	function _calculateAWinner(Bet[] calldata _bets, uint256 _winningNumber, uint256 _pool) internal pure returns (address) {
		uint256 sum = 0;

		for(uint i = 0; i < _bets.length; i++) {
            sum += _bets[i].amount * 10000 / _pool;

            if(sum >= _winningNumber)
                return _bets[i].player;
        }

		return address(0);
	}

}