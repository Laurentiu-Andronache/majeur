# Moloch (Majeur) DAO Framework

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/solidity-%5E0.8.30-black)](https://docs.soliditylang.org/en/v0.8.30/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-000000.svg)](https://getfoundry.sh/)

[![IPFS Image](https://content.wrappr.wtf/ipfs/bafybeih2mxprvjigedatwn5tdgjx6mcpktfd75t736kkrpjfepcll2n3o4)](https://content.wrappr.wtf/ipfs/bafybeih2mxprvjigedatwn5tdgjx6mcpktfd75t736kkrpjfepcll2n3o4)

**A minimally maximalized DAO governance framework** — Wyoming DUNA-shielded, futarchy-enabled, lightweight membership orgs with weighted delegation and soulbound shareholder council badges.

## Deployments

Summoner: [`0x0000000000330B8df9E3bc5E553074DA58eE9138`](https://contractscan.xyz/contract/0x0000000000330B8df9E3bc5E553074DA58eE9138)

Renderer: [`0x00000000005556244d291c4C7187cDF3702A0019`](https://contractscan.xyz/contract/0x00000000005556244d291c4C7187cDF3702A0019)

## TL;DR

Moloch (Majeur) is a DAO framework where:
- **Members vote** with shares (tokens) on proposals
- **Votes can be split** between multiple delegates (e.g., 60% Alice, 40% Bob)
- **Prediction markets** reward correct voters (futarchy)
- **Members can exit** anytime with their treasury portion (ragequit)
- **Top 256 holders** get special badges for exclusive features
- **Everything is on-chain** including the visual art (SVGs)

## Overview

Moloch (Majeur) is a comprehensive DAO framework that combines:
- **ERC-20 Shares**: Voting power tokens with delegation and split delegation support
- **ERC-20 Loot**: Non-voting economic tokens for profit sharing  
- **ERC-6909 Receipts**: Vote receipts that become redeemable in futarchy markets
- **ERC-721 Badges**: Non-transferable badges for top 256 shareholders
- **Advanced Governance**: Timelocks, permits, token sales, and ragequit functionality

## Architecture

<img src="<svg xmlns='http://www.w3.org/2000/svg' width='700' height='400' viewBox='0 0 700 400'>
  <rect width='700' height='400' fill='#000'/>
  <style>
    .m{font-family:monospace;font-size:12px;fill:#fff;}
    .label{font-family:monospace;font-size:10px;fill:#888;}
  </style>
  
  <!-- Title -->
  <text x='350' y='30' class='m' text-anchor='middle'>MAJEUR ARCHITECTURE</text>
  
  <!-- Moloch (Main) -->
  <rect x='250' y='60' width='200' height='80' fill='none' stroke='#fff' stroke-width='2'/>
  <text x='350' y='90' class='m' text-anchor='middle'>--------------------</text>
  <text x='350' y='105' class='m' text-anchor='middle'>|     MOLOCH     |</text>
  <text x='350' y='120' class='m' text-anchor='middle'>|  (Main DAO)   |</text>
  <text x='350' y='135' class='m' text-anchor='middle'>--------------------</text>
  
  <!-- Connection lines -->
  <line x1='350' y1='140' x2='350' y2='180' stroke='#fff' stroke-width='1'/>
  <line x1='350' y1='180' x2='150' y2='180' stroke='#fff' stroke-width='1'/>
  <line x1='350' y1='180' x2='550' y2='180' stroke='#fff' stroke-width='1'/>
  <line x1='150' y1='180' x2='150' y2='210' stroke='#fff' stroke-width='1'/>
  <line x1='350' y1='180' x2='350' y2='210' stroke='#fff' stroke-width='1'/>
  <line x1='550' y1='180' x2='550' y2='210' stroke='#fff' stroke-width='1'/>
  
  <!-- Shares -->
  <rect x='50' y='210' width='200' height='60' fill='none' stroke='#fff' stroke-width='1'/>
  <text x='150' y='235' class='m' text-anchor='middle'>| SHARES |</text>
  <text x='150' y='250' class='label' text-anchor='middle'>ERC20 + Votes</text>
  
  <!-- Loot -->
  <rect x='250' y='210' width='200' height='60' fill='none' stroke='#fff' stroke-width='1'/>
  <text x='350' y='235' class='m' text-anchor='middle'>|  LOOT  |</text>
  <text x='350' y='250' class='label' text-anchor='middle'>ERC20 Only</text>
  
  <!-- Badges -->
  <rect x='450' y='210' width='200' height='60' fill='none' stroke='#fff' stroke-width='1'/>
  <text x='550' y='235' class='m' text-anchor='middle'>| BAGES |</text>
  <text x='550' y='250' class='label' text-anchor='middle'>ERC721 SBT</text>
  
  <!-- Bottom layer -->
  <line x1='350' y1='140' x2='100' y2='320' stroke='#444' stroke-width='1' stroke-dasharray='2,3'/>
  <line x1='350' y1='140' x2='600' y2='320' stroke='#444' stroke-width='1' stroke-dasharray='2,3'/>
  
  <!-- Summoner -->
  <rect x='50' y='320' width='100' height='40' fill='none' stroke='#444' stroke-width='1'/>
  <text x='100' y='345' class='label' text-anchor='middle'>SUMMONER</text>
  
  <!-- Renderer -->
  <rect x='550' y='320' width='100' height='40' fill='none' stroke='#444' stroke-width='1'/>
  <text x='600' y='345' class='label' text-anchor='middle'>RENDERER</text>
</svg>" />

## Core Concepts (Simplified)

### 🗳️ What are Shares vs Loot?
- **Shares**: Your voting power AND economic rights (like stock with voting)
- **Loot**: Just economic rights, no voting (like non-voting preferred stock)
- **Why both?**: Some members may want profits without governance responsibility

### 🎯 What is Futarchy?
Think of it as "betting on outcomes":
1. You vote YES on a proposal
2. You get a receipt for your vote
3. If proposal succeeds → YES voters can claim rewards
4. If proposal fails → NO voters can claim rewards
5. This incentivizes thoughtful voting

### 🏃 What is Ragequit?
Your "exit door" from the DAO:
- Burn your shares/loot → Get proportional treasury
- Example: Own 10% of shares → Get 10% of each treasury token
- Cannot ragequit internal tokens (shares/loot/badges)

### 👥 What is Split Delegation?
Instead of "all-or-nothing" delegation:
- Traditional: 100% of your votes → Alice
- Split: 60% → Alice, 40% → Bob
- Useful for diversifying representation

### 🏅 What are Badges?
- Automatic NFTs for top 256 shareholders
- Soulbound (non-transferable)
- Unlocks features like member chat
- Updates automatically as balances change

## Core Concepts (Technical)

### 1. Token System

The Majeur framework uses a multi-token architecture:

```solidity
// Token types and their roles:
shares   // Voting + economic rights (delegatable)
loot     // Economic rights only (non-voting)  
badges   // Top 256 holder badges (soulbound NFTs)
receipts // Vote receipts (ERC-6909 for futarchy)
```

### 2. Proposal Lifecycle

<img src="<svg xmlns='http://www.w3.org/2000/svg' width='700' height='300' viewBox='0 0 700 300'>
  <rect width='700' height='300' fill='#000'/>
  <style>
    .txt{font-family:monospace;font-size:10px;fill:#fff;}
    .label{font-family:monospace;font-size:8px;fill:#888;}
  </style>
  
  <text x='350' y='30' class='txt' text-anchor='middle'>PROPOSAL LIFECYCLE</text>
  
  <!-- Unopened -->
  <rect x='50' y='60' width='80' height='40' fill='none' stroke='#fff' stroke-width='1'/>
  <text x='90' y='85' class='txt' text-anchor='middle'>UNOPENED</text>
  
  <!-- Active -->
  <rect x='180' y='60' width='80' height='40' fill='none' stroke='#fff' stroke-width='1'/>
  <text x='220' y='85' class='txt' text-anchor='middle'>ACTIVE</text>
  
  <!-- Succeeded -->
  <rect x='310' y='20' width='80' height='40' fill='none' stroke='#0f0' stroke-width='1'/>
  <text x='350' y='45' class='txt' text-anchor='middle'>_________</text>
  <text x='350' y='55' class='txt' text-anchor='middle'>SUCCEEDED</text>
  
  <!-- Defeated -->
  <rect x='310' y='100' width='80' height='40' fill='none' stroke='#f00' stroke-width='1'/>
  <text x='350' y='125' class='txt' text-anchor='middle'>DEFEATED/EXPIRED</text>
  
  <!-- Queued -->
  <rect x='440' y='20' width='80' height='40' fill='none' stroke='#ff0' stroke-width='1'/>
  <text x='480' y='45' class='txt' text-anchor='middle'>QUEUED</text>
  
  <!-- Executed -->
  <rect x='570' y='20' width='80' height='40' fill='none' stroke='#0ff' stroke-width='1'/>
  <text x='610' y='45' class='txt' text-anchor='middle'>EXECUTED</text>
  
  <!-- Arrows -->
  <line x1='130' y1='80' x2='180' y2='80' stroke='#fff' stroke-width='1' marker-end='url(#arrow)'/>
  <line x1='260' y1='80' x2='310' y2='40' stroke='#0f0' stroke-width='1' marker-end='url(#arrow)'/>
  <line x1='260' y1='80' x2='310' y2='120' stroke='#f00' stroke-width='1' marker-end='url(#arrow)'/>
  <line x1='390' y1='40' x2='440' y2='40' stroke='#ff0' stroke-width='1' marker-end='url(#arrow)'/>
  <line x1='520' y1='40' x2='570' y2='40' stroke='#0ff' stroke-width='1' marker-end='url(#arrow)'/>
  
  <!-- Labels -->
  <text x='155' y='70' class='label' text-anchor='middle'>open</text>
  <text x='270' y='50' class='label'>pass?</text>
  <text x='270' y='110' class='label'>fail/timeout</text>
  <text x='415' y='30' class='label' text-anchor='middle'>queue</text>
  <text x='545' y='30' class='label' text-anchor='middle'>exec</text>
  
  <defs>
    <marker id='arrow' markerWidth='10' markerHeight='7' refX='9' refY='3.5' orient='auto' fill='#fff'>
      <polygon points='0,0 10,3.5 0,7' />
    </marker>
  </defs>
</svg>" />

### 3. Futarchy Markets

Proposals can have prediction markets where YES/NO voters compete. Winners split the reward pool proportionally based on their vote weight.

## Visual Card Examples

### DAO Contract Card
<img src="data:image/svg+xml;base64,PHN2ZyB4bWxucz0naHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmcnIHdpZHRoPSc0MjAnIGhlaWdodD0nNjAwJyB2aWV3Qm94PScwIDAgNDIwIDYwMCc+CiAgPHJlY3Qgd2lkdGg9JzQyMCcgaGVpZ2h0PSc2MDAnIGZpbGw9JyMwMDAnLz4KICA8cmVjdCB4PScyMCcgeT0nMjAnIHdpZHRoPSczODAnIGhlaWdodD0nNTYwJyBmaWxsPSdub25lJyBzdHJva2U9JyM4YjAwMDAnIHN0cm9rZS13aWR0aD0nMicvPgogIDxzdHlsZT4KICAgIC5ne2ZvbnQtZmFtaWx5OkdhcmFtb25kLHNlcmlmO30KICAgIC5tYXtmb250LWZhbWlseTptb25vc3BhY2U7Zm9udC1zaXplOjhweDt9CiAgICAuYXtmaWxsOiNmZmY7fQogICAgLmJ7ZmlsbDojOGIwMDAwO30KICAgIC5je2ZpbGw6I2FhYTt9CiAgPC9zdHlsZT4KICAKICA8dGV4dCB4PScyMTAnIHk9JzU1JyBjbGFzcz0nZyBhJyBmb250LXNpemU9JzE4JyB0ZXh0LWFuY2hvcj0nbWlkZGxlJyBsZXR0ZXItc3BhY2luZz0nMyc+TUFKRVVSIERBTTAQ PC90ZXh0PgogIDx0ZXh0IHg9JzIxMCcgeT0nNzUnIGNsYXNzPSdnIGInIGZvbnQtc2l6ZT0nMTAnIHRleHQtYW5jaG9yPSdtaWRkbGUnIGxldHRlci1zcGFjaW5nPScyJz5EVU5BIENPVKVOQU5UPC90ZXh0PgogIDxsaW5lIHgxPSc0MCcgeTE9JzkwJyB4Mj0nMzgwJyB5Mj0nOTAnIHN0cm9rZT0nIzhiMDAwMCcgc3Ryb2tlLXdpZHRoPScxJy8+CiAgCiAgPCEtLSBBU0NJSSBzaWdpbCAtLT4KICA8dGV4dCB4PScyMTAnIHk9JzExNScgY2xhc3M9J21hIGInIHRleHQtYW5jaG9yPSdtaWRkbGUnPl9fXy9cX19fPC90ZXh0PgogIDx0ZXh0IHg9JzIxMCcgeT0nMTI0JyBjbGFzcz0nbWEgYicgdGV4dC1hbmNob3I9J21pZGRsZSc+LyAgXCAgLyAgXDwvdGV4dD4KICA8dGV4dCB4PScyMTAnIHk9JzEzMycgY2xhc3M9J21hIGInIHRleHQtYW5jaG9yPSdtaWRkbGUnPi8gICAgXC8gICAgXDwvdGV4dD4KICA8dGV4dCB4PScyMTAnIHk9JzE0MicgY2xhc3M9J21hIGInIHRleHQtYW5jaG9yPSdtaWRkbGUnPlwgIC9cICAvXCAgLzwvdGV4dD4KICA8dGV4dCB4PScyMTAnIHk9JzE1MScgY2xhc3M9J21hIGInIHRleHQtYW5jaG9yPSdtaWRkbGUnPlwvICBcLyAgXC88L3RleHQ+CiAgPHRleHQgeD0nMjEwJyB5PScxNjAnIGNsYXNzPSdtYSBiJyB0ZXh0LWFuY2hvcj0nbWlkZGxlJz4qPC90ZXh0PgogIAogIDx0ZXh0IHg9JzYwJyB5PScyMDgnIGNsYXNzPSdtYSBhJz4weEFiQ2QuLi4xMjM0PC90ZXh0PgogIDx0ZXh0IHg9JzYwJyB5PScyNDEnIGNsYXNzPSdtYSBhJz5NQUpFVVIgREFPIC8gTUpSPC90ZXh0PgogIDx0ZXh0IHg9JzYwJyB5PScyNzQnIGNsYXNzPSdtYSBhJz4xMDAsMDAwIFNoYXJlczwvdGV4dD4KICA8dGV4dCB4PScyMjAnIHk9JzI3NCcgY2xhc3M9J21hIGEnPjUwLDAwMCBMb290PC90ZXh0PgogIAogIDx0ZXh0IHg9JzIxMCcgeT0nNTQwJyBjbGFzcz0nbWEgYicgdGV4dC1hbmNob3I9J21pZGRsZSc+PCBUSEUGREFPIERFTUFORCBTQUNSSUZJQ0UE0+PC90ZXh0Pgo8L3N2Zz4=" />

### Proposal Card
<img src="data:image/svg+xml;base64,PHN2ZyB4bWxucz0naHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmcnIHdpZHRoPSc0MjAnIGhlaWdodD0nNjAwJz4KICA8cmVjdCB3aWR0aD0nNDIwJyBoZWlnaHQ9JzYwMCcgZmlsbD0nIzAwMCcvPgogIDxyZWN0IHg9JzIwJyB5PScyMCcgd2lkdGg9JzM4MCcgaGVpZ2h0PSc1NjAnIGZpbGw9J25vbmUnIHN0cm9rZT0nI2ZmZicgc3Ryb2tlLXdpZHRoPScxJy8+CiAgPHN0eWxlPgogICAgLmd7Zm9udC1mYW1pbHk6R2FyYW1vbmQsc2VyaWY7fQogICAgLm17Zm9udC1mYW1pbHk6bW9ub3NwYWNlO30KICA8L3N0eWxlPgogIAogIDx0ZXh0IHg9JzIxMCcgeT0nNTUnIGNsYXNzPSdnJyBmb250LXNpemU9JzE4JyBmaWxsPScjZmZmJyB0ZXh0LWFuY2hvcj0nbWlkZGxlJyBsZXR0ZXItc3BhY2luZz0nMyc+TUFKRVVSIERBTTAQ PC90ZXh0PgogIDx0ZXh0IHg9JzIxMCcgeT0nNzUnIGNsYXNzPSdnJyBmb250LXNpemU9JzExJyBmaWxsPScjZmZmJyB0ZXh0LWFuY2hvcj0nbWlkZGxlJyBsZXR0ZXItc3BhY2luZz0nMic+UFJPUE9TQUw8L3RleHQ+CiAgPGxpbmUgeDE9JzQwJyB5MT0nOTAnIHgyPSczODAnIHkyPSc5MCcgc3Ryb2tlPScjZmZmJyBzdHJva2Utd2lkdGg9JzEnLz4KICAKICA8IS0tIEFTQ0lJIGV5ZSAtLT4KICA8dGV4dCB4PScyMTAnIHk9JzE1NScgY2xhc3M9J20nIGZvbnQtc2l6ZT0nOScgZmlsbD0nI2ZmZicgdGV4dC1hbmNob3I9J21pZGRsZSc+Li0tLS0tLS0tLS48L3RleHQ+CiAgPHRleHQgeD0nMjEwJyB5PScxNjYnIGNsYXNzPSdtJyBmb250LXNpemU9JzknIGZpbGw9JyNmZmYnIHRleHQtYW5jaG9yPSdtaWRkbGUnPihgICAgIE8gICAgIGApPC90ZXh0PgogIDx0ZXh0IHg9JzIxMCcgeT0nMTc3JyBjbGFzcz0nbScgZm9udC1zaXplPSc5JyBmaWxsPScjZmZmJyB0ZXh0LWFuY2hvcj0nbWlkZGxlJz4nLS0tLS0tLS0tJzwvdGV4dD4KICAKICA8dGV4dCB4PSc2MCcgeT0nMjcyJyBjbGFzcz0nbScgZm9udC1zaXplPSc5JyBmaWxsPScjZmZmJz4xMjM0Li4uNTY3ODwvdGV4dD4KICA8dGV4dCB4PSc2MCcgeT0nMzIyJyBjbGFzcz0nbScgZm9udC1zaXplPSc5JyBmaWxsPScjZmZmJz5CbG9jayAzMTQxNTkyPC90ZXh0PgogIDx0ZXh0IHg9JzYwJyB5PSczMzUnIGNsYXNzPSdtJyBmb250LXNpemU9JzknIGZpbGw9JyNmZmYnPlN1cHBseSAxMDAsMDAwPC90ZXh0PgogIAogIDx0ZXh0IHg9JzYwJyB5PSczODUnIGNsYXNzPSdtJyBmb250LXNpemU9JzknIGZpbGw9JyNmZmYnPkZvciAgICAgIDYwLDAwMDwvdGV4dD4KICA8dGV4dCB4PSc2MCcgeT0nMzk4JyBjbGFzcz0nbScgZm9udC1zaXplPSc5JyBmaWxsPScjZmZmJz5BZ2FpbnN0ICAyMCwwMDA8L3RleHQ+CiAgPHRleHQgeD0nNjAnIHk9JzQxMScgY2xhc3M9J20nIGZvbnQtc2l6ZT0nOScgZmlsbD0nI2ZmZic+QWJzdGFpbiAgIDUsMDAwPC90ZXh0PgogIAogIDx0ZXh0IHg9JzIxMCcgeT0nNDY1JyBjbGFzcz0nZycgZm9udC1zaXplPScxMicgZmlsbD0nI2ZmZicgdGV4dC1hbmNob3I9J21pZGRsZScgbGV0dGVyLXNwYWNpbmc9JzInPlNVQ0NFRURURC8vdGV4dD4KPC9zdmc+" />

### Vote Receipt Cards
<img src="data:image/svg+xml;base64,PHN2ZyB4bWxucz0naHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmcnIHdpZHRoPScxMjgwJyBoZWlnaHQ9JzY0MCcgdmlld0JveD0nMCAwIDEyODAgNjQwJz4KICA8cmVjdCB3aWR0aD0nMTI4MCcgaGVpZ2h0PSc2NDAnIGZpbGw9JyMwMDAnLz4KICA8c3R5bGU+CiAgICAuZ3tmb250LWZhbWlseTpHYXJhbW9uZCxzZXJpZjt9CiAgICAubXtmb250LWZhbWlseTptb25vc3BhY2U7fQogIDwvc3R5bGU+CiAgCiAgPCEtLSBZRVMgUmVjZWlwdCAtLT4KICA8ZyB0cmFuc2Zvcm09J3RyYW5zbGF0ZSgwLDIwKSc+CiAgICA8cmVjdCB4PScyMCcgeT0nMjAnIHdpZHRoPSczODAnIGhlaWdodD0nNTYwJyBmaWxsPSdub25lJyBzdHJva2U9JyMwZjAnIHN0cm9rZS13aWR0aD0nMScvPgogICAgPHRleHQgeD0nMjEwJyB5PSc1NScgY2xhc3M9J2cnIGZvbnQtc2l6ZT0nMTgnIGZpbGw9JyNmZmYnIHRleHQtYW5jaG9yPSdtaWRkbGUnPk1BSkVVUiBEQU88L3RleHQ+CiAgICA8dGV4dCB4PScyMTAnIHk9Jzc1JyBjbGFzcz0nZycgZm9udC1zaXplPScxMScgZmlsbD0nI2ZmZicgdGV4dC1hbmNob3I9J21pZGRsZSc+Vk9URSBSRUNFJVBUPC90ZXh0PgogICAgPGxpbmUgeDE9JzQwJyB5MT0nOTAnIHgyPSczODAnIHkyPSc5MCcgc3Ryb2tlPScjZmZmJyBzdHJva2Utd2lkdGg9JzEnLz4KICAgIAogICAgPCEtLSBZRVMgaGFuZCAtLT4KICAgIDx0ZXh0IHg9JzIxMCcgeT0nMTM1JyBjbGFzcz0nbScgZm9udC1zaXplPSc5JyBmaWxsPScjMGYwJyB0ZXh0LWFuY2hvcj0nbWlkZGxlJz58PC90ZXh0PgogICAgPHRleHQgeD0nMjEwJyB5PScxNDYnIGNsYXNzPSdtJyBmb250LXNpemU9JzknIGZpbGw9JyMwZjAnIHRleHQtYW5jaG9yPSdtaWRkbGUnPi9fXDwvdGV4dD4KICAgIDx0ZXh0IHg9JzIxMCcgeT0nMTU3JyBjbGFzcz0nbScgZm9udC1zaXplPSc5JyBmaWxsPScjMGYwJyB0ZXh0LWFuY2hvcj0nbWlkZGxlJz4vICAgXDwvdGV4dD4KICAgIDx0ZXh0IHg9JzIxMCcgeT0nMTY4JyBjbGFzcz0nbScgZm9udC1zaXplPSc5JyBmaWxsPScjMGYwJyB0ZXh0LWFuY2hvcj0nbWlkZGxlJz58ICAqICB8PC90ZXh0PgogICAgPHRleHQgeD0nMjEwJyB5PScxNzknIGNsYXNzPSdtJyBmb250LXNpemU9JzknIGZpbGw9JyMwZjAnIHRleHQtYW5jaG9yPSdtaWRkbGUnPnwgICAgIHw8L3RleHQ+CiAgICA8dGV4dCB4PScyMTAnIHk9JzE5MCcgY2xhc3M9J20nIGZvbnQtc2l6ZT0nOScgZmlsbD0nIzBmMCcgdGV4dC1hbmNob3I9J21pZGRsZSc+fF9fX19ffDwvdGV4dD4KICAgIAogICAgPHRleHQgeD0nNjAnIHk9JzI5MicgY2xhc3M9J20nIGZvbnQtc2l6ZT0nOScgZmlsbD0nI2ZmZic+MTIzNC4uLjU2Nzg8L3RleHQ+CiAgICA8dGV4dCB4PSc2MCcgeT0nMzQ1JyBjbGFzcz0nZycgZm9udC1zaXplPScxNCcgZmlsbD0nIzBmMCc+WUVTPC90ZXh0PgogICAgPHRleHQgeD0nNjAnIHk9JzM5NScgY2xhc3M9J20nIGZvbnQtc2l6ZT0nOScgZmlsbD0nI2ZmZic+MTAsMDAwIHZvdGVzPC90ZXh0PgogICAgPHRleHQgeD0nNjAnIHk9JzQ0NScgY2xhc3M9J20nIGZvbnQtc2l6ZT0nOScgZmlsbD0nI2ZmZic+UG9vbCAxMCBFVEg8L3RleHQ+CiAgICA8dGV4dCB4PScyMTAnIHk9JzUxMCcgY2xhc3M9J2cnIGZvbnQtc2l6ZT0nMTInIGZpbGw9JyMwZjAnIHRleHQtYW5jaG9yPSdtaWRkbGUnPlJFREVFTUFCTEU8L3RleHQ+CiAgPC9nPgogIAogIDwhLS0gTk8gUmVjZWlwdCAtLT4KICA8ZyB0cmFuc2Zvcm09J3RyYW5zbGF0ZSg0NDAsMjApJz4KICAgIDxyZWN0IHg9JzIwJyB5PScyMCcgd2lkdGg9JzM4MCcgaGVpZ2h0PSc1NjAnIGZpbGw9J25vbmUnIHN0cm9rZT0nI2YwMCcgc3Ryb2tlLXdpZHRoPScxJy8+CiAgICA8dGV4dCB4PScyMTAnIHk9JzU1JyBjbGFzcz0nZycgZm9udC1zaXplPScxOCcgZmlsbD0nI2ZmZicgdGV4dC1hbmNob3I9J21pZGRsZSc+TUFKRVVSIERBTZAQ PC90ZXh0PgogICAgPHRleHQgeD0nMjEwJyB5PSc3NScgY2xhc3M9J2cnIGZvbnQtc2l6ZT0nMTEnIGZpbGw9JyNmZmYnIHRleHQtYW5jaG9yPSdtaWRkbGUnPlZPVEUgUkVDRUlQVDwvdGV4dD4KICAgIDxsaW5lIHgxPSc0MCcgeTE9JzkwJyB4Mj0nMzgwJyB5Mj0nOTAnIHN0cm9rZT0nI2ZmZicgc3Ryb2tlLXdpZHRoPScxJy8+CiAgICAKICAgIDwhLS0gWCBzeW1ib2wgLS0+CiAgICA8dGV4dCB4PScyMTAnIHk9JzE0NScgY2xhc3M9J20nIGZvbnQtc2l6ZT0nOScgZmlsbD0nI2YwMCcgdGV4dC1hbmNob3I9J21pZGRsZSc+XCAgICAgICAvPC90ZXh0PgogICAgPHRleHQgeD0nMjEwJyB5PScxNTYnIGNsYXNzPSdtJyBmb250LXNpemU9JzknIGZpbGw9JyNmMDAnIHRleHQtYW5jaG9yPSdtaWRkbGUnPiBcICAgICAvIDwvdGV4dD4KICAgIDx0ZXh0IHg9JzIxMCcgeT0nMTY3JyBjbGFzcz0nbScgZm9udC1zaXplPSc5JyBmaWxsPScjZjAwJyB0ZXh0LWFuY2hvcj0nbWlkZGxlJz4gIFwgICAg IC88L3RleHQ+CiAgICA8dGV4dCB4PScyMTAnIHk9JzE3OCcgY2xhc3M9J20nIGZvbnQtc2l6ZT0nOScgZmlsbD0nI2YwMCcgdGV4dC1hbmNob3I9J21pZGRsZSc+ICAgIFggICAgPC90ZXh0PgogICAgPHRleHQgeD0nMjEwJyB5PScxODknIGNsYXNzPSdtJyBmb250LXNpemU9JzknIGZpbGw9JyNmMDAnIHRleHQtYW5jaG9yPSdtaWRkbGUnPiAgLyAgICBcICAgPC90ZXh0PgogICAgPHRleHQgeD0nMjEwJyB5PScyMDAnIGNsYXNzPSdtJyBmb250LXNpemU9JzknIGZpbGw9JyNmMDAnIHRleHQtYW5jaG9yPSdtaWRkbGUnPiAvICAgIHMgXCA8L3RleHQ+CiAgICA8dGV4dCB4PScyMTAnIHk9JzIxMScgY2xhc3M9J20nIGZvbnQtc2l6ZT0nOScgZmlsbD0nI2YwMCcgdGV4dC1hbmNob3I9J21pZGRsZSc+LyAgICAgIFw8L3RleHQ+CiAgICAKICAgIDx0ZXh0IHg9JzYwJyB5PScyOTInIGNsYXNzPSdtJyBmb250LXNpemU9JzknIGZpbGw9JyNmZmYnPjEyMzQuLi41Njc4PC90ZXh0PgogICAgPHRleHQgeD0nNjAnIHk9JzM0NScgY2xhc3M9J2cnIGZvbnQtc2l6ZT0nMTQnIGZpbGw9JyNmMDAnPk5PPC90ZXh0PgogICAgPHRleHQgeD0nNjAnIHk9JzM5NScgY2xhc3M9J20nIGZvbnQtc2l6ZT0nOScgZmlsbD0nI2ZmZic+NSAwMDAgdm90ZXM8L3RleHQ+CiAgICA8dGV4dCB4PScyMTAnIHk9JzUxMCcgY2xhc3M9J2cnIGZvbnQtc2l6ZT0nMTInIGZpbGw9JyNmMDAnIHRleHQtYW5jaG9yPSdtaWRkbGUnPlNFQUxFRDwvdGV4dD4KICA8L2c+CiAgCiAgPCEtLSBBQlNUQUlOIFJlY2VpcHQgLS0+CiAgPGcgdHJhbnNmb3JtPSd0cmFuc2xhdGUoODgwLDIwKSc+CiAgICA8cmVjdCB4PScyMCcgeT0nMjAnIHdpZHRoPSczODAnIGhlaWdodD0nNTYwJyBmaWxsPSdub25lJyBzdHJva2U9JyNhYWEnIHN0cm9rZS13aWR0aD0nMScvPgogICAgPHRleHQgeD0nMjEwJyB5PSc1NScgY2xhc3M9J2cnIGZvbnQtc2l6ZT0nMTgnIGZpbGw9JyNmZmYnIHRleHQtYW5jaG9yPSdtaWRkbGUnPk1BSkVVUiBEQU88L3RleHQ+CiAgICA8dGV4dCB4PScyMTAnIHk9Jzc1JyBjbGFzcz0nZycgZm9udC1zaXplPScxMScgZmlsbD0nI2ZmZicgdGV4dC1hbmNob3I9J21pZGRsZSc+Vk9URSVSRUNFJVBUPC90ZXh0PgogICAgPGxpbmUgeDE9JzQwJyB5MT0nOTAnIHgyPSczODAnIHkyPSc5MCcgc3Ryb2tlPScjZmZmJyBzdHJva2Utd2lkdGg9JzEnLz4KICAgIAogICAgPCEtLSBDaXJjbGUgLS0+CiAgICA8dGV4dCB4PScyMTAnIHk9JzE0NScgY2xhc3M9J20nIGZvbnQtc2l6ZT0nOScgZmlsbD0nI2FhYScgdGV4dC1hbmNob3I9J21pZGRsZSc+X19fPC90ZXh0PgogICAgPHRleHQgeD0nMjEwJyB5PScxNTYnIGNsYXNzPSdtJyBmb250LXNpemU9JzknIGZpbGw9JyNhYWEnIHRleHQtYW5jaG9yPSdtaWRkbGUnPi8gICAgIFw8L3RleHQ+CiAgICA8dGV4dCB4PScyMTAnIHk9JzE2NycgY2xhc3M9J20nIGZvbnQtc2l6ZT0nOScgZmlsbD0nI2FhYScgdGV4dC1hbmNob3I9J21pZGRsZSc+fCAgICAgICB8PC90ZXh0PgogICAgPHRleHQgeD0nMjEwJyB5PScxNzgnIGNsYXNzPSdtJyBmb250LXNpemU9JzknIGZpbGw9JyNhYWEnIHRleHQtYW5jaG9yPSdtaWRkbGUnPnwgICAgICAgfDwvdGV4dD4KICAgIDx0ZXh0IHg9JzIxMCcgeT0nMTg5JyBjbGFzcz0nbScgZm9udC1zaXplPSc5JyBmaWxsPScjYWFhJyB0ZXh0LWFuY2hvcj0nbWlkZGxlJz58ICAgICAgIHw8L3RleHQ+CiAgICA8dGV4dCB4PScyMTAnIHk9JzIwMCcgY2xhc3M9J20nIGZvbnQtc2l6ZT0nOScgZmlsbD0nI2FhYScgdGV4dC1hbmNob3I9J21pZGRsZSc+XCAgICAgLzwvdGV4dD4KICAgIDx0ZXh0IHg9JzIxMCcgeT0nMjExJyBjbGFzcz0nbScgZm9udC1zaXplPSc5JyBmaWxsPScjYWFhJyB0ZXh0LWFuY2hvcj0nbWlkZGxlJz4tLS08L3RleHQ+CiAgICAKICAgIDx0ZXh0IHg9JzYwJyB5PScyOTInIGNsYXNzPSdtJyBmb250LXNpemU9JzknIGZpbGw9JyNmZmYnPjEyMzQuLi41Njc4PC90ZXh0PgogICAgPHRleHQgeD0nNjAnIHk9JzM0NScgY2xhc3M9J2cnIGZvbnQtc2l6ZT0nMTQnIGZpbGw9JyNhYWEnPkFCU1RBSU48L3RleHQ+CiAgICA8dGV4dCB4PSc2MCcgeT0nMzk1JyBjbGFzcz0nbScgZm9udC1zaXplPSc5JyBmaWxsPScjZmZmJz4yLDAwMCB2b3RlczwvdGV4dD4KICAgIDx0ZXh0IHg9JzIxMCcgeT0nNTEwJyBjbGFzcz0nZycgZm9udC1zaXplPScxMicgZmlsbD0nI2FhYScgdGV4dC1hbmNob3I9J21pZGRsZSc+U0VBTEVET8L3RleHQ+CiAgPC9nPgo8L3N2Zz4=" />

### Permit Card
<img src="data:image/svg+xml;base64,PHN2ZyB4bWxucz0naHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmcnIHdpZHRoPSc0MjAnIGhlaWdodD0nNjAwJz4KICA8cmVjdCB3aWR0aD0nNDIwJyBoZWlnaHQ9JzYwMCcgZmlsbD0nIzAwMCcvPgogIDxyZWN0IHg9JzIwJyB5PScyMCcgd2lkdGg9JzM4MCcgaGVpZ2h0PSc1NjAnIGZpbGw9J25vbmUnIHN0cm9rZT0nI2ZmZicgc3Ryb2tlLXdpZHRoPScxJy8+CiAgPHN0eWxlPgogICAgLmd7Zm9udC1mYW1pbHk6R2FyYW1vbmQsc2VyaWY7fQogICAgLm17Zm9udC1mYW1pbHk6bW9ub3NwYWNlO30KICA8L3N0eWxlPgogIAogIDx0ZXh0IHg9JzIxMCcgeT0nNTUnIGNsYXNzPSdnJyBmb250LXNpemU9JzE4JyBmaWxsPScjZmZmJyB0ZXh0LWFuY2hvcj0nbWlkZGxlJyBsZXR0ZXItc3BhY2luZz0nMyc+TUFKRVVSIERBTZAQ PC90ZXh0PgogIDx0ZXh0IHg9JzIxMCcgeT0nNzUnIGNsYXNzPSdnJyBmb250LXNpemU9JzExJyBmaWxsPScjZmZmJyB0ZXh0LWFuY2hvcj0nbWlkZGxlJyBsZXR0ZXItc3BhY2luZz0nMic+UEVSTULUPC90ZXh0PgogIDxsaW5lIHgxPSc0MCcgeTE9JzkwJyB4Mj0nMzgwJyB5Mj0nOTAnIHN0cm9rZT0nI2ZmZicgc3Ryb2tlLXdpZHRoPScxJy8+CiAgCiAgPCEtLSBBU0NJSSBrZXkgLS0+CiAgPHRleHQgeD0nMjEwJyB5PScxNDAnIGNsYXNzPSdtJyBmb250LXNpemU9JzknIGZpbGw9JyNmZmYnIHRleHQtYW5jaG9yPSdtaWRkbGUnPl9fXzwvdGV4dD4KICA8dGV4dCB4PScyMTAnIHk9JzE1MScgY2xhc3M9J20nIGZvbnQtc2l6ZT0nOScgZmlsbD0nI2ZmZicgdGV4dC1hbmNob3I9J21pZGRsZSc+KCBvICk8L3RleHQ+CiAgPHRleHQgeD0nMjEwJyB5PScxNjInIGNsYXNzPSdtJyBmb250LXNpemU9JzknIGZpbGw9JyNmZmYnIHRleHQtYW5jaG9yPSdtaWRkbGUnPnwgfDwvdGV4dD4KICA8dGV4dCB4PScyMTAnIHk9JzE3MycgY2xhc3M9J20nIGZvbnQtc2l6ZT0nOScgZmlsbD0nI2ZmZicgdGV4dC1hbmNob3I9J21pZGRsZSc+fCB8PC90ZXh0PgogIDx0ZXh0IHg9JzIxMCcgeT0nMTg0JyBjbGFzcz0nbScgZm9udC1zaXplPSc5JyBmaWxsPScjZmZmJyB0ZXh0LWFuY2hvcj0nbWlkZGxlJz49PT09IyMjPT09PTwvdGV4dD4KICA8dGV4dCB4PScyMTAnIHk9JzE5NScgY2xhc3M9J20nIGZvbnQtc2l6ZT0nOScgZmlsbD0nI2ZmZicgdGV4dC1hbmNob3I9J21pZGRsZSc+fCB8PC90ZXh0PgogIDx0ZXh0IHg9JzIxMCcgeT0nMjA2JyBjbGFzcz0nbScgZm9udC1zaXplPSc5JyBmaWxsPScjZmZmJyB0ZXh0LWFuY2hvcj0nbWlkZGxlJz58IHw8L3RleHQ+CiAgPHRleHQgeD0nMjEwJyB5PScyMTcnIGNsYXNzPSdtJyBmb250LXNpemU9JzknIGZpbGw9JyNmZmYnIHRleHQtYW5jaG9yPSdtaWRkbGUnPnxffDwvdGV4dD4KICAKICA8dGV4dCB4PSc2MCcgeT0nMjk3JyBjbGFzcz0nbScgZm9udC1zaXplPSc5JyBmaWxsPScjZmZmJz4xMjM0Li4uNTY3ODwvdGV4dD4KICA8dGV4dCB4PSc2MCcgeT0nMzUwJyBjbGFzcz0nZycgZm9udC1zaXplPScxNCcgZmlsbD0nI2ZmZic+NSBVU0VTPC90ZXh0PgogIAogIDx0ZXh0IHg9JzIxMCcgeT0nNDgwJyBjbGFzcz0nZycgZm9udC1zaXplPScxMicgZmlsbD0nI2ZmZicgdGV4dC1hbmNob3I9J21pZGRsZSc+QUNUSVZFPC90ZXh0Pgo8L3N2Zz4=" />

### Badge Card (Top 256 Holders)
<img src="data:image/svg+xml;base64,PHN2ZyB4bWxucz0naHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmcnIHdpZHRoPSc0MjAnIGhlaWdodD0nNjAwJz4KICA8cmVjdCB3aWR0aD0nNDIwJyBoZWlnaHQ9JzYwMCcgZmlsbD0nIzAwMCcvPgogIDxyZWN0IHg9JzIwJyB5PScyMCcgd2lkdGg9JzM4MCcgaGVpZ2h0PSc1NjAnIGZpbGw9J25vbmUnIHN0cm9rZT0nI2ZmZicgc3Ryb2tlLXdpZHRoPScxJy8+CiAgPHN0eWxlPgogICAgLmd7Zm9udC1mYW1pbHk6R2FyYW1vbmQsc2VyaWY7fQogICAgLm17Zm9udC1mYW1pbHk6bW9ub3NwYWNlO30KICA8L3N0eWxlPgogIAogIDx0ZXh0IHg9JzIxMCcgeT0nNTUnIGNsYXNzPSdnJyBmb250LXNpemU9JzE4JyBmaWxsPScjZmZmJyB0ZXh0LWFuY2hvcj0nbWlkZGxlJyBsZXR0ZXItc3BhY2luZz0nMyc+TUFKRVVSIERBTZAQ PC90ZXh0PgogIDx0ZXh0IHg9JzIxMCcgeT0nNzUnIGNsYXNzPSdnJyBmb250LXNpemU9JzExJyBmaWxsPScjZmZmJyB0ZXh0LWFuY2hvcj0nbWlkZGxlJyBsZXR0ZXItc3BhY2luZz0nMic+TUVNQKESIEJBR0dFPC90ZXh0PgogIDxsaW5lIHgxPSc0MCcgeTE9JzkwJyB4Mj0nMzgwJyB5Mj0nOTAnIHN0cm9rZT0nI2ZmZicgc3Ryb2tlLXdpZHRoPScxJy8+CiAgCiAgPCEtLSBBU0NJSSBjcm93biAtLT4KICA8dGV4dCB4PScyMTAnIHk9JzEzNScgY2xhc3M9J20nIGZvbnQtc2l6ZT0nOScgZmlsbD0nI2ZmZicgdGV4dC1hbmNob3I9J21pZGRsZSc+KiAgICAqICAgKjwvdGV4dD4KICA8dGV4dCB4PScyMTAnIHk9JzE0NicgY2xhc3M9J20nIGZvbnQtc2l6ZT0nOScgZmlsbD0nI2ZmZicgdGV4dC1hbmNob3I9J21pZGRsZSc+L3xcICAgL3xcICAvfFw8L3RleHQ+CiAgPHRleHQgeD0nMjEwJyB5PScxNTcnIGNsYXNzPSdtJyBmb250LXNpemU9JzknIGZpbGw9JyNmZmYnIHRleHQtYW5jaG9yPSdtaWRkbGUnPistLS0rLS0tKy0tLSs8L3RleHQ+CiAgPHRleHQgeD0nMjEwJyB5PScxNjgnIGNsYXNzPSdtJyBmb250LXNpemU9JzknIGZpbGw9JyNmZmYnIHRleHQtYW5jaG9yPSdtaWRkbGUnPnwgICB8ICogfCAgIHw8L3RleHQ+CiAgPHRleHQgeD0nMjEwJyB5PScxNzknIGNsYXNzPSdtJyBmb250LXNpemU9JzknIGZpbGw9JyNmZmYnIHRleHQtYW5jaG9yPSdtaWRkbGUnPnwgICB8ICAgfCAgIHw8L3RleHQ+CiAgPHRleHQgeD0nMjEwJyB5PScxOTAnIGNsYXNzPSdtJyBmb250LXNpemU9JzknIGZpbGw9JyNmZmYnIHRleHQtYW5jaG9yPSdtaWRkbGUnPistLS0rLS0tKy0tLSs8L3RleHQ+CiAgPHRleHQgeD0nMjEwJyB5PScyMDEnIGNsYXNzPSdtJyBmb250LXNpemU9JzknIGZpbGw9JyNmZmYnIHRleHQtYW5jaG9yPSdtaWRkbGUnPlwgICAgICAgICAvPC90ZXh0PgogIDx0ZXh0IHg9JzIxMCcgeT0nMjEyJyBjbGFzcz0nbScgZm9udC1zaXplPSc5JyBmaWxsPScjZmZmJyB0ZXh0LWFuY2hvcj0nbWlkZGxlJz4tLS0tLS0tLS08L3RleHQ+CiAgCiAgPHRleHQgeD0nNjAnIHk9JzI5MicgY2xhc3M9J20nIGZvbnQtc2l6ZT0nOScgZmlsbD0nI2ZmZic+MHhBYkNkLi4uMTIzNDwvdGV4dD4KICA8dGV4dCB4PSc2MCcgeT0nMzQ1JyBjbGFzcz0nZycgZm9udC1zaXplPScxNicgZmlsbD0nI2ZmZic+U0VBVCAZAC0zPC90ZXh0PgogIDx0ZXh0IHg9JzYwJyB5PSczOTUnIGNsYXNzPSdtJyBmb250LXNpemU9JzknIGZpbGw9JyNmZmYnPjUwLDAwMCBzaGFyZXM8L3RleHQ+CiAgPHRleHQgeD0nNjAnIHk9JzQ0NScgY2xhc3M9J20nIGZvbnQtc2l6ZT0nOScgZmlsbD0nI2ZmZic+NS4wMCU8L3RleHQ+CiAgCiAgPHRleHQgeD0nMjEwJyB5PSc1MDAnIGNsYXNzPSdnJyBmb250LXNpemU9JzEyJyBmaWxsPScjZmZmJyB0ZXh0LWFuY2hvcj0nbWlkZGxlJyBsZXR0ZXItc3BhY2luZz0nMic+VE9QIDI1NiAtZWUBQVQrNDnVzvPC90ZXh0PgogIDx0ZXh0IHg9JzIxMCcgeT0nNTY1JyBjbGFzcz0nZycgZm9udC1zaXplPSc4JyBmaWxsPScjNDQ0JyB0ZXh0LWFuY2hvcj0nbWlkZGxlJyBsZXR0ZXItc3BhY2luZz0nMSc+Tk9OLVRSQU5TRkVSQUJMRTwvdGV4dD4KPC9zdmc+" />



## Quick Start

### Deploy a DAO

```solidity
// Deploy via Summoner factory
Summoner summoner = new Summoner();

address[] memory holders = [alice, bob, charlie];
uint256[] memory shares = [100e18, 50e18, 50e18];

Moloch dao = summoner.summon(
    "MyDAO",           // name
    "MYDAO",          // symbol
    "",               // URI (metadata)
    5000,             // 50% quorum (basis points)
    true,             // ragequittable
    address(0),       // renderer (0 = default on-chain SVG)
    bytes32(0),       // salt (for deterministic addresses)
    holders,          // initial holders
    shares,           // initial shares
    new Call[](0)     // init calls (optional setup actions)
);
```

### Create & Vote on Proposals

```solidity
// 1. Create proposal ID (anyone can compute this)
uint256 proposalId = dao.proposalId(
    0,                    // op: 0=call, 1=delegatecall
    target,               // contract to call
    value,                // ETH to send
    data,                 // calldata
    nonce                 // unique nonce
);

// 2. Open and vote (auto-opens on first vote)
dao.castVote(proposalId, 1);  // 1=FOR, 0=AGAINST, 2=ABSTAIN

// 3. Execute when passed
dao.executeByVotes(0, target, value, data, nonce);
```

### Weighted Delegation (Split Voting Power)

```solidity
// Split delegation: 60% to alice, 40% to bob
address[] memory delegates = [alice, bob];
uint32[] memory bps = [6000, 4000];  // must sum to 10000
dao.shares().setSplitDelegation(delegates, bps);

// Clear split (return to single delegate)
dao.shares().clearSplitDelegation();
```

### Futarchy Markets

```solidity
// Fund a prediction market for a proposal
dao.fundFutarchy(
    proposalId,
    address(0),  // 0 = ETH, or token address
    1 ether      // amount
);

// After resolution, claim winnings
uint256 receiptId = dao._receiptId(proposalId, 1); // 1=YES
dao.cashOutFutarchy(proposalId, myReceiptBalance);
```

### Token Sales

```solidity
// DAO enables share sales (governance action)
dao.setSale(
    address(0),  // payment token (0=ETH)
    0.01 ether,  // price per share
    1000e18,     // cap (max shares)
    true,        // mint new shares
    true,        // active
    false        // isLoot
);

// Users can buy shares
dao.buyShares{value: 1 ether}(
    address(0),  // payment token
    100e18,      // shares to buy
    1 ether      // max payment
);
```

### Ragequit

```solidity
// Exit with proportional share of treasury
address[] memory tokens = [weth, usdc, dai];
dao.ragequit(
    tokens,      // tokens to claim
    myShares,    // shares to burn
    myLoot       // loot to burn
);
```

## Advanced Features

### Pre-Authorized Permits

DAOs can issue permits allowing specific addresses to execute actions without voting:

```solidity
// DAO issues permit
dao.setPermit(op, target, value, data, nonce, alice, 1);

// Alice spends permit
dao.spendPermit(op, target, value, data, nonce);
```

### Timelock Configuration

```solidity
dao.setTimelockDelay(2 days);  // Delay between queue and execute
dao.setProposalTTL(7 days);     // Proposal expiry time
```

### Member Chat (Badge-Gated)

```solidity
// Only badge holders (top 256) can chat
dao.chat("Hello DAO members!");
```

## Integration Examples

### Reading DAO State

```javascript
// Web3.js/Ethers.js
const shares = await dao.shares();
const totalSupply = await shares.totalSupply();
const myBalance = await shares.balanceOf(account);
const myVotes = await shares.getVotes(account);

// Check proposal state
const state = await dao.state(proposalId);
// 0=Unopened, 1=Active, 2=Queued, 3=Succeeded, 4=Defeated, 5=Expired, 6=Executed

// Get vote tally
const tally = await dao.tallies(proposalId);
console.log(`FOR: ${tally.forVotes}, AGAINST: ${tally.againstVotes}`);
```

### Monitoring Events

```javascript
// Key events to watch
dao.on("Opened", (id, snapshot, supply) => {
    console.log(`Proposal ${id} opened at block ${snapshot}`);
});

dao.on("Voted", (id, voter, support, weight) => {
    console.log(`${voter} voted ${support} with ${weight} votes`);
});

dao.on("Executed", (id, executor, op, target, value) => {
    console.log(`Proposal ${id} executed by ${executor}`);
});
```

## Key Features

### Wyoming DUNA Compliance

The framework includes built-in support for Wyoming's Decentralized Unincorporated Nonprofit Association (DUNA) structure, providing legal recognition for DAOs:

#### What is a DUNA?
- **Legal entity** recognized by Wyoming law (W.S. 17-32-101)
- **Limited liability** for members (similar to LLC)
- **No incorporation** required - exists through smart contract
- **Nonprofit** structure (can still have treasury/tokens)

#### How Majeur Implements DUNA:
- **On-chain covenant**: Legal agreement displayed in contract URI
- **Member registry**: Badge system tracks top 256 members
- **Governance records**: All votes permanently on-chain
- **Self-help remedy**: Ragequit allows member exit
- **Transparent operations**: All actions visible on blockchain

#### Legal Benefits:
✅ Members have limited liability protection  
✅ Can enter contracts as an entity  
✅ Can own property (including treasury)  
✅ Dispute resolution through code  
✅ No traditional corporate formalities

### Advanced Governance
- **Snapshot voting** at block N-1 prevents vote buying
- **Timelocks** for high-impact decisions
- **Proposal expiry** (TTL) prevents zombie proposals
- **Dynamic quorum** based on supply percentage
- **Vote cancellation** before proposal execution

### Economic Features
- **Ragequit** - Exit with proportional treasury share
- **Token sales** - Fundraising with price discovery
- **Futarchy markets** - Prediction markets on proposals
- **Split economics** - Shares (voting) vs Loot (non-voting)

### Technical Innovation
- **Weighted delegation** - Split voting power across multiple delegates
- **ERC-6909 receipts** - Efficient multi-token for vote tracking
- **Clones pattern** - Gas-efficient deployment
- **Transient storage** - Optimized reentrancy guards
- **On-chain SVG** - Fully decentralized metadata

## Contract Architecture

```
Moloch (Main Contract)
├── Shares (ERC20 + ERC20Votes)
│   ├── Transferable/Lockable
│   ├── Delegation (single or split)
│   └── Checkpoint-based voting
├── Loot (ERC20)
│   ├── Non-voting economic rights
│   └── Transferable/Lockable
├── Badges (ERC721)
│   ├── Soulbound (non-transferable)
│   ├── Top 256 holders
│   └── Auto-updated on balance changes
├── Renderer
│   ├── On-chain SVG generation
│   ├── DUNA covenant display
│   └── Card visualizations
└── Summoner (Factory)
    └── Clone deployment
```

## Quick Reference

### Essential Functions

| Function | Purpose | Who Can Call |
|----------|---------|--------------|
| `summon()` | Deploy new DAO | Anyone |
| `castVote()` | Vote on proposal | Share holders |
| `executeByVotes()` | Execute passed proposal | Anyone |
| `ragequit()` | Exit with treasury share | Share/Loot holders |
| `delegate()` | Delegate voting power | Share holders |
| `setSplitDelegation()` | Split delegation | Share holders |
| `buyShares()` | Purchase shares during sale | Anyone (if sale active) |
| `fundFutarchy()` | Add to prediction market | Anyone |
| `cashOutFutarchy()` | Claim futarchy rewards | Receipt holders |
| `chat()` | Post in member chat | Badge holders |

### Governance Functions (DAO Only)

| Function | Purpose |
|----------|---------|
| `setSale()` | Enable token sales |
| `setPermit()` | Issue execution permits |
| `setTimelockDelay()` | Set execution delay |
| `setQuorumBps()` | Set quorum percentage |
| `setRagequittable()` | Enable/disable ragequit |
| `bumpConfig()` | Invalidate old proposals |

## User Stories

### As a DAO Member
- **Vote on proposals** with your shares (voting power)
- **Delegate voting power** to trusted members (even split between multiple delegates)
- **Buy more shares** during token sales
- **Ragequit** to exit with your proportional share of treasury
- **Chat** with other top holders (if you have a badge)

### As a Proposal Creator
- **Submit proposals** for DAO actions (treasury, governance, operations)
- **Fund futarchy markets** to incentivize participation
- **Set timelocks** for important decisions
- **Cancel proposals** you created (before votes cast)

### As an App Developer
- **Monitor governance** via events
- **Build delegation UIs** for split voting interfaces
- **Create futarchy dashboards** showing market predictions
- **Integrate chat features** for badge holders
- **Display on-chain SVGs** for proposals, receipts, and badges

## Common Pitfalls & Solutions

### 🚫 Pitfall: Forgetting to sort tokens in ragequit
```solidity
// ❌ Wrong - will revert if not sorted
address[] memory tokens = [dai, weth, usdc];
dao.ragequit(tokens, shares, loot);

// ✅ Correct - tokens sorted by address
address[] memory tokens = [dai, usdc, weth]; // sorted ascending
dao.ragequit(tokens, shares, loot);
```

### 🚫 Pitfall: Voting after proposal expiry
```solidity
// Check proposal state before voting
if (dao.state(proposalId) == ProposalState.Active) {
    dao.castVote(proposalId, 1);
}
```

### 🚫 Pitfall: Wrong basis points in delegation
```solidity
// ❌ Wrong - doesn't sum to 10000
uint32[] memory bps = [6000, 3000]; // 90% total

// ✅ Correct - must sum to exactly 10000
uint32[] memory bps = [6000, 4000]; // 100% total
```

## Deployment

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup

# Build
forge build

# Test
forge test

# Deploy
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast
```

## Security Considerations

- Proposals are **snapshot-based** (block N-1) to prevent vote buying
- **Reentrancy guards** on all financial operations
- **Timelock delays** for high-impact decisions
- **Ragequit** prevents majority attacks on treasury
- **Config versioning** can invalidate old proposal IDs

## Complete Workflow Example

### Full DAO Lifecycle
```solidity
// 1. Deploy DAO
Summoner summoner = new Summoner();
Moloch dao = summoner.summon("MyDAO", "DAO", "", 5000, true, address(0), 
    bytes32(0), [alice, bob], [100e18, 100e18], new Call[](0));

// 2. Alice delegates 70% to expert1, 30% to expert2
Shares shares = dao.shares();
shares.setSplitDelegation([expert1, expert2], [7000, 3000]);

// 3. Create and vote on treasury proposal
bytes memory data = abi.encodeWithSignature(
    "transfer(address,uint256)", charlie, 10 ether
);
uint256 id = dao.proposalId(0, weth, 0, data, bytes32("prop1"));
dao.castVote(id, 1); // Vote FOR

// 4. Wait for voting period...

// 5. Execute if passed
if (dao.state(id) == ProposalState.Succeeded) {
    dao.executeByVotes(0, weth, 0, data, bytes32("prop1"));
}

// 6. Charlie can ragequit if unhappy
address[] memory tokens = getSortedTreasuryTokens();
dao.ragequit(tokens, myShares, 0);
```

## Gas Optimization

The framework uses several optimization techniques:

### Clone Pattern
- **Deployment cost**: ~500k gas (vs ~3M for individual contracts)
- **How**: Minimal proxy clones for Shares, Loot, Badges
- **Savings**: ~80% on deployment

### Transient Storage (EIP-1153)
- **Reentrancy guards**: Uses `TSTORE`/`TLOAD`
- **Savings**: ~5k gas per guarded function

### Bitmap for Badges
- **Storage**: 256 holders in single storage slot
- **Operations**: O(1) updates using bit manipulation
- **Savings**: ~20k gas per badge update

### Packed Structs
```solidity
struct Tally {
    uint96 forVotes;      // Packed into
    uint96 againstVotes;  // single
    uint96 abstainVotes;  // storage slot
}
```

## FAQ

### Q: Can I change my vote after voting?
**A:** Yes! Use `cancelVote(proposalId)` before the proposal is executed. You'll get your vote receipt back and can vote again.

### Q: What happens to badges when someone's balance changes?
**A:** Badges automatically update. If you fall out of top 256, you lose the badge. If you enter top 256, you get one instantly.

### Q: Can I delegate to myself?
**A:** Yes, and it's the default. Your votes stay with you unless you explicitly delegate.

### Q: What's the difference between `call` and `delegatecall` in proposals?
**A:** 
- `call` (op=0): Execute from DAO's context (normal)
- `delegatecall` (op=1): Execute in DAO's storage (upgrades/modules)

### Q: Can I partially ragequit?
**A:** Yes! Specify how many shares/loot to burn. You don't have to exit completely.

### Q: How are proposal IDs generated?
**A:** Deterministically from: `keccak256(dao, op, to, value, data, nonce, config)`. Anyone can compute it.

### Q: What prevents vote buying?
**A:** Snapshots at block N-1. You can't buy tokens after seeing a proposal and vote.

### Q: Can the DAO upgrade itself?
**A:** Yes, through proposals with `delegatecall` or by deploying new contracts.

### Q: What's the `config` parameter?
**A:** A version number. Incrementing it invalidates all old proposal IDs (emergency reset).

### Q: Can I build a front-end for this?
**A:** Yes! All metadata is on-chain (including SVGs). No external dependencies needed.

## Disclaimer

*These contracts are unaudited. Use at your own risk. No warranties or guarantees provided.*

## License

MIT