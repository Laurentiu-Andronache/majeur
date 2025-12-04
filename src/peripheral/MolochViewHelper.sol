// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/* -------------------------------------------------------------------------- */
/*                                   INTERFACES                               */
/* -------------------------------------------------------------------------- */

interface ISummoner {
    function getDAOCount() external view returns (uint256);
    function daos(uint256) external view returns (address);
}

struct Seat {
    address holder;
    uint96 bal; // shares balance
}

interface IBadges {
    function getSeats() external view returns (Seat[] memory);
    function seatOf(address) external view returns (uint256);
}

interface IShares {
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function getVotes(address) external view returns (uint256);
    function splitDelegationOf(address account)
        external
        view
        returns (address[] memory delegates_, uint32[] memory bps_);
}

interface ILoot {
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

// Full-ish Moloch surface needed for the view helper
interface IMoloch {
    // Metadata / DAO-level
    function name(uint256 id) external view returns (string memory);
    function symbol(uint256 id) external view returns (string memory);
    function contractURI() external view returns (string memory);
    function renderer() external view returns (address);

    // Governance params
    function proposalThreshold() external view returns (uint96);
    function minYesVotesAbsolute() external view returns (uint96);
    function quorumAbsolute() external view returns (uint96);
    function proposalTTL() external view returns (uint64);
    function timelockDelay() external view returns (uint64);
    function quorumBps() external view returns (uint16);
    function ragequittable() external view returns (bool);
    function autoFutarchyParam() external view returns (uint256);
    function autoFutarchyCap() external view returns (uint256);
    function rewardToken() external view returns (address);

    // Token refs
    function shares() external view returns (address);
    function loot() external view returns (address);
    function badges() external view returns (address);

    // Proposals and votes
    function getProposalCount() external view returns (uint256);
    function proposalIds(uint256) external view returns (uint256);
    function proposerOf(uint256) external view returns (address);
    function snapshotBlock(uint256) external view returns (uint48);
    function createdAt(uint256) external view returns (uint64);
    function queuedAt(uint256) external view returns (uint64);
    function supplySnapshot(uint256) external view returns (uint256);
    function tallies(uint256 id)
        external
        view
        returns (uint96 forVotes, uint96 againstVotes, uint96 abstainVotes);
    function state(uint256 id) external view returns (uint8);

    function hasVoted(uint256 id, address voter) external view returns (uint8);
    function voteWeight(uint256 id, address voter) external view returns (uint96);

    // Futarchy
    function futarchy(uint256 id)
        external
        view
        returns (
            bool enabled,
            address rewardToken,
            uint256 pool,
            bool resolved,
            uint8 winner,
            uint256 finalWinningSupply,
            uint256 payoutPerUnit
        );

    // Chat / messages
    function getMessageCount() external view returns (uint256);
    function messages(uint256) external view returns (string memory);
}

/* -------------------------------------------------------------------------- */
/*                                   STRUCTS                                  */
/* -------------------------------------------------------------------------- */

struct DAOMeta {
    string name;
    string symbol;
    string contractURI;
    address sharesToken;
    address lootToken;
    address badgesToken;
    address renderer;
}

struct DAOGovConfig {
    uint96 proposalThreshold;
    uint96 minYesVotesAbsolute;
    uint96 quorumAbsolute;
    uint64 proposalTTL;
    uint64 timelockDelay;
    uint16 quorumBps;
    bool ragequittable;
    uint256 autoFutarchyParam;
    uint256 autoFutarchyCap;
    address rewardToken;
}

struct DAOTokenSupplies {
    uint256 sharesTotalSupply;
    uint256 lootTotalSupply;
    uint256 sharesHeldByDAO;
    uint256 lootHeldByDAO;
}

struct MemberView {
    address account;
    uint256 shares;
    uint256 loot;
    uint16 seatId; // 1..256, or 0 if none

