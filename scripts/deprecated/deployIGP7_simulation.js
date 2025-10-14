const hre = require("hardhat");
const { ethers } = hre;

async function main() {
  const oldTimelockAddress = "0xC7Cb1dE2721BFC0E0DA1b9D526bCdC54eF1C0eFC"
  const guardain = "0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e"

  const governorDelegate = await ethers.deployContract("InstaGovernorBravoDelegate")

  await governorDelegate.waitForDeployment()

  console.log(governorDelegate)

  const timelock = await ethers.deployContract("InstaTimelock", [oldTimelockAddress, guardain])

  await timelock.waitForDeployment()
  
  const payload = await ethers.deployContract("PayloadIGP7", [governorDelegate.target, timelock.target])
  await payload.waitForDeployment()

  const payload2 = await ethers.deployContract("PayloadIGP8Mock", [governorDelegate.target, timelock.target])
  await payload2.waitForDeployment()

  console.log("InstaTimelock: ", timelock.target)
  console.log("InstaGovernorBravoDelegate: ", governorDelegate.target)
  console.log("PayloadIGP7: ", payload.target)
  console.log("PayloadIGP8Mock: ", payload2.target)
  console.log()

  await hre.run("verify:verify", {
    address: governorDelegate.target,
    constructorArguments: []
  })

  await hre.run("verify:verify", {
    address: timelock.target,
    constructorArguments: [oldTimelockAddress, guardain]
  })
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
