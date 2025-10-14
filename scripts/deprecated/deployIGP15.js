const hre = require("hardhat");
const { ethers } = hre;

async function main() {
  const PayloadIGP15 = await ethers.getContractFactory("PayloadIGP15")
  const payloadIGP15 = await PayloadIGP15.deploy()
  await payloadIGP15.deployed()

  console.log("PayloadIGP15: ", payloadIGP15.address)

  await hre.run("verify:verify", {
    address: payloadIGP15.address,
    constructorArguments: []
  })
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
