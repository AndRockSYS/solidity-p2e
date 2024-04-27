//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../chainlink/NumberGenerator.sol";

import "../utils/PaymentManagement.sol";

contract Wheel is PaymentManagement {
    NumberGenerator public Generator;

    uint256 minBet = 0.005 ether;
    uint256 maxBet = 1000 ether;
    uint256 roundTime = 1 minutes;

	uint256 public spinId;
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
        uint256[4] pools;
        uint256 timestamp;
    }

    mapping(uint256 => Spin) public spins;

    event CreateWheel(uint256 spinId);
    event EnterWheel(address indexed player, uint256 bet, Color bettingColor);
    event CloseWheel(uint256 spinId, Color winningColor, uint256 pool);

    constructor(uint256 _ownerFee, address _numberGenerator) PaymentManagement(_ownerFee) {
		Generator = NumberGenerator(_numberGenerator);
    }

    function createWheel() external onlyOwner {
        require(spins[spinId].timestamp == 0, "Previous round is not closed");

        spins[spinId].timestamp = block.timestamp;

        emit CreateWheel(spinId);
    }

    function enterWheel(Color _bettingColor) payable external returns (Bet memory) {
        require(spins[spinId].timestamp + roundTime > block.timestamp, "Round is closed");
		require(msg.value >= minBet, "Your bet is too low");
        require(msg.value <= maxBet, "Your bet is too high");

		uint256 poolId = _bettingColor == Color.Black ? 0 :
		_bettingColor == Color.Red ? 1 :
		_bettingColor == Color.Blue ? 2 : 3;

        spins[spinId].pools[poolId] += msg.value;

        emit EnterWheel(msg.sender, msg.value, _bettingColor);

		return Bet(msg.sender, msg.value);
    }

    function sendRequestForNumber() onlyOwner external {
        require(spins[spinId].timestamp + roundTime < block.timestamp, "Round is not closed");
        requestId = Generator.generateRandomNumber();
    }

	function calculateWinningColor() onlyOwner external view returns (Color) {
		require(spins[spinId].timestamp + roundTime < block.timestamp, "Round is not closed");

		(bool isFulfilled, uint256 randomNumber) = Generator.getRequestStatus(requestId);
        require(isFulfilled, "The request is not fulfilled");

		unchecked {
			uint8 smallRange = uint8(randomNumber);
			uint16 biggerRange = uint16(smallRange);
			uint16 winningNumber = biggerRange * 50 / 256;

			if(winningNumber == 0) 
				return Color.Gold;
			if(winningNumber % 2 == 0) 
				return Color.Black;

			for(uint8 i = 0; i < blueNumbers.length; i++) {
				if(winningNumber == blueNumbers[i]) 
					return Color.Blue;
			}

			return Color.Red;
		}
    }

    function closeWheel(Bet[] calldata _winningBets, Color _winningColor) external onlyOwner {
		spins[spinId].winningColor = _winningColor;
		Spin memory spin = spins[spinId];

		uint256 winningPoolId = spin.winningColor == Color.Black ? 0 :
		spin.winningColor == Color.Red ? 1 :
		spin.winningColor == Color.Blue ? 2 : 3;

		uint256 totalPool;
		for(uint8 i = 0; i < 4; i++) {
			totalPool += spin.pools[i];
		}

		uint256 prizePool = _payToWinnersBasedOnTheirBet(_winningBets, spin.pools[winningPoolId], totalPool);

        emit CloseWheel(spinId, spin.winningColor, prizePool);

        unchecked {
            spinId++;
			requestId = 0;
        }
    }

	function getPools(uint256 _spinId) public view returns (uint256[4] memory) {
		return spins[_spinId].pools;
	}

	function getWinningColor(uint256 _spinId) public view returns (Color) {
		require(_spinId < spinId, "Round does not exist");

		Color winningColor = spins[_spinId].winningColor;
		require(winningColor != Color.Unknown, "Round does not have a winner");

		return winningColor;
	}

}