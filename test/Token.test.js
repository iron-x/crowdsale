const BigNumber = web3.BigNumber;

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

contract('Token', accounts => {
  let token;
  const totalSupply = new BigNumber(50000000000000000000000);
  const decimals = new BigNumber(18);
  const name = "IronX";
  const symbol = "IRX";
  const creator = accounts[0];
  const recipient = accounts[1];
  const anotherAccount = accounts[2];


  beforeEach(async function () {
    token = await Token.new(totalSupply, decimals, name, symbol, { from: creator });
  });


  it('Has a name', async function () {
    const name_ = await token.name();
    assert.equal(name_, name);
  });


  it('Has a symbol', async function () {
    const symbol_ = await token.symbol();
    assert.equal(symbol_, symbol);
  });


  it('Has decimals', async function () {
    const decimals_ = await token.decimals();
    assert(decimals_.eq(decimals));
  });


  describe('Total supply', async function() {
    it('returns the total amount of tokens', async function() {
      const _totalSupply = await token.totalSupply();

      totalSupply.should.be.bignumber.equal(totalSupply);
    });


    it('total given to owner', async function() {
      const ownerBalance = await token.balanceOf(creator);

      ownerBalance.should.be.bignumber.equal(totalSupply);
    });
  });


  describe('balanceOf', async function() {
    describe('when the requested account has no tokens', function () {
      it('returns zero', async function () {
        const balance = await token.balanceOf(anotherAccount);

        assert.equal(balance, 0);
      });
    });


    describe('when the requested account has some tokens', function () {
      it('returns the total amount of tokens', async function () {
        const balance = await token.balanceOf(creator);

        assert(balance.eq(totalSupply));
      });
    });
  })


  describe('transfer', function () {

    describe('when the recipient is not the zero address', function () {
      const to = recipient;


      describe('when the sender does not have enough balance', function () {
        const amount = new BigNumber(totalSupply).plus(100);

        it('reverts', async function () {
          await assertRevert(token.transfer(to, amount, { from: creator }));
        });
      });


      describe('when the sender has enough balance', function () {
        const amount = 100;

        it('transfers the requested amount', async function () {
          await token.transfer(to, amount, { from: creator });

          const senderBalance = await token.balanceOf(creator);
          senderBalance.should.be.bignumber.equal(new BigNumber(totalSupply).sub(amount));

          const recipientBalance = await token.balanceOf(to);
          recipientBalance.should.be.bignumber.equal(amount);
        });


        it('emits a transfer event', async function () {
          const { logs } = await token.transfer(to, amount, { from: creator });

          assert.equal(logs.length, 1);
          assert.equal(logs[0].event, 'Transfer');
          assert.equal(logs[0].args.from, creator);
          assert.equal(logs[0].args.to, to);
          assert(logs[0].args.value.eq(amount));
        });
      });
    });
  });  
});
