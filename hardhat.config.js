require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 999999
          }
        }
      },
    ]
  },
  networks: {
    stableNet: {
      url: `${process.env.URL}`,
    },
    localhost: {
      url: 'http://127.0.0.1:8545',
    },
  }
};