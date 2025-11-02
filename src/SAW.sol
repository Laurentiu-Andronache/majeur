// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title SAW — Token-Weighted Multisig Org
/// @notice ERC20 Shares + embedded ERC6909 votes (id = intent hash), votes-threshold execution,
///         top-256 vanity SBT badge (with rank), permits, sales (ETH/ERC20), ragequit, allowances/pull, SBT-gated chat.
contract SAW {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error NotOk();
    error NotOwner();
    error NotApprover();
    error AlreadyExecuted();
    error LengthMismatch();

    /*//////////////////////////////////////////////////////////////
                          ORG / EXECUTION CONFIG
    //////////////////////////////////////////////////////////////*/
    string public orgName;
    string public orgSymbol;

    /// @notice Votes-based execution threshold in basis points (0 = disabled).
    uint16 public votesThresholdBP;

    /// @notice Bump to invalidate old proposal ids (hash salts).
    uint64 public config;

    bool public ragequittable;
    bool public transfersLocked; // global Shares transfer lock

    /*//////////////////////////////////////////////////////////////
                      TOKENS: SHARES (ERC20) / BADGE (SBT)
    //////////////////////////////////////////////////////////////*/
    SAWShares public shares;
    SAWBadge  public badge;

    event SharesDeployed(address token);
    event BadgeDeployed(address badge);

    /*//////////////////////////////////////////////////////////////
                        PER-PROPOSAL EXECUTION STATE
    //////////////////////////////////////////////////////////////*/
    mapping(bytes32 => bool)    public executed; // proposal executed latch
    mapping(bytes32 => uint256) public permits;  // remaining uses (max=unlimited)

    /*//////////////////////////////////////////////////////////////
                           ALLOWANCES / PULL
    //////////////////////////////////////////////////////////////*/
    mapping(address => mapping(address => uint256)) public allowance; // token => recipient => amount

    /*//////////////////////////////////////////////////////////////
                           TREASURY SALES (SHARES)
    //////////////////////////////////////////////////////////////*/
    struct Sale {
        uint256 pricePerShare; // in payToken units (wei for ETH)
        uint256 cap;           // remaining shares (0 = unlimited)
        bool    minting;       // true=mint, false=transfer SAW-held
        bool    active;
    }
    mapping(address => Sale) public sales; // payToken => Sale

    event SaleUpdated(address indexed payToken, uint256 price, uint256 cap, bool minting, bool active);
    event SharesPurchased(address indexed buyer, address indexed payToken, uint256 shares, uint256 paid);

    /*//////////////////////////////////////////////////////////////
                              SBT-GATED CHAT
    //////////////////////////////////////////////////////////////*/
    string[] public messages;

    /*//////////////////////////////////////////////////////////////
                     EMBEDDED ERC6909 VOTES (ID = PROPOSAL HASH)
    //////////////////////////////////////////////////////////////*/
    // ERC6909 metadata: always org name/symbol (shared across ids)
    function name(uint256 /*id*/) external view returns (string memory) { return orgName; }
    function symbol(uint256 /*id*/) external view returns (string memory) { return orgSymbol; }

    event OperatorSet(address indexed owner, address indexed operator, bool approved);
    event Approval(address indexed owner, address indexed spender, uint256 indexed id, uint256 amount);
    event Transfer(address caller, address indexed from, address indexed to, uint256 indexed id, uint256 amount);

    mapping(address => mapping(address => bool)) public isOperator;
    mapping(address => mapping(uint256 => uint256)) public balanceOf6909; // holder => id => amount
    mapping(address => mapping(address => mapping(uint256 => uint256))) public allowance6909; // holder => spender => id => amount
    mapping(uint256 => uint256) public totalVotes; // id => total

    /*//////////////////////////////////////////////////////////////
                         TOP-256 HOLDERS (VANITY SBT)
    //////////////////////////////////////////////////////////////*/
    address[256] public topHolders;
    uint16       public topCount;             // number of filled slots
    mapping(address => uint16) public topPos; // 1..256; 0=not present

    /// @notice Slot index 1..256 if in top set, else 0 (not strictly sorted by balance).
    function rankOf(address a) public view returns (uint256) { return topPos[a]; }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Executed(bytes32 indexed hash, address indexed by, uint8 op, address to, uint256 value);
    event PermitSet(bytes32 indexed hash, uint256 newCount, bool replaced);
    event PermitSpent(bytes32 indexed hash, address indexed by, uint8 op, address to, uint256 value);

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        string memory _orgName,
        string memory _orgSymbol,
        uint16 _votesThresholdBP,        // e.g. 5000 = 50%
        bool _ragequittable,
        address[] memory initialHolders,
        uint256[] memory initialAmounts
    ) payable {
        if (initialHolders.length != initialAmounts.length) revert LengthMismatch();

        orgName = _orgName;
        orgSymbol = _orgSymbol;
        votesThresholdBP = _votesThresholdBP;
        ragequittable = _ragequittable;

        // Deploy Shares + Badge; names/symbols are pulled from SAW.
        shares = new SAWShares(initialHolders, initialAmounts);
        emit SharesDeployed(address(shares));
        badge = new SAWBadge();
        emit BadgeDeployed(address(badge));

        // Seed top set via hook.
        for (uint256 i = 0; i < initialHolders.length; ++i) {
            _onSharesChanged(initialHolders[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                         GOVERNANCE: EXECUTE BY VOTES
    //////////////////////////////////////////////////////////////*/
    /// @notice Execute when locked votes for this intent meet the threshold.
    function executeByVotes(
        uint8 op,                // 0 = call, 1 = delegatecall
        address to,
        uint256 value,
        bytes calldata data,
        bytes32 nonce
    ) external payable returns (bool ok, bytes memory retData) {
        if (votesThresholdBP == 0) revert NotOk();
        bytes32 h = _intentHash(op, to, value, data, nonce);
        if (executed[h]) revert AlreadyExecuted();

        uint256 ts = shares.totalSupply();
        uint256 tv = totalVotes[uint256(h)];
        if (ts == 0) revert NotOk();
        if (tv * 10000 < uint256(votesThresholdBP) * ts) revert NotApprover();

        executed[h] = true;

        if (op == 0) { (ok, retData) = to.call{value: value}(data); }
        else { (ok, retData) = to.delegatecall(data); }
        if (!ok) revert NotOk();

        emit Executed(h, msg.sender, op, to, value);
    }

    /// @notice Governance "bump" to invalidate pre-bump proposal hashes.
    function bumpConfig() external {
        if (msg.sender != address(this)) revert NotOwner();
        unchecked { ++config; }
    }

    /*//////////////////////////////////////////////////////////////
                                  PERMITS
    //////////////////////////////////////////////////////////////*/
    function setPermit(
        uint8 op, address to, uint256 value, bytes calldata data, bytes32 nonce,
        uint256 count, bool replaceCount
    ) external {
        if (msg.sender != address(this)) revert NotOwner();
        bytes32 h = _intentHash(op, to, value, data, nonce);
        if (replaceCount) permits[h] = count; else { unchecked { permits[h] += count; } }
        emit PermitSet(h, permits[h], replaceCount);
    }

    /// @notice Spend a permit to execute without re-locking votes.
    function permitExecute(
        uint8 op, address to, uint256 value, bytes calldata data, bytes32 nonce
    ) external payable returns (bool ok, bytes memory retData) {
        bytes32 h = _intentHash(op, to, value, data, nonce);
        uint256 p = permits[h]; if (p == 0) revert NotApprover();

        // Effects
        if (!executed[h]) executed[h] = true;
        if (p != type(uint256).max) permits[h] = p - 1;

        // Interactions
        if (op == 0) { (ok, retData) = to.call{value: value}(data); }
        else { (ok, retData) = to.delegatecall(data); }
        if (!ok) revert NotOk();

        emit PermitSpent(h, msg.sender, op, to, value);
    }

    /*//////////////////////////////////////////////////////////////
                           ERC6909: VOTING FLOWS
    //////////////////////////////////////////////////////////////*/
    // Minimal ERC6909 primitives (optional vote delegation).
    function transfer(address to, uint256 id, uint256 amount) external returns (bool) {
        balanceOf6909[msg.sender][id] -= amount; balanceOf6909[to][id] += amount;
        emit Transfer(msg.sender, msg.sender, to, id, amount); return true;
    }
    function transferFrom(address from, address to, uint256 id, uint256 amount) external returns (bool) {
        if (msg.sender != from && !isOperator[from][msg.sender]) {
            uint256 a = allowance6909[from][msg.sender][id]; if (a != type(uint256).max) allowance6909[from][msg.sender][id] = a - amount;
        }
        balanceOf6909[from][id] -= amount; balanceOf6909[to][id] += amount;
        emit Transfer(msg.sender, from, to, id, amount); return true;
    }
    function approve(address spender, uint256 id, uint256 amount) external returns (bool) {
        allowance6909[msg.sender][spender][id] = amount; emit Approval(msg.sender, spender, id, amount); return true;
    }
    function setOperator(address operator, bool approved_) external returns (bool) {
        isOperator[msg.sender][operator] = approved_; emit OperatorSet(msg.sender, operator, approved_); return true;
    }
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x01ffc9a7 || interfaceId == 0x0f632fb3; // ERC165 / ERC6909
    }

    /// @notice Lock Shares into vote id (proposal) — id is bytes32 hash cast to uint256.
    function depositVotes(uint256 id, uint256 amount) external {
        if (executed[bytes32(id)]) revert AlreadyExecuted();
        _safeTransferFrom(address(shares), msg.sender, address(this), amount);
        _mint6909(msg.sender, id, amount);
    }
    /// @notice Unlock votes back into Shares.
    function withdrawVotes(uint256 id, uint256 amount) external {
        _burn6909(msg.sender, id, amount);
        _safeTransfer(address(shares), msg.sender, amount);
    }
    /// @notice Move votes between proposals.
    function pivotVotes(uint256 fromId, uint256 toId, uint256 amount) external {
        if (executed[bytes32(toId)]) revert AlreadyExecuted();
        _burn6909(msg.sender, fromId, amount); _mint6909(msg.sender, toId, amount);
    }
    /// @notice Burn votes (cancel).
    function cancelVote(uint256 id, uint256 amount) external { _burn6909(msg.sender, id, amount); }

    /// @notice On-chain JSON/SVG card for vote id.
    function tokenURI(uint256 id) external view returns (string memory) {
        string memory idHex = _toHex(bytes32(id));
        uint256 tv = totalVotes[id];
        uint256 ts = shares.totalSupply();
        string memory svg = string.concat(
            "<svg xmlns='http://www.w3.org/2000/svg' width='480' height='320'>",
              "<rect width='100%' height='100%' fill='#111'/>",
              "<text x='18' y='42' font-family='Courier New, monospace' font-size='18' fill='#fff'>", orgName, " Proposal</text>",
              "<text x='18' y='80' font-family='Courier New, monospace' font-size='12' fill='#fff'>id: ", idHex, "</text>",
              "<text x='18' y='110' font-family='Courier New, monospace' font-size='12' fill='#fff'>votes: ", _u2s(tv), " / ", _u2s(ts), "</text>",
            "</svg>"
        );
        return string.concat(
            "data:application/json;utf8,",
            "{\"name\":\"", orgName, " Proposal\",\"description\":\"ERC6909 vote token\",",
            "\"image\":\"data:image/svg+xml;utf8,", svg, "\"}"
        );
    }

    /*//////////////////////////////////////////////////////////////
                            SALES (ETH / ERC20)
    //////////////////////////////////////////////////////////////*/
    function setSale(address payToken, uint256 pricePerShare, uint256 cap, bool minting, bool active) external {
        if (msg.sender != address(this)) revert NotOwner();
        sales[payToken] = Sale({pricePerShare: pricePerShare, cap: cap, minting: minting, active: active});
        emit SaleUpdated(payToken, pricePerShare, cap, minting, active);
    }

    function buyShares(address payToken, uint256 shareAmount, uint256 maxPay) external payable {
        Sale memory s = sales[payToken];
        if (!s.active) revert NotApprover();

        if (s.cap != 0 && shareAmount > s.cap) revert NotOk();
        uint256 cost = shareAmount * s.pricePerShare;
        if (shareAmount != 0 && cost / shareAmount != s.pricePerShare) revert NotOk(); // overflow guard

        // EFFECTS first (CEI) to prevent oversell on reentry
        if (s.cap != 0) sales[payToken].cap = s.cap - shareAmount;

        // pull funds
        if (payToken == address(0)) {
            if (msg.value != cost) revert NotOk();
        } else {
            if (maxPay != 0 && cost > maxPay) revert NotOk();
            _safeTransferFrom(payToken, msg.sender, address(this), cost);
        }

        // issue shares
        if (s.minting) {
            shares.mintFromSAW(msg.sender, shareAmount);
        } else {
            shares.transfer(msg.sender, shareAmount); // SAW must hold enough
        }

        emit SharesPurchased(msg.sender, payToken, shareAmount, cost);
    }

    /*//////////////////////////////////////////////////////////////
                           ALLOWANCES / PULL
    //////////////////////////////////////////////////////////////*/
    function setAllowanceTo(address token, address to, uint256 amount) external {
        if (msg.sender != address(this)) revert NotOwner();
        allowance[token][to] = amount;
    }

    function claimAllowance(address token, uint256 amount) external {
        allowance[token][msg.sender] -= amount;
        if (token == address(0)) { (bool ok,) = payable(msg.sender).call{value: amount}(""); if (!ok) revert NotOk(); return; }
        _safeTransfer(token, msg.sender, amount);
    }

    function pull(address token, address from, uint256 amount) external {
        if (msg.sender != address(this)) revert NotOwner();
        _safeTransferFrom(token, from, address(this), amount);
    }

    /*//////////////////////////////////////////////////////////////
                               RAGE-QUIT
    //////////////////////////////////////////////////////////////*/
    function rageQuit(address[] calldata tokens) external {
        if (!ragequittable) revert NotApprover();
        uint256 amt = shares.balanceOf(msg.sender); if (amt == 0) revert NotOk();
        uint256 ts  = shares.totalSupply();

        shares.burnFromSAW(msg.sender, amt); // updates top-256 + SBT

        for (uint256 i = 0; i < tokens.length; ++i) {
            address tk = tokens[i];
            if (tk == address(0)) {
                uint256 pool = address(this).balance;
                uint256 due  = (pool * amt) / ts;
                if (due != 0) { (bool ok,) = payable(msg.sender).call{value: due}(""); if (!ok) revert NotOk(); }
            } else {
                uint256 pool = _erc20Balance(tk);
                uint256 due  = (pool * amt) / ts;
                if (due != 0) _safeTransfer(tk, msg.sender, due);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        SBT-GATED CHAT
    //////////////////////////////////////////////////////////////*/

    event Message(address indexed from, uint256 indexed index, string text);

    function getMessageCount() external view returns (uint256) {
        return messages.length;
    }

    function chat(string calldata text) external payable {
        // Only badge holders (top-256) can post
        if (badge.balanceOf(msg.sender) == 0) revert NotApprover();
        messages.push(text);
        emit Message(msg.sender, messages.length - 1, text);
    }

    /*//////////////////////////////////////////////////////////////
                             GOV HELPERS (SELF)
    //////////////////////////////////////////////////////////////*/
    function setVotesThresholdBP(uint16 bp) external { if (msg.sender != address(this)) revert NotOwner(); votesThresholdBP = bp; }
    function setRagequittable(bool on) external { if (msg.sender != address(this)) revert NotOwner(); ragequittable = on; }
    function setTransfersLocked(bool on) external { if (msg.sender != address(this)) revert NotOwner(); transfersLocked = on; }

    /*//////////////////////////////////////////////////////////////
                          SHARES HOOK (TOP-256 + SBT)
    //////////////////////////////////////////////////////////////*/
    function onSharesChanged(address a) external { if (msg.sender != address(shares)) revert NotOwner(); _onSharesChanged(a); }

    function _onSharesChanged(address a) internal {
        uint256 bal = shares.balanceOf(a);
        bool inTop = (topPos[a] != 0);

        if (bal == 0) {
            _removeFromTop(a);
            if (badge.balanceOf(a) != 0) badge.burn(a);
            return;
        }
        if (inTop) return; // already in set

        if (topCount < 256) {
            _addToTop(a);
            if (badge.balanceOf(a) == 0) badge.mint(a);
        } else {
            // Replace current min if this holder surpasses it
            uint16 minI = 0; uint256 minBal = type(uint256).max;
            for (uint16 i = 0; i < 256; ++i) {
                address cur = topHolders[i];
                uint256 cbal = shares.balanceOf(cur);
                if (cbal < minBal) { minBal = cbal; minI = i; }
            }
            if (bal > minBal) {
                address evict = topHolders[minI];
                topHolders[minI] = a;
                topPos[a] = minI + 1;
                topPos[evict] = 0;

                // badges
                if (badge.balanceOf(evict) != 0) badge.burn(evict);
                if (badge.balanceOf(a) == 0) badge.mint(a);
            }
        }
    }

    function _addToTop(address a) internal {
        for (uint16 i = 0; i < 256; ++i) {
            if (topHolders[i] == address(0)) {
                topHolders[i] = a; topPos[a] = i + 1; topCount++; return;
            }
        }
    }
    function _removeFromTop(address a) internal {
        uint16 p = topPos[a]; if (p == 0) return;
        topHolders[p - 1] = address(0); topPos[a] = 0; if (topCount > 0) topCount--;
    }

    /*//////////////////////////////////////////////////////////////
                             RECEIVE / ERCs
    //////////////////////////////////////////////////////////////*/
    receive() external payable {}
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /*//////////////////////////////////////////////////////////////
                               INTERNALS
    //////////////////////////////////////////////////////////////*/
    function _intentHash(uint8 op, address to, uint256 value, bytes calldata data, bytes32 nonce)
        internal view returns (bytes32)
    {   return keccak256(abi.encode(address(this), op, to, value, keccak256(data), nonce, config)); }

    function _mint6909(address to, uint256 id, uint256 amount) internal {
        balanceOf6909[to][id] += amount; totalVotes[id] += amount; emit Transfer(msg.sender, address(0), to, id, amount);
    }
    function _burn6909(address from, uint256 id, uint256 amount) internal {
        balanceOf6909[from][id] -= amount; totalVotes[id] -= amount; emit Transfer(msg.sender, from, address(0), id, amount);
    }

    function _safeTransfer(address token, address to, uint256 amount) private {
        (bool ok, bytes memory ret) = token.call(abi.encodeWithSelector(IToken.transfer.selector, to, amount));
        if (!(ok && (ret.length == 0 || abi.decode(ret, (bool))))) revert NotOk();
    }
    function _safeTransferFrom(address token, address from, address to, uint256 amount) private {
        (bool ok, bytes memory ret) = token.call(abi.encodeWithSelector(IToken.transferFrom.selector, from, to, amount));
        if (!(ok && (ret.length == 0 || abi.decode(ret, (bool))))) revert NotOk();
    }
    function _erc20Balance(address token) private view returns (uint256 bal) {
        (bool ok, bytes memory ret) = token.staticcall(abi.encodeWithSignature("balanceOf(address)", address(this)));
        if (ok && ret.length >= 32) bal = abi.decode(ret, (uint256));
    }

    // small helpers for SVGs
    function _toHex(bytes32 data) internal pure returns (string memory) {
        bytes16 H = 0x30313233343536373839616263646566;
        bytes memory out = new bytes(66); out[0] = "0"; out[1] = "x";
        for (uint256 i = 0; i < 32; ++i) {
            uint8 b = uint8(data[i]);
            out[2 + 2*i] = bytes1(H[b >> 4]);
            out[3 + 2*i] = bytes1(H[b & 0x0f]);
        }
        return string(out);
    }
    function _u2s(uint256 x) internal pure returns (string memory) {
        if (x == 0) return "0"; uint256 t = x; uint256 l; while (t != 0) { l++; t /= 10; }
        bytes memory out = new bytes(l); while (x != 0) { out[--l] = bytes1(uint8(48 + x % 10)); x /= 10; }
        return string(out);
    }
}

/*//////////////////////////////////////////////////////////////
                         MINIMAL EXTERNALS
//////////////////////////////////////////////////////////////*/
interface IToken {
    function transfer(address, uint256) external;
    function transferFrom(address, address, uint256) external;
}

/// @notice ERC20 Shares with dynamic name/symbol from SAW and a global transfer lock.
contract SAWShares {
    /* ERRORS */
    error Len();
    error Locked();

    /* ERC20 */
    event Approval(address indexed from, address indexed to, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    uint256 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address holder => uint256) public balanceOf;
    mapping(address holder => mapping(address spender => uint256)) public allowance;

    address payable public immutable saw;

    constructor(address[] memory to, uint256[] memory amt) payable {
        saw = payable(msg.sender);
        if (to.length != amt.length) revert Len();
        for (uint256 i = 0; i < to.length; ++i) _mint(to[i], amt[i]);
    }

    // dynamic metadata from SAW
    function name() public view returns (string memory) { return string.concat(SAW(saw).orgName(), " Shares"); }
    function symbol() public view returns (string memory) { return SAW(saw).orgSymbol(); }

    function approve(address to, uint256 amount) public returns (bool) {
        allowance[msg.sender][to] = amount; emit Approval(msg.sender, to, amount); return true;
    }
    function transfer(address to, uint256 amount) public returns (bool) {
        if (SAW(saw).transfersLocked()) revert Locked();
        balanceOf[msg.sender] -= amount; unchecked { balanceOf[to] += amount; }
        emit Transfer(msg.sender, to, amount);
        SAW(saw).onSharesChanged(msg.sender);
        SAW(saw).onSharesChanged(to);
        return true;
    }
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        if (SAW(saw).transfersLocked()) revert Locked();
        if (allowance[from][msg.sender] != type(uint256).max) allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount; unchecked { balanceOf[to] += amount; }
        emit Transfer(from, to, amount);
        SAW(saw).onSharesChanged(from);
        SAW(saw).onSharesChanged(to);
        return true;
    }

    function mintFromSAW(address to, uint256 amount) external {
        require(msg.sender == saw, "SAW");
        _mint(to, amount);
        SAW(saw).onSharesChanged(to);
    }
    function burnFromSAW(address from, uint256 amount) external {
        require(msg.sender == saw, "SAW");
        balanceOf[from] -= amount; unchecked { totalSupply -= amount; }
        emit Transfer(from, address(0), amount);
        SAW(saw).onSharesChanged(from);
    }

    function _mint(address to, uint256 amount) internal {
        unchecked { totalSupply += amount; balanceOf[to] += amount; }
        emit Transfer(address(0), to, amount);
    }
}

/// @notice Non-transferable top-256 vanity badge (SBT). ID is holder address (uint160).
///         tokenURI shows org name, holder address, balance, % of supply, and rank (slot index).
contract SAWBadge {
    /* ERC721-ish */
    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    address payable public immutable saw;

    mapping(uint256 => address) internal _ownerOf;
    mapping(address  => uint256) internal _balanceOf;

    constructor() payable { saw = payable(msg.sender); }

    // dynamic metadata from SAW
    function name() public view returns (string memory) { return string.concat(SAW(saw).orgName(), " Badge"); }
    function symbol() public view returns (string memory) { return string.concat(SAW(saw).orgSymbol(), "B"); }

    function ownerOf(uint256 id) public view returns (address o) { require((o = _ownerOf[id]) != address(0), "NOT_MINTED"); }
    function balanceOf(address o) public view returns (uint256) { require(o != address(0), "ZERO"); return _balanceOf[o]; }

    function tokenURI(uint256 id) external view returns (string memory) {
        address holder = address(uint160(id));
        SAWShares sh = SAW(saw).shares();
        uint256 bal = sh.balanceOf(holder);
        uint256 ts  = sh.totalSupply();
        uint256 rk  = SAW(saw).rankOf(holder); // 0 if not in top set

        string memory addr = _addrHex(holder);
        string memory pct  = _percent(bal, ts);
        string memory rank = rk == 0 ? "-" : _u2s(rk);

        string memory svg = string.concat(
            "<svg xmlns='http://www.w3.org/2000/svg' width='420' height='420'>",
              "<rect width='100%' height='100%' fill='#111'/>",
              "<text x='20' y='60'  font-family='Courier New, monospace' font-size='18' fill='#fff'>", name(), "</text>",
              "<text x='20' y='100' font-family='Courier New, monospace' font-size='12' fill='#fff' letter-spacing='1'>", addr, "</text>",
              "<text x='20' y='130' font-family='Courier New, monospace' font-size='12' fill='#fff'>balance: ", _u2s(bal), "</text>",
              "<text x='20' y='150' font-family='Courier New, monospace' font-size='12' fill='#fff'>supply: ", _u2s(ts), "</text>",
              "<text x='20' y='170' font-family='Courier New, monospace' font-size='12' fill='#fff'>percent: ", pct, "</text>",
              "<text x='20' y='190' font-family='Courier New, monospace' font-size='12' fill='#fff'>rank: ", rank, "</text>",
            "</svg>"
        );
        return string.concat(
            "data:application/json;utf8,",
            "{\"name\":\"", name(), "\",\"description\":\"Top-256 holder badge (slot rank)\",",
            "\"image\":\"data:image/svg+xml;utf8,", svg, "\"}"
        );
    }

    function transferFrom(address, address, uint256) external pure { revert("SBT"); }

    function mint(address to) external {
        require(msg.sender == saw, "SAW");
        uint256 id = uint256(uint160(to));
        require(to != address(0) && _ownerOf[id] == address(0), "MINTED");
        _ownerOf[id] = to; unchecked { _balanceOf[to]++; }
        emit Transfer(address(0), to, id);
    }
    function burn(address from) external {
        require(msg.sender == saw, "SAW");
        uint256 id = uint256(uint160(from));
        require(_ownerOf[id] == from, "OWN");
        _ownerOf[id] = address(0); unchecked { _balanceOf[from]--; }
        emit Transfer(from, address(0), id);
    }

    /* utils */
    function _addrHex(address a) internal pure returns (string memory s) {
        bytes20 b = bytes20(a); bytes16 H = 0x30313233343536373839616263646566;
        bytes memory out = new bytes(42); out[0]="0"; out[1]="x";
        for (uint256 i=0;i<20;++i){ uint8 v=uint8(b[i]); out[2+2*i]=bytes1(H[v>>4]); out[3+2*i]=bytes1(H[v&0x0f]); }
        s = string(out);
    }
    function _u2s(uint256 x) internal pure returns (string memory) {
        if (x == 0) return "0"; uint256 t=x; uint256 l; while (t!=0){l++; t/=10;} bytes memory out=new bytes(l);
        while (x!=0){ out[--l]=bytes1(uint8(48 + x%10)); x/=10; } return string(out);
    }
    function _percent(uint256 a, uint256 b) internal pure returns (string memory) {
        if (b == 0) return "0.00%"; uint256 p = a * 10000 / b; uint256 i = p / 100; uint256 d = p % 100;
        return string.concat(_u2s(i), ".", d < 10 ? "0" : "", _u2s(d), "%");
    }
}