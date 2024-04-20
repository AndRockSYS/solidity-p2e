//SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/Address.sol";

import "./chainlink/PriceFeed.sol";

contract HigherLower {
    using Address for address payable;

    PriceFeed public Feed;

    address owner;
    uint256 ownerFee;

    uint256 bet = 1 ether;
	uint256 roundTime = 60 seconds;

    uint256 public roundId;

    enum Prediction {
		Unknown,
		Lower, 
		Equal, 
		Higher
	}

	//address[] higher, address[] lower - will be stored on backend to save gas
    struct Round {
		int256 startPrice;
		int256 endPrice;
        Prediction result;
		uint256 pool;
		uint256 timestamp;
    }

    mapping(uint256 => Round) public rounds;

    event CreateRound(uint256 roundId, int256 startPrice);
    event EnterRound(address indexed player, uint256 bet, Prediction prediction);
    event CloseRound(uint256 roundId, int256 endPrice, Prediction result);

    constructor(uint256 _ownerFee, address _priceFeed) {
		Feed = PriceFeed(_priceFeed);

        owner = msg.sender;
		setOwnerFee(_ownerFee);
    }

    function createRound(string calldata _symbolIn, string calldata _symbolOut) external onlyOwner {
        require(rounds[roundId].result == Prediction(0), "Current round is not closed");
		(int256 startPrice, ) = Feed.getLatestPriceFeed(_symbolIn, _symbolOut);

        rounds[roundId].timestamp = block.timestamp;

        emit CreateRound(roundId, startPrice);
    }
	//add to readme - add player to backend dependin on its prediction
    function enterRound(Prediction _prediction) external payable {
		require(rounds[roundId].timestamp + roundTime > block.timestamp, "Round is closed");
		require(msg.value == bet, "Your bet is not correct");

        rounds[roundId].pool += msg.value;

        emit EnterRound(msg.sender, msg.value, _prediction);
    }
	//send arrays from backend
    function closeRound(string calldata _symbolIn, string calldata _symbolOut, address[] calldata _higher, address[] calldata _lower) external onlyOwner {
		Round memory currentRound = rounds[roundId];
        require(currentRound.timestamp + roundTime <= block.timestamp, "Round is still going");

        (int256 newPrice, uint256 updatedAt) = Feed.getLatestPriceFeed(_symbolIn, _symbolOut);
        require(updatedAt >= currentRound.timestamp, "The price was not updated yet");

		rounds[roundId].endPrice = newPrice;
		
		Prediction result = newPrice > currentRound.startPrice ? Prediction(3) :
		newPrice < currentRound.startPrice ? Prediction(1) : Prediction(2);
		rounds[roundId].result = result;
 
        uint256 fee = currentRound.pool * ownerFee / 100;
        uint256 prize = currentRound.pool - fee;

		if(result == Prediction(1))
			_payToWinners(_lower, prize);
		if(result == Prediction(3))
			_payToWinners(_higher, prize);

        emit CloseRound(roundId, newPrice, result);

        unchecked {
            roundId++;
        }
    }

	function _payToWinners(address[] calldata _winners, uint256 _prize) internal {
		uint256 perAddress = _prize / _winners.length;

		for(uint256 i = 0; i < _winners.length; i++) {
			payable(_winners[i]).sendValue(perAddress);
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