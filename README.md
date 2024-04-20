# Number Generator

While deploying this contract, you need to pass 3 arguments.

```solidity
constructor(address _coordinator, uint64 _subscriptionId, bytes32 _keyHash)
```

`address coordinator` and `keyHash` can be found on [VRF Subscription Manager](https://vrf.chain.link).
As for `uint64 subscriptionId` you will need to Create an subscription and fund it with LINK tokens.
