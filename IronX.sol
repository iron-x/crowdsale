pragma solidity ^0.4.23;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    if (a == 0) {
      return 0;
    }
    c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return a / b;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
  
  
    function max64(uint64 a, uint64 b) internal pure returns (uint64) {
    return a >= b ? a : b;
  }

  function min64(uint64 a, uint64 b) internal pure returns (uint64) {
    return a < b ? a : b;
  }

  function max256(uint256 a, uint256 b) internal pure returns (uint256) {
    return a >= b ? a : b;
  }

  function min256(uint256 a, uint256 b) internal pure returns (uint256) {
    return a < b ? a : b;
  }
  
  function percent(uint256 numerator, uint256 percents, uint256 precision) internal returns(uint256 quotient) {
        uint _numerator  = numerator * 10 ** (precision+1);
        uint _quotient =  (((_numerator / 100) * percents) + 5) / 10;
        return ( _quotient);
  }
}


interface tokenRecipient { function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) external; }

contract TokenERC20 {
    // Public variables of the token
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    // 18 decimals is the strongly suggested default, avoid changing it
    uint256 public totalSupply;

    // This creates an array with all balances
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    // This generates a public event on the blockchain that will notify clients
    event Transfer(address indexed from, address indexed to, uint256 value);

    // This notifies clients about the amount burnt
    event Burn(address indexed from, uint256 value);

    /**
     * Constructor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    constructor (
        uint256 initialSupply,
        string tokenName,
        string tokenSymbol
    ) public {
        totalSupply = initialSupply * 10 ** uint256(decimals);  // Update total supply with the decimal amount
        balanceOf[msg.sender] = totalSupply;                // Give the creator all initial tokens
        name = tokenName;                                   // Set the name for display purposes
        symbol = tokenSymbol;                               // Set the symbol for display purposes
    }

    /**
     * Internal transfer, only can be called by this contract
     */
    function _transfer(address _from, address _to, uint _value) internal {
        // Prevent transfer to 0x0 address. Use burn() instead
        require(_to != 0x0);
        // Check if the sender has enough
        require(balanceOf[_from] >= _value);
        // Check for overflows
        require(balanceOf[_to] + _value >= balanceOf[_to]);
        // Save this for an assertion in the future
        uint previousBalances = balanceOf[_from] + balanceOf[_to];
        // Subtract from the sender
        balanceOf[_from] -= _value;
        // Add the same to the recipient
        balanceOf[_to] += _value;
        emit Transfer(_from, _to, _value);
        // Asserts are used to use static analysis to find bugs in your code. They should never fail
        assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
    }

    /**
     * Transfer tokens
     *
     * Send `_value` tokens to `_to` from your account
     *
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transfer(address _to, uint256 _value) public {
        _transfer(msg.sender, _to, _value);
    }

    /**
     * Transfer tokens from other address
     *
     * Send `_value` tokens to `_to` on behalf of `_from`
     *
     * @param _from The address of the sender
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_value <= allowance[_from][msg.sender]);     // Check allowance
        allowance[_from][msg.sender] -= _value;
        _transfer(_from, _to, _value);
        return true;
    }

    /**
     * Set allowance for other address
     *
     * Allows `_spender` to spend no more than `_value` tokens on your behalf
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     */
    function approve(address _spender, uint256 _value) public
        returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        return true;
    }

    /**
     * Set allowance for other address and notify
     *
     * Allows `_spender` to spend no more than `_value` tokens on your behalf, and then ping the contract about it
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     * @param _extraData some extra information to send to the approved contract
     */
    function approveAndCall(address _spender, uint256 _value, bytes _extraData)
        public
        returns (bool success) {
        tokenRecipient spender = tokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, this, _extraData);
            return true;
        }
    }

    /**
     * Destroy tokens
     *
     * Remove `_value` tokens from the system irreversibly
     *
     * @param _value the amount of money to burn
     */
    function burn(uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value);   // Check if the sender has enough
        balanceOf[msg.sender] -= _value;            // Subtract from the sender
        totalSupply -= _value;                      // Updates totalSupply
        emit Burn(msg.sender, _value);
        return true;
    }

    /**
     * Destroy tokens from other account
     *
     * Remove `_value` tokens from the system irreversibly on behalf of `_from`.
     *
     * @param _from the address of the sender
     * @param _value the amount of money to burn
     */
    function burnFrom(address _from, uint256 _value) public returns (bool success) {
        require(balanceOf[_from] >= _value);                // Check if the targeted balance is enough
        require(_value <= allowance[_from][msg.sender]);    // Check allowance
        balanceOf[_from] -= _value;                         // Subtract from the targeted balance
        allowance[_from][msg.sender] -= _value;             // Subtract from the sender's allowance
        totalSupply -= _value;                              // Update totalSupply
        emit Burn(_from, _value);
        return true;
    }
}


