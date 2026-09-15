# HSR Damage Meter
## Veritas Collector + Native macOS Swift App
### Codex Engineering Specification

> Purpose: This document is the authoritative implementation specification for Codex.
> Work milestone-by-milestone. Keep the project buildable after every milestone.
> Do not implement anti-cheat bypass, stealth, hook hiding, or evasion features.

---

# 0. Product Definition

Build a two-part Honkai: Star Rail damage meter for a Mac user running the Windows game inside Wine.

The product consists of:

```text
┌─────────────────────────────────────────────┐
│ Wine Container                              │
│                                             │
│  StarRail.exe                               │
│       │                                     │
│       ▼                                     │
│  Veritas-derived Collector                  │
│  - existing IL2CPP/game-event logic         │
│  - existing damage attribution              │
│  - battle/session state                     │
│  - NEW: localhost event publisher           │
│       │                                     │
└───────┼─────────────────────────────────────┘
        │ localhost IPC
        │ WebSocket preferred
        ▼
┌─────────────────────────────────────────────┐
│ macOS                                       │
│                                             │
│  HSR Damage Meter.app                       │
│  - Swift 6                                  │
│  - SwiftUI + AppKit                         │
│  - IPC client                               │
│  - combat aggregation                       │
│  - live floating meter                      │
│  - dashboard                                │
│  - history                                  │
│  - analysis                                 │
│  - settings                                 │
│  - menu bar integration                     │
└─────────────────────────────────────────────┘
```

The macOS app MUST NOT attach to the game process.

The macOS app must behave only as a localhost client.

---

# 1. Design Principles

## 1.1 Reuse Veritas, do not rewrite it

The Collector should retain as much upstream Veritas code as possible.

Prefer:

```text
existing Veritas backend
        │
        ├── existing overlay/UI
        │
        └── NEW EventPublisher
```

over:

```text
rewrite all game hooks
rewrite all IL2CPP logic
rewrite all character mapping
```

The fork should remain structurally close enough to upstream that rebasing/updating is practical.

## 1.2 UI and Collector are independent products

The Collector is responsible for:

```text
game integration
damage-event extraction
game entity mapping
combat lifecycle
data correctness
```

The Swift app is responsible for:

```text
connection state
aggregation
presentation
history
native macOS UX
```

The Swift app should not understand IL2CPP internals.

The Collector should not understand Swift UI state.

## 1.3 Network contract is the boundary

Everything crossing the Collector/App boundary must be represented by a versioned protocol.

Never make the Swift app depend on Collector structs directly.

Use JSON initially. MessagePack/CBOR can be considered later if profiling justifies it.

---

# 2. Repository Layout

```text
HSRDamageMeter/
│
├── collector/
│   ├── upstream-veritas/
│   ├── src/
│   │   ├── bridge/
│   │   │   ├── event_publisher.rs
│   │   │   ├── websocket_server.rs
│   │   │   └── protocol.rs
│   │   └── ...
│   ├── Cargo.toml
│   └── README.md
│
├── protocol/
│   ├── README.md
│   ├── schema/
│   │   ├── envelope.schema.json
│   │   ├── hello.schema.json
│   │   ├── session.schema.json
│   │   ├── party.schema.json
│   │   ├── damage.schema.json
│   │   └── action.schema.json
│   └── fixtures/
│       ├── sample_session.jsonl
│       └── sample_damage.json
│
├── macos/
│   └── HSRDamageMeter/
│       ├── HSRDamageMeter.xcodeproj
│       ├── App/
│       ├── Networking/
│       ├── Domain/
│       ├── Features/
│       ├── Storage/
│       ├── DesignSystem/
│       ├── Overlay/
│       ├── MenuBar/
│       ├── PreviewData/
│       └── Tests/
│
├── docs/
│   ├── ARCHITECTURE.md
│   ├── IPC_PROTOCOL.md
│   ├── UI_SPEC.md
│   ├── VERITAS_PATCHES.md
│   └── DEVELOPMENT.md
│
└── README.md
```

---

# 3. System Architecture

