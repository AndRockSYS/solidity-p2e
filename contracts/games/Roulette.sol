//SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import "../chainlink/NumberGenerator.sol";

import "../utils/PaymentManagement.sol";

contract Roulette is PaymentManagement {
    NumberGenerator public Generator;

    uint256 minBet = 0.005 ether;
    uint256 maxBet = 1000 ether;
    uint256 roundTime = 1 minutes;

    uint256 public roundId;
	uint256 public requestId;
	
    enum Color { 
		Unknown, 
		Black, 
		Red,
		Green 
	}

    struct Round {
		uint256[3] pools;
        Color winningColor;
		uint256 timestamp;
    }

    uint8[] redNumbers = [1,3,5,7,9,12,14,16,18,21,23,25,27,28,30,32,34,36];

    mapping(uint256 => Round) public rounds;

    event CreateRoulette(uint256 round);
    event EnterRoulette(address indexed player, uint256 bet, Color color);
    event CloseRoulette(uint256 round, uint256 totalPool, Color winningColor);

	constructor(uint256 _ownerFee, address _numberGenerator) PaymentManagement(_ownerFee) {
		Generator = NumberGenerator(_numberGenerator);
    }

    function createRound() onlyOwner external {
        require(rounds[roundId].timestamp == 0, "Current round is not closed");

        rounds[roundId].timestamp = block.timestamp;

        emit CreateRoulette(roundId);
    }

    function enterRound(Color _bettingColor) external payable returns (Bet memory) {
        require(rounds[roundId].timestamp + roundTime > block.timestamp, "Round is closed");
		require(msg.value >= minBet, "Your bet is too low");
        require(msg.value <= maxBet, "Your bet is too high");

		uint256 poolId = _bettingColor == Color.Black ? 0 : 
		_bettingColor == Color.Red ? 1 : 2;
        rounds[roundId].pools[poolId] += msg.value;

        emit EnterRoulette(msg.sender, msg.value, _bettingColor);

		return Bet(msg.sender, msg.value);
    }

    function sendRequestForNumber() onlyOwner external {
        require(rounds[roundId].timestamp + roundTime < block.timestamp, "Round is not closed");
        requestId = Generator.generateRandomNumber();
    }

	function calculateWinningColor() onlyOwner external view returns (Color) {
		require(rounds[roundId].timestamp + roundTime < block.timestamp, "Round is not closed");

        (bool isFullFilled, uint256 randomNumber) = Generator.getRequestStatus(requestId);
        require(isFullFilled, "The request was not fulfilled");

		unchecked {
			uint8 newRange = uint8(randomNumber);
			uint16 winningNumber = uint16(newRange) * 37 / 256;

			Color winningColor = winningNumber == 0 ? Color.Green : Color.Black;

        	for(uint8 i = 0; i < redNumbers.length; i++) {
           		if(redNumbers[i] == winningNumber) 
					winningColor = Color.Red;
        	}

			return winningColor;
		}
	}

    function closeRound(Bet[] calldata _winningBets, Color _winningColor) onlyOwner external {
		rounds[roundId].winningColor = _winningColor;
		Round memory round = rounds[roundId];

		uint256 winningPoolId = _winningColor == Color.Black ? 0 : 
		_winningColor == Color.Red ? 1 : 2;

		uint256 totalPool;
		for(uint8 i = 0; i < 3; i++) {
			totalPool += round.pools[i];
		}

		uint256 prizePool = _payToWinnersBasedOnTheirBet(_winningBets, round.pools[winningPoolId], totalPool);

        emit CloseRoulette(roundId, prizePool, _winningColor);

        unchecked {
            roundId++;
			requestId = 0;
        }
    }

	function getPools(uint256 _roundId) public view returns (uint256[3] memory) {
		return rounds[_roundId].pools;
	}

	function getWinningColor(uint256 _roundId) public view returns (Color) {
		require(_roundId < roundId, "Round does not exist");

		Color winningColor = rounds[_roundId].winningColor;
		require(winningColor != Color.Unknown, "Round does not have a winner");

		return winningColor;
	}

}