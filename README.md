# Number Generator

When you deploy this contract, you'll need to pass 3 arguments.

```solidity
constructor(address _coordinator, uint64 _subscriptionId, bytes32 _keyHash)
```

`coordinator` and `keyHash` can be found on [VRF Subscription Manager](https://vrf.chain.link), values depend on the network you use for deployment.
As for `subscriptionId` you need to **Create Subscription** and fund it with LINK tokens.

## 1.1 Approve Game Contract

To use a number generator from other contracts, you approve a generator for them. Pass the address and `true` to give or `false` to take the permit.
```solidity
function approve(address _contract, bool _isApproved) external
```

## 1.2 Use generator

To generate a random number use this function.
```solidity
function generateRandomNumber() external returns (uint256 requestId)
```
The function returns the `requestId` that will be used later to access the random number and check when the Coordinator fulfills the request. 

The Coordinator will call a function when the request is fulfilled.
```solidity
function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) requestExist(_requestId) internal override
```
and 
```solidity 
event RequestFulfilled(uint256 requestId, uint256 randomNumber)
```
will be emitted.

# Duels For Two

When you deploy this contract, you'll need to pass `ownerFee` and `numberGenerator` - the address of deployed previously `NumberGenerator.sol`.

## 1.1 Create the Lobby

```solidity
function createLobby(Color _chosenColor) payable external {
  ...
  emit CreateLobby(lobbyId, msg.sender, msg.value);
}
```
Call this function with argument as **1** for **Blue** or **2** for **Red**. The user must provide the amount of ETH between `minBet` and `maxBet`.

## 1.2 Enter the Lobby

```solidity
function enterLobby(uint256 _lobbyId) payable checkLobby(_lobbyId) external {
  ...
  uint256 requestId = Generator.generateRandomNumber();
  requests[_lobbyId] = requestId;

  emit EnterLobby(_lobbyId, msg.sender);
}
```
Call the functions with an `id` of the existing lobby. The user must provide a value of ETH equal to the lobby's pool (provided by the creator of the lobby).
Then the `requestId` of the lobby is stored in mapping `requests` under the `lobbyId` and will be used later to access the randomly generated number.

## 1.3 Start the Lobby

```solidity
function startLobby(uint256 _lobbyId) checkLobby(_lobbyId) external {
  ...
  (bool isFullfilled, uint256 randomNumber) = Generator.getRequestStatus(requests[_lobbyId]);
  require(isFullfilled, "The request was not fullfilled yet");
  ...
  uint256 fee = currentLobby.pool * ownerFee / 100;
  uint256 prize = currentLobby.pool - fee;
  payable(winner).sendValue(prize);

  emit Winner(_lobbyId, winner, prize);
}
```
Call it to finish the game. If the number for this lobby is not generated, the function will be reverted. After the function, the winner will receive the `pool - ownerFee`.

## 1.4 Close the lobby after some time

```solidity
function closeLobbyAfterTime(uint256 _lobbyId) checkLobby(_lobbyId) external {
  ...
  require(currentLobby.timestamp + lobbyLifeTime <= block.timestamp, "Lobby cannot be closed now");

  payable(msg.sender).sendValue(currentLobby.pool);

  emit CloseLobby(_lobbyId);
}
```
Call the function to close a non-full lobby. Only the creator of the lobby can close the game after `lobbyLifeTime` has passed and only then the user will receive the pool back.

## 1.5 Get the winner of the lobby

```solidity
function getLobbyWinner(uint256 _lobbyId) checkLobby(_lobbyId) view public returns (address)
```
Will return the winner of the lobby, if the lobby exists and has a winner in `Lobby` struct.

