# crowdsale

## Installation 

1. `git clone https://github.com/iron-x/crowdsale.git`
2. `git checkout develop`
3. `npm install` or `npm i`
4. `truffle compile`

## Smart-contracts description

### IronxToken 

* ERC-20 compatible token
* Has fixed supply of tokens
* Allow to increase or decrease amount of approval tokens

### IronxCrowdsale

* Time-dependent crowdsale with bonuses depending on contribution sum
* Vesting and cliff features

### TokenVesting

* Lockup of tokens for 9-month period with 3-month cliff
* Allows owner to revoke (optionally, that's defined by variable in the constructor) 
