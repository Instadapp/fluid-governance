const hre = require("hardhat");
const { ethers } = hre;

async function main() {
  const PayloadIGP16 = await ethers.getContractFactory("PayloadIGP16")
  const payloadIGP16 = await PayloadIGP16.deploy()
  await payloadIGP16.deployed()

  console.log("PayloadIGP16: ", payloadIGP16.address)

  await hre.run("verify:verify", {
    address: payloadIGP16.address,
    constructorArguments: []
  })
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
