# Limit Order Book Simulation and Analysis (LOBSTER, KDB+/Q)

This project implements a simulation and analytics framework for a limit order book using **LOBSTER level-10 order book data**, written in **KDB+/Q**. It is designed to help evaluate the microstructure behavior of markets, including order book replay, metrics tracking, and the impact of simulated market orders.

---

## 📁 Project Structure

| File         | Description |
|--------------|-------------|
| `orderBook.q` | Core logic to **replay** order book line-by-line using LOBSTER message data. Initializes from LOBSTER level-10 snapshot. Includes basic **validation** logic to ensure order book state integrity. |
| `obstat.q`    | Contains various **statistical metrics** for analyzing order book behavior — e.g., depth histograms, spread, imbalance ratios. |
| `moSim.q`     | Simulates the **injection of market orders** into the order book and measures impact such as depth consumption and recovery dynamics. Further analytics will be incorporated. |

---

## 🔍 Key Features

- ✅ Reconstructs the order book from raw message/event data
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
