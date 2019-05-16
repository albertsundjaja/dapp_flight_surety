var HDWalletProvider = require("truffle-hdwallet-provider");
var mnemonic = "fiscal picnic also favorite dove step copper similar season label approve best";

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",     // Localhost (default: none)
      port: 8545,            // Standard Ethereum port (default: none)
      network_id: "*", 
      gas: 4600000
    }
  },
  compilers: {
    solc: {
      version: "0.5.2"
    }
  }
};