```text
             ┌────────────────────┐
             │ StarRail.exe       │
             └─────────┬──────────┘
                       │
             Veritas existing hooks
                       │
                       ▼
             ┌────────────────────┐
             │ Veritas Core       │
             │ damage events      │
             │ party mapping      │
             │ action state       │
             │ battle lifecycle   │
             └─────────┬──────────┘
                       │
                  bridge adapter
                       │
                       ▼
             ┌────────────────────┐
             │ EventPublisher     │
             │ WebSocket Server   │
             │ 127.0.0.1 only     │
             └─────────┬──────────┘
                       │
                       ▼
             ┌────────────────────┐
             │ Swift IPC Client   │
             │ URLSession WS      │
             └─────────┬──────────┘
                       │
                       ▼
             ┌────────────────────┐
             │ EventDecoder       │
             └─────────┬──────────┘
                       │
                       ▼
             ┌────────────────────┐
             │ CombatStore Actor  │
             └──────┬───────┬─────┘
                    │       │
             Live UI│       │Persistence
                    │       ▼
                    │  ┌──────────────┐
                    │  │ SQLite       │
                    │  │ History      │
                    │  └──────────────┘
                    ▼
        ┌───────────────────────────────┐
        │ SwiftUI Presentation         │
        │ Floating Meter               │
        │ Dashboard                    │
        │ History                      │
        │ Analysis                     │
        │ Settings                     │
        │ Menu Bar                     │
        └───────────────────────────────┘
```

---

# 4. Collector Modification Strategy

Turn Veritas into a backend that can expose its already-resolved combat data externally.

Do not delete the original UI initially. First add a second output path:

```text
existing event
   │
   ├── current Veritas UI
   │
   └── EventPublisher
```

After the native app is stable, making the in-game UI optional is acceptable.

---

# 5. Collector Event Contract

Use WebSocket JSON messages with a versioned envelope.

```json
{
  "protocolVersion": 1,
  "type": "damage",
  "sequence": 421,
  "timestamp": 1726201001.231,
  "payload": {}
}
```

Required fields:

```text
protocolVersion
type
sequence
timestamp
payload
```

`sequence` must monotonically increase during one Collector process lifetime.

---

# 6. Protocol Events

## 6.1 hello

```json
{
  "protocolVersion": 1,
  "type": "hello",
  "sequence": 1,
  "timestamp": 1726201000.000,
  "payload": {
    "collector": "veritas-bridge",
    "collectorVersion": "0.1.0",
    "gameVersion": "unknown",
    "capabilities": ["damage", "combat_session", "party"]
  }
}
```

## 6.2 combat_start

```json
{
  "protocolVersion": 1,
  "type": "combat_start",
  "sequence": 2,
  "timestamp": 1726201001.000,
  "payload": { "sessionId": "uuid" }
}
```

## 6.3 combat_end

```json
{
  "protocolVersion": 1,
  "type": "combat_end",
  "sequence": 2000,
  "timestamp": 1726201084.200,
  "payload": {
    "sessionId": "uuid",
    "reason": "normal"
  }
}
```

## 6.4 party_update

```json
{
  "protocolVersion": 1,
  "type": "party_update",
  "sequence": 5,
  "timestamp": 1726201001.100,
  "payload": {
    "members": [
      {
        "entityId": 1001,
        "characterId": 1310,
        "name": "Firefly"
      }
    ]
  }
}
```

Do not rely on `name` as an identity key. Use character/entity IDs.

## 6.5 damage

```json
{
  "protocolVersion": 1,
  "type": "damage",
  "sequence": 42,
  "timestamp": 1726201010.132,
  "payload": {
    "sessionId": "uuid",
    "sourceEntityId": 1001,
    "sourceCharacterId": 1310,
    "targetEntityId": 20001,
    "skillId": 131001,
    "amount": 182930,
    "damageType": "unknown",
    "isCrit": false
  }
}
```

Nullable/unknown fields are valid. Never invent values to make the schema complete.

## 6.6 Optional future events

```text
action_start
action_end
enemy_spawn
enemy_death
healing
shield
break
buff
debuff
```

Do not block MVP on them.

---

# 7. IPC Requirements

Preferred transport: WebSocket.

Server:

```text
127.0.0.1:<configurable port>
```

Recommended default:

```text
127.0.0.1:13051
```

Requirements:

```text
localhost only
single machine
multiple Swift reconnect attempts allowed
no LAN binding by default
no authentication required for MVP
bounded outgoing queue
slow client must not stall game hooks
serialization must happen outside hot hook path
```

Collector pipeline:

