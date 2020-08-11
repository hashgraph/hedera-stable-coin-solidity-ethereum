module.exports = {
  plugins: ["solidity-coverage"],

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
