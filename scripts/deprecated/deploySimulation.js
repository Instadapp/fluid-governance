const hre = require("hardhat");
const { ethers } = hre;

async function main() {
  const payload = await ethers.deployContract("PayloadIGP16", [])
  await payload.waitForDeployment()

  console.log("PayloadIGP16: ", payload.target)
  console.log()
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
