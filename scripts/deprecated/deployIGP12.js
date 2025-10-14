const hre = require("hardhat");
const { ethers } = hre;

async function main() {
  const PayloadIGP12 = await ethers.getContractFactory("PayloadIGP12")
  const payloadIGP12 = await PayloadIGP12.deploy()
  await payloadIGP12.deployed()

  console.log("PayloadIGP12: ", payloadIGP12.address)

  await hre.run("verify:verify", {
    address: payloadIGP12.address,
    constructorArguments: []
  })
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
