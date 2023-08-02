// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./FanTiger.sol";

import "hardhat/console.sol";

contract FanTigerV2 is
    FanTiger,
    AccessControlUpgradeable
{
    bytes32 public constant DEV = keccak256("DEV");

    function initialize(string memory nftMetadataURI) public override initializer {
        super.initialize(nftMetadataURI);
        _grantRole(DEFAULT_ADMIN_ROLE );
    }
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

     /**
        version V2
        Create a new Tier
    */
    function createNewNFTTierV2(uint256 tierID, uint256 maxSupply)
        external
        onlyRole(DEV)
        whenNotPaused
    {
        Tier memory tierInformation = tierData[tierID];
        require(
            tierID > 0 && tierID < 0x100000000000000000000000000000000,
            "Invalid tierID"
        );
        require(
            maxSupply > 0 && maxSupply < 0x10000000000000000,
            "Max Supply not in bounds"
        );
        require(!tierInformation.exists, "Tier Already Exists");
        tierInformation.exists = true;
        tierInformation.mintable = true;
        tierInformation.maxNFTTokenSupply = uint64(maxSupply);
        tierData[tierID] = tierInformation;
        emit NewNftTierCreated(uint128(tierID));
    }

    /**
        version V2
        Mint NFT
     */
     function mintNFTToWalletV2(
        address mintWalletAddress,
        uint256 nftTokenId,
        bytes calldata data
    ) external onlyRole(DEV) whenNotPaused {
        uint256 tierID = nftTokenId >> 128;
        Tier memory tierInformation = tierData[tierID];

        require(mintWalletAddress != address(0), "The Wallet Address is 0");
        require(tierInformation.exists, "Tier does not exists");
        require(tierInformation.mintable, "Tier has already been exhausted");
        require(
            nftTokenOwner[nftTokenId] == address(0),
            "Token Already Minted"
        );

        // Updating the Tier Information Data to prevent reentrancy attacks
        tierInformation.nftTokenCurrentSupply += 1;
        if (
            tierInformation.maxNFTTokenSupply ==
            tierInformation.nftTokenCurrentSupply
        ) {
            tierInformation.mintable = false;
        }
        tierData[tierID] = tierInformation;
        _mint(mintWalletAddress, nftTokenId, 1, data);

        if (!tierInformation.mintable) {
            emit NFTTierExhausted(tierID);
        }
    }

    /**
        version V2
        BatchMint NFT
     */
    function batchMintNFTToWalletV2(
        address mintWalletAddress,
        uint256 tierID,
        uint256[] calldata nftIDs,
        bytes calldata data
    ) external onlyRole(DEV) whenNotPaused {
        uint256 length = nftIDs.length;
        Tier memory tierInformation = tierData[tierID];
        require(
            tierID > 0 && tierID < 0x100000000000000000000000000000000,
            "Tier ID invalid"
        );
        require(mintWalletAddress != address(0), "The Wallet Address is 0");
        require(tierInformation.exists, "Tier does not exists");
        require(length > 0, "Empty list of token id for nfts");
        require(
            tierInformation.maxNFTTokenSupply >=
                tierInformation.nftTokenCurrentSupply + length,
            "Minting more tokens than supply"
        );

        uint256[] memory amounts = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            require(
                (nftIDs[i] >> 128) == tierID,
                "NFT doesn't belong to given tier"
            );
            require(
                nftTokenOwner[nftIDs[i]] == address(0),
                "Token Already Minted"
            );
            amounts[i] = 1;
        }

        // Preventing Re-entrancy attacks
        tierInformation.nftTokenCurrentSupply += uint64(length);
        if (
            tierInformation.nftTokenCurrentSupply ==
            tierInformation.maxNFTTokenSupply
        ) {
            tierInformation.mintable = false;
        }
        tierData[tierID] = tierInformation;

        _mintBatch(mintWalletAddress, nftIDs, amounts, data);

        if (!tierInformation.mintable) {
            emit NFTTierExhausted(tierID);
        }
    }
}
