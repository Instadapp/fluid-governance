const hre = require("hardhat");
const { ethers } = hre;

async function main() {
  const PayloadIGP109 = await ethers.getContractFactory("PayloadIGP109")
  const payloadIGP109 = await PayloadIGP109.deploy()
  await payloadIGP109.deployed()

  console.log("PayloadIGP109: ", payloadIGP109.address)

  if (hre.network.name != "mainnet_simulation") {
    await hre.run("verify:verify", {
      address: "0x1ee01058bf39C1daAe1DED16Da06C007117A9e5c",
        constructorArguments: []
    })
  }
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
