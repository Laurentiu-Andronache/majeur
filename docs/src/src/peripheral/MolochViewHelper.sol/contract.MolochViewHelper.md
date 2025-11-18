# MolochViewHelper
[Git Source](https://github.com/z0r0z/SAW/blob/4543b7efb14e209f705fa5119a17da115da65148/src/peripheral/MolochViewHelper.sol)


## State Variables
### SUMMONER

```solidity
ISummoner public constant SUMMONER = ISummoner(0x0000000000330B8df9E3bc5E553074DA58eE9138)
```


### USDC

```solidity
address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
```


### USDT

```solidity
address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7
```


### DAI

```solidity
address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F
```


### WSTETH

```solidity
address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0
```


### RETH

```solidity
address public constant RETH = 0xae78736Cd615f374D3085123A210448E74Fc6393
```


## Functions
### getDaos

Get a slice of DAOs created by the Summoner.


```solidity
function getDaos(uint256 start, uint256 count) public view returns (address[] memory out);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`start`|`uint256`| Index into Summoner.daos[]|
|`count`|`uint256`| Max number of DAOs to return|


### getDAOFullState

Full state for a single DAO: meta, config, supplies, members,
proposals & votes, futarchy, treasury.


```solidity
function getDAOFullState(address dao, uint256 proposalStart, uint256 proposalCount)
    public
    view
    returns (DAOLens memory out);
```

### getDAOsFullState

One-shot fetch of multiple DAOs' state for the UI.
For each DAO in [daoStart, daoStart+daoCount), returns:
- meta (name, symbol, contractURI, token addresses)
- governance config
- token supplies + DAO-held shares/loot
- members (badges seats) + voting power + delegation splits
- proposals [proposalStart .. proposalStart+proposalCount)
- per-proposal tallies, state, per-member votes
- per-proposal futarchy config
- treasury balances (ETH, USDC, USDT, DAI, wstETH, rETH)


```solidity
function getDAOsFullState(
    uint256 daoStart,
    uint256 daoCount,
    uint256 proposalStart,
    uint256 proposalCount
) public view returns (DAOLens[] memory out);
```

### _buildDAOFullState


```solidity
function _buildDAOFullState(address dao, uint256 proposalStart, uint256 proposalCount)
    internal
    view
    returns (DAOLens memory out);
```

### _getMembers


```solidity
function _getMembers(address sharesToken, address lootToken, address badgesToken)
    internal
    view
    returns (MemberView[] memory mv);
```

### _getProposals


```solidity
function _getProposals(IMoloch M, MemberView[] memory members, uint256 start, uint256 count)
    internal
    view
    returns (ProposalView[] memory pv);
```

### _getTreasury


```solidity
function _getTreasury(address dao) internal view returns (DAOTreasury memory t);
```

