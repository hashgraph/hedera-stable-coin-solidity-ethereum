const HDWalletProvider = require("@truffle/hdwallet-provider");
const { API_KEY, MNEMONIC } = require("./secrets.json");

// Deployed Contract (Ropsten)
// 0x42E9d6514D613D63c8c32cE385aad3dE9917C681

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
        return new HDWalletProvider(
          MNEMONIC,
          `https://ropsten.infura.io/v3/${API_KEY}`
        );
      },
      network_id: "3",
      gas: 4000000, // Max Allowed
      skipDryRun: true
    },
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
