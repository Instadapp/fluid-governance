const hre = require("hardhat");
const { ethers } = hre;

async function main() {
  const PayloadIGP9 = await ethers.getContractFactory("PayloadIGP9")
  const payloadIGP9 = await PayloadIGP9.deploy()
  await payloadIGP9.deployed()

  console.log("PayloadIGP9: ", payloadIGP9.address)

  await hre.run("verify:verify", {
    address: payloadIGP9.address,
    constructorArguments: []
  })
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
