pragma solidity ^0.4.24;

library Percent {

  /**
   * @dev Add percent to numerator variable with precision
   * @param numerator initial value
   * @param percent percent that must be added to numerator
   * @param precision defines accuracy of rounding off
   */
	function perc
	(
    uint256 numerator, 
    uint256 percent, 
    uint256 precision
  ) 
    internal 
    pure 
    returns(uint256 quotient) 
  { 
    uint _numerator  = numerator * 10 ** (precision + 1);
    uint _quotient =  (((_numerator / 100) * percent) + 5) / 10;
    return ( _quotient);
  }
}
