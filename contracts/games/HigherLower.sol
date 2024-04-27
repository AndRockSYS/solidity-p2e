//SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/Address.sol";

import "../chainlink/PriceFeed.sol";

import "../utils/PaymentManagement.sol";

contract HigherLower is PaymentManagement {
    PriceFeed public Feed;

    uint256 minBet = 0.005 ether;
	uint256 maxBet = 1 ether;
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
		string[2] symbols;
		int256[2] prices;
        Prediction result;
		uint256[2] pools;
		uint256 timestamp;
    }

    mapping(uint256 => Round) public rounds;

    event CreateRound(uint256 roundId, int256 startPrice);
    event EnterRound(address indexed player, uint256 bet, Prediction prediction);
    event CloseRound(uint256 roundId, int256 endPrice, Prediction result);

    constructor(uint256 _ownerFee, address _priceFeed) PaymentManagement(_ownerFee) {
		Feed = PriceFeed(_priceFeed);
    }

    function createRound(string[2] calldata _symbols) external onlyOwner {
        require(rounds[roundId].result == Prediction(0), "Current round is not closed");
		(int256 startPrice, ) = Feed.getLatestPriceFeed(_symbols);

		rounds[roundId].symbols = _symbols;
		rounds[roundId].prices[0] = startPrice;
        rounds[roundId].timestamp = block.timestamp;

        emit CreateRound(roundId, startPrice);

		unchecked {
            roundId++;
        }
    }
	//add to readme - add player to backend dependin on its prediction
    function enterRound(uint256 _roundId, Prediction _prediction) external payable {
		require(rounds[_roundId].timestamp + roundTime > block.timestamp, "Round is closed");
		require(msg.value >= minBet, "Your bet is too low");
        require(msg.value <= maxBet, "Your bet is too high");

		uint8 poolId = _prediction == Prediction.Higher ? 1 : 0;
        rounds[_roundId].pools[poolId] += msg.value;

        emit EnterRound(msg.sender, msg.value, _prediction);
    }

	function calculateWinner(uint256 _roundId) external onlyOwner returns (Prediction) {
		Round memory round = rounds[_roundId];
		require(round.timestamp + roundTime < block.timestamp, "Round is not closed");

		(int256 endPrice, uint256 updatedAt) = Feed.getLatestPriceFeed(round.symbols);
		require(round.timestamp < updatedAt, "Price was not updated");

		rounds[_roundId].prices[1] = endPrice;

		Prediction result = getResult(_roundId);
		rounds[_roundId].result = result;
		return result;
	}
	//send an array of winners depending on the result of getResult()
    function closeRound(uint256 _roundId, Bet[] calldata _winners) external onlyOwner {
		Round memory round = rounds[_roundId];

		if(round.result != Prediction.Equal) {
			uint256 winningPoolId = round.result == Prediction.Higher ? 1 : 0;
			uint256 winningPool = round.pools[winningPoolId];

			uint256 totalPool;
			for(uint8 i = 0; i < 2; i++) {
				totalPool += round.pools[i];
			}
			_payToWinnersBasedOnTheirBet(_winners, winningPool, totalPool);
		}

        emit CloseRound(_roundId, round.prices[1], round.result);
    }

	function getResult(uint256 _roundId) public view returns (Prediction) {
		require(_roundId >= roundId, "Round does not exist");

		int256[2] memory prices = rounds[_roundId].prices;

		if(prices[0] > prices[1])
			return Prediction.Lower;
		if(prices[0] < prices[1])
			return Prediction.Higher;
		if(prices[0] == prices[1])
			return Prediction.Equal;

		return Prediction.Unknown;
	}

}