const hre = require("hardhat");
const fs = require('fs');
const { ethers } = require("hardhat");

BASE_TOKEN_URI = 'https://assets.artistfirst.in/meta-data/early-access-fantiger-nft/{id}.json'

async function setProxyAddresses(config,contract_name,contract_address) {
  config[contract_name+"_PROXY_CONTRACT_ADDRESS"] = contract_address;
  config[contract_name+"_CONTRACT_ADDRESS"] = await hre.upgrades.erc1967.getImplementationAddress(contract_address);
  config[contract_name+"_PROXY_ADMIN_CONTRACT_ADDRESS"] = await hre.upgrades.erc1967.getAdminAddress(contract_address);
}

async function deployFanTigerContract(config) {
  const contractFactory= await hre.ethers.getContractFactory("FanTiger");
  const nft_contract = await hre.upgrades.deployProxy(contractFactory, [BASE_TOKEN_URI],{kind:"transparent"});
  console.log(nft_contract.address);
  await nft_contract.deployed();
  await setProxyAddresses(config,"FANTIGER",nft_contract.address);
  return nft_contract;
}

async function main() {

  [owner] = await ethers.getSigners();
  config = {
    "OWNER_ADDRESS" : owner.address
    // "PAYMENT_WALLET_ADDRESS" : '0xb16F8DB9421Dd6940571c27356a328B498D7c86c',
    // "NFT_WALLET_ADDRESS" : '0x9FFF4734D40A5F6c9C02Af9239a2Cfb6cD8724F0'
  }

  tx = await deployFanTigerContract(config);
  console.log('NFT Contract',tx);
  // tx = await deployPrimaryPurchaseContract(config);
  // console.log('Primary Purchase',tx);
  console.log(config);
  fs.writeFileSync('./scripts/config.json',JSON.stringify(config,null,4),{encoding: 'utf8',flag: 'w'});
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });

  //0x594B32E3A4cBF6A801a78Cc8a84E86b5E522dbFa