// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { VRFCoordinatorV2Interface } from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import { VRFConsumerBaseV2 } from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

contract NumberGenerator is VRFConsumerBaseV2 {
	address owner;

	VRFCoordinatorV2Interface COORDINATOR;
    uint64 subscriptionId;
    bytes32 keyHash;
	
    uint32 callbackGasLimit = 100000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;

	struct Request {
        bool fulfilled;
        bool exists;
        uint256 randomNumber;
    }

    mapping(uint256 => Request) public requests;
	mapping(address => bool) approval;

	event RequestSent(uint256 requestId);
    event RequestFulfilled(uint256 requestId, uint256 randomNumber);

    constructor(address _coordinator, uint64 _subscriptionId, bytes32 _keyHash) VRFConsumerBaseV2(_coordinator)  {
		owner = msg.sender;

    	COORDINATOR = VRFCoordinatorV2Interface(_coordinator);
    	subscriptionId = _subscriptionId;
		keyHash = _keyHash;
    }

	function approve(address _contract, bool _isApproved) external {
		require(msg.sender == owner, "You are not the owner");
		approval[_contract] = _isApproved;
	}

    function generateRandomNumber() onlyApproved external returns (uint256 requestId) {
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );

        requests[requestId] = Request({
			fulfilled: false,
            exists: true,
			randomNumber: 0
        });

        emit RequestSent(requestId);

        return requestId;
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) requestExist(_requestId) internal override {
        requests[_requestId].fulfilled = true;
        requests[_requestId].randomNumber = _randomWords[0];

        emit RequestFulfilled(_requestId, _randomWords[0]);
    }

    function getRequestStatus(uint256 _requestId) requestExist(_requestId) onlyApproved external view returns (bool, uint256) {
        Request memory request = requests[_requestId];

        return (request.fulfilled, request.randomNumber);
    }

	modifier requestExist(uint256 _requestId) {
		require(requests[_requestId].exists, "Request does not exist");
		_;
	}

	modifier onlyApproved {
		require(approval[msg.sender], "You are not allowed to use generator");
		_;
	}
}