```text
game hook
   ↓
small event struct
   ↓
non-blocking channel
   ↓
publisher worker
   ↓
JSON encode
   ↓
WebSocket
```

Never perform WebSocket I/O synchronously inside a game callback.

---

# 8. Swift App Technical Stack

Target:

```text
macOS 14+ preferred
Apple Silicon
Swift 6
SwiftUI
AppKit where necessary
Swift Concurrency
URLSessionWebSocketTask
SQLite via GRDB preferred
Charts framework
OSLog
```

Use AppKit for:

```text
NSPanel floating overlay
window level
click-through mode
menu bar/window coordination
```

Use SwiftUI for content.

---

# 9. Swift App Directory Structure

```text
macos/HSRDamageMeter/
│
├── App/
│   ├── HSRDamageMeterApp.swift
│   ├── AppModel.swift
│   ├── AppCommands.swift
│   └── WindowCoordinator.swift
│
├── Networking/
│   ├── CollectorClient.swift
│   ├── CollectorConnectionState.swift
│   ├── ProtocolEnvelope.swift
│   ├── ProtocolEvent.swift
│   ├── EventDecoder.swift
│   └── ReconnectionPolicy.swift
│
├── Domain/
│   ├── CharacterID.swift
│   ├── PartyMember.swift
│   ├── DamageEvent.swift
│   ├── CombatSession.swift
│   ├── CharacterCombatStats.swift
│   ├── SkillCombatStats.swift
│   └── CombatStore.swift
│
├── Features/
│   ├── Live/
│   ├── History/
│   ├── Analysis/
│   └── Settings/
│
├── Overlay/
│   ├── OverlayPanel.swift
│   ├── OverlayWindowController.swift
│   ├── OverlayModel.swift
│   ├── MinimalOverlayView.swift
│   ├── CompactOverlayView.swift
│   └── DetailedOverlayView.swift
│
├── MenuBar/
│   ├── DamageMeterMenu.swift
│   └── MenuBarModel.swift
│
├── Storage/
│   ├── AppDatabase.swift
│   ├── SessionRepository.swift
│   └── Migrations.swift
│
├── DesignSystem/
│   ├── Tokens/
│   ├── Components/
│   ├── Typography.swift
│   ├── Metrics.swift
│   └── Motion.swift
│
├── PreviewData/
│   └── PreviewFactory.swift
│
└── Tests/
```

---

# 10. Swift Domain Model

## CharacterCombatStats

```swift
struct CharacterCombatStats: Identifiable, Equatable, Sendable {
    let id: CharacterID
    var displayName: String
    var totalDamage: Int64
    var damageShare: Double
    var dps: Double
    var maxHit: Int64
    var hitCount: Int
}
```

## CombatSession

```swift
struct CombatSession: Identifiable, Sendable {
    let id: UUID
    let startedAt: Date
    var endedAt: Date?
    var party: [PartyMember]
    var totalDamage: Int64
    var statsByCharacter: [CharacterID: CharacterCombatStats]
    var eventCount: Int
}
```

---

# 11. CombatStore

Use an actor.

Responsibilities:

```text
consume decoded Collector events
maintain active session
aggregate character totals
calculate share
calculate DPS
maintain max hit
publish UI snapshots
persist completed sessions
```

Concept:

```swift
actor CombatStore {
    func consume(_ event: ProtocolEvent)
    func resetCurrentSession()
    func currentSnapshot() -> CombatSnapshot
}
```

UI must not directly mutate combat state.

---

# 12. Connection Behavior

```swift
enum CollectorConnectionState {
    case disconnected
    case connecting
    case connected
    case incompatibleProtocol
    case error(String)
}
```

Reconnection schedule:

```text
0s
1s
2s
5s
10s
10s ...
```

UI states:

```text
Connected
Connecting
Collector Not Found
Protocol Mismatch
```

Do not show raw socket errors as the primary user message.

---

# 13. Product Information Architecture

The app has five surfaces:

```text
1. Menu Bar
2. Floating Meter
3. Main Dashboard — Live
4. Main Dashboard — History
5. Main Dashboard — Analysis / Settings
```

Primary sidebar:

```text
Live
History
Analysis
Settings
```

No more than four top-level destinations for MVP.

---

# 14. Design Direction

Visual concept:

```text
Raycast
×
modern macOS system utility
×
HunterPie / ACT-style damage meter
```

