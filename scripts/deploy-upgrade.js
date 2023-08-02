const { ethers, upgrades } = require('hardhat');
const fs = require('fs');

async function setProxyAddresses(configUpgrade,contract_name,contract_address) {
    configUpgrade[contract_name+"_PROXY_CONTRACT_ADDRESS"] = contract_address;
    configUpgrade[contract_name+"_CONTRACT_ADDRESS"] = await hre.upgrades.erc1967.getImplementationAddress(contract_address);
    configUpgrade[contract_name+"_PROXY_ADMIN_CONTRACT_ADDRESS"] = await hre.upgrades.erc1967.getAdminAddress(contract_address);
}

async function main () {
  [owner] = await ethers.getSigners();
  configUpgrade = {
    "OWNER_ADDRESS" : owner.address
    }
  const FanTigerV2 = await ethers.getContractFactory('FanTigerV2');
  console.log('Upgrading FanTiger...');
  const nft_contract = await upgrades.upgradeProxy('0x2e1F68189d358cf70dd90978568Ed797D0267F37', FanTigerV2);
  await nft_contract.deployed()
  console.log(nft_contract.address);


  console.log('FanTiger upgraded');

  await setProxyAddresses(configUpgrade,"FANTIGER",nft_contract.address);
  fs.writeFileSync('./scripts/configUpgrade.json',JSON.stringify(configUpgrade,null,4),{encoding: 'utf8',flag: 'w'});


}

main();