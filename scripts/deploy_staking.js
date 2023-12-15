
const { ethers } = require('hardhat');

const path = require('path');
const fs = require('fs');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const pathOutputJson = path.join(__dirname, '../deploy_output.json');
let deployOutput = {};
if (fs.existsSync(pathOutputJson)) {
  deployOutput = require(pathOutputJson);
}


async function main() {
  let deployer = new ethers.Wallet(process.env.PRIVATE_KEY, ethers.provider);
  console.log(await deployer.getAddress())

  const stakingContractFactory = await ethers.getContractFactory("StakingContract", deployer);

  let stakingContract;
  if (deployOutput.stakingContract === undefined || deployOutput.stakingContract === '') {
    stakingContract = await upgrades.deployProxy(
      stakingContractFactory,
      [
        process.env.TOKEN_ADDRESS,
      ],
    );
    console.log('tx hash:', stakingContract.deployTransaction.hash);
  } else {
    stakingContract = stakingContractFactory.attach(deployOutput.stakingContract);
  }

  deployOutput.stakingContract = stakingContract.address;
  fs.writeFileSync(pathOutputJson, JSON.stringify(deployOutput, null, 1));
  console.log('#######################\n');
  console.log('StakingContract deployed to:', stakingContract.address);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });