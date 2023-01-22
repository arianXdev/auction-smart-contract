import { time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, web3 } from "hardhat";
import { Auction2 } from "../typechain-types";

let contract: Auction2;
let addressOwner: any;
let addressOne: any;
let addressTwo: any;
let biddingTime: any;

describe("Auction2", () => {
  beforeEach(async () => {
    const [owner, one, two] = await ethers.getSigners();
    addressOwner = owner;
    addressOne = one;
    addressTwo = two;

    const ONE_MIN = 60;
    biddingTime = (await time.latest()) + ONE_MIN;
    const Auction2 = await ethers.getContractFactory("Auction2");
    contract = await Auction2.connect(addressOwner).deploy(biddingTime);
    await contract.deployed();
  });

  it("is contract deployed", async () => {
    expect(contract.address);
  });

  it("should set the auctioneer as the msg.sender", async function () {
    const auctioneerAddress = await contract.auctioneer();
    expect(auctioneerAddress).to.equal(addressOwner.address);
  });

  it("should throw an error if a non-auctioneer tries to end the auction", async () => {
    await expect(contract.connect(addressOne).finish()).to.be.revertedWith(
      "You aren't the auctioneer!"
    );
  });

  it("bid should throw custom error if msg.value <= highestBid", async () => {
    await contract.bid({ value: web3.utils.toWei("1", "ether") });
    await expect(
      contract
        .connect(addressTwo)
        .bid({ value: web3.utils.toWei("1", "ether") })
    ).to.be.revertedWithCustomError(contract, "BeyondYourBid");
  });

  it("bid should be able to bid if msg.value > highestBid", async () => {
    await contract
      .connect(addressOne)
      .bid({ value: web3.utils.toWei("1", "ether") });

    await contract
      .connect(addressTwo)
      .bid({ value: web3.utils.toWei("2", "ether") });
  });

  it("bid should throw error if block.timestamp >= auctionEndTime", async () => {
    const Auction3 = await ethers.getContractFactory("Auction2");
    contract = await Auction3.connect(addressOwner).deploy(0);
    await contract.deployed();

    await expect(
      contract
        .connect(addressOne)
        .bid({ value: web3.utils.toWei("1", "ether") })
    ).to.be.revertedWith("The Auction has ended! Try later!");
  });

  it("should withdraw bid", async () => {
    await contract.bid({ value: web3.utils.toWei("1", "ether") });
    const balanceAfterBid = await ethers.provider.getBalance(
      addressOwner.address
    );

    const tx = await contract.withdraw();
    const txe = await tx.wait();
    txe.events?.filter((x) => {
      expect(x.event).to.equal("WithdrawBid");
    });

    const balanceAfterWithdraw = await ethers.provider.getBalance(
      addressOwner.address
    );
    expect(balanceAfterWithdraw).to.be.greaterThan(balanceAfterBid);

    const bid = await contract.listOfBids(1);
    expect(bid.OfferedAmount.toString()).to.equal("0");
  });

  it("withdraw should revert with error", async () => {
    await contract
      .connect(addressTwo)
      .bid({ value: web3.utils.toWei("1", "ether") });
    await expect(contract.connect(addressOne).withdraw()).to.be.revertedWith(
      "You received your bid amount already or was not the bidder!"
    );
  });
});
