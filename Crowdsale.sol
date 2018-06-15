pragma solidity ^0.4.23;

import "SafeMath.sol";
import "ERC20.sol";
import "Ownable.sol";



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
