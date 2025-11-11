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
}

contract Target {
    uint256 public stored;

    function store(uint256 x) public {
        stored = x;
    }
}
