// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./chain.link/VRFv2.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract JackpotWheel {
    
    using Address for address payable;

    VRFv2 public VRF_V2;

    uint64 percentageForOwner;
    address owner;

    uint256 minBet = 0.005 ether;
    uint256 maxBet = 1000 ether;
    uint256 timeToStart = 1 minutes;

    uint256 public currentRound;

    struct Spin {
        address winner;
        uint256 totalPool;

        uint256 createdAt;

        Player[] players;
    }

    struct Player {
        address player;
        uint256 bet;
    }

    mapping(uint256 => Spin) public spins;

    event CreateWheel(uint256 _wheelRound);
    event EnterWheel(address indexed _account, uint256 _bet);
    event Winner(address indexed _winner, uint256 _winningAmount);

    constructor(uint64 _percentageForOwner, uint64 _subscriptionId) {
      owner = msg.sender;
      percentageForOwner = _percentageForOwner;

      VRF_V2 = new VRFv2(_subscriptionId); //random number generator
    }

    function createWheel() external onlyOwner {
        require(spins[currentRound].createdAt == 0, "This round has not been ended"); //check if this round exists
        spins[currentRound].createdAt = block.timestamp;

        emit CreateWheel(currentRound);
    }

    function enterWheel() external payable checkSender {
        require(msg.value >= minBet && msg.value <= maxBet, "Your bet is too low or too high");
        require(spins[currentRound].createdAt + timeToStart < block.timestamp, "Bets are closed");

        spins[currentRound].totalPool += msg.value;
        spins[currentRound].players.push(Player(msg.sender, msg.value)); //adding player to an array of players

        emit EnterWheel(msg.sender, msg.value);
    }

    function generateNumber() external onlyOwner {
        require(block.timestamp > spins[currentRound].createdAt + timeToStart, "You can not start the game now");

        VRF_V2.requestRandomWords(currentRound); //generate random number
    }
    //this function must be run only after event in VRFv2.sol was emited
    function closeWheel() external onlyOwner {
        require(spins[currentRound+1].createdAt == 0, "This round was ended");
        (uint256 randomNumber,bool hasSet) = VRF_V2.getRandomNumberByJackpotWheelRound(currentRound);
        require(hasSet, "The number was not set yet");
        uint256 comission = spins[currentRound].totalPool * percentageForOwner/100;

        uint256 winNumber;

        unchecked {
            uint16 newRange = uint16(randomNumber); //random number to new range
            winNumber = uint256(newRange) * 10000 / 65536; // new random number to range from 0 to 10_000
        }

        uint256 previous = 0;
        Player[] memory actualPlayers = spins[currentRound].players;

        for(uint i = 0; i < actualPlayers.length; i++) { //finding a winner by adding players number to total
            previous += actualPlayers[i].bet * 10000 / spins[currentRound].totalPool;
            if(previous >= winNumber) { //adding until the number equal or higher
                spins[currentRound].winner = actualPlayers[i].player; //if so, the person who last added his number is the winner
                break;
            }
        }
        payable(spins[currentRound].winner).sendValue(spins[currentRound].totalPool - comission); //paying to winner
        
        payable(owner).sendValue(comission);
        
        emit Winner(spins[currentRound].winner, spins[currentRound].totalPool - comission);

        unchecked {
            currentRound++;
        }
    }

    function setNewPercentage(uint64 _newPercentage) external onlyOwner {
        percentageForOwner = _newPercentage;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "You are not the owner");
        _;
    }

    modifier checkSender {
        require(msg.sender != address(0), "This account does not exist");
        _;
    }

}