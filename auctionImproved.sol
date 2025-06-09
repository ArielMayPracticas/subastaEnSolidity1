// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TimedAuction {
    address public owner;
    address public highestBidder;
    uint public highestBid;
    uint public endTime;
    bool public finalized;

    uint public constant STARTING_BID = 2 ether;
    uint public constant BID_INCREMENT_PERCENT = 5;
    uint public constant REFUND_FEE_PERCENT = 2;
    uint public constant DURATION = 7 days;
    uint public constant EXTENSION_TIME = 10 minutes;
    uint public constant EXTENSION_THRESHOLD = 10 minutes;

    struct Bidder {
        address bidder;
        uint amount;
        uint timestamp;
    }

    Bidder[] public bidders;

    // Reentrancy guard
    uint private unlocked = 1;
    modifier nonReentrant() {
        require(unlocked == 1, "ReentrancyGuard: reentrant call");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call");
        _;
    }

    event BidPlaced(address indexed bidder, uint amount, uint timestamp);
    event Refunded(address indexed bidder, uint amount);
    event Finalized(address indexed winner, uint amount, uint timestamp);

    constructor() {
        owner = msg.sender;
        highestBid = STARTING_BID;
        endTime = block.timestamp + DURATION;
    }

    function bid() external payable nonReentrant {
        require(block.timestamp < endTime, "Auction ended");
        require(
            msg.value >= highestBid + (highestBid * BID_INCREMENT_PERCENT / 100),
            "Bid must be at least 5% higher"
        );

        // Refund previous highest bidder minus 2% fee
        if (highestBidder != address(0)) {
            uint refundAmount = highestBid - (highestBid * REFUND_FEE_PERCENT / 100);
            (bool success, ) = payable(highestBidder).call{value: refundAmount}("");
            require(success, "Refund failed");
            emit Refunded(highestBidder, refundAmount);
        }

        // Update state
        highestBidder = msg.sender;
        highestBid = msg.value;
        bidders.push(Bidder({
            bidder: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        }));
        emit BidPlaced(msg.sender, msg.value, block.timestamp);

        // Extend auction if bid is placed in last 10 minutes
        if (endTime - block.timestamp <= EXTENSION_THRESHOLD) {
            endTime += EXTENSION_TIME;
        }
    }

    function finalize() external nonReentrant onlyOwner {
        require(block.timestamp >= endTime, "Auction not ended yet");
        require(!finalized, "Already finalized");
        finalized = true;

        uint payout = address(this).balance;
        (bool success, ) = payable(owner).call{value: payout}("");
        require(success, "Transfer to owner failed");

        emit Finalized(highestBidder, highestBid, block.timestamp);
    }

    // Fallback: Prevent accidental ETH transfer
    receive() external payable {
        revert("Use bid() function");
    }

    fallback() external payable {
        revert("Use bid() function");
    }

    // Public view functions
    function getBiddersCount() external view returns (uint) {
        return bidders.length;
    }

    function getBidder(uint index) external view returns (address, uint, uint) {
        require(index < bidders.length, "Index out of range");
        Bidder memory b = bidders[index];
        return (b.bidder, b.amount, b.timestamp);
    }
}
