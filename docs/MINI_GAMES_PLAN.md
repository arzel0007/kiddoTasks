# Kiddotasks — Mini-Games System Plan

**Status:** Plan only (not implemented)  
**Date:** 2026-09-11  
**Target:** iOS first (Kids Station → Play), web later if needed  

---

## 1. Goals

1. **Play without picking a kid first** — games are a shared activity, not “this child’s session.”
2. **Flexible players** — 2–4 players; names default to family kids, can type custom names.
3. **Dashboards** — recent games, wins, top scores, simple stats.
4. **Ship v1 → v3** without rewriting architecture each time.
5. **Parent control** — reuse `enableMiniGames` / later `miniGamesMaxMinutes`.
6. **No reward farming** — optional tiny badge only; never enough stars to skip chores.

---

## 2. Information architecture (entry)

### Current problem
Kids Station → pick child → **Play** tab feels like “only this kid plays.”

### New structure

```
Kids Station
├─ Who's playing?          → Missions / Shop / Badges (per child)
└─ Games (shared)          → NO child picker required
     ├─ Lobby / hub
     ├─ Game picker
     ├─ Player setup
     ├─ Gameplay
     └─ Results + dashboard
```

### Entry points

| Location | Behavior |
|---|---|
| **Kids Station tabs** | Add **Games** tab next to Missions/Shop/Badges — always available when `enableMiniGames` |
| **Who’s playing?** | Secondary “Play games together” button (does **not** require selecting a face first) |
| **Parent → Family** | Toggle remains; optional “max minutes / day” later |

### Navigation rules
- Entering **Games** does **not** set `currentChildProfile`.
- Leaving Games never locks the kid PIN session by itself.
- From Games, user can still “Go to Missions” after picking a child if desired.

---

## 3. Game catalog & roadmap

### Shared engine requirements (all games)
- 2–4 players on one device (pass-and-play)
- Explicit game state machine
- Rematch / Change players / Exit
- Encouraging end copy (no shame: “Great match!”)
- Works in Night mode + Calm Adventure tokens
- Reduce Motion respected
- Parent can hide Games tab entirely

### v1 (ship first)

| ID | Game | Players | Core loop |
|---|---|---|---|
| `tictactoe` | Tic-Tac-Toe | 2 | 3×3, win line, draw |
| `memory` | Pairs | 2–4 | Grid of cards, flip two, match |
| `rps` | Rock · Paper · Scissors | 2 | Best of 3 or 5 |

### v2

| ID | Game | Players | Notes |
|---|---|---|---|
| `connect4` | Connect 4 | 2 | Gravity columns |
| `dots` | Dots & Boxes | 2–4 | Claim edges, close boxes |
| `pig` | Pig (dice) | 2–4 | Hold or roll; bust on 1 |

### v3

| ID | Game | Players | Notes |
|---|---|---|---|
| `snakes` | Snakes & Ladders | 2–4 | Single die, path to end |
| `simon` | Pattern Memory | sequential | Longest streak wins |
| `trivia` | Emoji Trivia | 2–4 | Kid-safe card deck |

### Already live
- **Basketball** — keep; same lobby; optional later “team” mode

---

## 4. Player model (game-agnostic)

```text
GamePlayer
  id: UUID
  displayName: String
  source: familyChild(id) | custom
  colorHex: String          // from avatar or assigned palette
  score: Int
  wins: Int
```

### Player setup flow (one screen for all games)
1. Choose **2 / 3 / 4** players (or default 2).
2. For each seat:
   - Pick from **family kids** (avatar + name) **or**
   - Type a **custom name**
3. **Start game** → pass-and-play turns labeled clearly.

Rules:
- Same child can only occupy one seat per round (prevent duplicate profiles).
- Custom names don’t create Child documents.
- Colors from controlled palette (Calm Adventure), not random rainbow.

---

## 5. Lobby / hub screens

### A. Games hub (root of mini-games)
- Featured: Basketball, Tic-Tac-Toe, Memory, RPS
- Locked/coming soon: v2–v3 (optional gray cards)
- **My game stats** card (wins, games played, best streak)
- Parent note: “Games are for fun — chores still earn stars”

### B. Game picker (category optional later)
- Cards: name, players, “1–2 min”
- Tap → player setup

### C. Dashboard / top scores
**Local-first** (UserDefaults / snapshot later if multi-device needed):

```text
GameStats
  gameId
  playedAt
  players: [{ name, source, score, rank }]
  winnerIds: [String]
  durationSeconds
```

