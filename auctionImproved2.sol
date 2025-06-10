// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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

    Bidder[] public bidders;
    mapping(address => uint) public userBids;
    mapping(address => bool) public refunded;

    // ====== Reentrancy Guard ======
    uint private unlocked = 1;
    modifier nonReentrant() {
        require(unlocked == 1, "Reent");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Owner");
        _;
    }

    // ====== Events ======
    event BidPlaced(address indexed bidder, uint amount, uint timestamp);
    event Refunded(address indexed bidder, uint amount);
    event Finalized(address indexed winner, uint amount, uint timestamp);

    constructor() {
        owner = msg.sender;
        highestBid = STARTING_BID;
        endTime = block.timestamp + DURATION;
    }

    function bid() external payable nonReentrant {
        require(block.timestamp < endTime, "Ended");

        uint minRequired = highestBid + (highestBid * BID_INCREMENT_PERCENT / 100);
        require(msg.value >= minRequired, "Low");

        userBids[msg.sender] = msg.value;
        highestBidder = msg.sender;
        highestBid = msg.value;

        bidders.push(Bidder({
            bidder: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        }));

        emit BidPlaced(msg.sender, msg.value, block.timestamp);

        if (endTime - block.timestamp <= EXTENSION_THRESHOLD) {
            endTime += EXTENSION_TIME;
        }
    }

    function finalize() external onlyOwner nonReentrant {
        require(block.timestamp >= endTime, "Active");
        require(!finalized, "Done");

        finalized = true;

        (bool sentOwner, ) = payable(owner).call{value: highestBid}("");
        require(sentOwner, "SendFail");
        emit Finalized(highestBidder, highestBid, block.timestamp);

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

    function getBiddersCount() external view returns (uint) {
        return bidders.length;
    }

    function getBidder(uint index) external view returns (address, uint, uint) {
        require(index < bidders.length, "OOR"); // Out of range
        Bidder memory b = bidders[index];
        return (b.bidder, b.amount, b.timestamp);
    }

    receive() external payable {
        revert("bid()");
    }

    fallback() external payable {
        revert("bid()");
    }
}
