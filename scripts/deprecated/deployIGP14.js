const hre = require("hardhat");
const { ethers } = hre;

async function main() {
  const PayloadIGP14 = await ethers.getContractFactory("PayloadIGP14")
  const payloadIGP14 = await PayloadIGP14.deploy()
  await payloadIGP14.deployed()

  console.log("PayloadIGP14: ", payloadIGP14.address)

  await hre.run("verify:verify", {
    address: payloadIGP14.address,
    constructorArguments: []
  })
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
