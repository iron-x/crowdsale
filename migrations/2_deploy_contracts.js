const Token = artifacts.require("./Token.sol");
const Allocation = artifacts.require("./Allocation.sol");

/**
 * Token constructor parameters
 */
const totalSupply = 50000000000000000000000;
const decimals = 18;
const name = "IronX";
const symbol = "IRX";

/**
 * PrivateSale constructor parameters
 */ 
const rate = 330000000000000000;
const softCap = 200000000000000000000;
const hardCap = 40000000000000000000000;
const weekInSeconds = 604800;
const startTime = Date.now() + weekInSeconds;
const endTime = startTime + weekInSeconds;
const smallestSum = 971911700000000000;
const smallerSum = 291573500000000000000;
const mediumSum = 485955800000000000000;
const biggerSum = 971911700000000000000;
const biggestSum = 1943823500000000000000;

module.exports = function(deployer, network, accounts) {
  let wallet, token;

  wallet = accounts[0];

  console.log(wallet);

  deployer.deploy(Token, totalSupply, decimals, name, symbol).then((instance) => {
  	token = instance;

  	console.log(token.address);

  	deployer.deploy(Allocation, rate, wallet, token.address, softCap, hardCap, startTime, endTime, smallestSum, smallerSum, mediumSum, biggerSum, biggestSum)
  		.then((instance) => {
  			console.log(instance.address);
  		});
  });
};