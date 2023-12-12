
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

  const ZKFRewardContractFactory = await ethers.getContractFactory("ZKFRewardContract", deployer);
  let ZKFRewardContract;
  if (deployOutput.ZKFRewardContract === undefined || deployOutput.ZKFRewardContract === '') {
    ZKFRewardContract = await upgrades.deployProxy(
      ZKFRewardContractFactory,
      [
      ],
      {
      constructorArgs: [
        process.env.PROPOSAL_AUTHORITY,
        process.env.REVIEW_AUTHORITY,
        process.env.REWARD_SPONSOR,
      ],
      unsafeAllow: ['constructor', 'state-variable-immutable'],
    });
    console.log('tx hash:', ZKFRewardContract.deploymentTransaction().hash);
  } else {
    ZKFRewardContract = ZKFRewardContractFactory.attach(deployOutput.ZKFRewardContract);
  }

  deployOutput.ZKFRewardContract = ZKFRewardContract.target;
  fs.writeFileSync(pathOutputJson, JSON.stringify(deployOutput, null, 1));
  console.log('#######################\n');
  console.log('ZKFRewardContract deployed to:', ZKFRewardContract.target);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });