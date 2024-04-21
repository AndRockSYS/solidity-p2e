//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/Address.sol";
import "./chain.link/VRFv2.sol";

contract ColorWheel { //Wheel has 24 black 15 red 10 blue 1 gold

    using Address for address payable;

    VRFv2 public VRF_V2;

    address owner;
    uint256 percentageForOwner;
    uint256 treasury;

    uint256 public currentRound;

    uint256 minBet = 0.005 ether;
    uint256 maxBet = 1000 ether;
    uint256 timeToStart = 1 minutes;

    enum Color {BLACK, RED, BLUE, GOLD} //availible numbers on wheel

    uint8[] blues = [1, 9, 11, 19, 21, 29, 31, 39, 41, 49]; //all blue numbers

    struct Round {
        Color winColor;

        uint256 totalPool;
        uint256 createdAt;

        address[] black; //arrays of people who placed their bets on specific color
        address[] red;
        address[] blue;
        address[] gold;
    }

    mapping(uint256 => Round) public rounds;

    event CreateRound(uint256 roundNumber);
    event EnterRound(address indexed player, uint256 bet, Color selectedColor);
    event CloseRound(Color winColor, uint256 totalPool);

    constructor(uint256 _percentageForOwner, uint64 _subscriptionId) {
        percentageForOwner = _percentageForOwner;
        owner = msg.sender;

        VRF_V2 = new VRFv2(_subscriptionId); //RNG
    }

    function createRound() external onlyOwner {
        require(rounds[currentRound].createdAt == 0, "This round has not been ended"); //check if this round already exist

        rounds[currentRound].createdAt = block.timestamp;
        emit CreateRound(currentRound);
    }

    function enterRound(Color _selectedColor) payable external {
        require(rounds[currentRound].createdAt + timeToStart > block.timestamp, "Bets are closed");
        require(msg.value >= minBet && msg.value <= maxBet, "Your bet is not correct");

        rounds[currentRound].totalPool += msg.value;

        if(_selectedColor == Color(0)) rounds[currentRound].black.push(msg.sender); //adding player to an array depends on his chosen color
        if(_selectedColor == Color(1)) rounds[currentRound].red.push(msg.sender);
        if(_selectedColor == Color(2)) rounds[currentRound].blue.push(msg.sender);
        if(_selectedColor == Color(3)) rounds[currentRound].gold.push(msg.sender);

        emit EnterRound(msg.sender, msg.value, _selectedColor);
    }

    function requestRandomNumber() external onlyOwner {
        require(rounds[currentRound].createdAt + timeToStart < block.timestamp, "You can not request number now");

        VRF_V2.requestRandomWords(currentRound);
    }
    //this function must be run only after event in VRFv2.sol was emited
    function closeRound() external onlyOwner {
        require(rounds[currentRound].createdAt + timeToStart < block.timestamp, "You can not close wheel now");
        (uint256 randomNumber, bool hasSet) = VRF_V2.getRandomNumberByColorWheelRound(currentRound);
        require(hasSet, "The number was not set yet");

        Color win; //winning color

        uint256 comission = rounds[currentRound].totalPool / 100 * percentageForOwner;

        unchecked {
            uint8 oldRange = uint8(randomNumber); //computate random number to an another range (0 to 49)
            uint16 newRange = uint16(oldRange);
            uint16 winNumber = newRange / 256 * 50;
            win = selectWinnerColor(winNumber);
        }

        rounds[currentRound].winColor = win;

        address[] memory winners = rounds[currentRound].black; //selecting winners depends on winning number
        if(win == Color(1)) winners = rounds[currentRound].red;
        if(win == Color(2)) winners = rounds[currentRound].blue;
        if(win == Color(3)) winners = rounds[currentRound].gold;

        if(winners.length > 0) { //pay to winners
            uint256 winMoney = (rounds[currentRound].totalPool - comission) / winners.length;

            for(uint8 i = 0; i < winners.length; i++) {
                payable(winners[i]).sendValue(winMoney);
            }
        } else treasury += rounds[currentRound].totalPool; //adding pool to treasury if there are no winners
        payable(owner).sendValue(comission);

        emit CloseRound(win, rounds[currentRound].totalPool);

        unchecked {
            currentRound++;
        }
    }
    //selecting winning color depends on random number in a new range
    function selectWinnerColor(uint16 _winNumber) internal view returns(Color) {
        if(_winNumber == 0) return Color(3);
        if(_winNumber % 2 == 0) return Color(0);
        for(uint8 i = 0; i < blues.length; i++) {
            if(_winNumber == blues[i]) return Color(2);
        }
        return Color(1);
    }
    //receive money from treasury
    function getFromTreasury(uint256 _amount) external onlyOwner {
        require(_amount <= treasury, "Amount is bigger tha treasury contains");

        treasury -= _amount;
        payable(msg.sender).sendValue(_amount);
    }

    modifier checkSender {
        require(msg.sender != address(0), "This account does not exist");
        _;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "You are not the owner");
        _;
    }

}