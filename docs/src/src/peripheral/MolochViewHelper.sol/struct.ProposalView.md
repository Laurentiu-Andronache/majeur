# ProposalView
[Git Source](https://github.com/z0r0z/SAW/blob/4543b7efb14e209f705fa5119a17da115da65148/src/peripheral/MolochViewHelper.sol)


```solidity
struct ProposalView {
uint256 id;
address proposer;
uint8 state;

uint48 snapshotBlock;
uint64 createdAt;
uint64 queuedAt;
uint256 supplySnapshot;

uint96 forVotes;
uint96 againstVotes;
uint96 abstainVotes;

FutarchyView futarchy;
VoterView[] voters; // only members who actually voted
}
```

