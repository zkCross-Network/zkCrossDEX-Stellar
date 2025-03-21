require('@nomiclabs/hardhat-ethers');
require('@openzeppelin/hardhat-upgrades');

module.exports = {
  solidity: "0.8.26",
  networks: {
    hardhat: {},

    bnb_testnet: {
      url: `https://data-seed-prebsc-1-s1.binance.org:8545/`,
      accounts: [""]
    },
    sepolia: {
      url:"https://sepolia.infura.io/v3/952e156dc5a248d6943be946e034cc89",
      accounts: [""],
    },
  }
};

