// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/Address.sol";

import "./chainlink/NumberGenerator.sol";

contract Jackpot {
    using Address for address payable;

    NumberGenerator public Generator;

    address owner;
	uint256 ownerFee;

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

    struct Bet {
        address player;
        uint256 amount;
    }

    mapping(uint256 => Round) public rounds;

    event CreateJackpot(uint256 roundId);
    event EnterJackpot(address indexed player, uint256 bet);
    event CloseJackpot(address indexed winner, uint256 winningAmount);

    constructor(uint256 _ownerFee, address _numberGenerator) {
		Generator = NumberGenerator(_numberGenerator);

      	owner = msg.sender;
      	ownerFee = _ownerFee;
    }

    function createJackpot() onlyOwner external {
        require(rounds[roundId].timestamp == 0, "Previous round is still going");

        rounds[roundId].timestamp = block.timestamp;

        emit CreateJackpot(roundId);
    }

    function enterJackpot() payable external {
        require(rounds[roundId].timestamp + roundTime > block.timestamp, "Round is closed");
		require(msg.value >= minBet, "Your bet is too low");
        require(msg.value <= maxBet, "Your bet is too high");

        rounds[roundId].pool += msg.value;

        emit EnterJackpot(msg.sender, msg.value);
    }

    function sendRequestForNumber() onlyOwner external {
        require(rounds[roundId].timestamp + roundTime < block.timestamp, "Round is not closed");
        requestId = Generator.generateRandomNumber();
    }

    function closeJackpot(Bet[] calldata _bets) external onlyOwner {
        require(rounds[roundId].timestamp + roundTime < block.timestamp, "Round is not closed");

        (bool isFullFilled, uint256 randomNumber) = Generator.getRequestStatus(requestId);
        require(isFullFilled, "The request was not fulfilled");

        uint256 winningNumber = _convertNumberToWinningNumber(randomNumber);

        address winner = _findAWinner(_bets, winningNumber, rounds[roundId].pool);

		uint256 comission = rounds[roundId].pool * ownerFee / 100;
		uint256 winningAmount = rounds[roundId].pool - comission;

		if(winner != address(0))
        	payable(winner).sendValue(winningAmount);

		rounds[roundId].winner = winner;
        
        emit CloseJackpot(winner, winningAmount);

        unchecked {
            roundId++;
			requestId = 0;
        }
    }

	function _convertNumberToWinningNumber(uint256 _number) internal pure returns (uint256) {
		uint16 newRange = uint16(_number);
        return uint256(newRange) * 10000 / 65536;
	}

	function _findAWinner(Bet[] calldata _bets, uint256 _winningNumber, uint256 _pool) internal pure returns (address) {
		uint256 sum = 0;

		for(uint i = 0; i < _bets.length; i++) {
            sum += _bets[i].amount * 10000 / _pool;

            if(sum >= _winningNumber)
                return _bets[i].player;
        }

		return address(0);
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