Avoid:

```text
heavy anime decoration
gold fantasy frames
game UI imitation
large character splash art
neon overload
excessive glass panels
```

Use HSR identity only through:

```text
character portraits
subtle per-character accent
small iconography
```

The app should feel native first, game-adjacent second.

---

# 15. Design Tokens

## Corner radius

```text
small controls       6
buttons              8
cards               12
large cards         16
overlay container   16
```

## Spacing scale

```text
4
8
12
16
20
24
32
```

## Typography

Use SF Pro through native SwiftUI styles.

```text
Screen title:
.title2 / semibold

Section title:
.headline

Hero number:
system 32–40 / semibold / monospacedDigit

Card value:
title3 / semibold / monospacedDigit

Character name:
body / medium

Secondary metric:
caption

Metadata:
caption2
```

Numeric values should use `.monospacedDigit()`.

---

# 16. Character Visual Identity

Each character may have:

```text
portrait
accentColor
displayName
```

Accent usage:

```text
damage bar
small status dot
portrait ring
selected-character highlight
chart series
```

Never tint entire cards with saturated character colors.

---

# 17. Main Window Specification

```text
minimum: 900 × 620
recommended default: 1120 × 760
```

Use `NavigationSplitView`.

```text
┌───────────────────────────────────────────────────────────────┐
│ HSR Damage Meter                                  ● Connected│
├───────────────┬───────────────────────────────────────────────┤
│ Live          │                                               │
│ History       │              Content                          │
│ Analysis      │                                               │
│               │                                               │
│ Settings      │                                               │
└───────────────┴───────────────────────────────────────────────┘
```

Sidebar target width: 180–220.

---

# 18. Live Page — Primary Layout

```text
┌──────────────────────────────────────────────────────────────────┐
│ Live Combat                                      ●  Connected    │
│ Simulated Universe · 01:23                                      │
│                                                                  │
│ ┌────────────────┐ ┌────────────────┐ ┌────────────────┐        │
│ │ TOTAL DAMAGE   │ │ PARTY DPS      │ │ HIGHEST HIT    │        │
│ │ 7.88M          │ │ 94.8K/s        │ │ 482K           │        │
│ │                │ │                │ │ Firefly        │        │
│ └────────────────┘ └────────────────┘ └────────────────┘        │
│                                                                  │
│ Damage Contribution                                              │
│                                                                  │
│ ╭────╮ Firefly                                      4.82M       │
│ │img │ ███████████████████████░░░░░░░               61.2%       │
│ ╰────╯ 58.1K/s · 18 hits                           Max 482K      │
│                                                                  │
│ ╭────╮ Fugue                                        1.51M       │
│ │img │ ████████░░░░░░░░░░░░░░░░░░░                 19.2%       │
│ ╰────╯ 18.2K/s                                      Max 160K      │
│                                                                  │
│ ╭────╮ Robin                                         894K       │
│ │img │ █████░░░░░░░░░░░░░░░░░░░░░                  11.3%       │
│ ╰────╯ 10.7K/s                                      Max 92K       │
│                                                                  │
│ ╭────╮ Character 4                                   653K       │
│ │img │ ███░░░░░░░░░░░░░░░░░░░░░                     8.3%       │
│ ╰────╯                                                Max 81K      │
└──────────────────────────────────────────────────────────────────┘
```

---

# 19. Live Header

Left:

```text
Live Combat
encounter/session subtitle
```

Right:

```text
connection status
elapsed duration
Reset button
```

Reset requires lightweight confirmation if an active session contains data.

---

# 20. Hero Metric Cards

Exactly three initially:

```text
Total Damage
Party DPS
Highest Hit
```

Examples:

```text
7.88M
94.8K/s
482K
```

Hover may reveal precise values.

---

# 21. Character Damage Row

Reusable component: `DamageContributionRow`.

Inputs:

```text
portrait
name
damage
damageShare
relativeBarValue
dps
hitCount
maxHit
accent
```

Important distinction:

```text
bar width = character damage / highest character damage
percentage text = character damage / total party damage
```

---

# 22. Damage Bar

Recommended height: 5 px.

Use a low-emphasis track and character-accent progress.

Animate changes gently; do not restart from zero for every update.

---

# 23. Live Character Selection

Clicking a row selects that character.

