# ISummoner
[Git Source](https://github.com/z0r0z/SAW/blob/1098c25d112838b519fc1471aa11e5ab4aaeadc5/src/peripheral/DAICO.sol)

Minimal Summoner interface.


## Functions
### summon


```solidity
function summon(
    string calldata orgName,
    string calldata orgSymbol,
    string calldata orgURI,
    uint16 quorumBps,
    bool ragequittable,
    address renderer,
    bytes32 salt,
    address[] calldata initHolders,
    uint256[] calldata initShares,
    Call[] calldata initCalls
) external payable returns (address);
```

