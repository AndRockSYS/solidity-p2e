// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/Address.sol";

import "./chainlink/NumberGenerator.sol";

contract DuelsForTwo {
  	using Address for address payable;

  	NumberGenerator public Generator;

  	address owner;
  	uint256 ownerFee;

  	uint256 minBet = 0.005 ether;
  	uint256 maxBet = 1000 ether;
	uint256 lobbyLifeTime = 5 minutes;

	uint256 public lobbyId;

	enum Color {
		Unknown,
		Blue,
		Red
	}

	struct Lobby {
		address blue;
		address red;
		Color winner;
		uint256 pool;
		uint256 timestamp;
	}

 	mapping(uint256 => Lobby) public lobbies;
	mapping(uint256 => uint256) public requests;

    event CreateLobby(uint256 lobby, address indexed creator, uint256 bet);
  	event EnterLobby(uint256 lobby, address indexed enteredPlayer);
  	event CloseLobby(uint256 lobby);
  	event Winner(uint256 lobby, address indexed winner, uint256 amount);

	constructor(uint16 _ownerFee, address _numberGenerator){
		Generator = NumberGenerator(_numberGenerator);

		owner = msg.sender;
		setOwnerFee(_ownerFee);
	}

	function createLobby(Color _chosenColor) payable external {
		require(msg.value >= minBet, "Bet is too low");
		require(msg.value <= maxBet, "Bet is too high");

		Lobby memory newLobby = Lobby({
			blue: address(0),
			red: address(0),
			winner: Color(0),
			pool: msg.value,
			timestamp: block.timestamp
		});

		if(_chosenColor == Color(1))
			newLobby.blue = msg.sender;
		else
			newLobby.red = msg.sender;

		lobbies[lobbyId] = newLobby;

		emit CreateLobby(lobbyId, msg.sender, msg.value);

		unchecked {
			lobbyId++;
		}
	}

	function enterLobby(uint256 _lobbyId) payable checkLobby(_lobbyId) external {
		Lobby memory currentLobby = lobbies[_lobbyId];
		require(_isLobbyEmpty(_lobbyId), "Lobby is full");
		require(currentLobby.pool == msg.value, "Your bet is not correct");

		if(currentLobby.blue == address(0))
			lobbies[_lobbyId].blue = msg.sender;
		else
			lobbies[_lobbyId].red = msg.sender;

		lobbies[_lobbyId].pool += msg.value;

		uint256 requestId = Generator.generateRandomNumber();
		requests[_lobbyId] = requestId;

		emit EnterLobby(_lobbyId, msg.sender);
	}

	function closeLobbyAfterTime(uint256 _lobbyId) checkLobby(_lobbyId) external {
		Lobby memory currentLobby = lobbies[_lobbyId];
		require(currentLobby.blue == msg.sender || currentLobby.red == msg.sender, "You are not in the lobby");
		require(_isLobbyEmpty(_lobbyId), "Lobby is full");
		require(currentLobby.timestamp + lobbyLifeTime <= block.timestamp, "Lobby cannot be closed now");

		payable(msg.sender).sendValue(currentLobby.pool);

		emit CloseLobby(_lobbyId);
	}

	function startLobby(uint256 _lobbyId) checkLobby(_lobbyId) external {
		Lobby memory currentLobby = lobbies[_lobbyId];
		require(currentLobby.winner == Color(0), "Lobby has a winner");
		require(!_isLobbyEmpty(_lobbyId), "Lobby is not full");

		(bool isFullfilled, uint256 randomNumber) = Generator.getRequestStatus(requests[_lobbyId]);
		require(isFullfilled, "The request was not fullfilled yet");

		lobbies[_lobbyId].winner = randomNumber % 2 == 0 ? Color(1) : Color(2);
		address winner = getLobbyWinner(_lobbyId);

		uint256 fee = currentLobby.pool * ownerFee / 100;
		uint256 prize = currentLobby.pool - fee;
		payable(winner).sendValue(prize);

		emit Winner(_lobbyId, winner, prize);
	}

	function getLobbyWinner(uint256 _lobbyId) checkLobby(_lobbyId) view public returns (address) {
		Lobby memory currentLobby = lobbies[_lobbyId];
		Color winnerColor = currentLobby.winner;
		require(winnerColor != Color(0), "Lobby has no winner");

		return winnerColor == Color(1) ? currentLobby.blue : currentLobby.red;
	}

	function _isLobbyEmpty(uint256 _lobbyId) view internal returns (bool) {
		return lobbies[_lobbyId].blue == address(0) || lobbies[_lobbyId].red == address(0);
	}

	function setOwnerFee(uint256 _newOwnerFee) onlyOwner public {
		ownerFee = _newOwnerFee;
	}

	function collectFees() onlyOwner external {
		payable(owner).sendValue(address(this).balance);
	}

	modifier onlyOwner {
		require(msg.sender == owner, "You are not an owner");
		_;
	}

	modifier checkLobby(uint256 _lobbyId) {
		require(lobbyId >= _lobbyId, "Lobby does not exist");
		_;
	}
}