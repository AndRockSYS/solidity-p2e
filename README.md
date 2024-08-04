# Games on Solidity with true randomness

>[!IMPORTANT]
>The games were made to demonstrate the possibility of ChainLink nodes and to implement true randomness into the blockchain.

1. [Set up](#set-up)
   - [Number generator](#number-generator)
   - [Price feed](#price-feed)
3. [Games](#games)
   - [Duels for two](#duels-for-two)
   - [Jackpot](#jackpot)
   - [Roulette](#roulette)
   - [Color wheel](#color-wheel)
   - [Higher lower](#higher-lower)

  
# Set-up

## Number generator

When you deploy this contract, you'll need to pass 3 arguments.

```solidity
constructor(address _coordinator, uint64 _subscriptionId, bytes32 _keyHash)
```

`coordinator` and `keyHash` can be found on [VRF Subscription Manager](https://vrf.chain.link), values depend on the network you use for deployment.
As for `subscriptionId` you need to **Create Subscription** and fund it with LINK tokens.

### 1.1 Approve game contract

To use a number generator from other contracts, you approve a generator for them. Pass the address and `true` to give or `false` to take the permit.
```solidity
function approve(address _contract, bool _isApproved) external
```

### 1.2 Use generator

To generate a random number use this function.
```solidity
function generateRandomNumber() onlyApproved external returns (uint256 requestId)
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

### 1.3 Check request status

```solidity
function getRequestStatus(uint256 _requestId) requestExist(_requestId) onlyApproved external view returns (bool, uint256)
```
You can check when `request` was fulfilled and its random number calling the function. 

## Price feed
### 1.1 Add price feed for pair
```solidity
function addPriceFeed(string[2] calldata _symbols, address _priceFeed) onlyOwner external
```

To add a new price fee, pass an array of symbols for that pair (example: [ETH, USDT]) and an address of price feed contract (you can find it on [Chain Link](https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum&page=1) website).

### 1.2 Get the latest price
>[!IMPORTANT]
>You must add a price feed for that pair to receive the price.
```solidity
function getLatestPriceFeed(string[2] calldata _symbols) public view returns (int256, uint256)
```
Pass an array of symbols for the existing pair. You will receive the latest `price` and `timestamp`, the price was updated.
# Games
> [!IMPORTANT]
> To deploy any game you'll need to pass `ownerFee` and `numberGenerator` - the address of deployed previously `NumberGenerator.sol`.


> [!NOTE]
> Struct to save the bets.
>```solidity
>struct Bet {
>   address player;
>   uint256 amount;
>}
>```

>[!IMPORTNAT]
> For each game you have to save all the bets in arrays of `Bet` under the color of a specific game on the server side. You can do it by listening to the events on each contract. It will help to reduce gas prices.

## Duels for two

> [!NOTE]
> Colors and their numbers. 1 - Blue, 2 - Red.

### 1.1 Create the lobby

```solidity
function createLobby(Color _bettingColor) payable external returns (Lobby memory, uint256) {
  ...
  emit CreateLobby(lobbyId, msg.sender, _bettingColor, msg.value);
}
```
Call this function to create a new lobby with `Color` argument. The user must provide the amount of ETH between `minBet` and `maxBet`. It returns the new `Lobby` and its `lobbyId`.

### 1.2 Enter the lobby

```solidity
function enterLobby(uint256 _lobbyId) payable checkLobby(_lobbyId) external {
  ...
  uint256 requestId = Generator.generateRandomNumber();
  requests[_lobbyId] = requestId;

  emit EnterLobby(_lobbyId, msg.sender);
}
```
Call the functions with a `lobbyId` of the existing lobby. The user must provide a value of ETH equal to the lobby's pool (provided by the creator of the lobby).
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
  emit StartLobby(_lobbyId, winner, prize);
}
```
The function will finish the lobby and pick a winner. If the number for this lobby is not generated, the function will be reverted. After the function, the winner will receive the `pool` - `ownerFee`.

### 1.4 Close the lobby after some time

```solidity
function closeLobbyAfterTime(uint256 _lobbyId) checkLobby(_lobbyId) external {
  ...
  emit CloseLobby(_lobbyId);
}
```
Call the function to close a non-full lobby. Only the creator of the lobby can close the game after `lobbyTime` has passed and only then will the user receive the pool back.

### 1.5 Get lobby winner
```solidity
function getLobbyWinner(uint256 _lobbyId) checkLobby(_lobbyId) view public returns (address)
```
If the lobby under this `_lobbyId` exists and the `winner` was assigner will return the address of the `winner`.

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
function enterJackpot() payable external returns (Bet memory) {
   ...
   emit EnterJackpot(msg.sender, msg.value);
   ...
}
```
The function must be called during `roundTime` after creating the round. The amount of ETH between `minBet` and `maxBet`. It will return the `Bet` that was just made.

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

The function must be executed only after the number is generated. The `winner` receives all the `pool` - owner commission.
```solidity
function closeJackpot(Bet[] calldata _bets) external onlyOwner {
   ...   
   emit CloseJackpot(winner, winningAmount);
   ...
}
```

>[!NOTE]
>The `winner` is calculated based on an algorithm. The maximum number is **10000** that is corresponding to 100%. Then, depending on the player's bet, we calculate his `winningNumber` and add it to the sum, if the `randomNumber` (that was previously cast to the 10000 range) is small or equal to the sum, the loop will stop and set this player as a `winner`.

## Roulette

> [!NOTE]
> Colors and their numbers. 1 - Black, 2 - Red, 3 - Green.

### 1.1 Create the round
```solidity
function createRound() onlyOwner external {
  ...
  emit CreateRoulette(roundId);
}
```
It can be called only if the previous round is over.
### 1.2 Enter the round
```solidity
function enterRound(Color _bettingColor) external payable returns (Bet memory) {
   ...
   emit EnterRoulette(msg.sender, msg.value, _bettingColor);
   ...
}
```
The function must be called during `roundTime`. The user must provide `_betColor` (see the colors [here](#roulette) and the amount of ETH between `minBet` and `maxBet`. Will return the bet of a user (see the struct [here](#games))

### 1.3 Generate the random number
```solidity
function sendRequestForNumber() onlyOwner external
```
The function must be called after `roundTime` ends and before closing the current round.
>[!NOTE]
>It will take some time to generate a number, and the event will be emitted (you can see it [here](#12-use-generator))


### 1.4 Calculate the winning color

This function must be called before providing the function `closeRound` with an array of winning bets. The function must be called after `roundTime` ended and `request` under the `requestId` was fulfilled.
```solidity
function calculateWinningColor() onlyOwner external view returns (Color) {
   require(rounds[roundId].timestamp + roundTime < block.timestamp, "Round is not closed");

   (bool isFullFilled, uint256 randomNumber) = Generator.getRequestStatus(requestId);
   require(isFullFilled, "The request was not fulfilled");
   ...
}
```
The random number will be converted to a range from 0-36, depending on the number in roulette it will choose the winners. 
![Roulette numbers](https://great.com/en-us/wp-content/uploads/sites/2/2022/12/image.png)

### 1.5 Close the round
>[!CAUTION]
>It might be quite expensive to execute this transaction so you can set a limit for maximum players in a round.

Use the `winningColor` that was received from `calculateWinningColor` function and bets that were picked from the server side depending on this color, the owner must provide both of these arguments to this function.
```solidity
function closeRound(Color _winningColor, Bet[] calldata _winningBets) onlyOwner external {
   ...
   emit CloseRoulette(roundId, poolToPay, _winningColor);
   ...
}
```
The function will pay each winner depending on its bet and `prizePool` (`totalPool` - `winningPool` - `comission`).

## Color wheel

> [!NOTE]
> Colors and their numbers. 1 - Black, 2 - Red, 3 - Blue, 4 - Gold.
> The wheel has 24 black, 15 red, 10 blue, 1 gold sections.

### 1.1 Create wheel
```solidity
function createWheel() external onlyOwner {
   emit CreateWheel(spinId);
}
```
It can be called only if the previous round is over.
### 1.2 Enter wheel
```solidity
function enterWheel(Color _bettingColor) payable external returns (Bet memory) {
   ...
   emit EnterWheel(msg.sender, msg.value, _bettingColor);
   ...
}
```
The function must be called during `roundTime`. The user must provide `_betColor` (see the colors [here](#roulette) and the amount of ETH between `minBet` and `maxBet`. Will return the bet of a user (see the struct [here](#games))
### 1.3 Generate the random number
```solidity
function sendRequestForNumber() onlyOwner external
```
The function must be called after `roundTime` ends and before closing the current round.
### 1.4 Calculate the winning color
This function must be called before providing the function `closeRound` with an array of winning bets. The function must be called after `roundTime` ended and `request` under the `requestId` was fulfilled.
```solidity
function calculateWinningColor() onlyOwner external view returns (Color) {
   require(spins[spinId].timestamp + roundTime < block.timestamp, "Round is not closed");

   (bool isFulfilled, uint256 randomNumber) = Generator.getRequestStatus(requestId);
   require(isFulfilled, "The request is not fulfilled");
   ...
}
```
The random number will be converted to a range from 0-36, depending on the number in roulette it will choose the winners. 
### 1.5 Close wheel
>[!CAUTION]
>It might be quite expensive to execute this transaction so you can set a limit for maximum players in a round.
```solidity
function closeWheel(Bet[] calldata _winningBets, Color _winningColor) external onlyOwner {
   ...
   emit CloseWheel(spinId, spin.winningColor, prizePool);
   ...
}
```
Use the `winningColor` that was received from `calculateWinningColor` function and the array of bets that were picked from the server side depending on this color, then you must provide both of these arguments to this function.

## Higher lower
>[!NOTE]
>One of the arguments is the `priceFeed` address of `PriceFeed.sol` that was previously deployed.

>[!NOTE]
> Prediction states for the game: Lower - 1, Equal - 2, Higher - 3.

### 1.1 Create round
```solidity
function createRound(string[2] calldata _symbols) external onlyOwner {
   ...
   emit CreateRound(roundId, startPrice);
   ...
}
```
You can create a round for any pair that exists. The price will be set to the `rounds` mapping under the `roundId`.

### 1.2 Enter round
```solidity
function enterRound(uint256 _roundId, Prediction _prediction) external payable returns (Bet memory) {
   ...
   emit EnterRound(msg.sender, msg.value, _prediction);
   ...
}
```
The function must be called during `roundTime`. The user must provide `_prediction` (see the states [here](#higher-lower) and the amount of ETH between `minBet` and `maxBet`. Will return the bet of a user (see the struct [here](#games))

### 1.3 Calculate result
>[!IMPORTANT]
>Must be called before calling `closeRound`.
```solidity
function calculateResult(uint256 _roundId) external onlyOwner returns (Prediction)
```
The function must be called only during the `roundTime`. It will set the latest price and calculate the result based on price change.

### 1.4 Close round
>[!CAUTION]
>It might be quite expensive to execute this transaction so you can set a limit for maximum players in a round.

>[!IMPORTANT]
>Must be called after calling `calculateResult`.
```solidity
function closeRound(uint256 _roundId, Bet[] calldata _winners) external onlyOwner {
   ...
   emit CloseRound(_roundId, round.prices[1], round.result);
}
```
You must provide an array of `Bet` from the backend, depending on the result from `calculateResult` function. The function will pay to each user depending on their bet.
