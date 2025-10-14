const hre = require("hardhat");
const { ethers } = hre;

async function main() {
  const PayloadIGP10 = await ethers.getContractFactory("PayloadIGP10")
  const payloadIGP10 = await PayloadIGP10.deploy()
  await payloadIGP10.deployed()

  console.log("PayloadIGP10: ", payloadIGP10.address)

  await hre.run("verify:verify", {
    address: payloadIGP10.address,
    constructorArguments: []
  })
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