    uint256 votingPower; // current getVotes(account)
    address[] delegates; // split delegation targets
    uint32[] delegatesBps; // bps per delegate
}

struct VoterView {
    address voter;
    uint8 support; // 0 = AGAINST, 1 = FOR, 2 = ABSTAIN
    uint256 weight; // voting weight at snapshot
}

struct FutarchyView {
    bool enabled;
    address rewardToken;
    uint256 pool;
    bool resolved;
    uint8 winner; // 1 = YES/FOR, 0 = NO/AGAINST
    uint256 finalWinningSupply;
    uint256 payoutPerUnit; // scaled by 1e18
}

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

struct TokenBalance {
    address token; // address(0) = native ETH
    uint256 balance;
}

struct DAOTreasury {
    TokenBalance[] balances;
}

struct MessageView {
    uint256 index;
    string text;
}

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

struct UserMemberView {
    address dao;
    DAOMeta meta;
    DAOGovConfig gov;
    DAOTokenSupplies supplies;
    DAOTreasury treasury;
    MemberView member;
}

struct UserDAOLens {
    DAOLens dao;
    MemberView member;
}

/* -------------------------------------------------------------------------- */
/*                              VIEW HELPER CONTRACT                          */
/* -------------------------------------------------------------------------- */

contract MolochViewHelper {
    /* ---------------------------- Core references --------------------------- */

    // Summoner factory (same CREATE2 address on all supported networks)
    ISummoner public constant SUMMONER = ISummoner(0x0000000000330B8df9E3bc5E553074DA58eE9138);

    /* ---------------------------------------------------------------------- */
    /*                             DAO PAGINATION                             */
    /* ---------------------------------------------------------------------- */

    /// @notice Get a slice of DAOs created by the Summoner.
    /// @param start  Index into Summoner.daos[]
    /// @param count  Max number of DAOs to return
    function getDaos(uint256 start, uint256 count) public view returns (address[] memory out) {
        uint256 total = SUMMONER.getDAOCount();
        if (start >= total) {
            return new address[](total);
        }

        uint256 end = start + count;
        if (end > total) end = total;

        uint256 len = end - start;
        out = new address[](len);

        for (uint256 i; i < len; ++i) {
            out[i] = SUMMONER.daos(start + i);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                      SINGLE-DAO: FULL STATE SNAPSHOT                   */
    /* ---------------------------------------------------------------------- */

    /// @notice Full state for a single DAO: meta, config, supplies, members,
    ///         proposals & votes, futarchy, treasury, messages.
    /// @param dao The DAO address
    /// @param proposalStart Starting index for proposals
    /// @param proposalCount Number of proposals to fetch
    /// @param messageStart Starting index for messages
    /// @param messageCount Number of messages to fetch
    /// @param treasuryTokens Array of token addresses to check balances for (address(0) = native ETH)
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

    /* ---------------------------------------------------------------------- */
    /*                    MULTI-DAO: FULL STATE SNAPSHOT ARRAY                */
    /* ---------------------------------------------------------------------- */

    /// @notice One-shot fetch of multiple DAOs' state for the UI.
    ///
    /// For each DAO in [daoStart, daoStart+daoCount), returns:
    ///  - meta (name, symbol, contractURI, token addresses)
    ///  - governance config
    ///  - token supplies + DAO-held shares/loot
    ///  - members (badge seats) + voting power + delegation splits
    ///  - proposals [proposalStart .. proposalStart+proposalCount)
    ///  - per-proposal tallies, state, per-member votes
    ///  - per-proposal futarchy config
    ///  - treasury balances for specified tokens
    ///  - messages [messageStart .. messageStart+messageCount)
    /// @param treasuryTokens Array of token addresses to check balances for (address(0) = native ETH)
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
            return new DAOLens[](total);
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

    /* ---------------------------------------------------------------------- */
    /*                       USER-FOCUSED PORTFOLIO VIEW                      */
    /* ---------------------------------------------------------------------- */

    /// @notice Find all DAOs (within a slice) where `user` has shares, loot, or a badge seat.
    /// @dev Lightweight summary: no proposals/messages; intended for wallet dashboards.
    /// @param treasuryTokens Array of token addresses to check balances for (address(0) = native ETH)
    function getUserDAOs(address user, uint256 daoStart, uint256 daoCount, address[] calldata treasuryTokens)
        public
        view
        returns (UserMemberView[] memory out)
    {
        uint256 total = SUMMONER.getDAOCount();
        if (daoStart >= total) {
            return new UserMemberView[](total);
        }

        uint256 daoEnd = daoStart + daoCount;
        if (daoEnd > total) daoEnd = total;

        // First pass: count matches
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

        // Second pass: populate views
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

            // Meta
            DAOMeta memory meta;
            meta.name = M.name(0);
            meta.symbol = M.symbol(0);
            meta.contractURI = M.contractURI();
            meta.sharesToken = sharesToken;
            meta.lootToken = lootToken;
            meta.badgesToken = badgesToken;
            meta.renderer = M.renderer();

            // Gov config
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

            // Supplies
            DAOTokenSupplies memory supplies;
            supplies.sharesTotalSupply = IShares(sharesToken).totalSupply();
            supplies.lootTotalSupply = ILoot(lootToken).totalSupply();
            supplies.sharesHeldByDAO = IShares(sharesToken).balanceOf(dao);
            supplies.lootHeldByDAO = ILoot(lootToken).balanceOf(dao);

            // Treasury snapshot
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

    /// @notice Full DAO state (like getDAOsFullState) but filtered to DAOs where `user` is a member.
    /// @dev This is the heavy "one-shot" user-dashboard view: use small daoCount / proposalCount / messageCount.
    /// @param treasuryTokens Array of token addresses to check balances for (address(0) = native ETH)
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
            return new UserDAOLens[](total);
        }

        uint256 daoEnd = daoStart + daoCount;
        if (daoEnd > total) daoEnd = total;

        // First pass: count matches
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

        // Second pass: build full DAO state + user member view
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

    /* ---------------------------------------------------------------------- */
    /*                         DAO MESSAGES / CHAT VIEW                       */
    /* ---------------------------------------------------------------------- */

    /// @notice Paginated fetch of DAO messages (chat).
    /// @dev Only message text + index is available on-chain with current Moloch storage.
    function getDAOMessages(address dao, uint256 start, uint256 count)
        public
        view
        returns (MessageView[] memory out)
    {
        out = _getMessagesInternal(dao, start, count);
    }

    /* ---------------------------------------------------------------------- */
    /*                             INTERNAL BUILDERS                          */
    /* ---------------------------------------------------------------------- */

    function _buildDAOFullState(
        address dao,
        uint256 proposalStart,
        uint256 proposalCount,
        uint256 messageStart,
        uint256 messageCount,
        address[] calldata treasuryTokens
    ) internal view returns (DAOLens memory out) {
        IMoloch M = IMoloch(dao);

        // --- Meta & config

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

        // --- Token supplies & DAO-held inventory

        IShares sharesToken = IShares(meta.sharesToken);
        ILoot lootToken = ILoot(meta.lootToken);

        DAOTokenSupplies memory supplies;
        supplies.sharesTotalSupply = sharesToken.totalSupply();
        supplies.lootTotalSupply = lootToken.totalSupply();
        supplies.sharesHeldByDAO = sharesToken.balanceOf(dao);
        supplies.lootHeldByDAO = lootToken.balanceOf(dao);

        // --- Members, proposals, messages

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

    /* ---------------------------------------------------------------------- */
    /*                           MEMBER ENUMERATION                           */
    /* ---------------------------------------------------------------------- */

    /// @dev Enumerate members as "badge seats" (top-256 by shares, sticky).
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

    /* ---------------------------------------------------------------------- */
    /*                              PROPOSAL VIEWS                            */
    /* ---------------------------------------------------------------------- */

    function _getProposals(IMoloch M, MemberView[] memory members, uint256 start, uint256 count)
        internal
        view
        returns (ProposalView[] memory pv)
    {
        uint256 total = M.getProposalCount();
        if (start >= total) {
            return new ProposalView[](total);
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

            // Futarchy config
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
                // First pass: count actual voters
                uint8[] memory votedCache = new uint8[](memberCount);
                uint256 nVoters;

                for (uint256 j; j < memberCount; ++j) {
                    address voterAddr = members[j].account;
                    uint8 hv = M.hasVoted(pid, voterAddr); // 0=not, 1=FOR, 2=AGAINST, 3=ABSTAIN
                    votedCache[j] = hv;
                    if (hv != 0) {
                        unchecked {
                            ++nVoters;
                        }
                    }
                }

                VoterView[] memory voters = new VoterView[](nVoters);
                uint256 k;

                // Second pass: populate only actual voters
                for (uint256 j; j < memberCount; ++j) {
                    uint8 hv = votedCache[j];
                    if (hv != 0) {
                        address voterAddr = members[j].account;
                        uint96 weight96 = M.voteWeight(pid, voterAddr);

                        voters[k] = VoterView({
                            voter: voterAddr,
                            support: hv - 1, // remap 1..3 -> 0..2
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

    /* ---------------------------------------------------------------------- */
    /*                           MESSAGES (INTERNAL)                          */
    /* ---------------------------------------------------------------------- */

    function _getMessagesInternal(address dao, uint256 start, uint256 count)
        internal
        view
        returns (MessageView[] memory out)
    {
        IMoloch M = IMoloch(dao);
        uint256 total = M.getMessageCount();
        if (start >= total) {
            return new MessageView[](total);
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

    /* ---------------------------------------------------------------------- */
    /*                           TREASURY BALANCE VIEW                        */
    /* ---------------------------------------------------------------------- */

    /// @dev Fetches balances for specified tokens. Uses staticcall to gracefully handle
    ///      missing contracts (returns 0 balance if call fails).
    /// @param dao The DAO address to check balances for
    /// @param tokens Array of token addresses (address(0) = native ETH)
    function _getTreasury(address dao, address[] calldata tokens) internal view returns (DAOTreasury memory t) {
        uint256 len = tokens.length;
        t.balances = new TokenBalance[](len);

        for (uint256 i; i < len; ++i) {
            address token = tokens[i];
            uint256 bal;

            if (token == address(0)) {
                // Native ETH
                bal = dao.balance;
            } else {
                // ERC20 - use staticcall to handle missing contracts gracefully
                (bool success, bytes memory data) = token.staticcall(
                    abi.encodeWithSelector(IERC20.balanceOf.selector, dao)
                );
                if (success && data.length >= 32) {
                    bal = abi.decode(data, (uint256));
                }
                // If call fails or returns invalid data, bal remains 0
            }

            t.balances[i] = TokenBalance({token: token, balance: bal});
        }
    }
}
