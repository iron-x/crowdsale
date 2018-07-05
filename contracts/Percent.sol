pragma solidity ^0.4.24;

library Percent {

  /**
   * @dev Add percent to numerator variable with precision
   */
	function perc
	(
    uint256 initialValue,
    uint256 percent
  ) 
    internal 
    pure 
    returns(uint256 result) 
  { 
    uint256 toAdd  = (initialValue / 100) * percent;
    result = initialValue + toAdd;
    return result;
  }
}
