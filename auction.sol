// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title Auction
 * @dev A smart contract for running an auction with the following rules:
 * - Starts at 2 ETH
 * - Each new bid must be at least 5% higher than the current highest
 * - Initial duration is 2 days
 * - If someone bids during the last 10 minutes, the auction is extended by 10 more minutes
 * - Losing bids are refunded, minus a 2% fee that goes to the auction owner
 */
contract Auction is ReentrancyGuard {
    /// @notice Address of the auction creator
    address public owner;

    /// @notice Start and end times of the auction
    uint256 public startTime;
    uint256 public endTime;

    /// @notice Duration and time extension constants
    uint256 public constant AUCTION_DURATION = 2 days;
    uint256 public constant TIME_EXTENSION = 10 minutes;

    /// @notice Minimum starting bid (2 ETH)
    uint256 public constant MIN_BID = 2 ether;

    /// @notice Current highest bidder and bid
    address public highestBidder;
    uint256 public highestBid;

    /// @notice Track refundable bids for participants
    mapping(address => uint256) public pendingReturns;

    /// @notice Tracks whether a participant has already withdrawn
    mapping(address => bool) public hasWithdrawn;

    /// @notice Total fees collected (2% from each losing bid)
    uint256 public totalFees;

    /// @notice Indicates whether the auction has been finalized
    bool public finalized;

    /// @notice Emitted whenever a new bid is placed
    event BidPlaced(address indexed bidder, uint256 amount, uint256 newEndTime);

    /// @notice Emitted when a user withdraws their funds
    event FundsWithdrawn(address indexed participant, uint256 refundedAmount, uint256 feeTaken);

    /// @notice Emitted when the auction owner withdraws the accumulated fees
    event FeesWithdrawn(address indexed owner, uint256 amount);

    /// @notice Emitted when the auction is finalized
    event AuctionFinalized(address winner, uint256 finalBid);

    /// @dev Initializes the auction and sets the start and end time
    constructor() {
        owner = msg.sender;
        startTime = block.timestamp;
        endTime = startTime + AUCTION_DURATION;
        highestBid = MIN_BID;
    }

    /// @dev Modifier to allow function calls only before the auction ends
    modifier onlyBeforeEnd() {
        require(block.timestamp < endTime, "Auction has ended");
        _;
    }

    /// @dev Modifier to allow function calls only after the auction ends
    modifier onlyAfterEnd() {
        require(block.timestamp >= endTime, "Auction is still ongoing");
        _;
    }

    /**
     * @notice Submit a new bid
     * @dev The new bid must be at least 5% higher than the current highest bid
     */
    function bid() external payable onlyBeforeEnd nonReentrant {
        require(msg.sender != owner, "Owner cannot bid");
        require(msg.value >= highestBid + (highestBid * 5) / 100, "Bid must be at least 5% higher");

        if (highestBidder != address(0)) {
            // Store previous highest bidder's amount for later withdrawal (minus 2% fee)
            pendingReturns[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;

        // Extend auction if the bid is placed within the last 10 minutes
        if (endTime - block.timestamp <= 10 minutes) {
            endTime = block.timestamp + TIME_EXTENSION;
        }

        emit BidPlaced(msg.sender, msg.value, endTime);
    }

    /**
     * @notice Withdraw funds if your bid was not the highest
     * @dev A 2% fee is deducted and kept for the auction owner
     */
    function withdraw() external onlyAfterEnd nonReentrant {
        require(msg.sender != highestBidder, "Winner cannot withdraw");
        require(!hasWithdrawn[msg.sender], "Already withdrawn");

        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "Nothing to withdraw");

        hasWithdrawn[msg.sender] = true;

        uint256 fee = (amount * 2) / 100;
        uint256 refund = amount - fee;
        totalFees += fee;

        pendingReturns[msg.sender] = 0;
        payable(msg.sender).transfer(refund);

        emit FundsWithdrawn(msg.sender, refund, fee);
    }

    /**
     * @notice Allows the auction owner to withdraw the total collected fees
     */
    function withdrawFees() external onlyAfterEnd nonReentrant {
        require(msg.sender == owner, "Only the owner can withdraw fees");
        require(totalFees > 0, "No fees to withdraw");

        uint256 amount = totalFees;
        totalFees = 0;

        payable(owner).transfer(amount);
        emit FeesWithdrawn(owner, amount);
    }

    /**
     * @notice Finalizes the auction and emits the winner
     */
    function finalize() external onlyAfterEnd {
        require(!finalized, "Auction already finalized");
        finalized = true;

        emit AuctionFinalized(highestBidder, highestBid);
    }

    /**
     * @notice Returns the number of seconds left in the auction
     */
    function timeRemaining() external view returns (uint256) {
        if (block.timestamp >= endTime) return 0;
        return endTime - block.timestamp;
    }
}
