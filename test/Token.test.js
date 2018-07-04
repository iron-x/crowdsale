const BigNumber = web3.BigNumber;

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should();

const Token = artifacts.require('Token');

contract('Token', accounts => {
  let token;

  const totalSupply = new BigNumber(50000000000000000000000);
  const decimals = new BigNumber(18);
  const name = "IronX";
  const symbol = "IRX";

  const creator = accounts[0];

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

  it('Assigns the initial total supply to the creator', async function () {
    const totalSupply_ = await token.totalSupply();
    const creatorBalance_ = await token.balanceOf(creator);

    assert(creatorBalance_.eq(totalSupply_));
  });
});
