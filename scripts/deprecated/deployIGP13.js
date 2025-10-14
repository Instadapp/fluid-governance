const hre = require("hardhat");
const { ethers } = hre;

async function main() {
  const PayloadIGP13 = await ethers.getContractFactory("PayloadIGP13")
  const payloadIGP13 = await PayloadIGP13.deploy()
  await payloadIGP13.deployed()

  console.log("PayloadIGP13: ", payloadIGP13.address)

  await hre.run("verify:verify", {
    address: payloadIGP13.address,
    constructorArguments: []
  })
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
