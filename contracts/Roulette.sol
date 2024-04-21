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
        Color winColor;
        uint256 timestamp;

		uint256 blackPool;
		uint256 redPool;
		uint256 greenPool;
    }

    uint8[] redNumbers = [1,3,5,7,9,12,14,16,18,21,23,25,27,28,30,32,34,36];

    mapping(uint256 => Round) public rounds;
	mapping(uint256 => mapping(address => uint256)) bets;

    event CreateRoulette(uint256 round);
    event EnterRoulette(address indexed player, uint256 bet, Color color);
    event CloseRoulette(uint256 round, uint256 totalPool, Color winColor);

	constructor(uint256 _ownerFee, address _numberGenerator) {
		Generator = NumberGenerator(_numberGenerator);

		owner = msg.sender;
		setOwnerFee(_ownerFee);
    }

    function createRound() onlyOwner external {
		Round memory currentRound = rounds[roundId];
        require(currentRound.winColor == Color(0) && currentRound.timestamp == 0, "Current round is not closed");

        rounds[roundId].timestamp = block.timestamp;

        emit CreateRoulette(roundId);
    }
	//push player to array on backend depends on which color he chose
    function enterRound(Color _color) external payable {
        require(rounds[roundId].timestamp + roundTime > block.timestamp, "Round is closed");
		require(msg.value >= minBet, "Your bet is too low");
        require(msg.value <= maxBet, "Your bet is too high");

		bets[roundId][msg.sender] += msg.value;

		if(_color == Color(1))
			rounds[roundId].blackPool += msg.value;
		else if(_color == Color(2))
			rounds[roundId].redPool += msg.value;
		else 
			rounds[roundId].greenPool += msg.value;

        emit EnterRoulette(msg.sender, msg.value, _color);
    }
	//add to readme that need to be called before close round
    function sendRequestForNumber() onlyOwner external {
        require(rounds[roundId].timestamp + roundTime < block.timestamp, "Round is not closed");
        currentRequestId = Generator.generateRandomNumber();
    }
	//data is taking from backend to make it cheaper
    function closeRound(address[] calldata _black, address[] calldata _red, address[] calldata _green) onlyOwner external {
		require(currentRequestId == 0, "Request for number was not sent");

        (bool isFullFilled, uint256 number) = Generator.getRequestStatus(currentRequestId);
        require(isFullFilled, "The request was not fullfilled");

        Color winningColor = _convertNumberToColor(number);

		(uint256 blackPool, uint256 redPool, uint256 greenPool) = getPools(roundId);
		uint256 totalPool = blackPool + redPool + greenPool;

		uint256 winnerPool = winningColor == Color(1) ? blackPool : 
		winningColor == Color(2) ? redPool : greenPool;

        _payToWinner(winningColor == Color(1) ? _black : 
		winningColor == Color(2) ? _red : _green, winnerPool, totalPool - winnerPool);

        emit CloseRoulette(roundId, totalPool, winningColor);

        unchecked {
            roundId++;
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

	function _payToWinner(address[] calldata _winners, uint256 _winnerPool, uint256 _prizePool) internal {
        for(uint256 i = 0; i < _winners.length; i++) {
			address winner = _winners[i];

			uint256 userBet = bets[roundId][winner];

            payable(winner).sendValue(_prizePool * userBet / _winnerPool);
        }
	}

	function getPools(uint256 _roundId) public view returns(uint256, uint256, uint256) {
		Round memory round = rounds[_roundId];
		return (round.blackPool, round.redPool, round.greenPool);
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