When width permits, show a right inspector:

```text
Firefly

4.82M
61.2%

DPS        58.1K
Max Hit    482K
Hits       18

Skills
Enhanced Skill      2.18M
Super Break         1.63M
Other               1.01M
```

For MVP, hide skill breakdown unless Collector data genuinely supports it.

---

# 24. History Page

Avoid spreadsheet-style UI by default.

```text
Today

┌──────────────────────────────────────────────────────────┐
│ 14:23  Forgotten Hall                          01:38    │
│ 12.82M total                                  130.8K/s  │
│                                                          │
│ Firefly  ███████████████████                67.2%       │
│ Fugue    █████                               17.0%       │
│ Robin    ███                                  9.3%       │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│ 13:52  Simulated Universe                       02:11   │
│ 18.21M total                                   139.0K/s │
└──────────────────────────────────────────────────────────┘
```

Group:

```text
Today
Yesterday
Earlier
```

MVP filters:

```text
Search
Recent / Oldest sort
```

---

# 25. Session Detail View

```text
┌───────────────────────────────────────────────────────────────┐
│ Back      Session · 14:23                                    │
│ 01:38 · 12.82M total · 130.8K/s                             │
│                                                               │
│ Party                                                         │
│ [Portrait] [Portrait] [Portrait] [Portrait]                   │
│                                                               │
│ Damage Share                                                  │
│ Firefly       ███████████████████  8.62M     67.2%           │
│ Fugue         █████                 2.18M     17.0%           │
│ Robin         ███                   1.19M      9.3%           │
│ Character 4   ██                    0.83M      6.5%           │
│                                                               │
│ Damage Over Time                                              │
│ ┌───────────────────────────────────────────────────────────┐ │
│ │ chart                                                     │ │
│ └───────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────┘
```

---

# 26. Analysis Page

Top selector:

```text
[ Character ▼ ]   [ Last 20 Sessions ▼ ]
```

Hero metrics:

```text
Total Damage      82.4M
Average Share     61.8%
Average DPS       54.1K
Highest Hit       721K
```

Sections:

```text
Damage Trend
Damage Share Trend
Recent Sessions
Skill Breakdown (if supported)
```

Use Apple's Charts framework.

---

# 27. Settings Page

Sections:

```text
Collector
Overlay
Appearance
Data
About
```

## Collector

```text
Status                  ● Connected
Address                 127.0.0.1
Port                    13051

[ Test Connection ]

Protocol                v1
Collector Version       0.1.0
```

Allow host, port, auto-connect. Default host remains `127.0.0.1`.

## Overlay

```text
Show Overlay                 [on]
Always on Top                [on]
Click Through                [off]

Mode
( ) Minimal
(●) Compact
( ) Detailed

Show Damage                  [on]
Show Percentage              [on]
Show DPS                     [on]
Show Portraits               [on]

Opacity                      ─────●────
Scale                        Small / Medium / Large
```

## Appearance

```text
Theme
System / Light / Dark

Density
Compact / Comfortable

Animations
Full / Reduced
```

Honor Reduce Motion and Reduce Transparency where practical.

## Data

```text
Session History
143 sessions

[ Export JSON ]
[ Clear History ]
```

Clear History requires confirmation.

---

# 28. Floating Overlay Architecture

Use:

```text
NSPanel
+
SwiftUI hosting
```

Behavior:

```text
floating
non-activating where practical
optional click-through
movable
position persisted
size persisted
visible across Spaces if user enables it
```

---

# 29. Overlay Mode 1 — Minimal

Target ~220 × 130.

```text
┌────────────────────────────┐
│ Firefly              61.2% │
│ Fugue                19.2% │
│ Robin                11.3% │
│ Character 4           8.3% │
└────────────────────────────┘
```

Portraits off by default.

---

# 30. Overlay Mode 2 — Compact

Default. Width 300–340 px.

```text
┌─────────────────────────────────┐
│ Combat                  01:23 ● │
├─────────────────────────────────┤
│ ◉ Firefly                 4.82M │
│ ████████████████████      61.2% │
│                           58K/s │
│                                 │
│ ◉ Fugue                   1.51M │
│ ██████                    19.2% │
│                           18K/s │
│                                 │
│ ◉ Robin                    894K │
│ ████                      11.3% │
│                           11K/s │
├─────────────────────────────────┤
│ Total                    7.88M  │
└─────────────────────────────────┘
```

