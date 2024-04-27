// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import { Ownable } from "../security/Ownable.sol";

//add to readme https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum&page=1
contract PriceFeed is Ownable {
	mapping(string => mapping(string => address)) public feeds;

	function addPriceFeed(string calldata _symbolIn, string calldata _symbolOut, address _priceFeed) onlyOwner external {
		feeds[_symbolIn][_symbolOut] = _priceFeed;
	}

    function getLatestPriceFeed(string calldata _symbolIn, string calldata _symbolOut) public view returns (int256, uint256) {
		address priceFeed = feeds[_symbolIn][_symbolOut];

        (, int256 answer, , uint256 timestamp, ) = AggregatorV3Interface(priceFeed).latestRoundData();
		return (answer, timestamp);
    }
}
