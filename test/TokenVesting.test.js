var EVMRevert = require('./helpers/EVMRevert');
var assertRevert = require('./helpers/assertRevert');
var latestTime = require('./helpers/latestTime');
var increaseTimeTo = require('./helpers/increaseTime');

const BigNumber = web3.BigNumber

const duration = {
  seconds: function (val) { return val; },
  minutes: function (val) { return val * this.seconds(60); },
  hours: function (val) { return val * this.minutes(60); },
  days: function (val) { return val * this.hours(24); },
  weeks: function (val) { return val * this.days(7); },
  years: function (val) { return val * this.days(365); },
};

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should();

const Token = artifacts.require('Token');
const TokenVesting = artifacts.require('TokenVesting');

contract('TokenVesting', function ([owner, beneficiary]) {
  const amount = new BigNumber(1000);
  const totalSupply = new BigNumber(1000);
  const decimals = new BigNumber(18);
  const name = "IronX";
  const symbol = "IRX";

  beforeEach(async function () {
  
    this.start = latestTime() + duration.minutes(1); // +1 minute so it starts after contract instantiation
    this.duration = duration.seconds(566173295);

    this.token = await Token.new(totalSupply, decimals, name, symbol);
    this.vesting = await TokenVesting.new(beneficiary, this.start, true);

    await this.token.transfer(this.vesting.address, amount);
  });

  it('Can be released after cliff', async function () {
    await increaseTimeTo(this.start + this.duration + duration.weeks(1));
    await this.vesting.release(this.token.address).should.be.fulfilled;
  });

  it('Should release proper amount after duration', async function () {
    await increaseTimeTo(this.start + this.duration);

    const { receipt } = await this.vesting.release(this.token.address);
    const releaseTime = web3.eth.getBlock(receipt.blockNumber).timestamp;

    const balance = await this.token.balanceOf(beneficiary);
    balance.should.bignumber.equal(amount);
  });

  it('Should linearly release tokens during vesting period', async function () {
    const vestingPeriod = this.duration;

    await increaseTimeTo(duration.weeks(16));

    await this.vesting.release(this.token.address);
    let balance = await this.token.balanceOf(beneficiary);
    let expectedVesting = amount.div(3).floor();

    balance.should.bignumber.equal(expectedVesting);

    await increaseTimeTo(duration.weeks(16));

    await this.vesting.release(this.token.address);
    balance = await this.token.balanceOf(beneficiary);
    expectedVesting = amount.div(3).mul(2).floor();

    balance.should.bignumber.equal(expectedVesting);

    await increaseTimeTo(duration.weeks(16));

    await this.vesting.release(this.token.address);
    balance = await this.token.balanceOf(beneficiary);
    expectedVesting = amount.floor();

    balance.should.bignumber.equal(expectedVesting);
  });

  it('Should have released all after end', async function () {
    await increaseTimeTo(this.start + this.duration);
    await this.vesting.release(this.token.address);
    const balance = await this.token.balanceOf(beneficiary);
    balance.should.bignumber.equal(amount);
  });

  it('Should be revoked by owner if revocable is set', async function () {
    await this.vesting.revoke(this.token.address, { from: owner }).should.be.fulfilled;
  });

  it('Should fail to be revoked by owner if revocable not set', async function () {
    const vesting = await TokenVesting.new(beneficiary, this.start, false, { from: owner });
    await vesting.revoke(this.token.address, { from: owner }).should.be.rejectedWith(EVMRevert);
  });

  it('Should return the non-vested tokens when revoked by owner', async function () {
    await increaseTimeTo(this.start + duration.weeks(12));

    const vested = await this.vesting.vestedAmount(this.token.address);

    await this.vesting.revoke(this.token.address, { from: owner });

    const ownerBalance = await this.token.balanceOf(owner);
    ownerBalance.should.bignumber.equal(amount.sub(vested));
  });

  it('Should keep the vested tokens when revoked by owner', async function () {
    await increaseTimeTo(this.start + duration.weeks(12));

    const vestedPre = await this.vesting.vestedAmount(this.token.address);

    await this.vesting.revoke(this.token.address, { from: owner });

    const vestedPost = await this.vesting.vestedAmount(this.token.address);

    vestedPre.should.bignumber.equal(vestedPost);
  });

  it('Should fail to be revoked a second time', async function () {
    await increaseTimeTo(this.start + duration.weeks(12));

    await this.vesting.vestedAmount(this.token.address);

    await this.vesting.revoke(this.token.address, { from: owner });

    await this.vesting.revoke(this.token.address, { from: owner }).should.be.rejectedWith(EVMRevert);
  });
});