const HDWalletProvider = require("truffle-hdwallet-provider");
const MNEMONIC = "";
const API_KEY = "";

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
