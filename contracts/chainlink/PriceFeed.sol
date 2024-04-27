// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import { Ownable } from "../security/Ownable.sol";

//add to readme https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum&page=1
contract PriceFeed is Ownable {
	mapping(string => mapping(string => address)) public feeds;

	function addPriceFeed(string[2] calldata _symbols, address _priceFeed) onlyOwner external {
		require(feeds[_symbols[0]][_symbols[1]] == address(0), "Price feed for this pair exists");
		require(feeds[_symbols[1]][_symbols[0]] == address(0), "Price feed for this pair is reversed");

		feeds[_symbols[0]][_symbols[1]] = _priceFeed;
	}

    function getLatestPriceFeed(string[2] calldata _symbols) public view returns (int256, uint256) {
		require(feeds[_symbols[0]][_symbols[1]] != address(0), "Price feed for that pair was not set up");

		address priceFeed = feeds[_symbols[0]][_symbols[1]];

        (, int256 answer, , uint256 timestamp, ) = AggregatorV3Interface(priceFeed).latestRoundData();
		return (answer, timestamp);
    }
}