---

# 31. Overlay Mode 3 — Detailed

Width 360–420 px.

```text
┌──────────────────────────────────────┐
│ Firefly                             │
│ 4.82M                    61.2%       │
│ ███████████████████████              │
│ DPS 58.1K   Max 482K   Hits 18      │
│                                      │
│ Fugue                                │
│ 1.51M                    19.2%       │
│ ████████                             │
│ DPS 18.2K   Max 160K   Hits 11      │
└──────────────────────────────────────┘
```

---

# 32. Overlay Interaction Model

When click-through is disabled, hover reveals:

```text
lock
change mode
open dashboard
hide
```

When click-through is enabled, normal pointer events pass through.

Always provide a menu-bar action to disable click-through.

---

# 33. Menu Bar App

Suggested SF Symbol: `chart.bar.fill`.

```text
HSR Damage Meter

● Collector Connected

Current Battle
7.88M Damage
94.8K DPS
01:23

────────────

Show / Hide Overlay
Open Dashboard
Reset Current Battle

────────────

Settings…
Quit
```

Disconnected state:

```text
○ Collector Offline
```

---

# 34. Window Lifecycle

Closing the main window should NOT quit the app by default.

```text
main window closed
menu bar remains active
overlay may remain visible
collector connection remains active
```

Quit only via Cmd+Q or menu-bar Quit.

---

# 35. Numeric Formatting

Shared formatter:

```text
982          → 982
1,231        → 1.23K
18,231       → 18.2K
182,930      → 183K
1,520,001    → 1.52M
18,991,200   → 19.0M
```

Tooltips/inspectors may show precise integers.

---

# 36. Real-Time Motion

Prefer native numeric transitions:

```swift
Text(formattedDamage)
    .monospacedDigit()
    .contentTransition(.numericText())
```

Motion should be short, subtle, non-bouncy. Suggested duration: 0.15–0.25 sec.

Damage bars should interpolate smoothly.

Do not animate every raw event if the event rate is high.

---

# 37. UI Update Frequency

Collector may emit many events per second.

```text
CombatStore processes every event
UI snapshot publication: 10–20 Hz maximum
```

Historical persistence remains event-accurate.

---

# 38. Accessibility

If Reduce Motion is enabled:

```text
disable numeric rolling
use direct/opacity updates
minimize bar interpolation
```

If Reduce Transparency is enabled:

```text
replace translucent overlay with opaque system background
```

---

# 39. Empty States

## Collector offline

```text
Collector not connected

Start HSR with the Veritas collector,
then reconnect.

[ Reconnect ]
[ Open Settings ]
```

## Connected, no combat

```text
Ready

Collector connected.
Waiting for combat…
```

## No history

```text
No combat history yet.
Completed sessions will appear here.
```

---

# 40. Error Handling

Routine network failures use:

```text
inline banner
status badge
settings diagnostics
```

Reserve modal alerts for destructive actions.

---

# 41. Persistence

Use GRDB/SQLite.

Tables:

```text
sessions
party_members
damage_events
character_stats
app_settings
```

Minimum session fields:

```text
id
started_at
ended_at
total_damage
duration
game_version
collector_version
```

Keep raw damage events initially to allow recomputation.

---

# 42. Swift Preview Requirement

Every major SwiftUI view must have preview fixtures.

```text
PreviewFactory.connectedLiveSession()
PreviewFactory.disconnected()
PreviewFactory.emptyHistory()
PreviewFactory.largeDamageNumbers()
```

Do not require the real Collector to design UI.

---

# 43. Test Strategy

Collector tests:

```text
protocol serialization
event ordering
WebSocket publisher isolation
slow-client handling
session IDs
```

Swift unit tests:

```text
ProtocolEnvelope decoding
damage aggregation
damage share
DPS
max hit
session lifecycle
reconnection policy
number formatting
```

UI tests:

```text
main navigation
history selection
settings persistence
overlay mode switching
```

---

# 44. Development Milestones

## M0 — Repository + Protocol

Implement:

```text
repository structure
protocol v1
JSON fixtures
Collector event bridge interfaces
Swift protocol Codable models
```

Acceptance:

```text
[ ] protocol fixtures decode in Swift
[ ] same fixtures serialize in Rust
[ ] protocolVersion enforced
[ ] schema documented
```

