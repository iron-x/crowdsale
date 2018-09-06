var increaseTimeTo = require('./helpers/increaseTime');
var latestTime = require('./helpers/latestTime');
var advanceBlock = require('./helpers/advanceToBlock');
const BigNumber = web3.BigNumber;

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

const assertRevert = async promise => {
  try {
    await promise;
    throw new Error('should have thrown')
  } catch (error) {
    const revertFound = error.message.search('revert') >= 0;
    assert(revertFound, `Expected "revert", got ${error} instead`);
  }
};  

const Token = artifacts.require('Token');
const Allocation = artifacts.require('Allocation');

contract('Allocation', accounts => {
  let creator = accounts[0];
  let wallet = accounts[1];
  let outsider = accounts[2];

  const totalSupply = 100000000000000000000000000000000000;
  const decimals = 18;
  const name = "IronX";
  const symbol = "IRX";

  let token;
  let allocation;
  let rate = 1000;
  let softCap = 100000000000000000000;
  let hardCap = 100000000000000000000000000000000000;
  let weiAmount = 1000000;
  let smallest_sum = 1000;
  let smaller_sum = 100000;
  let medium_sum = 1000000;
  let bigger_sum = 1000000000;
  let biggest_sum = 1000000000000;
  const PERIOD_1Y = 31556926; 
  const PERIOD_9M = 23667695;

  beforeEach(async function () {
    token = await Token.new(totalSupply, decimals, name, symbol);
    allocation = await Allocation.new(rate, wallet, token.address, softCap, hardCap, smallest_sum, smaller_sum, medium_sum, bigger_sum, biggest_sum);
    await token.transfer(allocation.address, totalSupply);
  });

  describe('addOwner', async function() {
    it('should not be able to add new owner due to call not by owner', async function() {
       await allocation.addOwner(wallet, {from: outsider}).should.be.rejectedWith("revert");
    });

    it('should succesfuly add new owner', async function() {
       await allocation.addOwner(wallet);
       assert.equal(await allocation.isOwner(wallet), true);
    });
  });

  describe('deleteOwner', async function() {
    it('should not be able to delete owner due to call not by owner', async function() {
      await allocation.addOwner(wallet);
      await allocation.deleteOwner(wallet, {from: outsider}).should.be.rejectedWith("revert");
    });

    it('should succesfuly delete owner', async function() {
      await allocation.addOwner(wallet);
      assert.equal(await allocation.isOwner(wallet), true);
      await allocation.deleteOwner(wallet);
      assert.equal(await allocation.isOwner(wallet), false);
    });
  });

  describe('allocateTokens', async function() {
    it('should not be able to allocate tokens due to call not by owner', async function() {
      await allocation.addAddressToWhitelist(wallet);
      await allocation.addAddressToWhitelist(outsider); 
      let tx = await allocation.buyTokens(wallet, {from: wallet, value: smaller_sum});
      let events = tx.logs.filter(l => l.event === 'TokenPurchase');
      assert.equal(events[0].args.purchaser, wallet);
      assert.equal(events[0].args.beneficiary, wallet);
      assert.equal(events[0].args.value, smaller_sum);
      assert.equal(events[0].args.amount, smaller_sum * rate);
      tx = await allocation.buyTokens(outsider, {from: outsider, value: smaller_sum});
      events = tx.logs.filter(l => l.event === 'TokenPurchase');
      assert.equal(events[0].args.purchaser, outsider);
      assert.equal(events[0].args.beneficiary, outsider);
      assert.equal(events[0].args.value, smaller_sum);
      assert.equal(events[0].args.amount, smaller_sum * rate);
      await allocation.allocateTokens({from: outsider}).should.be.rejectedWith("revert");
    });

    it('should succesfuly allocate tokens', async function() {
      await allocation.addAddressToWhitelist(wallet);
      await allocation.addAddressToWhitelist(outsider); 
      let tx = await allocation.buyTokens(wallet, {from: wallet, value: weiAmount});
      let events = tx.logs.filter(l => l.event === 'TokenPurchase');
      assert.equal(events[0].args.purchaser, wallet);
      assert.equal(events[0].args.beneficiary, wallet);
      assert.equal(events[0].args.value, weiAmount);
      assert.equal(events[0].args.amount, weiAmount * rate);
      tx = await allocation.buyTokens(outsider, {from: outsider, value: weiAmount});
      events = tx.logs.filter(l => l.event === 'TokenPurchase');
      assert.equal(events[0].args.purchaser, outsider);
      assert.equal(events[0].args.beneficiary, outsider);
      assert.equal(events[0].args.value, weiAmount);
      assert.equal(events[0].args.amount, weiAmount * rate);
      tx = await allocation.allocateTokens();
      events = tx.logs.filter(l => l.event === 'TimeVestingCreation');
      assert.equal(events[0].args.beneficiary, wallet);
      assert.equal(events[1].args.beneficiary, outsider);
    });
  });

  describe('allocateTokensForContributor', async function() {
    it('should not be able to allocate tokens for contibutor due to call not by owner', async function() {
      await allocation.addAddressToWhitelist(wallet);
      let tx = await allocation.buyTokens(wallet, {from: wallet, value: weiAmount});
      let events = tx.logs.filter(l => l.event === 'TokenPurchase');
      assert.equal(events[0].args.purchaser, wallet);
      assert.equal(events[0].args.beneficiary, wallet);
      assert.equal(events[0].args.value, weiAmount);
      assert.equal(events[0].args.amount, weiAmount * rate);
      tx = await allocation.allocateTokensForContributor(wallet, {from: outsider}).should.be.rejectedWith("revert");
    });

    it('should succesfuly allocate tokens for contibutor', async function() {
      await allocation.addAddressToWhitelist(wallet);
      let tx = await allocation.buyTokens(wallet, {from: wallet, value: weiAmount});
      let events = tx.logs.filter(l => l.event === 'TokenPurchase');
      assert.equal(events[0].args.purchaser, wallet);
      assert.equal(events[0].args.beneficiary, wallet);
      assert.equal(events[0].args.value, weiAmount);
      assert.equal(events[0].args.amount, weiAmount * rate);
      tx = await allocation.allocateTokensForContributor(wallet);
      events = tx.logs.filter(l => l.event === 'TimeVestingCreation');
      assert.equal(events[0].args.beneficiary, wallet);
    });
  });

  describe('sendFunds', async function() {
    it('should not be able to send funds due to call not by owner', async function() {
      await allocation.sendFunds(wallet, 1, 100, {from: outsider}).should.be.rejectedWith("revert");
    });

    it('should not be able to send funds due to pie chart amount < asked amount', async function() {
      await allocation.sendFunds(wallet, 1, totalSupply).should.be.rejectedWith("revert");
    });

    it('should succesfuly send funds', async function() {
      await allocation.sendFunds(wallet, 1, 100);
    });
  });

  describe('buyTokens', async function() {
    it('should not be able to buy tokens due to account not in whitelist', async function() {
      await allocation.buyTokens(wallet, {from: wallet, value: weiAmount}).should.be.rejectedWith("revert");
    });

    it('should not be able to buy tokens due to allocation finalized', async function() {
      await allocation.addAddressToWhitelist(wallet);
      await allocation.finalize();
      await allocation.buyTokens(wallet, {from: wallet, value: weiAmount}).should.be.rejectedWith("revert");
    });

    it('should succesfuly buy tokens', async function() {
      await allocation.addAddressToWhitelist(wallet);
      let tx = await allocation.buyTokens(wallet, {from: wallet, value: weiAmount});
      let events = tx.logs.filter(l => l.event === 'TokenPurchase');
      assert.equal(events[0].args.purchaser, wallet);
      assert.equal(events[0].args.beneficiary, wallet);
      assert.equal(events[0].args.value, weiAmount);
      assert.equal(events[0].args.amount, weiAmount * rate);
    });
  });

  describe('releaseVestedTokens', async function() {
    it('should not be able to release vested tokens due to not time for release', async function() {
      await allocation.addAddressToWhitelist(wallet);
      let tx = await allocation.buyTokens(wallet, {from: wallet, value: weiAmount});
      let events = tx.logs.filter(l => l.event === 'TokenPurchase');
      assert.equal(events[0].args.purchaser, wallet);
      assert.equal(events[0].args.beneficiary, wallet);
      assert.equal(events[0].args.value, weiAmount);
      assert.equal(events[0].args.amount, weiAmount * rate);
      tx = await allocation.allocateTokensForContributor(wallet);
      events = tx.logs.filter(l => l.event === 'TimeVestingCreation');
      assert.equal(events[0].args.beneficiary, wallet);

      await increaseTimeTo(duration.weeks(1));
      await allocation.releaseVestedTokens({from: wallet}).should.be.rejectedWith("revert");
    });

    it('should succesfuly release vested tokens', async function() {
      await allocation.addAddressToWhitelist(wallet);
      let tx = await allocation.buyTokens(wallet, {from: wallet, value: weiAmount});
      let events = tx.logs.filter(l => l.event === 'TokenPurchase');
      assert.equal(events[0].args.purchaser, wallet);
      assert.equal(events[0].args.beneficiary, wallet);
      assert.equal(events[0].args.value, weiAmount);
      assert.equal(events[0].args.amount, weiAmount * rate);
      tx = await allocation.allocateTokensForContributor(wallet);
      events = tx.logs.filter(l => l.event === 'TimeVestingCreation');
      assert.equal(events[0].args.beneficiary, wallet);

      await increaseTimeTo(duration.years(1));
      await allocation.releaseVestedTokens({from: wallet});
    });
  });

  describe('finalize', async function() {
    it('should not be able to finalize allocation due to call not by owner', async function() {
      await allocation.finalize({from: outsider}).should.be.rejectedWith("revert");
    });

    it('should not be able to finalize allocation due to already finalized', async function() {
      await allocation.finalize();
      await allocation.finalize().should.be.rejectedWith("revert");
    });

    it('should succesfuly finalize allocation', async function() {
      await allocation.finalize();
    });
  });

});
