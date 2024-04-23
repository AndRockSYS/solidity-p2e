//SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/Address.sol";

import "../OwnerAccess.sol";

import "../chainlink/NumberGenerator.sol";

contract Roulette is OwnerAccess {
    using Address for address payable;

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
        Color winningColor;
		uint256[3] pools;
		uint256 timestamp;
    }

	struct Bet {
		address player;
		Color bettingColor;
		uint256 amount;
	}

    uint8[] redNumbers = [1,3,5,7,9,12,14,16,18,21,23,25,27,28,30,32,34,36];

    mapping(uint256 => Round) public rounds;

    event CreateRoulette(uint256 round);
    event EnterRoulette(address indexed player, uint256 bet, Color color);
    event CloseRoulette(uint256 round, uint256 totalPool, Color winningColor);

	constructor(uint256 _ownerFee, address _numberGenerator) OwnerAccess(_ownerFee) {
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

		if(_bettingColor == Color.Black)
        	rounds[roundId].pools[0] += msg.value;
		if(_bettingColor == Color.Red)
			rounds[roundId].pools[1] += msg.value;
		if(_bettingColor == Color.Green)
        	rounds[roundId].pools[2] += msg.value;

        emit EnterRoulette(msg.sender, msg.value, _bettingColor);

		return Bet(msg.sender, _bettingColor, msg.value);
    }

    function sendRequestForNumber() onlyOwner external {
        require(rounds[roundId].timestamp + roundTime < block.timestamp, "Round is not closed");
        requestId = Generator.generateRandomNumber();
    }
	//call it before closing the round
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
	//data is taking from backend to make it cheaper
    function closeRound(Color _winningColor, Bet[] calldata _winningBets) onlyOwner external {
		rounds[roundId].winningColor = _winningColor;
		Round memory round = rounds[roundId];

		uint256 totalPool;
		for(uint8 i = 0; i < 3; i++) {
			totalPool += round.pools[i];
		}

		uint256 comission = totalPool * ownerFee / 100;
		uint256 poolToPay = totalPool - comission;

		uint256 poolId = _winningColor == Color.Black ? 0 : 
		_winningColor == Color.Red ? 1 : 2;

		if(poolToPay > round.pools[poolId]) 
		    _payToWinner(_winningBets, round.pools[poolId], poolToPay - round.pools[poolId]);

        emit CloseRoulette(roundId, poolToPay, _winningColor);

        unchecked {
            roundId++;
			requestId = 0;
        }
    }

	function _payToWinner(Bet[] calldata _winners, uint256 _winnerPool, uint256 _prizePool) internal {
		if(_prizePool == 0) return;

		for(uint256 i = 0; i < _winners.length; i++) {
			Bet memory userBet = _winners[i];

            payable(userBet.player).sendValue(_prizePool * userBet.amount / _winnerPool + userBet.amount);
        }
	}

	function getWinningColor(uint256 _roundId) public view returns (Color) {
		require(_roundId < roundId, "Round does not exist");

		Color winningColor = rounds[_roundId].winningColor;
		require(winningColor != Color.Unknown, "Round does not have a winner");

		return winningColor;
	}

}