require('babel-register');
require('babel-polyfill');

module.exports = {
  networks: {
    localhost: {
      host: "localhost", 
      port: 7545,
      network_id: "5777" 
    }
  }
};