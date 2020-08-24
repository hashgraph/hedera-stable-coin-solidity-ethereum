const HDWalletProvider = require("truffle-hdwallet-provider");
const MNEMONIC = "d4907ee0ea57460e8e22314c4d03f1a5";
const API_KEY = "3a8c65248272416a858dadbbb66c05a4";

module.exports = {
  networks: {
    ganache: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*",
    },
    truffle: {
      host: "127.0.0.1",
      port: 9545,
      network_id: "*",
    },
    ropsten: {
        provider: function() {
            return new HDWalletProvider(MNEMONIC, `https://ropsten.infura.io/${API_KEY}`)
        },
        network_id: 3,
        gas: 4000000 // Max Allowed
    }
  },

  compilers: {
    solc: {
      version: "0.6.8",
      docker: false,
      settings: {
        optimizer: {
          enabled: true,
          runs: 2000,
        },
        evmVersion: "constantinople",
      },
    },
  },
};
