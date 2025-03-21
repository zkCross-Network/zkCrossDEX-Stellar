const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  const Swapper = await ethers.getContractFactory("Swapper");
  const swapper = await upgrades.deployProxy(Swapper, [deployer.address], { initializer: "initialize" });
  await swapper.waitForDeployment();
  const swapperProxyAddress = await swapper.target;
  console.log("Proxy Swapper deployed to:", swapperProxyAddress);
  
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
