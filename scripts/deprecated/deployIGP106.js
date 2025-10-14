const hre = require("hardhat");
const { ethers } = hre;

async function main() {
  const PayloadIGP106 = await ethers.getContractFactory("PayloadIGP106")
  const payloadIGP106 = await PayloadIGP106.deploy()
  await payloadIGP106.deployed()

  console.log("PayloadIGP106: ", payloadIGP106.address)

  await hre.run("verify:verify", {
    address: payloadIGP106.address,
    constructorArguments: []
  })
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
