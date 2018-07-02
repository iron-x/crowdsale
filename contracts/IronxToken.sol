pragma solidity ^0.4.24;

import "./StandardToken.sol";

contract IronxToken is StandardToken {

  string public constant name = "IronxToken";
  string public constant symbol = "IRX";
  uint8 public constant decimals = 18;

  uint256 public constant INITIAL_SUPPLY = 500000 * (10 ** uint256(decimals));


  /**
  * @dev IronxToken constructor
  */
  constructor() public {
    totalSupply = INITIAL_SUPPLY;
    balances[msg.sender] = INITIAL_SUPPLY;
    emit Transfer(address(0), msg.sender, INITIAL_SUPPLY);
  }
}