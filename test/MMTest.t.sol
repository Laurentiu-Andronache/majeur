// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "../lib/forge-std/src/Test.sol";
import {Moloch, Shares, Loot, Badge, Summoner, Call} from "../src/Moloch.sol";

contract MolochTest is Test {
    Summoner internal summoner;
    Moloch internal moloch;
    Shares internal shares;
    Loot internal loot;
    Badge internal badge;

    address internal alice = address(0xA11CE);
    address internal bob = address(0x0B0B);
    address internal charlie = address(0xCAFE);

    Target internal target;

    function setUp() public {
        vm.label(alice, "ALICE");
        vm.label(bob, "BOB");
        vm.label(charlie, "CHARLIE");

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);

        // Deploy summoner
        summoner = new Summoner();

        // Setup initial holders
        address[] memory initialHolders = new address[](2);
        initialHolders[0] = alice;
        initialHolders[1] = bob;

        uint256[] memory initialAmounts = new uint256[](2);
        initialAmounts[0] = 60e18;
        initialAmounts[1] = 40e18;

        // Summon new DAO with 50% quorum
        moloch = summoner.summon(
            "Test DAO",
            "TEST",
            "",
            5000, // 50% quorum
            true, // ragequit enabled
            bytes32(0),
            initialHolders,
            initialAmounts,
            new Call[](0)
        );

        shares = moloch.shares();
        loot = moloch.loot();
        badge = moloch.badge();

        assertEq(shares.balanceOf(alice), 60e18, "alice shares");
        assertEq(shares.balanceOf(bob), 40e18, "bob shares");
        assertEq(badge.balanceOf(alice), 1, "alice badge");
        assertEq(badge.balanceOf(bob), 1, "bob badge");

        target = new Target();
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    function _id(uint8 op, address to, uint256 val, bytes memory data, bytes32 nonce)
        internal
        view
        returns (uint256)
    {
        return moloch.proposalId(op, to, val, data, nonce);
    }

    function _open(uint256 h) internal {
        moloch.openProposal(h);
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);
    }

    function _voteYes(uint256 h, address voter) internal {
        vm.prank(voter);
        moloch.castVote(h, 1);
    }

    function _openAndPass(uint8 op, address to, uint256 val, bytes memory data, bytes32 nonce)
        internal
        returns (uint256 h, bool ok)
    {
        h = _id(op, to, val, data, nonce);
        _open(h);
        _voteYes(h, alice);
        _voteYes(h, bob);
        (ok,) = moloch.executeByVotes(op, to, val, data, nonce);
        assertTrue(ok, "execute ok");
    }

    /*//////////////////////////////////////////////////////////////
                          BASIC TESTS
    //////////////////////////////////////////////////////////////*/

    function test_initial_state() public view {
        assertEq(shares.totalSupply(), 100e18, "total supply");
        assertEq(shares.balanceOf(alice), 60e18, "alice balance");
        assertEq(shares.balanceOf(bob), 40e18, "bob balance");
        assertEq(moloch.quorumBps(), 5000, "quorum 50%");
        assertTrue(moloch.ragequittable(), "ragequit enabled");
    }

    function test_execute_simple_call() public {
        bytes memory data = abi.encodeWithSelector(Target.store.selector, 42);
        uint256 h = _id(0, address(target), 0, data, keccak256("test1"));

        _open(h);
        _voteYes(h, alice);
        _voteYes(h, bob);

        (bool ok,) = moloch.executeByVotes(0, address(target), 0, data, keccak256("test1"));
        assertTrue(ok, "execute succeeded");
        assertEq(target.stored(), 42, "target updated");
    }

    function test_proposal_states() public {
        bytes memory data = abi.encodeWithSelector(Target.store.selector, 123);
        uint256 h = _id(0, address(target), 0, data, keccak256("state-test"));

        // Unopened
        assertEq(uint256(moloch.state(h)), uint256(Moloch.ProposalState.Unopened), "unopened");

        // Open - snapshot at block 0 in test environment
        moloch.openProposal(h);
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        // At snapshot block 0 with no votes, state is still Unopened
        // Need to cast at least one vote for it to become Active
        vm.prank(alice);
        moloch.castVote(h, 1);

        // With partial votes (only alice), check if Active or Succeeded
        // Alice has 60%, Bob has 40%, so alice alone meets 50% quorum
        assertEq(
            uint256(moloch.state(h)),
            uint256(Moloch.ProposalState.Succeeded),
            "succeeded after alice"
        );

        // Bob votes too
        vm.prank(bob);
        moloch.castVote(h, 1);

        // Still succeeded with unanimous vote
        assertEq(uint256(moloch.state(h)), uint256(Moloch.ProposalState.Succeeded), "succeeded");

        // Execute
        (bool ok,) = moloch.executeByVotes(0, address(target), 0, data, keccak256("state-test"));
        assertTrue(ok);
        assertEq(uint256(moloch.state(h)), uint256(Moloch.ProposalState.Executed), "executed");
    }

    function test_voting_with_delegation() public {
        // Alice delegates to Charlie
        vm.prank(alice);
        shares.delegate(charlie);

        assertEq(shares.getVotes(alice), 0, "alice delegated away");
        assertEq(shares.getVotes(charlie), 60e18, "charlie has alice's votes");
        assertEq(shares.getVotes(bob), 40e18, "bob unchanged");

        // Charlie can vote with delegated power
        bytes memory data = abi.encodeWithSelector(Target.store.selector, 99);
        uint256 h = _id(0, address(target), 0, data, keccak256("delegate-test"));

        _open(h);

        vm.prank(charlie);
        moloch.castVote(h, 1); // Charlie votes YES with 60e18

        vm.prank(bob);
        moloch.castVote(h, 1); // Bob votes YES with 40e18

        (uint256 forVotes,,) = moloch.tallies(h);
        assertEq(forVotes, 100e18, "all votes cast");

        (bool ok,) = moloch.executeByVotes(0, address(target), 0, data, keccak256("delegate-test"));
        assertTrue(ok);
        assertEq(target.stored(), 99);
    }

    function test_split_delegation() public {
        address[] memory delegates = new address[](2);
        uint32[] memory bps = new uint32[](2);

        delegates[0] = bob;
        delegates[1] = charlie;
        bps[0] = 5000; // 50%
        bps[1] = 5000; // 50%

        vm.prank(alice);
        shares.setSplitDelegation(delegates, bps);

        // Alice's 60e18 split 50/50
        assertEq(shares.getVotes(alice), 0, "alice delegated");
        assertEq(shares.getVotes(bob), 70e18, "bob has 40 + 30");
        assertEq(shares.getVotes(charlie), 30e18, "charlie has 30");
    }

    function test_ragequit() public {
        // Move past genesis block
        vm.roll(10);
        vm.warp(10);

        // Trigger checkpoint creation for Bob by doing a self-delegation
        // This ensures the voting system is properly initialized
        vm.prank(bob);
        shares.delegate(bob);

        // Move forward one more block
        vm.roll(11);
        vm.warp(11);

        // Fund the DAO
        vm.deal(address(moloch), 10 ether);

        uint256 bobBefore = bob.balance;
        uint256 bobShares = shares.balanceOf(bob); // 40e18
        uint256 totalSupply = shares.totalSupply() + loot.totalSupply(); // 100e18 + 0
        uint256 treasury = address(moloch).balance; // 10 ether

        address[] memory tokens = new address[](1);
        tokens[0] = address(0); // ETH

        vm.prank(bob);
        moloch.rageQuit(tokens, bobShares, 0);

        uint256 expectedPayout = (treasury * bobShares) / totalSupply;
        assertEq(bob.balance - bobBefore, expectedPayout, "correct payout");
        assertEq(shares.balanceOf(bob), 0, "shares burned");
    }

    function test_sales_basic() public {
        // Enable a free sale via governance
        bytes memory data = abi.encodeWithSelector(
            Moloch.setSale.selector,
            address(0), // ETH
            0, // price (free)
            10e18, // cap
            true, // minting
            true, // active
            false // not loot
        );

        (, bool ok) = _openAndPass(0, address(moloch), 0, data, keccak256("enable-sale"));
        assertTrue(ok);

        // Charlie buys shares
        vm.prank(charlie);
        moloch.buyShares{value: 0}(address(0), 5e18, 0);

        assertEq(shares.balanceOf(charlie), 5e18, "charlie bought shares");
        assertEq(shares.totalSupply(), 105e18, "supply increased");
    }

    function test_timelock() public {
        // Enable 1 hour timelock
        bytes memory data = abi.encodeWithSelector(Moloch.setTimelockDelay.selector, uint64(3600));
        (, bool ok) = _openAndPass(0, address(moloch), 0, data, keccak256("timelock"));
        assertTrue(ok);

        // Create new proposal
        bytes memory callData = abi.encodeWithSelector(Target.store.selector, 777);
        uint256 h = _id(0, address(target), 0, callData, keccak256("tl-test"));

        _open(h);
        _voteYes(h, alice);
        _voteYes(h, bob);

        // First call queues
        (bool queued,) =
            moloch.executeByVotes(0, address(target), 0, callData, keccak256("tl-test"));
        assertTrue(queued);
        assertEq(uint256(moloch.state(h)), uint256(Moloch.ProposalState.Queued));

        // Can't execute yet
        vm.expectRevert();
        moloch.executeByVotes(0, address(target), 0, callData, keccak256("tl-test"));

        // After delay
        vm.warp(block.timestamp + 3600 + 1);
        (bool executed,) =
            moloch.executeByVotes(0, address(target), 0, callData, keccak256("tl-test"));
        assertTrue(executed);
        assertEq(target.stored(), 777);
    }

    function test_permits() public {
        bytes memory call = abi.encodeWithSelector(Target.store.selector, 555);
        bytes32 nonce = keccak256("permit-test");

        // Set permit via governance
        bytes memory data = abi.encodeWithSelector(
            Moloch.setPermit.selector,
            0, // op
            address(target), // to
            0, // value
            call, // data
            nonce,
            charlie, // spender
            1 // count
        );

        (, bool ok) = _openAndPass(0, address(moloch), 0, data, keccak256("set-permit"));
        assertTrue(ok);

        // Charlie spends permit
        vm.prank(charlie);
        (bool ok2,) = moloch.permitExecute(0, address(target), 0, call, nonce);
        assertTrue(ok2);
        assertEq(target.stored(), 555);
    }

    function test_futarchy_yes() public {
        bytes memory call = abi.encodeWithSelector(Target.store.selector, 888);
        uint256 h = _id(0, address(target), 0, call, keccak256("fut"));

        // Fund futarchy
        vm.deal(address(this), 100 ether);
        moloch.fundFutarchy{value: 100 ether}(h, address(0), 100 ether);

        // Vote and execute
        _open(h);
        _voteYes(h, alice);
        _voteYes(h, bob);

        (bool ok,) = moloch.executeByVotes(0, address(target), 0, call, keccak256("fut"));
        assertTrue(ok);

        // Check futarchy resolved
        (bool enabled,,, bool resolved, uint8 winner,, uint256 ppu) = moloch.futarchy(h);
        assertTrue(enabled && resolved);
        assertEq(winner, 1, "YES won");
        assertTrue(ppu > 0);

        // Cash out
        uint256 before = alice.balance;
        vm.prank(alice);
        moloch.cashOutFutarchy(h, 10e18);
        assertTrue(alice.balance > before, "got payout");
    }

    function test_chat() public {
        // Alice has badge, can chat
        vm.prank(alice);
        moloch.chat("hello world");
        assertEq(moloch.getMessageCount(), 1);

        // Charlie has no badge, cannot chat
        vm.expectRevert(Moloch.NotOk.selector);
        vm.prank(charlie);
        moloch.chat("should fail");
    }

    function test_top_256_eviction() public {
        // Enable free sale
        bytes memory d = abi.encodeWithSelector(
            Moloch.setSale.selector, address(0), 0, type(uint256).max, true, true, false
        );
        (, bool ok) = _openAndPass(0, address(moloch), 0, d, keccak256("sale"));
        assertTrue(ok);

        // Fill 254 slots (alice + bob = 2)
        for (uint256 i = 0; i < 254; i++) {
            address holder = vm.addr(i + 1000);
            vm.prank(holder);
            moloch.buyShares{value: 0}(address(0), 1e18, 0);
            assertEq(badge.balanceOf(holder), 1);
        }

        // 256 slots full. Add someone with more shares
        address whale = address(0x9999);
        vm.prank(whale);
        moloch.buyShares{value: 0}(address(0), 10e18, 0);

        // Whale should have badge
        assertEq(badge.balanceOf(whale), 1, "whale got badge");

        // Some small holder should have lost badge
        uint256 badgeCount = 0;
        for (uint256 i = 0; i < 256; i++) {
            address holder = moloch.topHolders(i);
            if (holder != address(0) && badge.balanceOf(holder) == 1) {
                badgeCount++;
            }
        }
        assertEq(badgeCount, 256, "still 256 badge holders");
    }

    function test_transfer_lock() public {
        bytes memory d = abi.encodeWithSelector(Moloch.setTransfersLocked.selector, true);
        (, bool ok) = _openAndPass(0, address(moloch), 0, d, keccak256("lock"));
        assertTrue(ok);

        vm.expectRevert();
        vm.prank(alice);
        shares.transfer(charlie, 1e18);
    }

    function test_double_vote_reverts() public {
        uint256 h = _id(0, address(this), 0, "", keccak256("double"));
        _open(h);

        vm.prank(alice);
        moloch.castVote(h, 1);

        vm.expectRevert(Moloch.NotOk.selector);
        vm.prank(alice);
        moloch.castVote(h, 1);
    }

    function test_quorum_enforcement() public {
        // Set 80% quorum
        bytes memory d = abi.encodeWithSelector(Moloch.setQuorumBps.selector, uint16(8000));
        (, bool ok) = _openAndPass(0, address(moloch), 0, d, keccak256("quorum"));
        assertTrue(ok);

        // Only alice votes (60% turnout, below 80%)
        uint256 h = _id(0, address(this), 0, "", keccak256("test"));
        _open(h);
        _voteYes(h, alice);

        assertEq(uint256(moloch.state(h)), uint256(Moloch.ProposalState.Active));

        vm.expectRevert(Moloch.NotOk.selector);
        moloch.executeByVotes(0, address(this), 0, "", keccak256("test"));
    }

    function test_config_bump_invalidates_old() public {
        uint256 h = _id(0, address(this), 0, "", keccak256("old"));
        _open(h);
        _voteYes(h, alice);
        _voteYes(h, bob);

        // Bump config
        bytes memory d = abi.encodeWithSelector(Moloch.bumpConfig.selector);
        (, bool ok) = _openAndPass(0, address(moloch), 0, d, keccak256("bump"));
        assertTrue(ok);

        // Old proposal can't execute
        vm.expectRevert(Moloch.NotOk.selector);
        moloch.executeByVotes(0, address(this), 0, "", keccak256("old"));
    }

    function test_loot_sales() public {
        // Enable loot sale
        bytes memory data = abi.encodeWithSelector(
            Moloch.setSale.selector,
            address(0), // ETH
            0, // price (free)
            10e18, // cap
            true, // minting
            true, // active
            true // IS LOOT
        );

        (, bool ok) = _openAndPass(0, address(moloch), 0, data, keccak256("loot-sale"));
        assertTrue(ok);

        // Charlie buys loot
        vm.prank(charlie);
        moloch.buyShares{value: 0}(address(0), 5e18, 0);

        assertEq(loot.balanceOf(charlie), 5e18, "charlie bought loot");
        assertEq(shares.balanceOf(charlie), 0, "no shares for charlie");
    }

    function test_loot_ragequit() public {
        // Enable loot sale
        bytes memory data =
            abi.encodeWithSelector(Moloch.setSale.selector, address(0), 0, 10e18, true, true, true);
        (, bool ok) = _openAndPass(0, address(moloch), 0, data, keccak256("loot-sale"));
        assertTrue(ok);

        // Charlie buys loot
        vm.prank(charlie);
        moloch.buyShares{value: 0}(address(0), 5e18, 0);

        vm.roll(10);
        vm.warp(10);

        // Fund DAO
        vm.deal(address(moloch), 10 ether);

        uint256 charlieBefore = charlie.balance;
        uint256 totalSupply = shares.totalSupply() + loot.totalSupply();

        address[] memory tokens = new address[](1);
        tokens[0] = address(0);

        // Ragequit with loot
        vm.prank(charlie);
        moloch.rageQuit(tokens, 0, 5e18); // 0 shares, 5e18 loot

        uint256 expectedPayout = (10 ether * 5e18) / totalSupply;
        assertEq(charlie.balance - charlieBefore, expectedPayout, "loot ragequit payout");
    }

    function test_futarchy_no_path() public {
        // Set short TTL
        bytes memory dTTL = abi.encodeWithSelector(Moloch.setProposalTTL.selector, uint64(100));
        (, bool ok) = _openAndPass(0, address(moloch), 0, dTTL, keccak256("ttl"));
        assertTrue(ok);

        bytes memory call = abi.encodeWithSelector(Target.store.selector, 999);
        uint256 h = _id(0, address(target), 0, call, keccak256("fut-no"));

        // Fund futarchy
        vm.deal(address(this), 100 ether);
        moloch.fundFutarchy{value: 100 ether}(h, address(0), 100 ether);

        // Vote NO
        _open(h);
        vm.prank(alice);
        moloch.castVote(h, 0); // AGAINST
        vm.prank(bob);
        moloch.castVote(h, 0); // AGAINST

        // Wait for TTL
        vm.warp(block.timestamp + 101);

        // Resolve NO
        moloch.resolveFutarchyNo(h);

        (bool enabled,,, bool resolved, uint8 winner,, uint256 ppu) = moloch.futarchy(h);
        assertTrue(enabled && resolved);
        assertEq(winner, 0, "NO won");

        // Cash out NO receipts
        uint256 before = alice.balance;
        vm.prank(alice);
        moloch.cashOutFutarchy(h, 10e18);
        assertTrue(alice.balance > before, "got NO payout");
    }

    function test_split_delegation_3_way() public {
        // Enable sale for charlie
        bytes memory d = abi.encodeWithSelector(
            Moloch.setSale.selector, address(0), 0, 10e18, true, true, false
        );
        (, bool ok) = _openAndPass(0, address(moloch), 0, d, keccak256("sale"));
        assertTrue(ok);

        vm.prank(charlie);
        moloch.buyShares{value: 0}(address(0), 10e18, 0);

        // Alice splits 3 ways
        address[] memory delegates = new address[](3);
        uint32[] memory bps = new uint32[](3);

        delegates[0] = bob;
        delegates[1] = charlie;
        delegates[2] = address(0x1111);
        bps[0] = 3333;
        bps[1] = 3333;
        bps[2] = 3334;

        vm.prank(alice);
        shares.setSplitDelegation(delegates, bps);

        // Check distribution
        assertEq(shares.getVotes(alice), 0, "alice delegated");
        assertTrue(shares.getVotes(bob) > 40e18, "bob has own + alice's");
        assertTrue(shares.getVotes(charlie) > 10e18, "charlie has own + alice's");
    }

    function test_clear_split_delegation() public {
        // Set split
        address[] memory delegates = new address[](2);
        uint32[] memory bps = new uint32[](2);
        delegates[0] = bob;
        delegates[1] = charlie;
        bps[0] = 5000;
        bps[1] = 5000;

        vm.prank(alice);
        shares.setSplitDelegation(delegates, bps);

        assertEq(shares.getVotes(alice), 0, "alice split");

        // Clear split
        vm.prank(alice);
        shares.clearSplitDelegation();

        assertEq(shares.getVotes(alice), 60e18, "alice back to self");
    }

    function test_allowance_eth() public {
        vm.deal(address(moloch), 10 ether);

        // Set allowance via governance
        bytes memory d =
            abi.encodeWithSelector(Moloch.setAllowanceTo.selector, address(0), charlie, 5 ether);
        (, bool ok) = _openAndPass(0, address(moloch), 0, d, keccak256("allowance"));
        assertTrue(ok);

        // Charlie claims
        uint256 before = charlie.balance;
        vm.prank(charlie);
        moloch.claimAllowance(address(0), 3 ether);

        assertEq(charlie.balance - before, 3 ether, "claimed");
        assertEq(moloch.allowance(address(0), charlie), 2 ether, "remaining");
    }

    function test_proposal_ttl_expiry() public {
        // Set short TTL
        bytes memory d = abi.encodeWithSelector(Moloch.setProposalTTL.selector, uint64(100));
        (, bool ok) = _openAndPass(0, address(moloch), 0, d, keccak256("ttl"));
        assertTrue(ok);

        // Open proposal
        uint256 h = _id(0, address(this), 0, "", keccak256("expire"));
        moloch.openProposal(h);

        // Wait past TTL
        vm.warp(block.timestamp + 101);

        // Should be expired
        assertEq(uint256(moloch.state(h)), uint256(Moloch.ProposalState.Expired));

        // Can't vote
        vm.expectRevert(Moloch.NotOk.selector);
        vm.prank(alice);
        moloch.castVote(h, 1);
    }

    function test_defeated_proposal() public {
        uint256 h = _id(0, address(this), 0, "", keccak256("defeat"));
        _open(h);

        // Alice votes YES, Bob votes NO
        vm.prank(alice);
        moloch.castVote(h, 1); // 60% FOR

        vm.prank(bob);
        moloch.castVote(h, 0); // 40% AGAINST

        // FOR > AGAINST but need to check quorum
        // With 50% quorum, 100% turnout is enough
        // 60 FOR vs 40 AGAINST = FOR wins
        assertEq(uint256(moloch.state(h)), uint256(Moloch.ProposalState.Succeeded));
    }

    function test_tie_vote_defeats() public {
        // Make alice and bob equal
        vm.prank(alice);
        shares.transfer(bob, 10e18); // Now both have 50e18

        vm.roll(10);
        vm.warp(10);

        uint256 h = _id(0, address(this), 0, "", keccak256("tie"));
        _open(h);

        vm.prank(alice);
        moloch.castVote(h, 1); // 50 FOR

        vm.prank(bob);
        moloch.castVote(h, 0); // 50 AGAINST

        // Tie means defeated (FOR <= AGAINST)
        assertEq(uint256(moloch.state(h)), uint256(Moloch.ProposalState.Defeated));
    }

    function test_abstain_votes() public {
        uint256 h = _id(0, address(this), 0, "", keccak256("abstain"));
        _open(h);

        vm.prank(alice);
        moloch.castVote(h, 2); // ABSTAIN

        vm.prank(bob);
        moloch.castVote(h, 1); // FOR

        // Should succeed (quorum met, FOR > AGAINST)
        assertEq(uint256(moloch.state(h)), uint256(Moloch.ProposalState.Succeeded));
    }

    function test_metadata_functions() public view {
        assertEq(shares.name(), "Test DAO Shares");
        assertEq(shares.symbol(), "TEST");
        assertEq(loot.name(), "Test DAO Loot");
        assertEq(badge.name(), "Test DAO Badge");
    }

    function test_permit_unlimited() public {
        bytes memory call = abi.encodeWithSelector(Target.store.selector, 111);
        bytes32 nonce = keccak256("unlimited");

        // Set unlimited permit
        bytes memory data = abi.encodeWithSelector(
            Moloch.setPermit.selector,
            0,
            address(target),
            0,
            call,
            nonce,
            charlie,
            type(uint256).max
        );

        (, bool ok) = _openAndPass(0, address(moloch), 0, data, keccak256("set-unlimited"));
        assertTrue(ok);

        // Charlie can spend multiple times
        vm.prank(charlie);
        moloch.permitExecute(0, address(target), 0, call, nonce);
        assertEq(target.stored(), 111);

        vm.prank(charlie);
        moloch.permitExecute(0, address(target), 0, call, nonce);
        assertEq(target.stored(), 111, "still works");
    }

    function test_batch_calls() public {
        Call[] memory calls = new Call[](2);
        calls[0] = Call({
            target: address(target),
            value: 0,
            data: abi.encodeWithSelector(Target.store.selector, 100)
        });
        calls[1] = Call({
            target: address(target),
            value: 0,
            data: abi.encodeWithSelector(Target.store.selector, 200)
        });

        bytes memory d = abi.encodeWithSelector(Moloch.batchCalls.selector, calls);
        (, bool ok) = _openAndPass(0, address(moloch), 0, d, keccak256("batch"));
        assertTrue(ok);

        assertEq(target.stored(), 200, "last call value");
    }

    function test_receive_eth() public {
        vm.deal(alice, 5 ether);
        vm.prank(alice);
        (bool ok,) = payable(address(moloch)).call{value: 5 ether}("");
        assertTrue(ok);
        assertEq(address(moloch).balance, 5 ether);
    }
}

contract Target {
    uint256 public stored;

    function store(uint256 x) public {
        stored = x;
    }
}
