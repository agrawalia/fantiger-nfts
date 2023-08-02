/** @type import('hardhat/config').HardhatUserConfig */
require('@openzeppelin/hardhat-upgrades');
require('@nomiclabs/hardhat-ethers');
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("solidity-coverage");
require("hardhat-gas-reporter");
require("dotenv").config();
const { POLYGON_MUMBAI_RPC_PROVIDER, PRIVATE_KEY, POLYGONSCAN_API_KEY } = process.env;

module.exports = {
  solidity: "0.8.19",

  networks: {
    "mumbai-testnet": {
      url : "https://polygon-mumbai.g.alchemy.com/v2/rB9A_YUgVpq6HOeK6RfA47aW6EHzgH_0",
      accounts: ["a20ed3fe416bad3c6f7f4c784340729737cf2d165f7a0927e536e4b389e8ef6a"],
      gas: 2100000,
      gasPrice: 60000000000
    },
  },
  etherscan: {
    apiKey: 'Q5YZDYV21G92RJVUSVZNEP6HZJI52G1UBG',
 },

  solidity: {
    compilers : [
      {
        version: "0.8.4",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      }
    ]
  },
  mocha: {
    timeout: 3000000
  },
  gasReporter: {
    enabled: true
  }
};
