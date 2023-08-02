// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "hardhat/console.sol";

contract FanTiger is
    ERC1155Upgradeable,
    PausableUpgradeable,
    OwnableUpgradeable
{
    event NewNftTierCreated(uint256 indexed tierID);
    event NFTTierExhausted(uint256 indexed tierID);
    event CreatedMarketPlace(address indexed marketPlaceAddress);
    event RemovedMarketPlace(address indexed marketPlaceAddress);
    event TierURI(uint256 tierID, string tierURI);

    struct Tier {
        bool exists;
        bool mintable;
        uint64 nftTokenCurrentSupply;
        uint64 maxNFTTokenSupply;
    }

    // Storing the uri of the tier
    mapping(uint256 => string) _tierURIs;

    // TierID => tier details
    // TierID is 128 bits but rounded up to 256 bits
    mapping(uint256 => Tier) public tierData;

    // tokenID => owner of the token
    mapping(uint256 => address) internal nftTokenOwner;

    // Storing the list of the marketplace address where the user is allowed to sell his nft
    address[] private marketPlaceAddresses;
    // Here the index of the marketplace address is stored in one indexing
    mapping(address => uint256) marketPlaceAddressIndex;

    function initialize(string memory nftMetadataURI) public virtual initializer {
        __ERC1155_init(nftMetadataURI);
        __Pausable_init();
        __Ownable_init();
    }

    // Get the owner of a given nft
    function nftOwnerAddress(uint256 nftTokenID)
        external
        view
        returns (address)
    {
        address nftOwner = nftTokenOwner[nftTokenID];
        return nftOwner;
    }

    function readTierData(uint256 tierID)
        public
        view
        returns (
            bool,
            bool,
            uint64,
            uint64
        )
    {
        Tier memory tierInformation = tierData[tierID];
        return (
            tierInformation.exists,
            tierInformation.mintable,
            tierInformation.nftTokenCurrentSupply,
            tierInformation.maxNFTTokenSupply
        );
    }

    // Need to check which is cheap, storing addresses into an array or creating a map of index to array

    /**
        Adding a new marketplace for the user to trade upon. 
    */
    function addMarketPlaceAddress(address marketPlaceAddress)
        external
        onlyOwner
        whenNotPaused
    {
        require(marketPlaceAddress != address(0), "Null Address");
        require(
            marketPlaceAddressIndex[marketPlaceAddress] == 0,
            "MarketPlace address already exists"
        );
        marketPlaceAddressIndex[marketPlaceAddress] =
            marketPlaceAddresses.length +
            1;
        marketPlaceAddresses.push(marketPlaceAddress);
        emit CreatedMarketPlace(marketPlaceAddress);
    }

    /**
        Remove a marketplace, on which the user was allowed to list his nfts upon.
     */
    function deleteMarketPlaceAddress(address marketPlaceAddress)
        external
        onlyOwner
        whenNotPaused
    {
        require(marketPlaceAddress != address(0), "Null Address");
        require(
            marketPlaceAddressIndex[marketPlaceAddress] != 0,
            "MarketPlace address does not exists"
        );

        // Gettting the array index and the index of the last element
        uint256 index = marketPlaceAddressIndex[marketPlaceAddress] - 1;
        uint256 lastIndex = marketPlaceAddresses.length - 1;

        // Swapping to be deleted element with the last element and deleting it from the array
        if (index != lastIndex) {
            address lastIndexAddress = marketPlaceAddresses[lastIndex];
            marketPlaceAddresses[index] = lastIndexAddress;
            marketPlaceAddressIndex[lastIndexAddress] = index + 1;
        }
        marketPlaceAddresses.pop();
        delete (marketPlaceAddressIndex[marketPlaceAddress]);
        emit RemovedMarketPlace(marketPlaceAddress);
    }

    /**
        Creating a new tier, with the maximum supply mentioned.
     */
    function createNewNFTTier(uint256 tierID, uint256 maxSupply)
        external
        onlyOwner
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
        Mint a token of the tierId into the contract owner controlled wallet.
     */
    function mintNFTToWallet(
        address mintWalletAddress,
        uint256 nftTokenId,
        bytes calldata data
    ) external onlyOwner whenNotPaused {
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
        Mint multiple tokens of a tier together into a wallet controlled by the owner contract. 
     */
    function batchMintNFTToWallet(
        address mintWalletAddress,
        uint256 tierID,
        uint256[] calldata nftIDs,
        bytes calldata data
    ) external onlyOwner whenNotPaused {
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

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
        for (uint256 i = 0; i < ids.length; i++) {
            // In case of minting, the require condition would have been flagged already if we would have sent already minted nft tokens,
            // but except the case of duplicate elements in the batch nft ID variable, where this wouldn't have been flagged, and
            // if this condition is false means that there are duplicate elements in the sent ids array during minting.
            if (from == address(0)) {
                require(
                    nftTokenOwner[ids[i]] == address(0),
                    "Duplicate nftIDs sent"
                );
            }
            nftTokenOwner[ids[i]] = to;
        }
    }

    /**
        Adding marketplace integration for all the list of the marketplaces added in the list.
        Ref https://docs.opensea.io/docs/polygon-basic-integration by Krishna
     */
    function isApprovedForAll(address _owner, address _operator)
        public
        view
        override
        returns (bool)
    {
        uint256 length = marketPlaceAddresses.length;
        for (uint256 i = 0; i < length; i++) {
            if (marketPlaceAddresses[i] == _operator) {
                return true;
            }
        }
        return ERC1155Upgradeable.isApprovedForAll(_owner, _operator);
    }

    function updateNftURI(string calldata nftMetaDataURI)
        public
        onlyOwner
        whenNotPaused
    {
        _setURI(nftMetaDataURI);
    }

    function setTierUri(uint256 tierID, string calldata tierURI)
        public
        onlyOwner
        whenNotPaused
    {
        require(tierID > 0, "Tier ID is 0");
        require(bytes(tierURI).length > 0, "Tier URI is empty");
        require(tierData[tierID].exists, "Tier is not registered");
        _tierURIs[tierID] = tierURI;
        emit TierURI(tierID, tierURI);
    }

    function getTierUri(uint128 tierID) public view returns (string memory) {
        return _tierURIs[uint256(tierID)];
    }

    /**
     * @dev See {IERC1155MetadataURI-uri}.
     *
     * This implementation returns the tierURI, and if it is not set then returns the baseURI.
     *
     * This enables the following behaviors:
     *
     * - if `_tierURIs[tierId]` is set, then the result is _tierURIs[tierId]
     *
     * - if `_tierURIs[tierId]` is NOT set or tier does not exists then we fallback to `super.uri()`
     *   which in most cases will contain `ERC1155._uri`;
     *
     * - if `_tierURIs[tierId]` is NOT set, and if the parents do not have a
     *   uri value set, then the result is empty.
     */
    function uri(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        uint256 tierID = tokenId >> 128;
        string memory tokenURI = _tierURIs[tierID];
        if (tierData[tierID].exists && bytes(tokenURI).length > 0)
            return tokenURI;
        else return super.uri(tokenId);
    }

    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() public onlyOwner whenPaused {
        _unpause();
    }
}
