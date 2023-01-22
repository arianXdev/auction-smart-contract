// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;
/// @title Decentralized Auction
/// @author Arian Hosseini | https://github.com/aryanhosseini
/// @notice It is a simple Auction smart contract
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Auction2 is ReentrancyGuard {
    
    using SafeMath for uint256;

    address payable public auctioneer;
    address public highestBidder;
    uint256 public highestBid;
    uint256 public bidCounter;
    uint256 public auctionStartTime;
    uint256 public auctionEndTime;
    bool endStatus;

    struct Bids {
        address payable Bidder;
        uint256 OfferedAmount;
    }

    mapping(uint256 => Bids) public listOfBids;

    event Bid(
        uint256 bidId,
        uint256 offeredAmount,
        address bidder,
        uint256 time
    );
    event AuctionEnded(
        uint256 auctionStartTime,
        uint256 auctionEndTime,
        uint256 currentTime,
        uint256 highestBid,
        address winner
    );
    event WithdrawBid(
        uint256 offeredAmount,
        address bidder,
        uint256 time,
        uint256 previousBid,
        address previousBidder
    );
    error BeyondYourBid(
        uint256 highestBid,
        uint256 offeredAmount,
        string reason
    );

    constructor(uint256 _biddingTime) {
        auctioneer = payable(msg.sender);
        highestBid = 0 ether;
        endStatus = false;
        bidCounter = 0;
        auctionStartTime = block.timestamp;
        auctionEndTime = auctionStartTime + _biddingTime;
    }

    function bid() external payable closeAfter(auctionEndTime) {
        uint256 offeredAmount = msg.value;

        if (offeredAmount <= highestBid && msg.sender != highestBidder) {
            revert BeyondYourBid({
                highestBid: highestBid,
                offeredAmount: offeredAmount,
                reason: "Sorry, Unfortuantely, There is an offered amount greater than or equal to your offered bid! You can check the highest bid."
            });
        }

        highestBidder = msg.sender;
        highestBid = offeredAmount;

        bidCounter++;
        listOfBids[bidCounter] = Bids(payable(highestBidder), highestBid);

        emit Bid(bidCounter, highestBid, highestBidder, block.timestamp);

        // Checks if the highest bid is greater than the offered amount of the previous bidder, 
        // then refunds the amount of the previous bidder
        if (highestBid > listOfBids[bidCounter - 1].OfferedAmount) {
            listOfBids[bidCounter - 1].Bidder.transfer(
                listOfBids[bidCounter - 1].OfferedAmount
            );
        }
    }

    // Refunds the offered amount of the last bidder
    function withdraw() external nonReentrant {
        require(
            msg.sender == listOfBids[bidCounter].Bidder,
            "You received your bid amount already or was not the bidder!"
        );
        payable(listOfBids[bidCounter].Bidder).transfer(
            listOfBids[bidCounter].OfferedAmount
        );

        emit WithdrawBid(
            listOfBids[bidCounter].OfferedAmount,
            listOfBids[bidCounter].Bidder,
            block.timestamp,
            listOfBids[bidCounter - 1].OfferedAmount,
            listOfBids[bidCounter - 1].Bidder
        );

        delete listOfBids[bidCounter];
        delete highestBidder;
        delete highestBid;
        bidCounter--;
    }

    // Closes the auction after a specific time
    function finish() external onlyAuctioneer {
        require(
            block.timestamp >= auctionEndTime,
            "The Auction hasn't ended yet!"
        );

        endStatus = true;
        auctioneer.transfer(highestBid);

        emit AuctionEnded(
            auctionStartTime,
            auctionEndTime,
            block.timestamp,
            highestBid,
            highestBidder
        );
    }

    modifier onlyAuctioneer() {
        require(msg.sender == auctioneer, "You aren't the auctioneer!");
        _;
    }
    modifier closeAfter(uint256 _time) {
        require(block.timestamp <= _time, "The Auction has ended! Try later!");
        _;
    }
}
