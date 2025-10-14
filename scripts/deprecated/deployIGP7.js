const hre = require("hardhat");
const { ethers } = hre;

async function main() {
  const oldTimelockAddress = "0xC7Cb1dE2721BFC0E0DA1b9D526bCdC54eF1C0eFC"
  const guardain = "0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e"

  const Timelock = await ethers.getContractFactory("InstaTimelock")
  const timelock = await Timelock.deploy(oldTimelockAddress, guardain)
  await timelock.deployed()

  const GovernorDelegate = await ethers.getContractFactory("InstaGovernorBravoDelegate")
  const governorDelegate = await GovernorDelegate.deploy()
  await governorDelegate.deployed()

  const PayloadIGP7 = await ethers.getContractFactory("PayloadIGP7")
  const payloadIGP7 = await PayloadIGP7.deploy(governorDelegate.address, timelock.address)
  await payloadIGP7.deployed()

  console.log("PayloadIGP7: ", payloadIGP7.address)
  console.log("InstaTimelock: ", timelock.address)
  console.log("InstaGovernorBravoDelegate: ", governorDelegate.address)


  await hre.run("verify:verify", {
    address: timelock.address,
    constructorArguments: [oldTimelockAddress, guardain]
  })

  await hre.run("verify:verify", {
    address: governorDelegate.address,
    constructorArguments: []
  })

  await hre.run("verify:verify", {
    address: payloadIGP7.address,
    constructorArguments: [governorDelegate.address, timelock.address]
  })
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
