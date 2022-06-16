// SPDX-License-Identifier: MIT
// Creator: DDD(DeDogma DAO)

pragma solidity 0.8.4;

// CollectiGame : Collectible + Game
// interface of NFT.sol for interacting with it from other contracts
interface ICollectiGame {
    struct ContractState {
        bool initialized;
        bool auctionIsActive;
        bool whitelistMintingIsActive;
        bool mintingIsActive;
        bool artIsRevealed;
        bool finished;
    }

    struct ContractIPFS {
        string godCID;
        string notRevealedArtCID;
        string artCID;
    }

    struct RoyaltyInfo {
        address recipient;
        uint8 percent;
    }

    struct AuctionConfig {
        uint256 startPrice; // in wei
        uint256 endPrice; // in wei
        uint256 auctionDropPerStep; // in wei
    }
    struct Auction {
        uint8 tokenId;
        uint256 startAt; // epoch time
        uint256 expireAt; // epoch time
        uint256 startPrice; // in wei
        uint256 endPrice; // in wei
        uint256 auctionDropPerStep; // in wei
        bool isSold;
        uint256 purchasedPrice; // in wei
        address owner;
    }

    struct ContractAddresses {
        address daoTreasuryContract;
        address whiteListVerifier;
        address gameTreasuryContract;
    }

    function MAX_SUPPLY() external view returns (uint16);

    function getState() external view returns (ContractState memory);

    function getAddresses() external view returns (ContractAddresses memory);

    function MINT_PRICE_IN_WEI() external view returns (uint256);

    function NUMBER_OF_TOKEN_FOR_AUCTION() external view returns (uint8);
}
