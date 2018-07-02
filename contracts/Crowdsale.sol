pragma solidity ^0.4.24;

import "./SafeMath.sol";
import "./IronxToken.sol";
import "./TokenVesting.sol";


/**
 * @title Crowdsale
 * @dev Crowdsale is a base contract for managing a token crowdsale.
 * Crowdsales have a start and end timestamps, where investors can make
 * token purchases and the crowdsale will assign them tokens based
 * on a token per ETH rate. Funds collected are forwarded to a wallet
 * as they arrive.
 */
contract Crowdsale {
  using SafeMath for uint256;

  struct TokenReward { 
    uint256 time;
    uint256 reward;
  }

  mapping(address => address) wallets;
  mapping(address => TokenReward) tokenRewards;
  address[] public tokenRewardReceivers;

  IronxToken token;
  uint256 public startTime;
  uint256 public endTime;
  uint256 public minContributionSum = 971911700000000000;
  uint256 public rate;
  uint256 public weiRaised;
  address wallet;

  /**
   * event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param beneficiary who got the tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   */
  event TokenPurchase(
    address indexed purchaser, 
    address indexed beneficiary, 
    uint256 value, 
    uint256 amount);

  event Created(
    address indexed wallet, 
    address indexed from, 
    address indexed to,
    uint256 tokens, 
    uint256 start, 
    uint256 cliff, 
    uint256 duration);

  modifier respectContribution() {
    require(msg.value > minContributionSum);
    _;
  }

  function getCountRewardReceivers() public constant returns(uint count) {
    return tokenRewardReceivers.length;
  }

  function getWallets(address _user) 
    public
    view 
    returns(address) {
      return wallets[_user];
  }

  function newTimeLockedWallet( 
    address _owner, 
    uint256 _tokens,
    uint256 _start, 
    uint256 _cliff, 
    uint256 _duration 
  ) 
    payable
    public
    returns(address _wallet) 
  {

      _wallet = new TokenVesting(msg.sender, _owner, _start, _cliff, _duration, false);

      if (msg.sender != _owner) {
        wallets[_owner] = _wallet;
      }

      _wallet.transfer(_tokens);

      wallets[msg.sender] = _wallet;

      emit Created(_wallet, msg.sender, _owner, _tokens, _start, _cliff, _duration);
  }

  constructor (
    IronxToken _token,
    uint256 _startTime,
    uint256 _endTime,
    uint256 _rate, 
    address _wallet
  ) 
    public 
  {
    require(_startTime >= now);
    require(_endTime >= _startTime);
    require(_rate > 0);
    require(_wallet != address(0));

    token = _token;
    startTime = _startTime;
    endTime = _endTime;
    rate = _rate;
    wallet = _wallet;
  }



  // fallback function can be used to buy tokens
  function () 
    external 
    payable
    respectContribution() 
  {
    buyTokens(msg.sender);
    giveReward();
  }

  function giveReward() internal returns (bool) {
    for (uint256 i = 0; i < getCountRewardReceivers(); i++) {
      if(tokenRewards[tokenRewardReceivers[i]].time < now) {
        wallets[tokenRewardReceivers[i]].transfer(tokenRewards[tokenRewardReceivers[i]].reward);
      }
    }
    return true;
  }

  function _establishReward(address tokenReceiver, uint256 amount) internal returns (uint256 purchasedAmount) {
    TokenReward memory _tokenReward;
    if (amount > 971911700000000000 && amount < 291573500000000000000) {
        purchasedAmount = amount + SafeMath.percent(amount, 5, 3);
    }
    if (amount > 291573500000000000000 && amount < 485955800000000000000) {
        purchasedAmount = amount + SafeMath.percent(amount, 10, 3);
    }
    if (amount > 485955800000000000000 && amount < 971911700000000000000) {
        purchasedAmount = amount + SafeMath.percent(amount, 15, 3);
    }
    if (amount > 971911700000000000000 && amount < 1943823500000000000000) {
        purchasedAmount = amount + SafeMath.percent(amount, 20, 3);
        _tokenReward.reward = uint256(1000000000000000000).mul(rate);
        _tokenReward.time = block.timestamp + 31556926;
        tokenRewardReceivers.push(tokenReceiver);
        tokenRewards[tokenReceiver] = _tokenReward;
    }
    if (amount > 1943823500000000000000) {
        purchasedAmount = amount + SafeMath.percent(amount, 30, 3);
        _tokenReward.reward = uint256(2000000000000000000).mul(rate);
        _tokenReward.time = block.timestamp + 31556926;
        tokenRewardReceivers.push(tokenReceiver);
        tokenRewards[tokenReceiver] = _tokenReward;
    }
  }



  // low level token purchase function
  function buyTokens
  (
    address beneficiary
  ) 
    public 
    payable 
  {
    require(beneficiary != address(0));
    require(validPurchase());

    uint256 weiAmount = msg.value;

    // calculate token amount to be created
    uint256 tokens = _establishReward(msg.sender, weiAmount.mul(rate));

    // update state
    weiRaised = weiRaised.add(weiAmount);

    uint256 _start = now;
    uint256 _cliff = _start.add(uint256(23667695)); 
    uint256 _duration = 31556926;

    newTimeLockedWallet(beneficiary, tokens, _start, _cliff, _duration);
    
    emit TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);
  }

  // @return true if the transaction can buy tokens
  function validPurchase() 
    internal 
    view 
    returns (bool) 
  {
    bool withinPeriod = now >= startTime && now <= endTime;
    bool nonZeroPurchase = msg.value != 0;
    return withinPeriod && nonZeroPurchase;
  }

  // @return true if crowdsale event has ended
  function hasEnded() 
    public 
    view 
    returns (bool) 
  {
    return now > endTime;
  }
}