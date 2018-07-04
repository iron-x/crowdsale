pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";
import "./Percent.sol";
import "./Token.sol";
import "./Whitelist.sol";
import "./TokenVesting.sol";

/**
 * @title Crowdsale
 * @dev Crowdsale is a base contract for managing a token crowdsale,
 * allowing investors to purchase tokens with ether. This contract implements
 * such functionality in its most fundamental form and can be extended to provide additional
 * functionality and/or custom behavior.
 * The external interface represents the basic interface for purchasing tokens, and conform
 * the base architecture for crowdsales. They are *not* intended to be modified / overriden.
 * The internal interface conforms the extensible and modifiable surface of crowdsales. Override
 * the methods to add functionality. Consider using 'super' where appropiate to concatenate
 * behavior.
 */
contract Crowdsale is Whitelist {
  using SafeMath for uint256;
  using Percent for uint256;
  using SafeERC20 for Token;

  struct RewardReceiver {
    uint256 time;
    uint256 reward;
  }

  mapping (address => uint256) public tokenRewards;
  mapping (address => TokenVesting) public vesting;
  mapping (address => RewardReceiver) public rewardReceivers;
  

  /**
   *  Variables for bonus program
   */
  uint256 public USD_50K = 971911700000000000;
  uint256 public USD_150K = 291573500000000000000;
  uint256 public USD_250K = 485955800000000000000;
  uint256 public USD_500K = 971911700000000000000;
  uint256 public USD_1KK = 1943823500000000000000;

  /**
   * Variables for setup vesting period
   */
  uint256 public PERIOD_1Y = 31556926; 
  uint256 public PERIOD_9M = 23667695;
  uint256 public PERIOD_3M = 7889231;

  bool public isFinalized = false;

  Token public token;
  
  address public wallet;
  uint256 public rate;
  uint256 public weiRaised;
  uint256 public softCap;
  uint256 public hardCap;
  uint256 public startTime;
  uint256 public endTime;

  /**
   * Event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param beneficiary who got the tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   */
  event TokenPurchase(
    address indexed purchaser,
    address indexed beneficiary,
    uint256 value,
    uint256 amount
  );

  event Finalized();

  /**
   * Event for creation of token vesting contract
   * @param beneficiary who will receive tokens 
   * @param start time of vesting start
   * @param cliff duration of cliff period
   * @param duration total vesting period duration
   * @param revocable specifies if vesting contract has abitility to revoke
   */
  event TimeVestingCreation
  (
    address beneficiary,
    uint256 start,
    uint256 cliff,
    uint256 duration,
    bool revocable
  );


  /**
   * @param _rate Number of token units a buyer gets per wei
   * @param _wallet Address where collected funds will be forwarded to
   * @param _token Address of the token being sold
   */
  constructor(
    uint256 _rate, 
    address _wallet, 
    Token _token,
    uint256 _softCap,
    uint256 _hardCap,
    uint256 _startTime,
    uint256 _endTime
  ) 
    public 
  {
    require(_rate > 0);
    require(_wallet != address(0));
    require(_token != address(0));
    require(_hardCap > 0);
    require(_softCap > 0);
    require(_startTime > 0);
    require(_endTime > _startTime);
    require(_hardCap > _softCap);

    rate = _rate;
    wallet = _wallet;
    token = _token;
    hardCap = _hardCap;
    softCap = _softCap;
    startTime = _startTime;
    endTime = _endTime;
  }


  // -----------------------------------------
  // Crowdsale external interface
  // -----------------------------------------
  /**
   * @dev function for buying tokens
   */
  function() 
    external 
    payable 
  {
    buyTokens(msg.sender);
  }


  /**
   * @dev check if soft cap reached
   */
  function softCapReached() public view returns (bool) {
    return weiRaised >= softCap;
  }


  /**
   * @dev check if hard cap reached
   */
  modifier hardCapNotReached() {
    require(
      weiRaised <= hardCap,
      "Hard cap is reached"
    );
    _;
  }

  /**
   *  @dev check if address is token reward receiver
   */
  modifier isRewardReceiver(address _receiver) {
    require(tokenRewards[_receiver] > 0);
    _;
  }


  /**
   *  @dev check if value respects crowdsale minimal contribution sum
   */
  modifier respectContribution() {
    require(
      msg.value >= USD_50K,
      "Minimum contribution is $50,000"
    );
    _;
  }


  /**
   * @dev check if crowdsale is still open
   */
  modifier onlyWhileOpen {
    require(
      block.timestamp >= startTime && block.timestamp <= endTime && !isFinalized,
      "Crowdsale is closed"
    );
    _;
  }


  /**
   * @dev low level token purchase ***DO NOT OVERRIDE***
   * @param _beneficiary Address performing the token purchase
   */
  function buyTokens(address _beneficiary) 
   public 
   payable
  {
    uint256 weiAmount = msg.value;
    _preValidatePurchase(_beneficiary, weiAmount);

    // calculate token amount to be created
    uint256 tokens = _getTokenAmount(msg.sender, weiAmount);

    // update state
    weiRaised = weiRaised.add(weiAmount);

    _processPurchase(_beneficiary, tokens);

    emit TokenPurchase(
      msg.sender,
      _beneficiary,
      weiAmount,
      tokens
    );

    //_updatePurchasingState(_beneficiary, weiAmount);
    _forwardFunds();
    //_postValidatePurchase(_beneficiary, weiAmount);
  }


  // -----------------------------------------
  // Internal interface (extensible)
  // -----------------------------------------
  /**
   * @dev Validation of an incoming purchase. Use require statements to revert state when conditions are not met. Use super to concatenate validations.
   * @param _beneficiary Address performing the token purchase
   * @param _weiAmount Value in wei involved in the purchase
   */
  function _preValidatePurchase(
    address _beneficiary,
    uint256 _weiAmount
  )
    onlyIfWhitelisted(_beneficiary)
    onlyWhileOpen
    hardCapNotReached
    view
    internal
  {
    require(weiRaised.add(_weiAmount) <= softCap);
    require(_beneficiary != address(0));
    require(_weiAmount != 0);
  }


  /**
   * @dev Validation of an executed purchase. Observe state and use revert statements to undo rollback when valid conditions are not met.
   * @param _beneficiary Address performing the token purchase
   * @param _weiAmount Value in wei involved in the purchase
   */
  function _postValidatePurchase(
    address _beneficiary,
    uint256 _weiAmount
  )
    pure
    internal
  {
    // optional override
  }


  /**
   * @dev Create vesting contract
   * @param _beneficiary address of person who will get all tokens as vesting ends
   * @param _tokens amount of vested tokens
   */
  function createTimeBasedVesting
  (
    address _beneficiary,
    uint256 _tokens
  )
    internal
  {
    require(_beneficiary != 0x0);
    require(_tokens > 0);

    uint256 _start = block.timestamp;
    uint256 _duration = _start.add(PERIOD_1Y);
    uint256 _cliff = PERIOD_3M;

    vesting[_beneficiary] = new TokenVesting(_beneficiary, _start, _cliff, _duration, false);

    token.safeTransfer(vesting[_beneficiary], _tokens);

    emit TimeVestingCreation(_beneficiary, _start, _cliff, _duration, false);
  }


  /**
   * @dev Adding contributor to the list of reward receivers
   * @param _beneficiary address of reward receiver
   * @param _reward amount of reward tokens
   */
  function addRewardReceiver
  (
    address _beneficiary,
    uint256 _reward
  ) 
    internal
  {
    rewardReceivers[_beneficiary] = RewardReceiver
    (
      block.timestamp,
       _reward
    );
  }


  /**
   * @dev Release token timely reward to beneficiary
   * @param _receiver address of person who will receive reward
   */
  function getReward
  (
    address _receiver
  ) 
    public
    view
    isRewardReceiver(_receiver)
    returns(uint256 _rewardToTransfer)
  {
    RewardReceiver memory _reward = rewardReceivers[_receiver];
    uint256 _passedTime = block.timestamp.sub(_reward.time);
    _rewardToTransfer = 0;

    if (_passedTime > PERIOD_1Y && _passedTime < PERIOD_1Y.mul(2)) {
      _rewardToTransfer = _reward.reward;
    }
    if (_passedTime > PERIOD_1Y.mul(2) && _passedTime < PERIOD_1Y.mul(3)) {
      _rewardToTransfer = _reward.reward.mul(2);
    }
    if (_passedTime > PERIOD_1Y.mul(3)) {
      _rewardToTransfer = _reward.reward.mul(3);
    }

    return _rewardToTransfer;
  }


  /**
   *  @dev checks if crowdsale is closed
   */
  function hasClosed() public view returns (bool) {
    return block.timestamp > endTime;
  }


  /** 
   * @dev Release tokens from vesting contract
   * @param _beneficiary address of the contacts beneficiary
   */
  function releaseVestedTokens
  (
    address _beneficiary
  ) 
    public
  {
    require(_beneficiary != 0x0);

    TokenVesting tokenVesting = vesting[_beneficiary];
    tokenVesting.release(token);

    token.safeTransfer(_beneficiary, getReward(_beneficiary));
  }


  /**
   * @dev Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends its tokens.
   * @param _beneficiary Address performing the token purchase
   * @param _tokenAmount Number of tokens to be emitted
   */
  function _deliverTokens(
    address _beneficiary,
    uint256 _tokenAmount
  )
    internal
  {
    if (tokenRewards[_beneficiary] > 0) {
      uint256 _tokenBonus = tokenRewards[_beneficiary];
      addRewardReceiver(_beneficiary, _tokenBonus);
    }
    createTimeBasedVesting(_beneficiary, _tokenAmount);
  }


  /**
   * @dev Executed when a purchase has been validated and is ready to be executed. Not necessarily emits/sends tokens.
   * @param _beneficiary Address receiving the tokens
   * @param _tokenAmount Number of tokens to be purchased
   */
  function _processPurchase(
    address _beneficiary,
    uint256 _tokenAmount
  )
    internal
  {
    _deliverTokens(_beneficiary, _tokenAmount);
  }


  /**
   * @dev Override for extensions that require an internal state to check for validity (current user contributions, etc.)
   * @param _beneficiary Address receiving the tokens
   * @param _weiAmount Value in wei involved in the purchase
   */
  function _updatePurchasingState(
    address _beneficiary,
    uint256 _weiAmount
  )
    pure
    internal
  {
    // optional override
  }


  /**
   * @dev Override to extend the way in which ether is converted to tokens.
   * @param _weiAmount Value in wei to be converted into tokens
   * @return Number of tokens that can be purchased with the specified _weiAmount
   */
  function _getTokenAmount
  (
    address _beneficiary,
    uint256 _weiAmount
  )
    internal
    returns (uint256 purchasedAmount)
  {
    if (_weiAmount > USD_50K && _weiAmount < USD_150K) {
      purchasedAmount = _weiAmount + _weiAmount.perc(5, 3);
    }
    if (_weiAmount > USD_150K && _weiAmount < USD_250K) {
      purchasedAmount = _weiAmount + _weiAmount.perc(10, 3);
    }
    if (_weiAmount > USD_250K && _weiAmount < USD_500K) {
      purchasedAmount = _weiAmount + _weiAmount.perc(15, 3);
    }
    if (_weiAmount > USD_500K && _weiAmount < USD_1KK) {
      purchasedAmount = _weiAmount + _weiAmount.perc(20, 3);
      tokenRewards[_beneficiary] = 1;
    }
    if (_weiAmount > USD_1KK) {
      purchasedAmount = _weiAmount + _weiAmount.perc(30, 3);
      tokenRewards[_beneficiary] = 2;
    }
    return purchasedAmount;
  }


  /**
   * @dev Determines how ETH is stored/forwarded on purchases.
   */
  function _forwardFunds() internal {
    wallet.transfer(msg.value);
  }


   /**
   * @dev Must be called after crowdsale ends, to do some extra finalization
   * work. Calls the contract's finalization function.
   */
  function finalize() onlyOwner public {
    require(!isFinalized);
    require(hasClosed());

    finalization();
    emit Finalized();

    isFinalized = true;
  } 


  /**
   * @dev Can be overridden to add finalization logic. The overriding function
   * should call super.finalization() to ensure the chain of finalization is
   * executed entirely.
   */
  function finalization() pure internal {}
}