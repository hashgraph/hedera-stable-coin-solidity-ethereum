### StableCoin Smart Contract

ERC20 Externally Minted Token with Access Control

Developed using OpenZeppelin CLI and the Truffle Suite

##### Setup

You'll need Yarn, the Open Zeppelin CLI and the Truffle Suite to set up the development environment. I also recommend using NVM for managing the Node Version you are currently using.

- [NVM](https://github.com/nvm-sh/nvm)

- [Yarn](https://classic.yarnpkg.com/en/docs/)

- [OpenZeppelin CLI](https://docs.openzeppelin.com/cli/2.8/)

- [Truffle Suite](https://www.trufflesuite.com/)

- [Using OZ CLI w/ Truffle](https://docs.openzeppelin.com/cli/2.8/truffle)

##### Commands

- `yarn` installs dependencies

- `yarn oz compile` uses the openzeppelin cli (**and oz sdk**) to compile the solidity contracts.

- `yarn truffle compile` uses truffle to compile the solidity contracts

- `yarn test` runs mocha/chai/oz tests inside of a managed test environment

- `yarn network:truffle` sets up the local development network via truffle

- `yarn network:ganache` sets up the local development network via ganache cli

- `yarn deploy` runs the openzeppelin deployment in interactive mode

- `yarn deploy:truffle` deploys the compiled smart contract to the local truffle development network

- `yarn deploy:ganache` deploys the compiled smart contract to the local ganache development network

Network information is defined in truffle-config.js, which is read by openzeppelin CLI automatically.

SOLC 0.6.8 used as compiler for both the oz sdk and truffle

##### Contract

- ERC20, Ownable, Claimable, Pausable

- RBAC for Supply, Asset Protection, KYC, Frozen
