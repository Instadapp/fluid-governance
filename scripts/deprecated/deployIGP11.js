const hre = require("hardhat");
const { ethers } = hre;

async function main() {
  const PayloadIGP11 = await ethers.getContractFactory("PayloadIGP11")
  const payloadIGP11 = await PayloadIGP11.deploy()
  await payloadIGP11.deployed()

  console.log("PayloadIGP11: ", payloadIGP11.address)

  await hre.run("verify:verify", {
    address: payloadIGP11.address,
    constructorArguments: []
  })
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
