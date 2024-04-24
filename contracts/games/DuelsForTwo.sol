// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../chainlink/NumberGenerator.sol";

import "../utils/PaymentManagement.sol";

contract DuelsForTwo is PaymentManagement {
  	NumberGenerator public Generator;

  	uint256 minBet = 0.005 ether;
  	uint256 maxBet = 1000 ether;
	uint256 lobbyTime = 5 minutes;

	uint256 public lobbyId;

	enum Color {
		Unknown,
		Blue,
		Red
	}

	struct Lobby {
		address blue;
		address red;
		Color winningColor;
		uint256 pool;
		uint256 timestamp;
	}

 	mapping(uint256 => Lobby) public lobbies;
	mapping(uint256 => uint256) public requests;

    event CreateLobby(uint256 lobby, address indexed creator, Color bettingColor, uint256 bet);
  	event EnterLobby(uint256 lobby, address indexed player);
  	event CloseLobby(uint256 lobby);
  	event StartLobby(uint256 lobby, address indexed winner, uint256 amount);

	constructor(uint16 _ownerFee, address _numberGenerator) PaymentManagement(_ownerFee){
		Generator = NumberGenerator(_numberGenerator);
	}

	function createLobby(Color _bettingColor) payable external returns (Lobby memory, uint256) {
		require(msg.value >= minBet, "Bet is too low");
		require(msg.value <= maxBet, "Bet is too high");

		Lobby memory newLobby = Lobby({
			blue: address(0),
			red: address(0),
			winningColor: Color.Unknown,
			pool: msg.value,
			timestamp: block.timestamp
		});

		if(_bettingColor == Color.Blue)
			newLobby.blue = msg.sender;
		else
			newLobby.red = msg.sender;

		lobbies[lobbyId] = newLobby;

		unchecked {
			lobbyId++;
		}

		emit CreateLobby(lobbyId - 1, msg.sender, _bettingColor, msg.value);

		return (newLobby, lobbyId - 1);
	}

	function enterLobby(uint256 _lobbyId) payable checkLobby(_lobbyId) external {
		Lobby memory lobby = lobbies[_lobbyId];
		require(_isLobbyEmpty(_lobbyId), "Lobby is full");
		require(lobby.pool == msg.value, "Your bet is not correct");

		if(lobby.blue == address(0))
			lobbies[_lobbyId].blue = msg.sender;
		else
			lobbies[_lobbyId].red = msg.sender;

		lobbies[_lobbyId].pool += msg.value;

		uint256 requestId = Generator.generateRandomNumber();
		requests[_lobbyId] = requestId;

		emit EnterLobby(_lobbyId, msg.sender);
	}

	function closeLobbyAfterTime(uint256 _lobbyId) checkLobby(_lobbyId) external {
		Lobby memory lobby = lobbies[_lobbyId];
		require(lobby.blue == msg.sender || lobby.red == msg.sender, "You are not in the lobby");
		require(_isLobbyEmpty(_lobbyId), "Lobby is full");
		require(lobby.timestamp + lobbyTime <= block.timestamp, "Lobby cannot be closed now");

		_payToWinnedTheWholeSum(msg.sender, lobby.pool, false);

		emit CloseLobby(_lobbyId);
	}

	function startLobby(uint256 _lobbyId) checkLobby(_lobbyId) external {
		Lobby memory lobby = lobbies[_lobbyId];
		require(lobby.winningColor == Color.Unknown, "Lobby has a winner");
		require(!_isLobbyEmpty(_lobbyId), "Lobby is not full");

		(bool isFullfilled, uint256 randomNumber) = Generator.getRequestStatus(requests[_lobbyId]);
		require(isFullfilled, "The request was not fullfilled yet");

		lobbies[_lobbyId].winningColor = randomNumber % 2 == 0 ? Color.Blue : Color.Red;
		address winner = getLobbyWinner(_lobbyId);

		uint256 prizePool = _payToWinnedTheWholeSum(winner, lobby.pool, true); 

		emit StartLobby(_lobbyId, winner, prizePool);
	}

	function getLobbyWinner(uint256 _lobbyId) checkLobby(_lobbyId) view public returns (address) {
		Lobby memory lobby = lobbies[_lobbyId];

		Color winningColor = lobby.winningColor;
		require(winningColor != Color.Unknown, "Lobby has no winner");

		return winningColor == Color.Blue ? lobby.blue : lobby.red;
	}

	function _isLobbyEmpty(uint256 _lobbyId) view internal returns (bool) {
		return lobbies[_lobbyId].blue == address(0) || lobbies[_lobbyId].red == address(0);
	}

	modifier checkLobby(uint256 _lobbyId) {
		require(lobbyId >= _lobbyId, "Lobby does not exist");
		_;
	}
}