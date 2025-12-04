// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "../lib/forge-std/src/Test.sol";
import {Renderer} from "../src/Renderer.sol";
import {Moloch, Shares, Loot, Badges, Summoner, Call} from "../src/Moloch.sol";
import {
    ISummoner,
    IBadges,
    IShares,
    ILoot,
    IERC20,
    IMoloch,
    Seat,
    DAOLens,
    DAOMeta,
    DAOGovConfig,
    DAOTokenSupplies,
    DAOTreasury,
    TokenBalance,
    MemberView,
    ProposalView,
    MessageView,
    UserMemberView,
    UserDAOLens,
    FutarchyView,
    VoterView
} from "../src/peripheral/MolochViewHelper.sol";

contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }
}

contract Target {
    uint256 public value;

    function setValue(uint256 _value) public payable {
        value = _value;
    }

    fallback() external payable {}
    receive() external payable {}
}

/// @dev Test version of MolochViewHelper with configurable Summoner
contract TestViewHelper {
    ISummoner public immutable SUMMONER;

    constructor(address _summoner) {
        SUMMONER = ISummoner(_summoner);
    }

    function getDaos(uint256 start, uint256 count) public view returns (address[] memory out) {
        uint256 total = SUMMONER.getDAOCount();
        if (start >= total) {
            return new address[](0);
        }

        uint256 end = start + count;
        if (end > total) end = total;

        uint256 len = end - start;
        out = new address[](len);

        for (uint256 i; i < len; ++i) {
            out[i] = SUMMONER.daos(start + i);
        }
    }

    function getDAOFullState(
        address dao,
        uint256 proposalStart,
        uint256 proposalCount,
        uint256 messageStart,
        uint256 messageCount,
        address[] calldata treasuryTokens
    ) public view returns (DAOLens memory out) {
        out = _buildDAOFullState(dao, proposalStart, proposalCount, messageStart, messageCount, treasuryTokens);
    }

    function getDAOsFullState(
        uint256 daoStart,
        uint256 daoCount,
        uint256 proposalStart,
        uint256 proposalCount,
        uint256 messageStart,
        uint256 messageCount,
        address[] calldata treasuryTokens
    ) public view returns (DAOLens[] memory out) {
        uint256 total = SUMMONER.getDAOCount();
        if (daoStart >= total) {
            return new DAOLens[](0);
        }

        uint256 daoEnd = daoStart + daoCount;
        if (daoEnd > total) daoEnd = total;

        uint256 len = daoEnd - daoStart;
        out = new DAOLens[](len);

        for (uint256 i; i < len; ++i) {
            address dao = SUMMONER.daos(daoStart + i);
            out[i] =
                _buildDAOFullState(dao, proposalStart, proposalCount, messageStart, messageCount, treasuryTokens);
        }
    }

    function getUserDAOs(address user, uint256 daoStart, uint256 daoCount, address[] calldata treasuryTokens)
        public
        view
        returns (UserMemberView[] memory out)
    {
        uint256 total = SUMMONER.getDAOCount();
        if (daoStart >= total) {
            return new UserMemberView[](0);
        }

        uint256 daoEnd = daoStart + daoCount;
        if (daoEnd > total) daoEnd = total;

        uint256 matchCount;
        for (uint256 i = daoStart; i < daoEnd; ++i) {
            address dao = SUMMONER.daos(i);
            IMoloch M = IMoloch(dao);

            address sharesToken = M.shares();
            address lootToken = M.loot();
            address badgesToken = M.badges();

            if (
                IShares(sharesToken).balanceOf(user) != 0 || ILoot(lootToken).balanceOf(user) != 0
                    || IBadges(badgesToken).seatOf(user) != 0
            ) {
                ++matchCount;
            }
        }

        out = new UserMemberView[](matchCount);
        uint256 k;

        for (uint256 i = daoStart; i < daoEnd; ++i) {
            address dao = SUMMONER.daos(i);
            IMoloch M = IMoloch(dao);

            address sharesToken = M.shares();
            address lootToken = M.loot();
            address badgesToken = M.badges();

            uint256 sharesBal = IShares(sharesToken).balanceOf(user);
            uint256 lootBal = ILoot(lootToken).balanceOf(user);
            uint256 seatId = IBadges(badgesToken).seatOf(user);

            if (sharesBal == 0 && lootBal == 0 && seatId == 0) {
                continue;
            }

            DAOMeta memory meta;
            meta.name = M.name(0);
            meta.symbol = M.symbol(0);
            meta.contractURI = M.contractURI();
            meta.sharesToken = sharesToken;
            meta.lootToken = lootToken;
            meta.badgesToken = badgesToken;
            meta.renderer = M.renderer();

            DAOGovConfig memory gov;
            gov.proposalThreshold = M.proposalThreshold();
            gov.minYesVotesAbsolute = M.minYesVotesAbsolute();
            gov.quorumAbsolute = M.quorumAbsolute();
            gov.proposalTTL = M.proposalTTL();
            gov.timelockDelay = M.timelockDelay();
            gov.quorumBps = M.quorumBps();
            gov.ragequittable = M.ragequittable();
            gov.autoFutarchyParam = M.autoFutarchyParam();
            gov.autoFutarchyCap = M.autoFutarchyCap();
            gov.rewardToken = M.rewardToken();

            DAOTokenSupplies memory supplies;
            supplies.sharesTotalSupply = IShares(sharesToken).totalSupply();
            supplies.lootTotalSupply = ILoot(lootToken).totalSupply();
            supplies.sharesHeldByDAO = IShares(sharesToken).balanceOf(dao);
            supplies.lootHeldByDAO = ILoot(lootToken).balanceOf(dao);

            DAOTreasury memory treasury = _getTreasury(dao, treasuryTokens);

            (address[] memory dels, uint32[] memory bps) =
                IShares(sharesToken).splitDelegationOf(user);
            uint256 votingPower = IShares(sharesToken).getVotes(user);

            MemberView memory memberView = MemberView({
                account: user,
                shares: sharesBal,
                loot: lootBal,
                seatId: uint16(seatId),
                votingPower: votingPower,
                delegates: dels,
                delegatesBps: bps
            });

            out[k] = UserMemberView({
                dao: dao,
                meta: meta,
                gov: gov,
                supplies: supplies,
                treasury: treasury,
                member: memberView
            });

            ++k;
        }
    }

    function getUserDAOsFullState(
        address user,
        uint256 daoStart,
        uint256 daoCount,
        uint256 proposalStart,
        uint256 proposalCount,
        uint256 messageStart,
        uint256 messageCount,
        address[] calldata treasuryTokens
    ) public view returns (UserDAOLens[] memory out) {
        uint256 total = SUMMONER.getDAOCount();
        if (daoStart >= total) {
            return new UserDAOLens[](0);
        }

        uint256 daoEnd = daoStart + daoCount;
        if (daoEnd > total) daoEnd = total;

        uint256 matchCount;
        for (uint256 i = daoStart; i < daoEnd; ++i) {
            address dao = SUMMONER.daos(i);
            IMoloch M = IMoloch(dao);

            address sharesToken = M.shares();
            address lootToken = M.loot();
            address badgesToken = M.badges();

            if (
                IShares(sharesToken).balanceOf(user) != 0 || ILoot(lootToken).balanceOf(user) != 0
                    || IBadges(badgesToken).seatOf(user) != 0
            ) {
                ++matchCount;
            }
        }

        out = new UserDAOLens[](matchCount);
        uint256 k;

        for (uint256 i = daoStart; i < daoEnd; ++i) {
            address daoAddr = SUMMONER.daos(i);
            IMoloch M = IMoloch(daoAddr);

            address sharesToken = M.shares();
            address lootToken = M.loot();
            address badgesToken = M.badges();

            uint256 sharesBal = IShares(sharesToken).balanceOf(user);
            uint256 lootBal = ILoot(lootToken).balanceOf(user);
            uint256 seatId = IBadges(badgesToken).seatOf(user);

            if (sharesBal == 0 && lootBal == 0 && seatId == 0) {
                continue;
            }

            DAOLens memory daoLens = _buildDAOFullState(
                daoAddr, proposalStart, proposalCount, messageStart, messageCount, treasuryTokens
            );

            (address[] memory dels, uint32[] memory bps) =
                IShares(sharesToken).splitDelegationOf(user);
            uint256 votingPower = IShares(sharesToken).getVotes(user);

            MemberView memory memberView = MemberView({
                account: user,
                shares: sharesBal,
                loot: lootBal,
                seatId: uint16(seatId),
                votingPower: votingPower,
                delegates: dels,
                delegatesBps: bps
            });

            out[k] = UserDAOLens({dao: daoLens, member: memberView});
            ++k;
        }
    }

    function getDAOMessages(address dao, uint256 start, uint256 count)
        public
        view
        returns (MessageView[] memory out)
    {
        out = _getMessagesInternal(dao, start, count);
    }

    function _buildDAOFullState(
        address dao,
        uint256 proposalStart,
        uint256 proposalCount,
        uint256 messageStart,
        uint256 messageCount,
        address[] calldata treasuryTokens
    ) internal view returns (DAOLens memory out) {
        IMoloch M = IMoloch(dao);

        DAOMeta memory meta;
        meta.name = M.name(0);
        meta.symbol = M.symbol(0);
        meta.contractURI = M.contractURI();
        meta.sharesToken = M.shares();
        meta.lootToken = M.loot();
        meta.badgesToken = M.badges();
        meta.renderer = M.renderer();

        DAOGovConfig memory gov;
        gov.proposalThreshold = M.proposalThreshold();
        gov.minYesVotesAbsolute = M.minYesVotesAbsolute();
        gov.quorumAbsolute = M.quorumAbsolute();
        gov.proposalTTL = M.proposalTTL();
        gov.timelockDelay = M.timelockDelay();
        gov.quorumBps = M.quorumBps();
        gov.ragequittable = M.ragequittable();
        gov.autoFutarchyParam = M.autoFutarchyParam();
        gov.autoFutarchyCap = M.autoFutarchyCap();
        gov.rewardToken = M.rewardToken();

        IShares sharesToken = IShares(meta.sharesToken);
        ILoot lootToken = ILoot(meta.lootToken);

        DAOTokenSupplies memory supplies;
        supplies.sharesTotalSupply = sharesToken.totalSupply();
        supplies.lootTotalSupply = lootToken.totalSupply();
        supplies.sharesHeldByDAO = sharesToken.balanceOf(dao);
        supplies.lootHeldByDAO = lootToken.balanceOf(dao);

        MemberView[] memory members =
            _getMembers(meta.sharesToken, meta.lootToken, meta.badgesToken);
        ProposalView[] memory proposals = _getProposals(M, members, proposalStart, proposalCount);
        MessageView[] memory messages = _getMessagesInternal(dao, messageStart, messageCount);

        DAOTreasury memory treasury = _getTreasury(dao, treasuryTokens);

        out.dao = dao;
        out.meta = meta;
        out.gov = gov;
        out.supplies = supplies;
        out.treasury = treasury;
        out.members = members;
        out.proposals = proposals;
        out.messages = messages;
    }

    function _getMembers(address sharesToken, address lootToken, address badgesToken)
        internal
        view
        returns (MemberView[] memory mv)
    {
        IBadges badges = IBadges(badgesToken);
        Seat[] memory seats = badges.getSeats();
        uint256 len = seats.length;

        mv = new MemberView[](len);
        IShares shares = IShares(sharesToken);
        ILoot loot = ILoot(lootToken);

        for (uint256 i; i < len; ++i) {
            address account = seats[i].holder;
            uint256 seatId = badges.seatOf(account);
            (address[] memory dels, uint32[] memory bps) = shares.splitDelegationOf(account);

            mv[i] = MemberView({
                account: account,
                shares: uint256(seats[i].bal),
                loot: loot.balanceOf(account),
                seatId: uint16(seatId),
                votingPower: shares.getVotes(account),
                delegates: dels,
                delegatesBps: bps
            });
        }
    }

    function _getProposals(IMoloch M, MemberView[] memory members, uint256 start, uint256 count)
        internal
        view
        returns (ProposalView[] memory pv)
    {
        uint256 total = M.getProposalCount();
        if (start >= total) {
            return new ProposalView[](0);
        }

        uint256 end = start + count;
        if (end > total) end = total;
        uint256 len = end - start;

        pv = new ProposalView[](len);
        uint256 memberCount = members.length;

        for (uint256 i; i < len; ++i) {
            uint256 idx = start + i;
            uint256 pid = M.proposalIds(idx);

            (uint96 forV, uint96 againstV, uint96 abstainV) = M.tallies(pid);

            ProposalView memory P;
            P.id = pid;
            P.proposer = M.proposerOf(pid);
            P.state = M.state(pid);
            P.snapshotBlock = M.snapshotBlock(pid);
            P.createdAt = M.createdAt(pid);
            P.queuedAt = M.queuedAt(pid);
            P.supplySnapshot = M.supplySnapshot(pid);

            P.forVotes = forV;
            P.againstVotes = againstV;
            P.abstainVotes = abstainV;

            (
                bool fEnabled,
                address fToken,
                uint256 fPool,
                bool fResolved,
                uint8 fWinner,
                uint256 fFinalSupply,
                uint256 fPayoutPerUnit
            ) = M.futarchy(pid);

            P.futarchy = FutarchyView({
                enabled: fEnabled,
                rewardToken: fToken,
                pool: fPool,
                resolved: fResolved,
                winner: fWinner,
                finalWinningSupply: fFinalSupply,
                payoutPerUnit: fPayoutPerUnit
            });

            if (memberCount != 0) {
                uint8[] memory votedCache = new uint8[](memberCount);
                uint256 nVoters;

                for (uint256 j; j < memberCount; ++j) {
                    address voterAddr = members[j].account;
                    uint8 hv = M.hasVoted(pid, voterAddr);
                    votedCache[j] = hv;
                    if (hv != 0) {
                        unchecked {
                            ++nVoters;
                        }
                    }
                }

                VoterView[] memory voters = new VoterView[](nVoters);
                uint256 k;

                for (uint256 j; j < memberCount; ++j) {
                    uint8 hv = votedCache[j];
                    if (hv != 0) {
                        address voterAddr = members[j].account;
                        uint96 weight96 = M.voteWeight(pid, voterAddr);

                        voters[k] = VoterView({
                            voter: voterAddr,
                            support: hv - 1,
                            weight: uint256(weight96)
                        });
                        unchecked {
                            ++k;
                        }
                    }
                }

                P.voters = voters;
            }

            pv[i] = P;
        }
    }

    function _getMessagesInternal(address dao, uint256 start, uint256 count)
        internal
        view
        returns (MessageView[] memory out)
    {
        IMoloch M = IMoloch(dao);
        uint256 total = M.getMessageCount();
        if (start >= total) {
            return new MessageView[](0);
        }

        uint256 end = start + count;
        if (end > total) end = total;
        uint256 len = end - start;

        out = new MessageView[](len);
        for (uint256 i; i < len; ++i) {
            uint256 idx = start + i;
            out[i] = MessageView({index: idx, text: M.messages(idx)});
        }
    }

    function _getTreasury(address dao, address[] calldata tokens) internal view returns (DAOTreasury memory t) {
        uint256 len = tokens.length;
        t.balances = new TokenBalance[](len);

        for (uint256 i; i < len; ++i) {
            address token = tokens[i];
            uint256 bal;

            if (token == address(0)) {
                bal = dao.balance;
            } else {
                (bool success, bytes memory data) = token.staticcall(
                    abi.encodeWithSelector(IERC20.balanceOf.selector, dao)
                );
                if (success && data.length >= 32) {
                    bal = abi.decode(data, (uint256));
                }
            }

            t.balances[i] = TokenBalance({token: token, balance: bal});
        }
    }
}

