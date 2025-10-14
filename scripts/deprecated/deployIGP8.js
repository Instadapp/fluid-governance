const hre = require("hardhat");
const { ethers } = hre;

async function main() {
  const PayloadIGP8 = await ethers.getContractFactory("PayloadIGP8")
  const payloadIGP8 = await PayloadIGP8.deploy()
  await payloadIGP8.deployed()

  console.log("PayloadIGP8: ", payloadIGP8.address)

  await hre.run("verify:verify", {
    address: payloadIGP8.address,
    constructorArguments: []
  })
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