**Hub shows:**
- Games played count
- Wins by player name (top 3)
- Last 5 games (“Maya beat Alex · Connect 4 · 2 min ago”)
- Per-game tab: Basketball, TTT, Memory, …

**Storage:** `kiddo.gamestats.v1` in UserDefaults initially.  
Optional later: `gameSessions` collection under family for cloud (not required for v1).

---

## 6. Game state architecture (iOS)

One pattern for every game:

```text
GamePhase
  .setupPlayers
  .countdown (optional, short)
  .playing
  .roundEnd
  .matchEnd
  .paused
```

```text
MiniGameLobbyView
  → PlayerSetupView(game:)
  → AnyMiniGameView (switch by gameId)
      TicTacToeView / MemoryGameView / RPSView / BasketballGameView
  → GameResultView (rematch / stats / exit)
```

Shared UI:
- `GameTurnHeader` — whose turn, round, score
- `PassDeviceCard` — “Pass to Maya” before next turn (optional, toggle)
- `GameResultView` — podium-style, encouraging copy

Shared logic (pure Swift, testable):
- `TicTacToeEngine`
- `MemoryEngine`
- `RPSEngine`
- Later: `Connect4Engine`, etc.

No SKScene / heavy engine for v1.

---

## 7. Per-game specs (v1)

### Tic-Tac-Toe
- 2 players; symbols X / O or player colors
- Win detection; draw; rematch
- Optional: best of 3 → `matchScore`

### Memory
- Grid 4×4 (8 pairs) or 4×6 (12 pairs) based on players
- Emoji/illustration deck (kid-safe)
- Score = pairs found; winner most pairs
- Staggered flip; Reduce Motion = instant flip

### Rock–Paper–Scissors
- 2 players; screen split or pass-device hide
- Best of 3 / 5 selectable
- Quick result animation

---

## 8. Parent settings

| Setting | v1 | v2 |
|---|---|---|
| Show Games tab | `enableMiniGames` (exists) | same |
| Max play minutes | — | per session or per day |
| Allow custom names | yes | yes |
| Stats cloud sync | — | optional |

---

## 9. UX / brand

- Calm Adventure chrome; personality from **celebrations**, not neon
- Games lobby slightly more playful illustrations allowed
- No purple/violet; primary `#3978A8` family
- Consistent radii (18px cards, 14px buttons)
- SVG/SF icons; emoji only inside kid game content where appropriate

---

## 10. Implementation phases (effort)

| Phase | Scope | Est. |
|---|---|---|
| **P0** | Navigation: Games entry without kid picker; lobby shell; player setup UI | 1–2 days |
| **P1** | v1: TTT + RPS + Memory + results + local stats | 3–5 days |
| **P2** | Dashboard polish (top scores, recent games) | 1 day |
| **P3** | v2: Connect 4, Dots, Pig | 1–2 weeks |
| **P4** | v3: Snakes, Simon, Trivia | 1–2 weeks |
| **P5** | Optional cloud stats + web parity | later |

**Recommended first ship:** P0 + TTT + RPS only (smallest vertical slice).  
Then Memory + dashboard.

---

## 11. Acceptance criteria

- [ ] Open Games without selecting a kid  
- [ ] Choose 2–4 players; mix family kids + custom names  
- [ ] Play Tic-Tac-Toe / Memory / RPS to completion  
- [ ] See whose turn it is  
- [ ] Encouraging results screen  
- [ ] Rematch / change players  
- [ ] Hub shows recent games + top scorers  
- [ ] Parent can hide Games  
- [ ] Works in night mode; Reduce Motion respected  
- [ ] Basketball still reachable from same hub  

---

## 12. Open decisions (confirm before coding)

1. **Pass-device interstitial** every turn? (default: off for TTT on one screen; on for RPS secret pick)  
2. **Cloud stats** in v1 or local-only? (recommend **local-only** v1)  
3. **Wins counting** against family kids only or custom names too?  
4. **Basketball** stays 1–2P or move fully into shared player setup?

---

## 13. Resume checklist (if context lost)

1. Read this file + `docs/UI_UX_ENHANCEMENT_HANDOVER.md`  
2. Start **P0** — Games tab entry without `currentChildProfile`  
3. Implement `PlayerSetupView` + `GameStatsStore`  
4. Implement `TicTacToeEngine` + view, then RPS  
5. Wire hub dashboard + parent toggle  
6. Run unit tests for engines; build iOS  

**Do not** require child selection before Games.  
**Do not** award chore-level stars for playing.
