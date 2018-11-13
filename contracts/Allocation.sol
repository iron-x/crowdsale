pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "./Percent.sol";
import "./Token.sol";
import "./Whitelist.sol";
import "./TokenVesting.sol";

/**
 * @title Allocation
 * Allocation is a base contract for managing a token sale,
 * allowing investors to purchase tokens with ether.
 */
contract Allocation is Whitelist {
  using SafeMath for uint256;
  using Percent for uint256;

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
   * @param revocable specifies if vesting contract has abitility to revoke
   */
  event TimeVestingCreation
  (
    address beneficiary,
    uint256 start,
    uint256 duration,
    bool revocable
  );

  struct PartInfo {
    uint256 percent;
    bool lockup;
    uint256 amount;
  }

  mapping (address => bool) public owners;
  mapping (address => uint256) public contributors;            
  mapping (address => TokenVesting) public vesting;
  mapping (uint256 => PartInfo) public pieChart;
  mapping (address => bool) public isInvestor;
  
  address[] public investors;

  /**
   * Variables for bonus program
   * ============================
   * Variables values are test!!!
   */
  uint256 private SMALLEST_SUM; // 971911700000000000
  uint256 private SMALLER_SUM;  // 291573500000000000000
  uint256 private MEDIUM_SUM;   // 485955800000000000000
  uint256 private BIGGER_SUM;   // 971911700000000000000
  uint256 private BIGGEST_SUM;  // 1943823500000000000000

  // Vesting period
  uint256 public duration = 23667695;

  // Flag of Finalized sale event
  bool public isFinalized = false;

  // Wei raides accumulator
  uint256 public weiRaised = 0;

  //
  Token public token;
  //
  address public wallet;
  uint256 public rate;  
  uint256 public softCap;
  uint256 public hardCap;

  /**
   * @param _rate Number of token units a buyer gets per wei
   * @param _wallet Address where collected funds will be forwarded to
   * @param _token Address of the token being sold
   * @param _softCap Soft cap
   * @param _hardCap Hard cap
   * @param _smallestSum Sum after which investor receives 5% of bonus tokens to vesting contract
   * @param _smallerSum Sum after which investor receives 10% of bonus tokens to vesting contract
   * @param _mediumSum Sum after which investor receives 15% of bonus tokens to vesting contract
   * @param _biggerSum Sum after which investor receives 20% of bonus tokens to vesting contract
   * @param _biggestSum Sum after which investor receives 30% of bonus tokens to vesting contract
   */
  constructor(
    uint256 _rate, 
    address _wallet, 
    Token _token,
    uint256 _softCap,
    uint256 _hardCap,
    uint256 _smallestSum,
    uint256 _smallerSum,
    uint256 _mediumSum,
    uint256 _biggerSum,
    uint256 _biggestSum
  ) 
    public 
  {
    require(_rate > 0);
    require(_wallet != address(0));
    require(_token != address(0));
    require(_hardCap > 0);
    require(_softCap > 0);
    require(_hardCap > _softCap);

    rate = _rate;
    wallet = _wallet;
    token = _token;
    hardCap = _hardCap;
    softCap = _softCap;

    SMALLEST_SUM = _smallestSum;
    SMALLER_SUM = _smallerSum;
    MEDIUM_SUM = _mediumSum;
    BIGGER_SUM = _biggerSum;
    BIGGEST_SUM = _biggestSum;

    owners[msg.sender] = true;

    /**
    * Pie chart 
    *
    * early cotributors => 1
    * management team => 2
    * advisors => 3
    * partners => 4
    * community => 5
    * company => 6
    * liquidity => 7
    * sale => 8
    */
    pieChart[1] = PartInfo(10, true, token.totalSupply().mul(10).div(100));
    pieChart[2] = PartInfo(15, true, token.totalSupply().mul(15).div(100));
    pieChart[3] = PartInfo(5, true, token.totalSupply().mul(5).div(100));
    pieChart[4] = PartInfo(5, false, token.totalSupply().mul(5).div(100));
    pieChart[5] = PartInfo(8, false, token.totalSupply().mul(8).div(100));
    pieChart[6] = PartInfo(17, false, token.totalSupply().mul(17).div(100));
    pieChart[7] = PartInfo(10, false, token.totalSupply().mul(10).div(100));
    pieChart[8] = PartInfo(30, false, token.totalSupply().mul(30).div(100));
  }

  // -----------------------------------------
  // Allocation external interface
  // -----------------------------------------
  /**
   * Function for buying tokens
   */
  function() 
    external 
    payable 
  {
    buyTokens(msg.sender);
  }

  /**
   *  Check if value respects sale minimal contribution sum
   */
  modifier respectContribution() {
    require(
      msg.value >= SMALLEST_SUM,
      "Minimum contribution is $50,000"
    );
    _;
  }


  /**
   * Check if sale is still open
   */
  modifier onlyWhileOpen {
    require(!isFinalized, "Sale is closed");
    _;
  }

  /**
   * Check if sender is owner
   */
  modifier onlyOwner {
    require(isOwner(msg.sender) == true, "User is not in Owners");
    _;
  }


  /**
   * Add new owner
   * @param _owner Address of owner which should be added
   */
  function addOwner(address _owner) public onlyOwner {
    require(owners[_owner] == false);
    owners[_owner] = true;
  }

  /**
   * Delete an onwer
   * @param _owner Address of owner which should be deleted
   */
  function deleteOwner(address _owner) public onlyOwner {
    require(owners[_owner] == true);
    owners[_owner] = false;
  }

  /**
   * Check if sender is owner
   * @param _address Address of owner which should be checked
   */
  function isOwner(address _address) public view returns(bool res) {
    return owners[_address];
  }
  
  /**
   * Allocate tokens to provided investors
   */
  function allocateTokens(address[] _investors) public onlyOwner {
    require(_investors.length <= 50);
    
    for (uint i = 0; i < _investors.length; i++) {
      allocateTokensInternal(_investors[i]);
    }
  }

  /**
   * Allocate tokens to a single investor
   * @param _contributor Address of the investor
   */
  function allocateTokensForContributor(address _contributor) public onlyOwner {
    allocateTokensInternal(_contributor);
  }

  /*
   * Allocates tokens to single investor
   * @param _contributor Investor address
   */
  function allocateTokensInternal(address _contributor) internal {
    uint256 weiAmount = contributors[_contributor];

    if (weiAmount > 0) {
      uint256 tokens = _getTokenAmount(weiAmount);
      uint256 bonusTokens = _getBonusTokens(weiAmount);

      pieChart[8].amount = pieChart[8].amount.sub(tokens);
      pieChart[1].amount = pieChart[1].amount.sub(bonusTokens);

      contributors[_contributor] = 0;

      token.transfer(_contributor, tokens);
      createTimeBasedVesting(_contributor, bonusTokens);

      _forwardFunds();

      contributors[_contributor] = 0;
    }
  }
  
  /**
   * Send funds from any part of pieChart
   * @param _to Investors address
   * @param _type Part of pieChart
   * @param _amount Amount of tokens
   */
  function sendFunds(address _to, uint256 _type, uint256 _amount) public onlyOwner {
    require(
      pieChart[_type].amount >= _amount &&
      _type >= 1 &&
      _type <= 8
    );

    if (pieChart[_type].lockup == true) {
      createTimeBasedVesting(_to, _amount);
    } else {
      token.transfer(_to, _amount);
    }
    
    pieChart[_type].amount -= _amount;
  }

  /**
   * Investment receiver
   * @param _beneficiary Address performing the token purchase
   */
  function buyTokens(address _beneficiary) public payable {
    uint256 weiAmount = msg.value;

    _preValidatePurchase(_beneficiary, weiAmount);

    // calculate token amount to be created without bonuses
    uint256 tokens = _getTokenAmount(weiAmount);

    // update state
    weiRaised = weiRaised.add(weiAmount);

    // update 
    contributors[_beneficiary] += weiAmount;

    if(!isInvestor[_beneficiary]){
      investors.push(_beneficiary);
      isInvestor[_beneficiary] = true;
    }

    emit TokenPurchase(
      msg.sender,
      _beneficiary,
      weiAmount,
      tokens
    );
  }


  // -----------------------------------------
  // Internal interface (extensible)
  // -----------------------------------------
  /**
   * Validation of an incoming purchase. Use require statements to revert state when conditions are not met. Use super to concatenate validations.
   * @param _beneficiary Address performing the token purchase
   * @param _weiAmount Value in wei involved in the purchase
   */
  function _preValidatePurchase
  (
    address _beneficiary,
    uint256 _weiAmount
  )
    onlyIfWhitelisted(_beneficiary)
    respectContribution
    onlyWhileOpen
    view
    internal
  {
    require(weiRaised.add(_weiAmount) <= hardCap);
    require(_beneficiary != address(0));
  }

  /**
   * Create vesting contract
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
    uint256 _start = block.timestamp;

    TokenVesting tokenVesting;

    if (vesting[_beneficiary] == address(0)) {
      tokenVesting = new TokenVesting(_beneficiary, _start, false);
      vesting[_beneficiary] = tokenVesting;
    } else {
      tokenVesting = vesting[_beneficiary];
    }

    token.transfer(address(tokenVesting), _tokens);

    emit TimeVestingCreation(_beneficiary, _start, duration, false);
  }


  /**
   *  checks if sale is closed
   */
  function hasClosed() public view returns (bool) {
    return isFinalized;
  }

  /** 
   * Release tokens from vesting contract
   */
  function releaseVestedTokens() public {
    address beneficiary = msg.sender;
    require(vesting[beneficiary] != address(0));

    TokenVesting tokenVesting = vesting[beneficiary];
    tokenVesting.release(token);
  }

  /**
   * Override to extend the way in which ether is converted to tokens.
   * @param _weiAmount Value in wei to be converted into tokens
   * @return Number of tokens that can be purchased with the specified _weiAmount
   */
  function _getBonusTokens
  (
    uint256 _weiAmount
  )
    internal
    view
    returns (uint256 purchasedAmount)
  {
    purchasedAmount = _weiAmount;

    if (_weiAmount >= SMALLEST_SUM && _weiAmount < SMALLER_SUM) {
      purchasedAmount = _weiAmount.perc(5);
    }

    if (_weiAmount >= SMALLER_SUM && _weiAmount < MEDIUM_SUM) {
      purchasedAmount = _weiAmount.perc(10);
    }

    if (_weiAmount >= MEDIUM_SUM && _weiAmount < BIGGER_SUM) {
      purchasedAmount = _weiAmount.perc(15);
    }

    if (_weiAmount >= BIGGER_SUM && _weiAmount < BIGGEST_SUM) {
      purchasedAmount = _weiAmount.perc(20);
    }

    if (_weiAmount >= BIGGEST_SUM) {
      purchasedAmount = _weiAmount.perc(30);
    }

    return purchasedAmount.mul(rate);
  }

  function _getTokenAmount
  (
    uint256 _weiAmount
  )
    internal
    view
    returns (uint256 purchasedAmount)
  {
    return _weiAmount.mul(rate);
  }

  /**
   * Determines how ETH is stored/forwarded on purchases.
   */
  function _forwardFunds() internal {
    wallet.transfer(msg.value);
  }


  /**
   * Must be called after sale ends, to do some extra finalization
   * work. Calls the contract's finalization function.
   */
  function finalize() public onlyOwner {
    require(!hasClosed());
    finalization();
    isFinalized = true;
    emit Finalized();
  } 


  /**
   * Can be overridden to add finalization logic. The overriding function
   * should call super.finalization() to ensure the chain of finalization is
   * executed entirely.
   */
  function finalization() pure internal {}

}