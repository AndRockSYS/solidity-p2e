# Games on Solidity with true randomness

1. [Number Generator](#number-generator)
2. [Games](#games)
   - [Duels For Two](#duels-for-two)
   - [Roulette](#roulette)
   - [Jackpot](#jackpot)

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

# Games
> [!IMPORTANT]
> To deploy any game you'll need to pass `ownerFee` and `numberGenerator` - the address of deployed previously `NumberGenerator.sol`.

## Duels For Two

### 1.1 Create the lobby

```solidity
function createLobby(Color _chosenColor) payable external {
  ...
  emit CreateLobby(lobbyId, msg.sender, msg.value);
}
```
Call this function to create a new lobby with `Color` argument. The user must provide the amount of ETH between `minBet` and `maxBet`.
> [!NOTE]
> 1 - Blue, 2 - Red

### 1.2 Enter the lobby

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
>[!NOTE]
>It will take some time to generate a number, and the event will be emitted (you can see it [here](#12-use-generator))

### 1.3 Start the lobby

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
The function will finish the lobby and pick a winner. If the number for this lobby is not generated, the function will be reverted. After the function, the winner will receive the `pool - ownerFee`.

### 1.4 Close the lobby after some time

```solidity
function closeLobbyAfterTime(uint256 _lobbyId) checkLobby(_lobbyId) external {
  ...
  require(currentLobby.timestamp + lobbyLifeTime <= block.timestamp, "Lobby cannot be closed now");

  payable(msg.sender).sendValue(currentLobby.pool);

  emit CloseLobby(_lobbyId);
}
```
Call the function to close a non-full lobby. Only the creator of the lobby can close the game after `lobbyLifeTime` has passed and only then will the user receive the pool back.

## Roulette
> [!IMPORTANT]
> REWRITE

### 1.1 Create the round
```solidity
function createRound() onlyOwner external {
  ...
  emit CreateRoulette(roundId);
}
```
It can be called only if the previous round was over.
### 1.2 Enter the round
```solidity
function enterRound(Color _betColor) external payable {
  ...
  emit EnterRoulette(msg.sender, msg.value, _betColor);
}
```
The function must be called during `roundTime` after the round is created. The user must provide `_betColor` (see lower) and the amount of ETH between `minBet` and `maxBet`.
> [!NOTE]
> Colors: 1 - Black, 2 - Red, 3 - Green.

> [!IMPORTANT]
> You have to listen `EnterRoulette` event and user data in the array of `Bet` struct (see lower) **for each color**, which will be provided later, to pay to all the winners. It should work in this way to decrease the amount of gas and not store arrays in the contract.
>
> ```solidity
>struct Bet {
>   address player;
>   Color betColor;
>   uint256 amount;
>}
> ```

### 1.3 Generate the random number
```solidity
function sendRequestForNumber() onlyOwner external
```
The function must be called after `roundTime` ended but before closing the current round.
>[!NOTE]
>It will take some time to generate a number, and the event will be emitted (you can see it [here](#12-use-generator))

### 1.4 Close the round
>[!CAUTION]
>It might be quite expensive to execute this transaction so you can set a limit for maximum players in a round.

```solidity
function closeRound(Bet[] calldata _black, Bet[] calldata _red, Bet[] calldata _green) onlyOwner external {
   require(rounds[roundId].timestamp + roundTime < block.timestamp, "Round is not closed");

   (bool isFullFilled, uint256 number) = Generator.getRequestStatus(currentRequestId);
   require(isFullFilled, "The request was not fulfilled");
   ...
   emit CloseRoulette(roundId, totalPool, winningColor);
   ...
    }
```
The function will be executed only if `roundTime` has passed and the request has been fulfilled.
>[!NOTE]
>Owner must provide 3 arrays: `_black`, `_red`, `_green` with all the bets made during this round.

The random number will be converted to a range from 0-36, depending on the number in roulette it will choose the winners. 
Then it will pay to all the winners their bet + profit, which is calculated based on their bet.

![Roulette numbers](https://great.com/en-us/wp-content/uploads/sites/2/2022/12/image.png)

## Jackpot

### 1.1 Create the round
```solidity
function createJackpot() onlyOwner external {
   ...
   emit CreateJackpot(roundId);
}
```
It can be called only if the previous round is over.

### 1.2 Enter the round
```solidity
function enterJackpot() payable external {
   ...
   emit EnterJackpot(msg.sender, msg.value);
}
```
The function must be called during `roundTime` after creating the round. The amount of ETH between `minBet` and `maxBet`.

> [!IMPORTANT]
> All the bets are supposed to be saved outside of the contract, on the backend. Use this struct for that.
> ```solidity
>struct Bet {
>   address player;
>   uint256 amount;
>}
> ```

### 1.3 Generate the random number
```solidity
function sendRequestForNumber() onlyOwner external
```
The function must be called after `roundTime` ended but before closing the current round.
>[!NOTE]
>It will take some time to generate a number, and the event will be emitted (you can see it [here](#12-use-generator))

### 1.4 Close the round
```solidity
function closeJackpot(Bet[] calldata _bets) external onlyOwner {
   ...   
   emit CloseJackpot(winner, winningAmount);
   ...
}
```
>[!NOTE]
>Argument for this function is the array, provided from the backend.

The function must be executed only after the number is generated. The `winner` receives all the `pool` - owner commission.

>[!NOTE]
>The `winner` is calculated based on an algorithm. The maximum number is **10000** that is corresponding to 100%. Then, depending on the player's bet, we calculate his `winningNumber` and add it to the sum, if the `randomNumber` (that was previously cast to the 10000 range) is small or equal to the sum, the loop will stop and set this player as a `winner`.

>[!CAUTION]
>It might be quite expensive to execute this transaction so you can set a limit for maximum players in a round.
