pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract Token is StandardToken, Ownable {
  
  /**
   * Variables that define basic token features
   */ 
  uint256 public decimals;
  string public name;
  string public symbol;
  uint256 releasedAmount = 0;

  constructor(uint256 _totalSupply, uint256 _decimals, string _name, string _symbol) public {
    require(_totalSupply > 0);
    require(_decimals > 0);

    totalSupply_ = _totalSupply;
    decimals = _decimals;
    name = _name;
    symbol = _symbol;

    balances[msg.sender] = _totalSupply;

    // transfer all supply to the owner
    emit Transfer(address(0), msg.sender, _totalSupply);
  }
}