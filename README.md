# crowdsale

## Installation 

1. `git clone https://github.com/iron-x/crowdsale.git`
2. `git checkout develop`
3. `npm install` or `npm i`
4. `truffle compile` 
5. `ganache-cli` - first terminal
6. `truffle test` - second terminal

## Smart-contracts description

### Token 

* ERC-20 compatible token
* Has fixed supply of tokens
* Allow to increase or decrease amount of approval tokens

### PrivateSale

* Time-dependent crowdsale with bonus structure
* Vesting and cliff features
* Provide most active contributors with annualy rewards
* Manage the token vesting process

### TokenVesting

* Lockup of tokens for 9-month period with 3-month cliff
* Allows owner to revoke (optionally, that's defined by variable in the constructor) 
