# Summoner
[Git Source](https://github.com/z0r0z/SAW/blob/4543b7efb14e209f705fa5119a17da115da65148/src/Moloch.sol)


## State Variables
### daos

```solidity
Moloch[] public daos
```


### implementation

```solidity
Moloch immutable implementation
```


## Functions
### constructor


```solidity
constructor() payable;
```

### summon

Summon new Majeur clone with initialization calls:


```solidity
function summon(
    string calldata orgName,
    string calldata orgSymbol,
    string calldata orgURI,
    uint16 quorumBps, // e.g. 5000 = 50% turnout of snapshot supply
    bool ragequittable,
    address renderer,
    bytes32 salt,
    address[] calldata initHolders,
    uint256[] calldata initShares,
    Call[] calldata initCalls
) public payable returns (Moloch dao);
```

### getDAOCount

Get dao array push count:


```solidity
function getDAOCount() public view returns (uint256);
```

## Events
### NewDAO

```solidity
event NewDAO(address indexed summoner, Moloch indexed dao);
```

