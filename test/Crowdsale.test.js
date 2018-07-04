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

const Crowdsale = artifacts.require('Crowdsale');
const Token = artifacts.require('Token');

contract('Crowdsale', function ([owner, wallet, investor, otherInvestor]) {
  const totalSupply = new BigNumber(50000000000000000000000);
  const decimals = new BigNumber(18);
  const name = "IronX";
  const symbol = "IRX";

  const rate = new BigNumber(33);

  const softCap = ether(200);
  const hardCap = ether(40000);
  

  before(async function () {
    // Advance to the next block to correctly read time in the solidity "now" function interpreted by testrpc
    await advanceBlock();
  });

  beforeEach(async function () {
    this.startTime = latestTime() + duration.weeks(1);
    this.endTime = this.startTime + duration.weeks(1);
    this.afterEndTime = this.endTime + duration.seconds(1);

    this.token = await Token.new(totalSupply, decimals, name, symbol, { from: owner });
    this.crowdsale = await Crowdsale.new(rate, wallet, this.token.address, softCap, hardCap, this.startTime, this.endTime);

    await this.token.transferOwnership(this.crowdsale.address);
  });

  it('Should create token & crowdsale with correct parameters', async function () {
    this.token.should.exist;
    this.crowdsale.should.exist;
    
    const totalSupply_ = await this.token.totalSupply();
    const decimals_ = await this.token.decimals();
    const name_ = await this.token.name();
    const symbol_ = await this.token.symbol();

    const rate_ = await this.crowdsale.rate();
    const wallet_ = await this.crowdsale.wallet();
    const token_ = await this.crowdsale.token();
    const softCap_ = await this.crowdsale.softCap();
    const hardCap_ = await this.crowdsale.hardCap();
    const startTime_ = await this.crowdsale.startTime();
    const endTime_ = await this.crowdsale.endTime();

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
    await this.crowdsale.send(investmentAmount).should.be.rejectedWith(EVMRevert);
    await this.crowdsale.buyTokens(investor, {value: investmentAmount, from: investor}).should.be.rejectedWith(EVMRevert);
  });

  it('Should reject payments after end', async function () {
    const investmentAmount = ether(1);
    await increaseTimeTo(this.afterEndTime);
    await this.crowdsale.send(investmentAmount).should.be.rejectedWith(EVMRevert);
    await this.crowdsale.buyTokens(investor, {value: investmentAmount, from: investor}).should.be.rejectedWith(EVMRevert);
  });

  it('Should reject payments if contribution is < $50k', async function () {
    const investmentAmount = ether(0.1);
    await increaseTimeTo(this.startTime);
    await this.crowdsale.send(investmentAmount).should.be.rejectedWith(EVMRevert);
    await this.crowdsale.buyTokens(investor, {value: investmentAmount, from: investor}).should.be.rejectedWith(EVMRevert);
  });

  // it('Should accept payments during the sale', async function () {
  //   const investmentAmount = ether(10);
  //   const expectedTokenAmount = rate.mul(investmentAmount);

  //   await increaseTimeTo(this.startTime);
  //   await this.crowdsale.buyTokens(investor, {value: investmentAmount, from: investor}).should.be.fulfilled;

  //   (await this.token.balanceOf(investor)).should.be.bignumber.equal(expectedTokenAmount);
  //   (await this.token.totalSupply()).should.be.bignumber.equal(expectedTokenAmount);
  // });

  it('should reject payments over cap', async function () {
    const investmentAmount = ether(10);
    await increaseTimeTo(this.openingTime);
    await this.crowdsale.send(hardCap);
    await this.crowdsale.send(investmentAmount).should.be.rejectedWith(EVMRevert);
  });
  // it('should reject payments over cap', async function () {
  //   await increaseTimeTo(this.startTime);
  //   await this.crowdsale.send(CAP);
  //   await this.crowdsale.send(1).should.be.rejectedWith(EVMRevert);
  // });

  // it.skip('should grant an extra 10% tokens as bonus for contributions over 5 ETH', async function () {
  //   const investmentAmount = ether(1);
  //   const largeInvestmentAmount = ether(10);
  //   const expectedTokenAmount = rate.mul(investmentAmount);
  //   const expectedLargeTokenAmount = rate.mul(largeInvestmentAmount).mul(1.1);

  //   await increaseTimeTo(this.startTime);
  //   await this.crowdsale.buyTokens(investor, { value: investmentAmount, from: investor }).should.be.fulfilled;
  //   await this.crowdsale.buyTokens(otherInvestor, { value: largeInvestmentAmount, from: otherInvestor }).should.be.fulfilled;

  //   (await this.token.balanceOf(investor)).should.be.bignumber.equal(expectedTokenAmount);
  //   (await this.token.balanceOf(otherInvestor)).should.be.bignumber.equal(expectedLargeTokenAmount);
  //   (await this.token.totalSupply()).should.be.bignumber.equal(expectedTokenAmount.add(expectedLargeTokenAmount));
  // });

  // it.skip('should mint 20% of total emitted tokens for the owner wallet upon finish', async function () {
  //   const totalInvestmentAmount = ether(10);

  //   await increaseTimeTo(this.startTime);
  //   await this.crowdsale.buyTokens(investor, { value: totalInvestmentAmount, from: investor });
  //   await increaseTimeTo(this.endTime + 1);
  //   const totalTokenAmount = await this.token.totalSupply();

  //   await this.crowdsale.finalize();
  //   (await this.token.balanceOf(wallet)).should.be.bignumber.equal(totalTokenAmount * 0.2);
  // });

  // it.skip('should only allow whitelisted users to participate', async function () {
  //   const investmentAmount = ether(1);
  //   const expectedTokenAmount = rate.mul(investmentAmount);

  //   // Requires implementing a whitelist(address) public function in the MyCrowdsale contract
  //   await this.crowdsale.whitelist(investor, { from: owner });
  //   await increaseTimeTo(this.startTime);

  //   await this.crowdsale.buyTokens(otherInvestor, { value: ether(1), from: otherInvestor }).should.be.rejectedWith(EVMRevert);
  //   await this.crowdsale.buyTokens(investor, { value: ether(1), from: investor }).should.be.fulfilled;

  //   const investorBalance = await this.token.balanceOf(investor);
  //   investorBalance.should.be.bignumber.equal(expectedTokenAmount);
  // });

  // it.skip('should only allow the owner to whitelist an investor', async function () {
  //   // Check out the Ownable.sol contract to see if there is a modifier that could help here
  //   await this.crowdsale.whitelist(investor, { from: investor }).should.be.rejectedWith(EVMRevert);
  // })

});