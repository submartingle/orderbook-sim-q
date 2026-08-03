# Limit Order Book Simulation and Analysis (LOBSTER, KDB+/Q)

This project implements a simulation and analytics framework for a limit order book using **LOBSTER level-10 order book data**, written in **KDB+/Q**. It is designed to help evaluate the microstructure behavior of markets, including order book replay, metrics tracking, and the impact of simulated market orders.

## 🛠️ How This Was Built

The simulator was written in q against LOBSTER level-10 sample data, developed between July 2025 and April 2026.

In May 2026 the three-file layout was restructured into namespaced modules using **Claude Code**. I set the module boundaries, the namespace layout (`.util` / `.replay` / `.stats` / `.sim`) and the pure-function rewrite of the simulation path; the tool handled the mechanical restructuring, and I reviewed and tested the output. Commits from that pass carry `Co-Authored-By` trailers.

The original three-file version is kept alongside the refactor rather than replaced, so the before and after can be read side by side.

`refactor-claude-2026-05/kdb-q-coding-guide.md` is a working reference on q conventions, architecture and language traps — my own material, built on top of Data Intellect's language reference.

---

## 🔄 Refactor Notes (May 2026)

The codebase has been restructured from a monolithic three-file layout into a set of focused, namespaced modules under `refactor-claude-2026-05/`. Key improvements:

- **Module separation** — `orderBook.q`, `obstat.q`, and `moSim.q` split into `ob_util.q`, `ob_replay.q`, `ob_stats.q`, `ob_mosim.q`, and `ob_main.q` (entry point)
- **Namespaced functions** — each module owns a dedicated q namespace (`.util.*`, `.replay.*`, `.stats.*`, `.sim.*`); no more unscoped globals
- **Pure functions** — market order simulation (`runScenario`, `marketOrderImpact`) rewritten without global state mutation, making results reproducible and composable
- **Parallel scenario runs** — `peach` support added for running large batches of market order scenarios across slave threads
- **Replay dispatch refactor** — event handler uses a dictionary-of-functions pattern instead of a chain of if/else branches

---

## 🐛 Notable Fixes

**Stale timestamp on unmatched cancellations** — *fixed April 2026, in the original `orderBook.q`.*

LOBSTER type-2 events are *partial cancellations*, and the message file records them at every price level — including levels outside the tracked level-10 book. When the cancelled price was not present in the visible book, the type-2 handler took an early-return branch and returned the book unchanged. Prices and sizes were correct (there was nothing to cancel), but the book's leading `time` field was left holding the **previous** event's timestamp:

```q
if[idx>=count bk; :bkCol!bk];                    / stale: keeps old time
if[idx>=count bk; :bkCol!(ets[`time],1_bk)];     / fixed: stamps current event time
```

Every other exit path in the handler stamped the event time correctly, so the defect was silent and data-dependent — no error, no type mismatch, only a book state attributed to the wrong instant. It mattered because the interval snapshots (10s/30s/1m) and the market-order time-to-recovery metric both key off the book's own `time` field. The fix is carried through to `.replay.evtCancelOrder` in the refactored modules.

---

NOTE:
This repository is a personal portfolio project created independently. It is shared for review/evaluation only. Please do not copy, redistribute, or use any part of this code in commercial or client deliverables without my written permission.

---

## 📁 Project Structure

### Original three-file layout

| File         | Description |
|--------------|-------------|
| `orderBook.q` | Core logic to **replay** order book line-by-line using LOBSTER message data. Initializes from LOBSTER level-10 snapshot. Includes basic **validation** logic to ensure order book state integrity. |
| `obstat.q`    | Contains various **statistical metrics** for analyzing order book behavior — e.g., depth histograms, spread, imbalance ratios. |
| `moSim.q`     | Simulates the **injection of market orders** into the order book and measures impact such as depth consumption and recovery dynamics. Further analytics will be incorporated. |

### Namespaced modules — `refactor-claude-2026-05/`

Each module owns one namespace and declares its dependencies in a header comment. Run with
`q refactor-claude-2026-05/ob_main.q`.

| File | Namespace | Description |
|------|-----------|-------------|
| `ob_util.q`   | `.util.*`   | Shared constants and helpers — price scaling, rounding, seconds-to-time conversion, book snapshots. Loaded first. |
| `ob_stats.q`  | `.stats.*`  | Order book analytics — imbalance ratio, spread, depth and execution cost metrics. Accepts a single-row dict or a table, returning scalar or vector accordingly. |
| `ob_replay.q` | `.replay.*` | Book reconstruction from LOBSTER message events. All functions pure — state passed as parameters, no globals modified. Event types are routed through a dispatch dictionary (`.replay.evtDispatch`) rather than branching logic. |
| `ob_mosim.q`  | `.sim.*`    | Market order impact simulation — depth consumption, execution cost and imbalance recovery. Global state (`imbpre`, `exPrice`, `bestMPrice`) eliminated; `marketOrderImpact` returns a dict and `runScenario` is fully pure, so scenarios can run under `peach`. |
| `ob_main.q`   | —           | Entry point. Loads the modules in dependency order, reads the LOBSTER message and order book CSVs, and builds the initial book state. |

---

## 🔍 Key Features

- ✅ Reconstructs the order book from raw message/event data, allow snapshot at different specified time intervals, 10s,30s,1m etc.
- 📊 Tracks key order book metrics like bid-ask spread, liquidity depth, and imbalance
- 📉 Simulates large market orders and evaluates:
  - Market depth impact
  - Spread widening
  - Time to recovery

---

## 🚧 Development Status

This is a **work-in-progress** codebase. Some modules and analysis functions are still under development or subject to change.

Planned additions:
- Analyze order book resilience as a function of trade size and time
- Expand simulation scenarios (e.g., multiple market orders, stress testing)

---

## 🔧 Requirements

- [KDB+/Q](https://kx.com) installed locally (tested with v3.6 and v4.1)
- LOBSTER data: level-10 order book and corresponding message file

---

## 🗂️ Data Source

This project uses sample LOBSTER data to simulate and analyze order book behavior.

You can download a test dataset directly from the official LOBSTER site:

🔗 [LOBSTER Sample Data](https://lobsterdata.com/info/DataSamples.php)

---

## 🧠 Background

This project uses high-resolution LOBSTER data to simulate and understand micro-level order book dynamics. It is useful for researchers, quants, and technologists interested in market microstructure, algo trading behavior, and price formation.

---

## 📎 Disclaimer

This code is for **educational and demonstration** purposes only. It is not optimized for production trading or execution.

---

## 📫 Contact

**Paul C. Jin**  
📧 Email: [lestat.jin@gmail.com](mailto:lestat.jin@gmail.com)  
🔗 LinkedIn: [www.linkedin.com/in/pjin](https://www.linkedin.com/in/pjin)
