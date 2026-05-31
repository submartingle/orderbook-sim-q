# Limit Order Book Simulation and Analysis (LOBSTER, KDB+/Q)

This project implements a simulation and analytics framework for a limit order book using **LOBSTER level-10 order book data**, written in **KDB+/Q**. It is designed to help evaluate the microstructure behavior of markets, including order book replay, metrics tracking, and the impact of simulated market orders.

## 🔄 Refactor Notes (May 2026)

The codebase has been restructured from a monolithic three-file layout into a set of focused, namespaced modules under `refactored/`. Key improvements:

- **Module separation** — `orderBook.q`, `obstat.q`, and `moSim.q` split into `ob_util.q`, `ob_replay.q`, `ob_stats.q`, `ob_mosim.q`, and `ob_main.q` (entry point)
- **Namespaced functions** — each module owns a dedicated q namespace (`.util.*`, `.replay.*`, `.stats.*`, `.sim.*`); no more unscoped globals
- **Pure functions** — market order simulation (`runScenario`, `marketOrderImpact`) rewritten without global state mutation, making results reproducible and composable
- **Parallel scenario runs** — `peach` support added for running large batches of market order scenarios across slave threads
- **Replay dispatch refactor** — event handler uses a dictionary-of-functions pattern instead of a chain of if/else branches
- **Bug fix** — type-2 (order delete) events now correctly propagate the timestamp into the updated book state

---

NOTE:
This repository is a personal portfolio project created independently. It is shared for review/evaluation only. Please do not copy, redistribute, or use any part of this code in commercial or client deliverables without my written permission.

---

## 📁 Project Structure

| File         | Description |
|--------------|-------------|
| `orderBook.q` | Core logic to **replay** order book line-by-line using LOBSTER message data. Initializes from LOBSTER level-10 snapshot. Includes basic **validation** logic to ensure order book state integrity. |
| `obstat.q`    | Contains various **statistical metrics** for analyzing order book behavior — e.g., depth histograms, spread, imbalance ratios. |
| `moSim.q`     | Simulates the **injection of market orders** into the order book and measures impact such as depth consumption and recovery dynamics. Further analytics will be incorporated. |

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
