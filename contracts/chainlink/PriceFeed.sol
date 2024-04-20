// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

//add to readme https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum&page=1
contract PriceFeed {
	address owner;

	mapping(string => mapping(string => address)) public feeds;

    constructor() {
        owner = msg.sender;
    }

	function addPriceFeed(string calldata _symbolIn, string calldata _symbolOut, address _priceFeed) external {
		require(msg.sender == owner, "You are not an owner");
		feeds[_symbolIn][_symbolOut] = _priceFeed;
	}

    function getLatestPriceFeed(string calldata _symbolIn, string calldata _symbolOut) public view returns (int256, uint256) {
		address priceFeed = feeds[_symbolIn][_symbolOut];

        (, int256 answer, , uint256 timestamp, ) = AggregatorV3Interface(priceFeed).latestRoundData();
		return (answer, timestamp);
    }
}
