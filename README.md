# Number Generator

While deploying this contract, you need to pass 3 arguments.

```solidity
address coordinator;
uint64 subscriptionId;
bytes32 keyHash;
```

All these variables can be found on [VRF Subscription Manager](https://vrf.chain.link).
As for

```solidity
uint64 subscriptionId;
```

you will need to Create an subscription and fund it with LINK tokens.