## M1 — Collector Publisher

Modify Veritas minimally.

Implement:

```text
EventPublisher
localhost WebSocket server
hello
combat_start
combat_end
party_update
damage
```

Acceptance:

```text
[ ] Collector starts normally
[ ] existing Veritas behavior remains functional
[ ] WebSocket binds only loopback
[ ] damage events appear in test client
[ ] network work never blocks game callback
```

Do not implement anti-cheat bypass work.

## M2 — Swift Networking Shell

Implement:

```text
macOS Swift app
CollectorClient
reconnect logic
connection state
event decoder
debug raw event console
```

Acceptance:

```text
[ ] app connects to Wine-hosted localhost server
[ ] hello parsed
[ ] disconnect/reconnect handled
[ ] protocol mismatch shown
[ ] raw damage events visible in debug view
```

## M3 — Combat Store

Implement:

```text
active session
party
damage totals
share
DPS
max hit
event count
```

Acceptance:

```text
[ ] totals exact
[ ] percentages sum correctly
[ ] sessions reset correctly
[ ] multi-character damage correctly aggregated
```

## M4 — Design System + Live Page

Implement:

```text
tokens
typography
number formatting
metric cards
damage rows
Live screen
preview data
```

Acceptance:

```text
[ ] Live works without Collector using previews
[ ] handles small and very large values
[ ] works at minimum window size
```

## M5 — Native Floating Overlay

Implement:

```text
NSPanel
Minimal
Compact
Detailed
always-on-top
click-through
position persistence
```

Acceptance:

```text
[ ] overlay updates from CombatStore
[ ] all three modes work
[ ] click-through can be recovered through menu bar
[ ] position persists across launch
```

## M6 — Menu Bar Integration

Implement:

```text
status item
connection state
live summary
overlay toggle
open dashboard
reset battle
quit
```

Acceptance:

```text
[ ] closing main window does not exit app
[ ] menu bar remains functional
[ ] collector connection remains alive
```

## M7 — Persistence + History

Implement:

```text
SQLite
session storage
History page
session detail
```

Acceptance:

```text
[ ] completed battles persisted
[ ] history survives restart
[ ] detail totals match live results
```

## M8 — Analysis Page

Implement:

```text
character selector
aggregate metrics
damage trend chart
share trend
recent sessions
```

Acceptance:

```text
[ ] calculations verified against stored sessions
[ ] charts handle empty and sparse data
```

## M9 — Settings + Polish

Implement:

```text
Collector settings
Overlay settings
Appearance
Data controls
reduced motion
reduced transparency
```

Acceptance:

```text
[ ] settings persist
[ ] destructive actions confirmed
[ ] accessibility preferences honored
```

---

# 45. Implementation Order

```text
1. Protocol
2. Collector bridge
3. Swift networking
4. CombatStore
5. Live page
6. Overlay
7. Menu bar
8. Persistence
9. History
10. Analysis
11. Settings
12. polish
```

Do not begin with visual polish before Collector → Swift event delivery works.

---

# 46. Collector Change Minimization

When editing upstream Veritas, prefer:

```text
small adapter
small publisher module
existing event subscriptions
```

Avoid:

```text
large architectural rewrite
renaming upstream modules unnecessarily
moving unrelated files
formatting the entire repository
```

Maintain `docs/VERITAS_PATCHES.md` with:

```text
upstream file
reason for change
minimal patch summary
dependencies
```

---

# 47. Security Boundary

The Swift app:

```text
MUST NOT read StarRail process memory
MUST NOT inject into Wine
MUST NOT modify game state
MUST NOT contain anti-cheat bypass code
```

Collector work should be limited to exposing existing Veritas-derived data.

Do not add:

```text
hook hiding
module hiding
anti-cheat evasion
detection avoidance
```

---

# 48. UI Component Library

Create reusable:

```text
ConnectionBadge
HeroMetricCard
DamageContributionRow
CharacterPortrait
DamageBar
MetricLabel
SessionHistoryRow
EmptyStateView
InlineStatusBanner
OverlayCharacterRow
SectionHeader
```

Do not duplicate styling in feature pages.

---

# 49. Design System Example

```swift
enum AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum AppRadius {
    static let control: CGFloat = 8
    static let card: CGFloat = 12
    static let largeCard: CGFloat = 16
}
```

