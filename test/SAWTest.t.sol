// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.30;

import {Test} from "../lib/forge-std/src/Test.sol";
import {SAW, SAWShares, SAWBadge} from "../src/SAW.sol";

contract SAWTest is Test {
    SAW internal saw;
    SAWShares internal shares;
    SAWBadge internal badge;

    address internal alice   = address(0xA11CE);
    address internal bob     = address(0x0B0B);
    address internal charlie = address(0x0CAFE);

    Target internal target;
    MockERC20 internal tkn; // for ERC20 pool test

    function setUp() public payable {
        vm.label(alice, "ALICE");
        vm.label(bob, "BOB");
        vm.label(charlie, "CHARLIE");

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);

        address[] memory initialHolders = new address[](2);
        initialHolders[0] = alice;
        initialHolders[1] = bob;

        uint256[] memory initialAmounts = new uint256[](2);
        initialAmounts[0] = 60e18;
        initialAmounts[1] = 40e18;

        // 50% threshold, ragequit enabled
        saw = new SAW("Neo Org", "NEO", 5000, true, initialHolders, initialAmounts);
        shares = saw.shares();
        badge  = saw.badge();

        assertEq(shares.balanceOf(alice), 60e18, "alice shares");
        assertEq(shares.balanceOf(bob),   40e18, "bob shares");
        assertEq(badge.balanceOf(alice), 1, "alice badge");
        assertEq(badge.balanceOf(bob),   1, "bob badge");

        target = new Target();
        tkn    = new MockERC20("Token", "TKN", 18);
    }

    function test_executeByVotes_call_then_pivot_then_sale_buy_rageQuit_permit_chat() public {
        // ===== Proposal #1: call target.store(42)
        uint8   op1   = 0;
        address to1   = address(target);
        uint256 val1  = 0;
        bytes memory data1 = abi.encodeWithSelector(Target.store.selector, 42);
        bytes32 nonce1     = keccak256("proposal-1");
        bytes32 h1 = keccak256(
            abi.encode(address(saw), op1, to1, val1, keccak256(data1), nonce1, saw.config())
        );

        // Lock just over threshold so Alice keeps a badge.
        vm.prank(alice);
        shares.approve(address(saw), type(uint256).max);
        vm.prank(alice);
        saw.depositVotes(uint256(h1), 51e18);

        vm.prank(alice);
        (bool ok1, ) = saw.executeByVotes(op1, to1, val1, data1, nonce1);
        assertTrue(ok1, "exec #1 ok");
        assertEq(target.stored(), 42, "stored 42");
        assertTrue(saw.executed(h1), "h1 executed");

        // ===== Proposal #2: setSale(ETH, price=1 wei per raw share, cap=10e18, minting=true, active=true)
        address payToken = address(0);
        bytes memory data2 = abi.encodeWithSelector(
            SAW.setSale.selector, payToken, uint256(1), 10e18, true, true
        );
        uint8   op2   = 0;
        address to2   = address(saw);
        uint256 val2  = 0;
        bytes32 nonce2 = keccak256("proposal-2");
        bytes32 h2 = keccak256(
            abi.encode(address(saw), op2, to2, val2, keccak256(data2), nonce2, saw.config())
        );

        vm.prank(alice);
        saw.pivotVotes(uint256(h1), uint256(h2), 51e18);

        vm.prank(alice);
        (bool ok2, ) = saw.executeByVotes(op2, to2, val2, data2, nonce2);
        assertTrue(ok2, "exec #2 ok");

        // ===== Charlie buys 2 shares for 2 ETH
        vm.prank(charlie);
        saw.buyShares{value: 2 ether}(address(0), 2e18, 0);
        assertEq(shares.balanceOf(charlie), 2e18, "charlie bought 2");

        // ===== Fund treasury with 10 ETH then Bob ragequits (use full pool)
        vm.deal(address(this), 10 ether);
        (bool sent,) = payable(address(saw)).call{value: 10 ether}("");
        assertTrue(sent, "fund SAW");

        uint256 bobBefore  = bob.balance;
        uint256 tsBefore   = shares.totalSupply();   // 102e18
        uint256 bobShares  = shares.balanceOf(bob);  // 40e18
        uint256 poolBefore = address(saw).balance;   // 2 ETH from sale + 10 ETH top-up

        address[] memory toks = new address[](1);
        toks[0] = address(0);

        vm.prank(bob);
        saw.rageQuit(toks);

        uint256 expected = (poolBefore * bobShares) / tsBefore;
        assertEq(bob.balance - bobBefore, expected, "rageQuit payout");

        // ===== Chat gating (badge holders only)
        vm.expectRevert(SAW.NotApprover.selector);
        vm.prank(bob);
        saw.chat("gm");

        assertEq(badge.balanceOf(alice), 1, "alice still has badge");
        vm.prank(alice);
        saw.chat("hello, world");
        assertEq(saw.getMessageCount(), 1, "one chat message");

        // ===== Permits: set a single-use permit then spend it
        bytes memory dataCall = abi.encodeWithSelector(Target.store.selector, 99);
        bytes32 nonceX = keccak256("permit-1");
        bytes memory data3 = abi.encodeWithSelector(
            SAW.setPermit.selector, uint8(0), address(target), uint256(0), dataCall, nonceX, uint256(1), true
        );
        uint8   op3   = 0;
        address to3   = address(saw);
        uint256 val3  = 0;
        bytes32 h3 = keccak256(
            abi.encode(address(saw), op3, to3, val3, keccak256(data3), keccak256("proposal-3"), saw.config())
        );

        vm.prank(alice);
        saw.pivotVotes(uint256(h2), uint256(h3), 51e18);
        vm.prank(alice);
        (bool ok3, ) = saw.executeByVotes(op3, to3, val3, data3, keccak256("proposal-3"));
        assertTrue(ok3, "setPermit ok");

        vm.prank(charlie);
        (bool ok4, ) = saw.permitExecute(0, address(target), 0, dataCall, nonceX);
        assertTrue(ok4, "permitExecute ok");
        assertEq(target.stored(), 99, "stored 99");
    }

    function test_rageQuit_withERC20_pool() public {
        // Fund SAW with ERC20 tokens directly.
        tkn.mint(address(saw), 1000e18);

        // Snapshot pool & balances BEFORE burn.
        uint256 poolBefore = tkn.balanceOf(address(saw));
        uint256 tsBefore   = shares.totalSupply();
        uint256 bobShares  = shares.balanceOf(bob);

        // Prepare tokens array EXACTLY per your style:
        address[] memory toks = new address[](1);
        toks[0] = address(tkn);

        uint256 bobBefore = tkn.balanceOf(bob);

        vm.prank(bob);
        saw.rageQuit(toks);

        uint256 expected = (poolBefore * bobShares) / tsBefore;
        assertEq(tkn.balanceOf(bob) - bobBefore, expected, "erc20 ragequit payout");
    }

    function test_rageQuit_bothPools_ETH_and_ERC20() public {
        // Fund SAW with 5 ETH.
        vm.deal(address(this), 5 ether);
        (bool sent,) = payable(address(saw)).call{value: 5 ether}("");
        assertTrue(sent, "fund SAW ETH");

        // Fund SAW with 300 TKN (MockERC20) and ensure we have the token.
        // NOTE: assumes `tkn` is created in setUp(): tkn = new MockERC20("Token","TKN",18);
        tkn.mint(address(saw), 300e18);

        // Snapshot balances BEFORE Bob ragequits.
        uint256 tsBefore    = shares.totalSupply();   // 100e18
        uint256 bobShares   = shares.balanceOf(bob);  // 40e18
        uint256 poolEth     = address(saw).balance;   // 5 ether
        uint256 poolTkn     = tkn.balanceOf(address(saw)); // 300e18

        uint256 bobEthBefore = bob.balance;
        uint256 bobTknBefore = tkn.balanceOf(bob);

        // Prepare tokens array EXACTLY per your style (ETH + ERC20).
        address[] memory toks = new address[](2);
        toks[0] = address(0);
        toks[1] = address(tkn);

        // Bob ragequits for both pools.
        vm.prank(bob);
        saw.rageQuit(toks);

        // Expected pro-rata payouts over the full pool (pre-burn).
        uint256 expectedEth = (poolEth * bobShares) / tsBefore;      // 5e18 * 40/100 = 2 ETH
        uint256 expectedTkn = (poolTkn * bobShares) / tsBefore;      // 300e18 * 40/100 = 120e18

        assertEq(bob.balance - bobEthBefore, expectedEth, "ETH rageQuit payout");
        assertEq(tkn.balanceOf(bob) - bobTknBefore, expectedTkn, "ERC20 rageQuit payout");

        // Shares burned & badge burned.
        assertEq(shares.balanceOf(bob), 0, "bob shares burned");
        assertEq(badge.balanceOf(bob),  0, "bob badge burned");

        // Chat should now be gated for Bob.
        vm.expectRevert(SAW.NotApprover.selector);
        vm.prank(bob);
        saw.chat("gm after quit");
    }

    function test_badgeChurn_onTransfer_and_replayPrevention() public {
    // ===== set up a cheap ETH sale so charlie can enter top set & get a badge
    uint8   op2   = 0;
    address to2   = address(saw);
    uint256 val2  = 0;
    bytes memory data2 = abi.encodeWithSelector(
        SAW.setSale.selector, address(0), uint256(1), 10e18, true, true
    );
    bytes32 nonce2 = keccak256("sale-eth-simple");
    bytes32 h2 = keccak256(
        abi.encode(address(saw), op2, to2, val2, keccak256(data2), nonce2, saw.config())
    );

    vm.prank(alice);
    shares.approve(address(saw), type(uint256).max);
    vm.prank(alice);
    saw.depositVotes(uint256(h2), 51e18);

    vm.prank(alice);
    (bool ok2,) = saw.executeByVotes(op2, to2, val2, data2, nonce2);
    assertTrue(ok2, "setSale ok");

    // ===== charlie buys 2 full shares via ETH
    vm.prank(charlie);
    saw.buyShares{value: 2 ether}(address(0), 2e18, 0);
    assertEq(shares.balanceOf(charlie), 2e18, "charlie=2 shares");

    // charlie should have a badge and be able to chat
    assertEq(badge.balanceOf(charlie), 1, "charlie badge minted");
    vm.prank(charlie);
    saw.chat("charlie here!");
    assertEq(saw.getMessageCount(), 1, "chat count=1");

    // ===== transfer all of charlie's shares away -> should burn his badge
    vm.prank(charlie);
    shares.transfer(alice, shares.balanceOf(charlie));
    assertEq(shares.balanceOf(charlie), 0, "charlie emptied");
    assertEq(badge.balanceOf(charlie),  0, "charlie badge burned");

    // chat now gated
    vm.expectRevert(SAW.NotApprover.selector);
    vm.prank(charlie);
    saw.chat("should fail");

    // ===== replay prevention: execute same call twice should fail
    uint8   op1   = 0; // call
    address to1   = address(this);
    uint256 val1  = 0;
    bytes memory data1 = ""; // harmless call to this with empty data (no-op)
    bytes32 nonce1 = keccak256("replay-proposal");
    bytes32 h1 = keccak256(
        abi.encode(address(saw), op1, to1, val1, keccak256(data1), nonce1, saw.config())
    );

    // lock again (alice still has 60e18; didn’t deposit for h1 yet)
    vm.prank(alice);
    saw.depositVotes(uint256(h1), 51e18);

    vm.prank(alice);
    (bool ok1,) = saw.executeByVotes(op1, to1, val1, data1, nonce1);
    assertTrue(ok1, "first exec ok");

    // second execution with same tuple must revert (hash already executed)
    vm.expectRevert(SAW.NotOk.selector);
    vm.prank(alice);
    saw.executeByVotes(op1, to1, val1, data1, nonce1);
}



    receive() external payable {}
}

/// Simple call target
contract Target {
    uint256 public stored;
    event Called(uint256 val, uint256 msgValue);
    function store(uint256 x) external payable {
        stored = x;
        emit Called(x, msg.value);
    }
}

/// Minimal ERC20 for testing.
contract MockERC20 {
    string public name;
    string public symbol;
    uint8  public immutable decimals;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    constructor(string memory _n, string memory _s, uint8 _d) {
        name = _n; symbol = _s; decimals = _d;
    }

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
        emit Transfer(address(0), to, amt);
    }

    function approve(address sp, uint256 amt) external returns (bool) {
        allowance[msg.sender][sp] = amt;
        emit Approval(msg.sender, sp, amt);
        return true;
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        emit Transfer(msg.sender, to, amt);
        return true;
    }

    function transferFrom(address from, address to, uint256 amt) external returns (bool) {
        uint256 a = allowance[from][msg.sender];
        if (a != type(uint256).max) allowance[from][msg.sender] = a - amt;
        balanceOf[from] -= amt;
        balanceOf[to] += amt;
        emit Transfer(from, to, amt);
        return true;
    }
}
