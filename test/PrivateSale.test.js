import ether from './helpers/ether';
import { advanceBlock } from './helpers/advanceToBlock';
import { increaseTimeTo, duration } from './helpers/increaseTime';
import latestTime from './helpers/latestTime';
import EVMRevert from './helpers/EVMRevert';
import assertRevert from './helpers/assertRevert';

const BigNumber = web3.BigNumber;

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should();

const PrivateSale = artifacts.require('PrivateSale');
const Token = artifacts.require('Token');

contract('PrivateSale', function ([owner, wallet, investor, otherInvestor]) {
  const totalSupply = new BigNumber(50000000000000000000000);
  const decimals = new BigNumber(18);
  const name = "IronX";
  const symbol = "IRX";
  const smallestSum = 971911700000000000;
  const smallerSum = 291573500000000000000;
  const mediumSum = 485955800000000000000;
  const biggerSum = 971911700000000000000;
  const biggestSum = 1943823500000000000000;
  const rate = new BigNumber(33);
  const softCap = ether(20);
  const hardCap = ether(50);
  

  before(async function () {
    // Advance to the next block to correctly read time in the solidity "now" function interpreted by testrpc
    await advanceBlock();
  });


  beforeEach(async function () {
    this.startTime = latestTime() + duration.weeks(1);
    this.endTime = this.startTime + duration.weeks(1);
    this.afterEndTime = this.endTime + duration.seconds(1);

    this.token = await Token.new(totalSupply, decimals, name, symbol, { from: owner });
    this.privateSale = await PrivateSale.new(rate, wallet, this.token.address, softCap, hardCap, this.startTime, this.endTime, smallestSum, smallerSum, mediumSum, biggerSum, biggestSum);

    await this.token.transferOwnership(this.privateSale.address);
    await this.token.transfer(this.privateSale.address, totalSupply);
  });


  it('Should create token & privateSale with correct parameters', async function () {
    this.token.should.exist;
    this.privateSale.should.exist;
    
    const totalSupply_ = await this.token.totalSupply();
    const decimals_ = await this.token.decimals();
    const name_ = await this.token.name();
    const symbol_ = await this.token.symbol();

    const rate_ = await this.privateSale.rate();
    const wallet_ = await this.privateSale.wallet();
    const token_ = await this.privateSale.token();
    const softCap_ = await this.privateSale.softCap();
    const hardCap_ = await this.privateSale.hardCap();
    const startTime_ = await this.privateSale.startTime();
    const endTime_ = await this.privateSale.endTime();

    totalSupply_.should.be.bignumber.equal(totalSupply);
    decimals_.should.be.bignumber.equal(decimals);
    name_.should.be.equal(name);
    symbol_.should.be.equal(symbol);

    rate_.should.be.bignumber.equal(rate);
    wallet_.should.be.bignumber.equal(wallet);
    token_.should.be.equal(this.token.address);
    softCap_.should.be.bignumber.equal(softCap);
    hardCap_.should.be.bignumber.equal(hardCap);
    startTime_.should.be.bignumber.equal(this.startTime);
    endTime_.should.be.bignumber.equal(this.endTime);
  });


  it('Should not accept payments before start', async function () {
    const investmentAmount = ether(1);
    await this.privateSale.send(investmentAmount).should.be.rejectedWith(EVMRevert);
    await this.privateSale.buyTokens(investor, {value: investmentAmount, from: investor}).should.be.rejectedWith(EVMRevert);
  });


  it('Should reject payments after end', async function () {
    const investmentAmount = ether(1);
    await increaseTimeTo(this.afterEndTime);
    await this.privateSale.send(investmentAmount).should.be.rejectedWith(EVMRevert);
    await this.privateSale.buyTokens(investor, {value: investmentAmount, from: investor}).should.be.rejectedWith(EVMRevert);
  });


  it('Should reject payments if contribution is < $50k', async function () {
    const investmentAmount = ether(0.1);
    await increaseTimeTo(this.startTime);
    await this.privateSale.send(investmentAmount).should.be.rejectedWith(EVMRevert);
    await this.privateSale.buyTokens(investor, {value: investmentAmount, from: investor}).should.be.rejectedWith(EVMRevert);
  });


  it('should only allow whitelisted users to participate', async function () {
    const investmentAmount = ether(10);
    await increaseTimeTo(this.startTime);
    await this.privateSale.addAddressToWhitelist(investor, { from: owner });
    await this.privateSale.buyTokens(investor, {value: investmentAmount, from: investor}).should.be.fulfilled;
    await this.privateSale.buyTokens(otherInvestor, { value: investmentAmount, from: otherInvestor }).should.be.rejectedWith(EVMRevert);
  });


  it('Should accept payments during the sale', async function () {
    const investmentAmount = ether(10);
    await increaseTimeTo(this.startTime);
    const privateSaleBalance = await this.token.balanceOf(this.privateSale.address);
    privateSaleBalance.should.be.bignumber.equal(totalSupply);
    await this.privateSale.addAddressToWhitelist(investor, { from: owner });
    await this.privateSale.buyTokens(investor, {value: investmentAmount, from: investor}).should.be.fulfilled;

    const tokenVesting = await this.privateSale.vesting.call(investor);
    const tokenVestingBalance = await this.token.balanceOf(tokenVesting);
    tokenVestingBalance.should.be.bignumber.equal(new BigNumber(10500000000000000000));
  });


  it('should reject payments over cap', async function () {
    const investmentAmount = ether(50);
    await increaseTimeTo(this.startTime);
    investmentAmount.should.be.bignumber.equal(hardCap);
    await this.privateSale.addAddressToWhitelist(investor, {from: owner});
    await this.privateSale.buyTokens(investor, {value: investmentAmount, from: investor}).should.be.fulfilled;
    await this.privateSale.send(1).should.be.rejectedWith(EVMRevert);
  });
});