interface token {
    function transfer(address receiver, uint amount) external;
}


interface SchedulerAPI {
    function scheduleCall(address contractAddress,
                          bytes4 abiSignature,
                          uint targetBlock) external returns (address);
}

contract Crowdsale is Ownable {
    // address constant Scheduler = SchedulerAPI(0x6c8f2a135f6ed072de4503bd7c4999a1a17f824b);
    address public beneficiary;
    uint public fundingGoal;
    uint public amountRaised;
    uint public deadline;
    uint public price;
    token public tokenReward;
    uint private latestBonusReceiverIndex = 0;
    
    
    struct Order {
        address owner;
        uint256 amount;
        uint256 lockup;
        bool claimed;
    }
    
    struct BonusTokenReceiver {
        address receiver;
        uint256 value;
    }
    
    mapping(uint256 => Order) private orders;
    mapping(address => uint256) public balanceOf;
    
    
    mapping (address => BonusTokenReceiver) bonusTokenReceivers;
    mapping (uint256 => address) bonusTokenReceiversIndex;
    
    uint256 private latestOrderId = 0;
    bool public fundingGoalReached = false;
    bool public crowdsaleClosed = false;
    bool public crowdsaleStarted = false;
    
    uint256 public hardCap;
    uint256 public softCap;

    event Activated(uint256 time);
    event Finished(uint256 time);
    event Purchase(address indexed purchaser, uint256 id, uint256 amount, uint256 purchasedAt, uint256 redeemAt);
    event Claim(address indexed purchaser, uint256 id, uint256 amount);
    event GoalReached(address recipient, uint totalAmountRaised);
    event FundTransfer(address backer, uint amount, bool isContribution);

    /**
     * Constructor function
     *
     * Setup the owner
     */
    constructor (
        address ifSuccessfulSendTo,
        uint fundingGoalInEthers,
        uint durationInMinutes,
        uint etherCostOfEachToken,
        address addressOfTokenUsedAsReward,
        uint256 presaleHardCap,
        uint256 presaleSoftCap
    ) public {
        beneficiary = ifSuccessfulSendTo;
        fundingGoal = fundingGoalInEthers * 1 ether;
        deadline = now + durationInMinutes * 1 minutes;
        price = etherCostOfEachToken * 1 ether;
        tokenReward = token(addressOfTokenUsedAsReward);
        hardCap = presaleHardCap;
        softCap = presaleSoftCap;
    }

    /**
     * Fallback function
     *
     * The function without name is the default function that is called whenever anyone sends funds to a contract
     */
    function () payable public {
        require(!crowdsaleStarted && !crowdsaleClosed);
        uint amount = msg.value;
        balanceOf[msg.sender] += amount;
        amountRaised += amount;
        tokenReward.transfer(msg.sender, amount / price);
        emit FundTransfer(msg.sender, amount, true);
        
        if (now > deadline) {
            giveBonus();
        }
    }

    function _establishReward(address receiver, uint256 amount) internal returns (uint256) {
        uint256 purchasedAmount = 0;
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
            bonusTokenReceivers[receiver] = BonusTokenReceiver(receiver, 1);
            ++latestBonusReceiverIndex;
            bonusTokenReceiversIndex[latestBonusReceiverIndex] = receiver; 
        }
        if (amount > 1943823500000000000000) {
            purchasedAmount = amount + SafeMath.percent(amount, 30, 3);
            bonusTokenReceivers[receiver] = BonusTokenReceiver(receiver, 2);
            ++latestBonusReceiverIndex;
            bonusTokenReceiversIndex[latestBonusReceiverIndex] = receiver;
        }
        return purchasedAmount;
    }
    
    function processPurchase(address _investor, uint256 _value, uint256 lockup) private {
        if (!crowdsaleStarted) { revert(); }
        if (msg.value == 0) { revert(); }
        ++latestOrderId;
    
        uint256 purchasedAmount = _establishReward(_investor, _value);
        if (purchasedAmount == 0) { revert(); } // not enough ETH sent
        if (purchasedAmount > hardCap - amountRaised) { revert(); } // too much ETH sent
    
        orders[latestOrderId] = Order(msg.sender, purchasedAmount, lockup, false);
        amountRaised += purchasedAmount;
    
        beneficiary.transfer(msg.value);
        emit Purchase(msg.sender, latestOrderId, purchasedAmount, now, lockup);
    }

    
    function invest() public payable {
        uint256 lockup = now + 39 weeks;
        processPurchase(msg.sender, msg.value, lockup);
        
        if (amountRaised > 10214504590000000000000) {
            
        }
    }
    
    
    function giveBonus() {
        for(uint i = 0; i < latestBonusReceiverIndex; i++) {
            balanceOf[bonusTokenReceiversIndex[i]] += bonusTokenReceivers[bonusTokenReceiversIndex[i]].value;
        }       
    }

    
    function start() public {
        require(msg.sender == beneficiary);
        require(!crowdsaleStarted);
        crowdsaleStarted = true;
        emit Activated(now);
    }

    modifier afterDeadline() { if (now >= deadline) _; }

    function checkGoalReached() public afterDeadline {
        if (amountRaised >= fundingGoal){
            fundingGoalReached = true;
            emit GoalReached(beneficiary, amountRaised);
        }
        crowdsaleClosed = true;
    }
    
    function amountOf(uint256 orderId) constant public returns (uint256 amount) {
        return orders[orderId].amount;
    }
    
    function lockupOf(uint256 orderId) constant public returns (uint256 timestamp) {
        return orders[orderId].lockup;
    }
    
    function ownerOf(uint256 orderId) constant public returns (address orderOwner) {
        return orders[orderId].owner;
    }
    
    function isClaimed(uint256 orderId) constant public returns (bool claimed) {
        return orders[orderId].claimed;
    }
    
    function redeem(uint256 orderId) public {
        if (orderId > latestOrderId) { revert(); }
        Order storage order = orders[orderId];
        
        if (msg.sender != order.owner) { revert(); }
        if (now < order.lockup) { revert(); }
        if (order.claimed) { revert(); }
        require(whiteList[order.owner]);
        order.claimed = true;
        
        balanceOf[msg.sender] = order.amount;
        emit Claim(order.owner, orderId, order.amount);
    }

    /**
     * @dev Reverts if beneficiary is not whitelisted
     */
    modifier isWhiteListed(address _beneficiary) {
        require(whiteList[_beneficiary]);
        _;
    }


    /**
     * @dev Adds single address to whitelist
     * @param _beneficiary Address to be added to the whitelist
     */
    function addToWhitelist(address _beneficiary) external onlyOwner {
        whiteList[_beneficiary] = true;
    }


    /**
     * @dev Adds list of addresses to whitelist
     * @param _beneficiaries Addresses to be added to the whitelist
     */
    function addManyToWhitelist(address[] _beneficiaries) external onlyOwner {
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            whiteList[_beneficiaries[i]] = true;
        }
    }


    /**
     * @dev Removes single address from whitelist
     * @param _beneficiary Address to be removed from the whitelist
     */
    function removeFromWhitelist(address _beneficiary) external onlyOwner {
        whiteList[_beneficiary] = false;
    }
}