Keep tokens centralized.

---

# 50. Responsive Rules

If content width >= 1000, allow optional character inspector.

If width < 1000, use single-column primary content.

Metric cards normally use three columns and wrap if required.

No horizontal scrolling for the main dashboard.

---

# 51. History Performance

Use lazy lists and database pagination.

Load summaries first and full detail on selection.

Do not load thousands of raw events at startup.

---

# 52. Overlay Performance

Overlay consumes summarized snapshots, never raw streams.

```text
raw events
  ↓
CombatStore
  ↓
CombatSnapshot
  ↓
OverlayModel
  ↓
SwiftUI
```

---

# 53. Combat Snapshot

```swift
struct CombatSnapshot: Sendable, Equatable {
    let sessionID: UUID?
    let connectionState: CollectorConnectionState
    let elapsed: TimeInterval
    let totalDamage: Int64
    let partyDPS: Double
    let characters: [CharacterCombatStats]
    let highestHit: Int64
    let highestHitCharacter: CharacterID?
}
```

Sort characters by total damage descending and preserve stable IDs.

---

# 54. First Codex Task

```text
Read this specification fully and treat it as the project's authoritative
architecture/UI contract.

For this iteration implement M0 only:

- repository structure
- protocol v1 definitions
- JSON schema/fixtures
- Rust protocol structs
- Swift Codable protocol structs
- cross-language sample fixtures
- documentation

Do not modify Veritas hooks yet.
Do not build the overlay yet.
Do not implement persistence yet.

Run all available tests/build checks.

At the end report:
1. files created/changed
2. protocol decisions
3. how to validate fixtures
4. known assumptions
5. exact next work for M1

Stop after M0.
```

---

# 55. Second Codex Task

```text
Implement M1 only.

Study the current Veritas source first.

Identify the narrowest point where already-resolved damage/session/party events
can be observed without rewriting upstream game integration.

Add a localhost-only asynchronous WebSocket publisher.

Requirements:
- preserve existing Veritas behavior
- no blocking network calls in game-event callbacks
- bounded channel
- hello/combat_start/combat_end/party_update/damage
- protocol v1
- clear logging
- no anti-cheat evasion functionality

Document every Veritas patch in docs/VERITAS_PATCHES.md.

Build/test and stop after M1.
```

---

# 56. Third Codex Task

```text
Implement M2 and M3.

Create the native macOS Swift app shell and event pipeline:

CollectorClient
→ EventDecoder
→ CombatStore
→ debug CombatSnapshot

Do not implement final visual design yet.

Prove:
- connect
- reconnect
- protocol negotiation
- party updates
- correct totals
- correct shares
- correct DPS
- session start/end

Add tests and stop.
```

---

# 57. UI Implementation Prompt

```text
Implement M4 using the UI specification in this document.

Build the shared design system first, then Live.

Use preview fixtures so all visual work can be developed without the game.

Do not invent unsupported data fields.
Do not implement History/Analysis yet.

Required:
- main NavigationSplitView
- Live header
- connection badge
- three hero metric cards
- DamageContributionRow
- character portrait support
- damage bars
- number formatting
- numeric transitions
- empty/offline/ready states
- minimum window behavior

Compare the final implementation against the ASCII wireframe and UI tokens.
```

---

# 58. Final Product Acceptance Criteria

```text
[ ] Veritas-derived Collector emits accurate damage events.
[ ] Collector and native app communicate over loopback.
[ ] Swift app never touches the game process.
[ ] Live page updates smoothly.
[ ] damage totals and shares are exact.
[ ] app can remain menu-bar-only when dashboard is closed.
[ ] Compact overlay works as the default live meter.
[ ] overlay can be click-through.
[ ] history persists completed battles.
[ ] reconnect survives Collector/game restart.
[ ] UI feels like a native macOS utility rather than an in-game clone.
```

---

# 59. Product Summary

The final system should feel like:

```text
Veritas accuracy
+
native macOS architecture
+
Raycast-level restraint
+
ACT/HunterPie-level combat readability
```

The intended user flow:

```text
launch HSR
launch HSR Damage Meter
see Collector connect automatically
play normally
glance at a small floating meter
open the dashboard for detail
review previous fights later
```

The Swift app should never need to know how Veritas obtains the underlying game data.
