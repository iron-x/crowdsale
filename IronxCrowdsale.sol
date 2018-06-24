pragma solidity ^0.4.24;

import "./Crowdsale.sol";
import "./IronxToken.sol";

contract IronxCrowdsale is Crowdsale {

  IronxToken public TOKEN;
  uint256 public START_TIME = 1529928000;
  uint256 public END_TIME = 1561464000;
  uint256 public RATE = 33;
  address public BENEFICIARY_WALLET;

  /**
  * @dev IronxCrowdsale constructor
  */
  constructor(
    IronxToken _token,
    address _wallet  
  ) public Crowdsale(_token, START_TIME, END_TIME, RATE, _wallet) {
    TOKEN = _token;
    BENEFICIARY_WALLET = _wallet;
  }
}