# Fees & Economics

## Performance & Management Fees

#### **Management Fees**

These are calculated based on the assets under management (AUM) and are charged over time and collected during vault settlement. The formula used here calculates management fees by multiplying the assets by the management rate (a percentage expressed in basis points or BPS) and prorating it by the time elapsed (relative to one year).



$$
\text{managementFee} = \left( \frac{\text{assets} \times \text{rate}}{\text{BPS}} \right) \times \frac{\text{timeElapsed}}{\text{1 year}}
$$

Where:

* **assets** is the total assets being managed.
* **rate** is the fee rate for 1 year in BPS.
* **BPS** is a constant representing "Basis Points", 10\_000 for percentage conversions (e.g.,  1% = 100 BPS).
* **timeElapsed** is the time period for which the fee is calculated.

The management fee increases linearly over time based on the asset value and the management rate.

#### **Performance Fees**

These are charged on profits and are calculated only when the value of the assets exceeds a **high water mark** (the highest historical value per one share). This is done to ensure that fees are charged only on actual profits and not on recovered losses.

$$
\begin{align*}
\text{If } \text{pricePerShare} > \text{highWaterMark}: \\
\text{profit} &= (\text{pricePerShare} - \text{highWaterMark}) \times \text{totalSupply} \\[1em]
\text{performanceFee} &= \frac{\text{profit} \times \text{rate}}{\text{BPS}}
\end{align*}
$$

Where:

* **pricePerShare** is the current price per share.
* **highWaterMark** is the previous highest price per share.
* **totalSupply** is the total number of shares.
* **rate** is the performance fee rate (in basis points).
* **BPS** is a constant representing basis points.

The performance fee is proportional to the profit made, ensuring managers are rewarded only when they generate returns above the high water mark.

#### **Exit & Entry Fees**

The current contract doesn’t include entry or exit fees, which are normally charged when investors join or leave the fund. These features will be added in future versions but are not part of the current design.

#### **Fee Distribution**

Once the total fees are calculated (sum of management and performance fees), the contract calculates the share for both the **manager** and the **protocol** (if applicable). The protocol takes a percentage cut from the total fees, and the rest goes to the manager. Both are converted into shares rather than paid in direct currency.

## **Rate Limits and Restrictions**

**Maximum Rates**: There are limits on management, performance, and protocol rates to protect investors from excessive fees:

* Maximum Management Rate: 10%
* Maximum Performance Rate: 50%
* Maximum Protocol Rate: 30%

**Cooldown Period**: Updates to fee rates can only occur after a cooldown period (e.g. 30 days). This ensures stability and prevents sudden fee rate changes.





```
```
