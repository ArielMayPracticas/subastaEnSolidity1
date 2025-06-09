# 🛒 TimedAuction Smart Contract

A fully-featured Ethereum smart contract implementing a 7-day auction with automatic refunds, time extension, and bid validation.

---

## 📋 Features

- **Duration:** 7-day fixed auction from contract deployment.
- **Starting Bid:** 2 ETH.
- **Minimum Bid Increment:** Each new bid must be **at least 5% higher** than the current highest bid.
- **Automatic Refunds:** Losing bidders are **automatically refunded** (minus a 2% fee) when the auction is finalized.
- **Time Extension:** If a bid is placed in the **last 10 minutes**, the auction is extended by **10 more minutes**.
- **Secure Logic:** Includes reentrancy protection, ownership restriction, and safe value handling.
- **Bid History:** All bids are recorded with address, amount, and timestamp.

---

## 🛠️ Contract Overview

### `constructor()`

Initializes:
- The auction **owner** as the deployer
- The **end time** to 7 days from deployment
- The **starting bid** to 2 ETH

---

### `function bid() external payable`

Places a bid.

- Must be at least 5% higher than the current highest.
- Overwrites any previous bid by the same user.
- If within the last 10 minutes of the auction, **extends the deadline by 10 minutes**.
- All bids are saved with timestamp for auditability.

---

### `function finalize() external onlyOwner`

Ends the auction. Can only be called by the **owner** after the auction duration has passed.

Performs:
- Transfers the **winning bid** to the owner.
- **Refunds** all losing bidders (minus a 2% fee).
- Emits events for transparency.

---

### `function getBiddersCount() external view returns (uint)`

Returns the total number of bids submitted.

---

### `function getBidder(uint index) external view returns (address, uint, uint)`

Returns the bidder’s:
- **Address**
- **Bid amount**
- **Timestamp**

---

### `receive()` and `fallback()`

Reject any ETH sent directly to the contract without using `bid()`.

---

## 🧪 Example Workflow

1. Alice deploys the contract.
2. Bob sends 2.1 ETH (invalid, must be ≥ 2.1).
3. Charlie bids 2.2 ETH.
4. Dave bids 2.31 ETH (valid, ≥ 5% over Charlie).
5. Auction nears end, Dave bids in last 10 mins → auction extends.
6. After end, Alice calls `finalize()`.
   - Alice receives the winning bid.
   - Charlie gets refund − 2% fee.

---

## ⚠️ Security Features

- ✅ Reentrancy guard on all ETH-moving functions.
- ✅ `onlyOwner` restriction on sensitive actions.
- ✅ Automatic refund tracking to avoid double payouts.
- ✅ ETH value and time validation for each bid.
- ✅ Fallback and receive blocks to prevent accidental fund loss.

---

## 📝 License

MIT License

---

## 🧑‍💻 Author

Developed by Ariel May.

