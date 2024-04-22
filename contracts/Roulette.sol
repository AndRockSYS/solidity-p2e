//SPDX-License-Identifier:MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/Address.sol";

import "./chainlink/NumberGenerator.sol";

contract Roulette {
    using Address for address payable;

    NumberGenerator public Generator;

  	address owner;
  	uint256 ownerFee;

    uint256 minBet = 0.005 ether;
    uint256 maxBet = 1000 ether;
    uint256 roundTime = 1 minutes;

    uint256 public roundId;
	uint256 public currentRequestId;
	
    enum Color { 
		Unknown, 
		Black, 
		Red,
		Green 
	}

    struct Round {
        Color winningColor;
        uint256 timestamp;

		uint256 blackPool;
		uint256 redPool;
		uint256 greenPool;
    }

	struct Bet {
		address player;
		Color betColor;
		uint256 amount;
	}

    uint8[] redNumbers = [1,3,5,7,9,12,14,16,18,21,23,25,27,28,30,32,34,36];

    mapping(uint256 => Round) public rounds;

    event CreateRoulette(uint256 round);
    event EnterRoulette(address indexed player, uint256 bet, Color color);
    event CloseRoulette(uint256 round, uint256 totalPool, Color winningColor);

	constructor(uint256 _ownerFee, address _numberGenerator) {
		Generator = NumberGenerator(_numberGenerator);

		owner = msg.sender;
		setOwnerFee(_ownerFee);
    }

    function createRound() onlyOwner external {
		Round memory currentRound = rounds[roundId];
        require(currentRound.winningColor == Color(0) && currentRound.timestamp == 0, "Current round is not closed");

        rounds[roundId].timestamp = block.timestamp;

        emit CreateRoulette(roundId);
    }

    function enterRound(Color _betColor) external payable {
        require(rounds[roundId].timestamp + roundTime > block.timestamp, "Round is closed");
		require(msg.value >= minBet, "Your bet is too low");
        require(msg.value <= maxBet, "Your bet is too high");

		if(_betColor == Color(1))
			rounds[roundId].blackPool += msg.value;
		else if(_betColor == Color(2))
			rounds[roundId].redPool += msg.value;
		else 
			rounds[roundId].greenPool += msg.value;

        emit EnterRoulette(msg.sender, msg.value, _betColor);
    }

    function sendRequestForNumber() onlyOwner external {
        require(rounds[roundId].timestamp + roundTime < block.timestamp, "Round is not closed");
        currentRequestId = Generator.generateRandomNumber();
    }
	//data is taking from backend to make it cheaper
    function closeRound(Bet[] calldata _black, Bet[] calldata _red, Bet[] calldata _green) onlyOwner external {
		require(rounds[roundId].timestamp + roundTime < block.timestamp, "Round is not closed");

        (bool isFullFilled, uint256 number) = Generator.getRequestStatus(currentRequestId);
        require(isFullFilled, "The request was not fulfilled");

        Color winningColor = _convertNumberToColor(number);
		rounds[roundId].winningColor = winningColor;

		(uint256 blackPool, uint256 redPool, uint256 greenPool) = getPools(roundId);
		uint256 totalPool = blackPool + redPool + greenPool;

		uint256 winnerPool = winningColor == Color(1) ? blackPool : 
		winningColor == Color(2) ? redPool : greenPool;

		uint256 comission = totalPool * ownerFee / 100;

		if(totalPool > winnerPool + comission) 
		    _payToWinner(winningColor == Color(1) ? _black : 
			winningColor == Color(2) ? _red : _green, winnerPool, totalPool - winnerPool - comission);

        emit CloseRoulette(roundId, totalPool, winningColor);

        unchecked {
            roundId++;
			currentRequestId = 0;
        }
    }

    function _convertNumberToColor(uint256 _number) internal view returns (Color) {
		uint16 winningNumber;

		unchecked {
			uint8 newRange = uint8(_number);
			winningNumber = uint16(newRange) * 37 / 256;
		}

		Color winningColor = winningNumber == 0 ? Color(3) : Color(1);

        for(uint8 i = 0; i < redNumbers.length; i++) {
            if(redNumbers[i] == winningNumber) 
				winningColor = Color(2);
        }

        return winningColor;
    }

	function _payToWinner(Bet[] calldata _winners, uint256 _winnerPool, uint256 _prizePool) internal {
		if(_prizePool == 0) return;

		for(uint256 i = 0; i < _winners.length; i++) {
			Bet memory userBet = _winners[i];

            payable(userBet.player).sendValue(_prizePool * userBet.amount / _winnerPool + userBet.amount);
        }
	}

	function getPools(uint256 _roundId) public view returns(uint256, uint256, uint256) {
		Round memory round = rounds[_roundId];
		return (round.blackPool, round.redPool, round.greenPool);
	}

	function getWinningColor(uint256 _roundId) public view returns(Color) {
		require(_roundId < roundId, "Round does not exist");

		Color winningColor = rounds[_roundId].winningColor;
		require(winningColor != Color(0), "Round does not have a winner");

		return winningColor;
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