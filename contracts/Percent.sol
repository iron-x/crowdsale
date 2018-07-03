pragma solidity ^0.4.24;

library Percent {
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
