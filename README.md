# StableDEX_whitepaper
Recognizing the incompatibility between the characteristics of stablecoins and the pair-based pools used in DEXs, we decided to devise a new mechanism for a stablecoin-specific DEX and document it in the following white paper.


## Abstract & Key Features

**Stable DEX** is an oracle-referenced decentralized exchange model specifically designed for stablecoins, separating **price discovery** (handled by external oracles) from **liquidity management** (controlled via an internal dynamic metric called **Distortion Value**).

Unlike traditional AMMs that adjust execution prices to attract arbitrageurs, Stable DEX fixes execution prices at the oracle's true market rate to preserve the 1-to-1 peg symmetry, while relying on a **dynamic quadratic penalty fee wall** to manage liquidity risk and defend against pool drain attacks.

### Key Mechanics
* **Decoupled Architecture:** Prices are strictly anchored to true oracle exchange rates ($M$), eliminating impermanent loss for liquidity providers and preventing price manipulation within the pool.
* **Distortion Value ($d$):** Continuously tracks liquidity imbalance based on reserve ratios vs. true market rates.
* **Asymmetric Incremental Dynamic Fee ($skew$):**
  * **Worsening Trades ($|d_{\text{after}}| - |d_{\text{before}}| \ge 0$):** A quadratic penalty fee ($d^2 \cdot f_m$) is levied to instantly block pool depletion and eliminate positive expected value (EV) for stale-oracle arbitrageurs.
  * **Rebalancing Trades ($|d_{\text{after}}| - |d_{\text{before}}| < 0$):** Zero fee penalty ($skew = 0$), allowing rebalancers to restore pool equilibrium at pure oracle rates.

---

## Stress Test & Attack Resistance (Worst-Case Single-Tick Loss)

To address single-tick drain risks during oracle update lags, the protocol was stress-tested against an extreme market shock scenario (Section 7.2.3 & 7.3.3)[cite: 1]:

* **Scenario:** A stale oracle condition where an unreflected price shift occurs ($1\text{ USDC} = 167.89\text{ JPYC}$), followed by a massive **2,500 USDC single-tick swap** against a **10,000 USDC pool reserve** ($d$ jumps from `0.0291` to `0.4233`).
* **Results:**
  * **Fee Multiplier ($f_m = 5$):** Generated **`2,239.79 USDC`** in $skew$ fees.
  * **Fee Multiplier ($f_m = 20$):** Generated **`8,959.18 USDC`** in $skew$ fees.

> **Conclusion:** Single-tick drain attacks are rendered economically impossible. The quadratic fee wall automatically scales far above any potential arbitrage profit, protecting the reserve from bleeding under worst-case market conditions.

---

## Whitepaper
For the full theoretical background, formula derivations, and detailed simulation data, please refer to the [Stable DEX Whitepaper (PDF)](./StableGuard-Whitepaper.pdf)[cite: 1].