contract MolochViewHelperTest is Test {
    Summoner internal summoner;
    Moloch internal moloch;
    Moloch internal moloch2;
    Shares internal shares;
    Loot internal loot;
    Badges internal badges;
    TestViewHelper internal viewHelper;

    address internal renderer;

    address internal alice = address(0xA11CE);
    address internal bob = address(0x0B0B);
    address internal charlie = address(0xCAFE);
    address internal dave = address(0xDAD);

    MockERC20 internal usdc;
    MockERC20 internal dai;
    Target internal target;

    function setUp() public {
        vm.label(alice, "ALICE");
        vm.label(bob, "BOB");
        vm.label(charlie, "CHARLIE");
        vm.label(dave, "DAVE");

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);
        vm.deal(dave, 100 ether);

        // Deploy Summoner normally
        summoner = new Summoner();

        renderer = address(new Renderer());

        // Create the first DAO
        address[] memory initialHolders = new address[](0);
        uint256[] memory initialAmounts = new uint256[](0);

        moloch = summoner.summon(
            "Test DAO",
            "TEST",
            "ipfs://QmTest123",
            5000, // 50% quorum
            true, // ragequit enabled
            renderer,
            bytes32(0),
            initialHolders,
            initialAmounts,
            new Call[](0)
        );

        shares = moloch.shares();
        loot = moloch.loot();
        badges = moloch.badges();

        // Mint shares to test users
        vm.startPrank(address(moloch));
        shares.mintFromMoloch(alice, 60e18);
        shares.mintFromMoloch(bob, 40e18);
        loot.mintFromMoloch(charlie, 20e18);
        vm.stopPrank();

        // Create a second DAO
        moloch2 = summoner.summon(
            "Second DAO",
            "DAO2",
            "ipfs://QmSecond",
            3000, // 30% quorum
            false, // ragequit disabled
            renderer,
            bytes32(uint256(1)),
            initialHolders,
            initialAmounts,
            new Call[](0)
        );

        // Mint shares in second DAO
        vm.startPrank(address(moloch2));
        Shares(address(moloch2.shares())).mintFromMoloch(alice, 100e18);
        Shares(address(moloch2.shares())).mintFromMoloch(dave, 50e18);
        vm.stopPrank();

        // Deploy mock tokens
        usdc = new MockERC20("USD Coin", "USDC", 6);
        dai = new MockERC20("Dai Stablecoin", "DAI", 18);

        // Fund the DAO treasury
        vm.deal(address(moloch), 10 ether);
        usdc.mint(address(moloch), 1000e6);
        dai.mint(address(moloch), 500e18);

        // Deploy the test view helper with our summoner
        viewHelper = new TestViewHelper(address(summoner));

        target = new Target();
        vm.roll(block.number + 1);
    }

    /*//////////////////////////////////////////////////////////////
                             DAO PAGINATION
    //////////////////////////////////////////////////////////////*/

    function test_GetDaos() public view {
        address[] memory daos = viewHelper.getDaos(0, 10);
        assertEq(daos.length, 2);
        assertEq(daos[0], address(moloch));
        assertEq(daos[1], address(moloch2));
    }

    function test_GetDaos_Pagination() public view {
        address[] memory daos = viewHelper.getDaos(0, 1);
        assertEq(daos.length, 1);
        assertEq(daos[0], address(moloch));

        daos = viewHelper.getDaos(1, 1);
        assertEq(daos.length, 1);
        assertEq(daos[0], address(moloch2));
    }

    function test_GetDaos_StartBeyondTotal() public view {
        address[] memory daos = viewHelper.getDaos(100, 10);
        // Fixed in test helper - should return empty array
        assertEq(daos.length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                          SINGLE DAO FULL STATE
    //////////////////////////////////////////////////////////////*/

    function test_GetDAOFullState_Meta() public view {
        address[] memory treasuryTokens = new address[](0);
        DAOLens memory lens = viewHelper.getDAOFullState(
            address(moloch), 0, 10, 0, 10, treasuryTokens
        );

        assertEq(lens.dao, address(moloch));
        assertEq(lens.meta.name, "Test DAO");
        assertEq(lens.meta.symbol, "TEST");
        assertEq(lens.meta.contractURI, "ipfs://QmTest123");
        assertEq(lens.meta.sharesToken, address(shares));
        assertEq(lens.meta.lootToken, address(loot));
        assertEq(lens.meta.badgesToken, address(badges));
        assertEq(lens.meta.renderer, renderer);
    }

    function test_GetDAOFullState_GovConfig() public view {
        address[] memory treasuryTokens = new address[](0);
        DAOLens memory lens = viewHelper.getDAOFullState(
            address(moloch), 0, 10, 0, 10, treasuryTokens
        );

        assertEq(lens.gov.quorumBps, 5000);
        assertTrue(lens.gov.ragequittable);
        assertEq(lens.gov.proposalThreshold, 0);
        assertEq(lens.gov.timelockDelay, 0);
    }

    function test_GetDAOFullState_Supplies() public view {
        address[] memory treasuryTokens = new address[](0);
        DAOLens memory lens = viewHelper.getDAOFullState(
            address(moloch), 0, 10, 0, 10, treasuryTokens
        );

        assertEq(lens.supplies.sharesTotalSupply, 100e18);
        assertEq(lens.supplies.lootTotalSupply, 20e18);
        assertEq(lens.supplies.sharesHeldByDAO, 0);
        assertEq(lens.supplies.lootHeldByDAO, 0);
    }

    function test_GetDAOFullState_Members() public view {
        address[] memory treasuryTokens = new address[](0);
        DAOLens memory lens = viewHelper.getDAOFullState(
            address(moloch), 0, 10, 0, 10, treasuryTokens
        );

        // Should have members from badge seats
        assertTrue(lens.members.length >= 2);
    }

    /*//////////////////////////////////////////////////////////////
                           TREASURY BALANCE VIEW
    //////////////////////////////////////////////////////////////*/

    function test_GetDAOFullState_Treasury_ETH() public view {
        address[] memory treasuryTokens = new address[](1);
        treasuryTokens[0] = address(0); // Native ETH

        DAOLens memory lens = viewHelper.getDAOFullState(
            address(moloch), 0, 10, 0, 10, treasuryTokens
        );

        assertEq(lens.treasury.balances.length, 1);
        assertEq(lens.treasury.balances[0].token, address(0));
        assertEq(lens.treasury.balances[0].balance, 10 ether);
    }

    function test_GetDAOFullState_Treasury_ERC20() public view {
        address[] memory treasuryTokens = new address[](2);
        treasuryTokens[0] = address(usdc);
        treasuryTokens[1] = address(dai);

        DAOLens memory lens = viewHelper.getDAOFullState(
            address(moloch), 0, 10, 0, 10, treasuryTokens
        );

        assertEq(lens.treasury.balances.length, 2);
        assertEq(lens.treasury.balances[0].token, address(usdc));
        assertEq(lens.treasury.balances[0].balance, 1000e6);
        assertEq(lens.treasury.balances[1].token, address(dai));
        assertEq(lens.treasury.balances[1].balance, 500e18);
    }

    function test_GetDAOFullState_Treasury_MixedTokens() public view {
        address[] memory treasuryTokens = new address[](3);
        treasuryTokens[0] = address(0); // Native ETH
        treasuryTokens[1] = address(usdc);
        treasuryTokens[2] = address(dai);

        DAOLens memory lens = viewHelper.getDAOFullState(
            address(moloch), 0, 10, 0, 10, treasuryTokens
        );

        assertEq(lens.treasury.balances.length, 3);
        assertEq(lens.treasury.balances[0].token, address(0));
        assertEq(lens.treasury.balances[0].balance, 10 ether);
        assertEq(lens.treasury.balances[1].token, address(usdc));
        assertEq(lens.treasury.balances[1].balance, 1000e6);
        assertEq(lens.treasury.balances[2].token, address(dai));
        assertEq(lens.treasury.balances[2].balance, 500e18);
    }

    function test_GetDAOFullState_Treasury_NonExistentToken() public view {
        address[] memory treasuryTokens = new address[](1);
        treasuryTokens[0] = address(0xDEAD); // Non-existent token

        DAOLens memory lens = viewHelper.getDAOFullState(
            address(moloch), 0, 10, 0, 10, treasuryTokens
        );

        // Should gracefully return 0 balance for non-existent token
        assertEq(lens.treasury.balances.length, 1);
        assertEq(lens.treasury.balances[0].token, address(0xDEAD));
        assertEq(lens.treasury.balances[0].balance, 0);
    }

    function test_GetDAOFullState_Treasury_EmptyArray() public view {
        address[] memory treasuryTokens = new address[](0);

        DAOLens memory lens = viewHelper.getDAOFullState(
            address(moloch), 0, 10, 0, 10, treasuryTokens
        );

        assertEq(lens.treasury.balances.length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                          MULTI-DAO FULL STATE
    //////////////////////////////////////////////////////////////*/

    function test_GetDAOsFullState() public view {
        address[] memory treasuryTokens = new address[](1);
        treasuryTokens[0] = address(0);

        DAOLens[] memory lenses = viewHelper.getDAOsFullState(
            0, 10, 0, 10, 0, 10, treasuryTokens
        );

        assertEq(lenses.length, 2);
        assertEq(lenses[0].dao, address(moloch));
        assertEq(lenses[0].meta.name, "Test DAO");
        assertEq(lenses[1].dao, address(moloch2));
        assertEq(lenses[1].meta.name, "Second DAO");
    }

    function test_GetDAOsFullState_Pagination() public view {
        address[] memory treasuryTokens = new address[](0);

        DAOLens[] memory lenses = viewHelper.getDAOsFullState(
            0, 1, 0, 10, 0, 10, treasuryTokens
        );

        assertEq(lenses.length, 1);
        assertEq(lenses[0].meta.name, "Test DAO");

        lenses = viewHelper.getDAOsFullState(
            1, 1, 0, 10, 0, 10, treasuryTokens
        );

        assertEq(lenses.length, 1);
        assertEq(lenses[0].meta.name, "Second DAO");
    }

    /*//////////////////////////////////////////////////////////////
                          USER DAO PORTFOLIO
    //////////////////////////////////////////////////////////////*/

    function test_GetUserDAOs() public view {
        address[] memory treasuryTokens = new address[](1);
        treasuryTokens[0] = address(0);

        UserMemberView[] memory userDaos = viewHelper.getUserDAOs(
            alice, 0, 10, treasuryTokens
        );

        // Alice has shares in both DAOs
        assertEq(userDaos.length, 2);
        assertEq(userDaos[0].dao, address(moloch));
        assertEq(userDaos[0].member.shares, 60e18);
        assertEq(userDaos[1].dao, address(moloch2));
        assertEq(userDaos[1].member.shares, 100e18);
    }

    function test_GetUserDAOs_OnlyLoot() public view {
        address[] memory treasuryTokens = new address[](0);

        UserMemberView[] memory userDaos = viewHelper.getUserDAOs(
            charlie, 0, 10, treasuryTokens
        );

        // Charlie only has loot in first DAO
        assertEq(userDaos.length, 1);
        assertEq(userDaos[0].dao, address(moloch));
        assertEq(userDaos[0].member.shares, 0);
        assertEq(userDaos[0].member.loot, 20e18);
    }

    function test_GetUserDAOs_NoMembership() public view {
        address[] memory treasuryTokens = new address[](0);
        address nonMember = address(0x1234);

        UserMemberView[] memory userDaos = viewHelper.getUserDAOs(
            nonMember, 0, 10, treasuryTokens
        );

        assertEq(userDaos.length, 0);
    }

    function test_GetUserDAOs_WithTreasury() public view {
        address[] memory treasuryTokens = new address[](2);
        treasuryTokens[0] = address(0);
        treasuryTokens[1] = address(usdc);

        UserMemberView[] memory userDaos = viewHelper.getUserDAOs(
            alice, 0, 10, treasuryTokens
        );

        assertEq(userDaos.length, 2);
        // First DAO has treasury
        assertEq(userDaos[0].treasury.balances.length, 2);
        assertEq(userDaos[0].treasury.balances[0].balance, 10 ether);
        assertEq(userDaos[0].treasury.balances[1].balance, 1000e6);
    }

    /*//////////////////////////////////////////////////////////////
                        USER DAO FULL STATE
    //////////////////////////////////////////////////////////////*/

    function test_GetUserDAOsFullState() public view {
        address[] memory treasuryTokens = new address[](1);
        treasuryTokens[0] = address(0);

        UserDAOLens[] memory userDaos = viewHelper.getUserDAOsFullState(
            alice, 0, 10, 0, 10, 0, 10, treasuryTokens
        );

        assertEq(userDaos.length, 2);
        assertEq(userDaos[0].dao.dao, address(moloch));
        assertEq(userDaos[0].member.shares, 60e18);
        assertEq(userDaos[1].dao.dao, address(moloch2));
        assertEq(userDaos[1].member.shares, 100e18);
    }

    /*//////////////////////////////////////////////////////////////
                             PROPOSALS
    //////////////////////////////////////////////////////////////*/

    function test_GetDAOFullState_WithProposals() public {
        // Create a proposal
        bytes memory data = abi.encodeWithSelector(Target.setValue.selector, 123);
        uint256 id = moloch.proposalId(0, address(target), 0, data, bytes32(0));

        vm.prank(alice);
        moloch.openProposal(id);

        // Cast a vote
        vm.prank(alice);
        moloch.castVote(id, 1); // Vote FOR

        vm.prank(bob);
        moloch.castVote(id, 0); // Vote AGAINST

        address[] memory treasuryTokens = new address[](0);
        DAOLens memory lens = viewHelper.getDAOFullState(
            address(moloch), 0, 10, 0, 10, treasuryTokens
        );

        assertEq(lens.proposals.length, 1);
        assertEq(lens.proposals[0].id, id);
        assertEq(lens.proposals[0].proposer, alice);
        assertEq(lens.proposals[0].forVotes, 60e18);
        assertEq(lens.proposals[0].againstVotes, 40e18);
        assertEq(lens.proposals[0].abstainVotes, 0);

        // Check voters
        assertTrue(lens.proposals[0].voters.length >= 2);
    }

    function test_GetDAOFullState_ProposalPagination() public {
        // Create multiple proposals
        for (uint256 i = 0; i < 5; i++) {
            bytes memory data = abi.encodeWithSelector(Target.setValue.selector, i);
            uint256 id = moloch.proposalId(0, address(target), 0, data, bytes32(i));
            vm.prank(alice);
            moloch.openProposal(id);
        }

        address[] memory treasuryTokens = new address[](0);

        // Get first 2 proposals
        DAOLens memory lens = viewHelper.getDAOFullState(
            address(moloch), 0, 2, 0, 10, treasuryTokens
        );
        assertEq(lens.proposals.length, 2);

        // Get next 2 proposals
        lens = viewHelper.getDAOFullState(
            address(moloch), 2, 2, 0, 10, treasuryTokens
        );
        assertEq(lens.proposals.length, 2);

        // Get last proposal
        lens = viewHelper.getDAOFullState(
            address(moloch), 4, 2, 0, 10, treasuryTokens
        );
        assertEq(lens.proposals.length, 1);
    }

    /*//////////////////////////////////////////////////////////////
                              MESSAGES
    //////////////////////////////////////////////////////////////*/

    function test_GetDAOMessages() public {
        // Post some messages (need to be a badge holder)
        vm.prank(alice);
        moloch.chat("Hello world!");

        vm.prank(bob);
        moloch.chat("Second message");

        MessageView[] memory messages = viewHelper.getDAOMessages(address(moloch), 0, 10);

        assertEq(messages.length, 2);
        assertEq(messages[0].index, 0);
        assertEq(messages[0].text, "Hello world!");
        assertEq(messages[1].index, 1);
        assertEq(messages[1].text, "Second message");
    }

    function test_GetDAOMessages_Pagination() public {
        // Post multiple messages
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(alice);
            moloch.chat(string(abi.encodePacked("Message ", bytes1(uint8(48 + i)))));
        }

        MessageView[] memory messages = viewHelper.getDAOMessages(address(moloch), 0, 2);
        assertEq(messages.length, 2);
        assertEq(messages[0].index, 0);
        assertEq(messages[1].index, 1);

        messages = viewHelper.getDAOMessages(address(moloch), 2, 2);
        assertEq(messages.length, 2);
        assertEq(messages[0].index, 2);
        assertEq(messages[1].index, 3);
    }

    function test_GetDAOFullState_WithMessages() public {
        vm.prank(alice);
        moloch.chat("Test message");

        address[] memory treasuryTokens = new address[](0);
        DAOLens memory lens = viewHelper.getDAOFullState(
            address(moloch), 0, 10, 0, 10, treasuryTokens
        );

        assertEq(lens.messages.length, 1);
        assertEq(lens.messages[0].text, "Test message");
    }

    /*//////////////////////////////////////////////////////////////
                         DELEGATION & VOTING POWER
    //////////////////////////////////////////////////////////////*/

    function test_GetDAOFullState_VotingPower() public {
        // Alice delegates to Bob
        vm.prank(alice);
        shares.delegate(bob);

        address[] memory treasuryTokens = new address[](0);
        DAOLens memory lens = viewHelper.getDAOFullState(
            address(moloch), 0, 10, 0, 10, treasuryTokens
        );

        // Find Alice and Bob in members
        for (uint256 i = 0; i < lens.members.length; i++) {
            if (lens.members[i].account == alice) {
                assertEq(lens.members[i].shares, 60e18);
                assertEq(lens.members[i].votingPower, 0); // Delegated away
            }
            if (lens.members[i].account == bob) {
                assertEq(lens.members[i].shares, 40e18);
                assertEq(lens.members[i].votingPower, 100e18); // Has Alice's delegation
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                         MULTICHAIN TREASURY TEST
    //////////////////////////////////////////////////////////////*/

    function test_Treasury_DifferentTokensPerChain() public {
        // Simulate different chains having different tokens
        MockERC20 arbitrumUsdc = new MockERC20("USDC", "USDC", 6);
        MockERC20 arbitrumArb = new MockERC20("Arbitrum", "ARB", 18);

        arbitrumUsdc.mint(address(moloch), 2000e6);
        arbitrumArb.mint(address(moloch), 1000e18);

        // Query with Arbitrum tokens
        address[] memory arbitrumTokens = new address[](3);
        arbitrumTokens[0] = address(0); // ETH
        arbitrumTokens[1] = address(arbitrumUsdc);
        arbitrumTokens[2] = address(arbitrumArb);

        DAOLens memory lens = viewHelper.getDAOFullState(
            address(moloch), 0, 10, 0, 10, arbitrumTokens
        );

        assertEq(lens.treasury.balances.length, 3);
        assertEq(lens.treasury.balances[0].balance, 10 ether);
        assertEq(lens.treasury.balances[1].balance, 2000e6);
        assertEq(lens.treasury.balances[2].balance, 1000e18);
    }

    function test_Treasury_ZeroBalanceTokens() public {
        MockERC20 emptyToken = new MockERC20("Empty", "EMPTY", 18);

        address[] memory treasuryTokens = new address[](1);
        treasuryTokens[0] = address(emptyToken);

        DAOLens memory lens = viewHelper.getDAOFullState(
            address(moloch), 0, 10, 0, 10, treasuryTokens
        );

        assertEq(lens.treasury.balances.length, 1);
        assertEq(lens.treasury.balances[0].balance, 0);
    }

    /*//////////////////////////////////////////////////////////////
                           EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_GetDAOFullState_EmptyDAO() public {
        // Create an empty DAO with no members
        address[] memory holders = new address[](0);
        uint256[] memory amounts = new uint256[](0);

        Moloch emptyMoloch = summoner.summon(
            "Empty DAO",
            "EMPTY",
            "",
            0,
            false,
            renderer,
            bytes32(uint256(999)),
            holders,
            amounts,
            new Call[](0)
        );

        address[] memory treasuryTokens = new address[](0);
        DAOLens memory lens = viewHelper.getDAOFullState(
            address(emptyMoloch), 0, 10, 0, 10, treasuryTokens
        );

        assertEq(lens.dao, address(emptyMoloch));
        assertEq(lens.meta.name, "Empty DAO");
        assertEq(lens.supplies.sharesTotalSupply, 0);
    }

    function test_GetDAOsFullState_StartBeyondTotal() public view {
        address[] memory treasuryTokens = new address[](0);

        DAOLens[] memory lenses = viewHelper.getDAOsFullState(
            100, 10, 0, 10, 0, 10, treasuryTokens
        );

        // Fixed in test helper - returns empty array
        assertEq(lenses.length, 0);
    }
}
