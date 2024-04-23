//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/Address.sol";

import "./chain.link/NumberGenerator.sol";

contract Wheel {
    using Address for address payable;

    NumberGenerator public Generator;

  	address owner;
  	uint256 ownerFee;

    uint256 minBet = 0.005 ether;
    uint256 maxBet = 1000 ether;
    uint256 roundTime = 1 minutes;

	uint256 public spindId;
	uint256 public requestId;

    enum Color {
		Unknown,
		Black, 
		Red, 
		Blue, 
		Gold
	}

    uint8[] blueNumbers = [1, 9, 11, 19, 21, 29, 31, 39, 41, 49];

    struct Spin {
        Color winningColor;
        uint256 pool;
        uint256 timestamp;
    }

	struct Bet {
		address player;
		uint256 bet;
	}

    mapping(uint256 => Spin) public spins;

    event CreateWheel(uint256 spinId);
    event EnterWheel(address indexed player, uint256 bet, Color bettingColor);
    event CloseWheel(Color winningColor, uint256 pool);

    constructor(uint256 _ownerFee, address _numberGenerator) {
		Generator = NumberGenerator(_numberGenerator);

      	owner = msg.sender;
      	ownerFee = _ownerFee;
    }

    function createWheel() external onlyOwner {
        require(spins[spindId].timestamp == 0, "Previous round is not closed");

        spins[spindId].timestamp = block.timestamp;
        emit CreateWheel(roundId);
    }
	//saving players on backend
    function enterWheel(Color _bettingColor) payable external {
        require(spins[spinId].timestamp + roundTime > block.timestamp, "Round is closed");
		require(msg.value >= minBet, "Your bet is too low");
        require(msg.value <= maxBet, "Your bet is too high");

        spins[spinId].pool += msg.value;

        emit EnterWheel(msg.sender, msg.value, _bettingColor);
    }

    function sendRequestForNumber() onlyOwner external {
        require(spins[spindId].timestamp + roundTime < block.timestamp, "Round is not closed");
        currentRequestId = Generator.generateRandomNumber();
    }
	//Wheel has 24 black 15 red 10 blue 1 gold
    function closeWheel() external onlyOwner {
        require(spins[spinId].createdAt + timeToStart < block.timestamp, "Round is not closed");

        (uint256 randomNumber, bool hasSet) = Generator.get
        require(hasSet, "The number was not set yet");

        Color winningColor = _selectWinningColor(randomNumber);

        uint256 comission = spins[spinId].totalPool / 100 * percentageForOwner;

        spins[spinId].winColor = win;

        address[] memory winners = spins[spinId].black; //selecting winners depends on winning number
        if(win == Color(1)) winners = spins[spinId].red;
        if(win == Color(2)) winners = spins[spinId].blue;
        if(win == Color(3)) winners = spins[spinId].gold;

        if(winners.length > 0) { //pay to winners
            uint256 winMoney = (spins[spinId].totalPool - comission) / winners.length;

            for(uint8 i = 0; i < winners.length; i++) {
                payable(winners[i]).sendValue(winMoney);
            }
        }

        emit CloseWheel(win, spins[spinId].totalPool);

        unchecked {
            spinId++;
			requestId = 0;
        }
    }

    function _selectWinningColor(uint256 _randomNumber) internal view returns(Color) {
		unchecked {
			uint8 smallRange = uint8(_randomNumber);
			uint16 biggerRange = uint16(smallRange);
			uint16 winningNumber = biggerRange * 50 / 256;

			if(winningNumber == 0) 
				return Color(4);
			if(winningNumber % 2 == 0) 
				return Color(1);

			for(uint8 i = 0; i < blueNumbers.length; i++) {
				if(winningNumber == blueNumbers[i]) 
					return Color(3);
			}

			return Color(2);
		}
    }

	function setOwnerFee(uint256 _newOwnerFee) onlyOwner public {
		ownerFee = _newOwnerFee;
	}

	function collectFees() onlyOwner external {
		payable(owner).sendValue(address(this).balance);
	}

    modifier onlyOwner {
        require(msg.sender == owner, "You are not the owner");
        _;
    }

}