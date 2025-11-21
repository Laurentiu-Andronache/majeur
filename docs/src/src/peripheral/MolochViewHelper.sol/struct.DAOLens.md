# DAOLens
[Git Source](https://github.com/z0r0z/SAW/blob/f6a0ba3113db52f4093dc799a792326706ecd9e8/src/peripheral/MolochViewHelper.sol)


```solidity
struct DAOLens {
address dao;
DAOMeta meta;
DAOGovConfig gov;
DAOTokenSupplies supplies;
DAOTreasury treasury;
MemberView[] members;
ProposalView[] proposals;
MessageView[] messages;
}
```

