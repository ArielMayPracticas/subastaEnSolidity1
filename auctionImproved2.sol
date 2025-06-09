// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title TimedAuction
/// @notice Implements a 7-day auction with minimum bid increments, delayed and automatic refunds (minus fees), and time extension on last-minute bids
/// @dev Handles secure bidding, automatic ETH refunds, and auction finalization with built-in protection against reentrancy

contract TimedAuction {
    // ====== Auction Parameters ======
    address public owner;
    address public highestBidder;
    uint public highestBid;
    uint public endTime;
    bool public finalized;

    // ====== Constants ======
    uint public constant STARTING_BID = 2 ether;
    uint public constant BID_INCREMENT_PERCENT = 5;
    uint public constant REFUND_FEE_PERCENT = 2;
    uint public constant DURATION = 7 days;
    uint public constant EXTENSION_TIME = 10 minutes;
    uint public constant EXTENSION_THRESHOLD = 10 minutes;

    // ====== Bidder Struct and Storage ======
    struct Bidder {
        address bidder;
        uint amount;
        uint timestamp;
    }

    Bidder[] public bidders; // All bid records
    mapping(address => uint) public userBids; // Tracks active bids
    mapping(address => bool) public refunded; // Prevents double refunding

    // ====== Reentrancy Guard ======
    uint private unlocked = 1;
    modifier nonReentrant() {
        require(unlocked == 1, "ReentrancyGuard: reentrant call");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    /// @dev Restricts function to the auction creator
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call");
        _;
    }

    // ====== Events ======
    event BidPlaced(address indexed bidder, uint amount, uint timestamp);
    event Refunded(address indexed bidder, uint amount);
    event Finalized(address indexed winner, uint amount, uint timestamp);

    /// @notice Deploys the auction and sets owner and initial parameters
    constructor() {
        owner = msg.sender;
        highestBid = STARTING_BID;
        endTime = block.timestamp + DURATION;
    }

    /// @notice Allows users to place bids; if previous bidder, overwrites their bid
    /// @dev Minimum new bid must be 5% higher than current highest; automatically extends auction if within last 10 minutes
    function bid() external payable nonReentrant {
        require(block.timestamp < endTime, "Auction ended");
        uint minRequired = highestBid + (highestBid * BID_INCREMENT_PERCENT / 100);
        require(msg.value >= minRequired, "Bid too low");

        // Save new bid and update top bidder
        userBids[msg.sender] = msg.value;
        highestBidder = msg.sender;
        highestBid = msg.value;

        bidders.push(Bidder({
            bidder: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        }));

        emit BidPlaced(msg.sender, msg.value, block.timestamp);

        // Optional: extend if close to end
        if (endTime - block.timestamp <= EXTENSION_THRESHOLD) {
            endTime += EXTENSION_TIME;
        }
    }

    /// @notice Finalizes the auction by transferring winning funds to the owner and refunding all losing bidders (minus 2%)
    /// @dev Only the contract owner can call after auction end
    function finalize() external onlyOwner nonReentrant {
        require(block.timestamp >= endTime, "Auction not ended yet");
        require(!finalized, "Already finalized");
        finalized = true;

        // Transfer winning bid to auction owner
        (bool sentOwner, ) = payable(owner).call{value: highestBid}("");
        require(sentOwner, "Transfer to owner failed");
        emit Finalized(highestBidder, highestBid, block.timestamp);

        // Refund all losing bidders (minus fee)
        for (uint i = 0; i < bidders.length; i++) {
            address bidder = bidders[i].bidder;

            if (bidder != highestBidder && !refunded[bidder]) {
                uint amount = userBids[bidder];
                if (amount > 0) {
                    uint refund = amount - (amount * REFUND_FEE_PERCENT / 100);
                    refunded[bidder] = true;

                    (bool sent, ) = payable(bidder).call{value: refund}("");
                    if (sent) {
                        emit Refunded(bidder, refund);
                    }
                }
            }
        }
    }

    /// @notice Returns the number of bids placed
    /// @return Total number of bids (including from same address multiple times)
    function getBiddersCount() external view returns (uint) {
        return bidders.length;
    }

    /// @notice Retrieves a bidder's info by index
    /// @param index The index of the bid in the bidders list
    /// @return bidder address, amount offered, and timestamp of bid
    function getBidder(uint index) external view returns (address, uint, uint) {
        require(index < bidders.length, "Index out of range");
        Bidder memory b = bidders[index];
        return (b.bidder, b.amount, b.timestamp);
    }

    /// @dev Prevent direct ETH transfers to contract
    receive() external payable {
        revert("Use bid()");
    }

    /// @dev Fallback for other calls
    fallback() external payable {
        revert("Use bid()");
    }
}
