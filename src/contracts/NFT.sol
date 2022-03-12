// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import './ERC721A.sol';
import './Ownable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

// TODO: receive and fall back
// TODO: good require message
// TODO: proper name for functions and variables
// TODO: add proper Event to functions
// TODO: set getter and setter for variables if needed
// ToDo: attention to eip165
// TODO: check 2982 correctness of implementation
// TODO: add NatSpec in above of the function
// TODO: add https://www.npmjs.com/package/@primitivefi/hardhat-dodoc to project
// TODO: add unit test and using this https://www.npmjs.com/package/hardhat-gas-trackooor or https://www.npmjs.com/package/hardhat-gas-reporter + dapp snapshot
contract NFT is ERC721A, Ownable, ReentrancyGuard {
    using ECDSA for bytes32;

    // ███╗░░██╗███████╗██████╗░░█████╗░██╗░░░░░███████╗██╗░█████╗░
    // ████╗░██║██╔════╝██╔══██╗██╔══██╗██║░░░░░██╔════╝██║██╔══██╗
    // ██╔██╗██║█████╗░░██████╔╝██║░░██║██║░░░░░█████╗░░██║███████║
    // ██║╚████║██╔══╝░░██╔═══╝░██║░░██║██║░░░░░██╔══╝░░██║██╔══██║
    // ██║░╚███║███████╗██║░░░░░╚█████╔╝███████╗███████╗██║██║░░██║
    // ╚═╝░░╚══╝╚══════╝╚═╝░░░░░░╚════╝░╚══════╝╚══════╝╚═╝╚═╝░░╚═╝

    uint16 public immutable MaxSupply;
    uint256 public UpgradeRequestFeeInWei;

    struct ContractState {
        bool Initialized;
        bool AuctionIsActive;
        bool WhiteListMintingIsActive;
        bool MintingIsActive;
        bool ArtIsRevealed;
        bool Finished;
    }
    ContractState public STATE;

    modifier whileAuctionIsActive() {
        require(STATE.AuctionIsActive, 'Auction is not active');
        _;
    }
    modifier whileMintingIsActive() {
        require(STATE.MintingIsActive, 'Minting is not active');
        _;
    }
    modifier whileWhiteListMintingIsActive() {
        require(STATE.WhiteListMintingIsActive, 'WhiteListMinting is not active');
        _;
    }
    modifier whileMintingDone() {
        require(STATE.Finished, 'Minting is not finished');
        require(STATE.Initialized, 'Contract is not initialized');
        _;
    }

    struct ContractAddresses {
        address Owner;
        address Platform;
        address DefiTitan;
        address BuyBackTreasury;
        address WhiteListVerifier;
        address RoyaltyDistributor;
    }

    ContractAddresses public ADDRESS;

    modifier onlyPlatform() {
        require(ADDRESS.Platform == _msgSender(), 'Only platform address can call this function');
        _;
    }
    modifier onlyDefiTitan() {
        require(ADDRESS.DefiTitan == _msgSender(), 'Only defi titan address can call this function');
        _;
    }

    struct ContractIPFS {
        string GodCID;
        string NotRevealedArtCID;
        string ArtCID;
    }

    ContractIPFS public IPFS;

    mapping(uint16 => bool) public TokenIsUpgraded;
    mapping(uint16 => string) private _UpgradedTokenCID;

    mapping(uint16 => bool) public TokenIsGod;

    modifier onlyHuman(uint16 tokenId_) {
        require(TokenIsGod[tokenId_] == false, 'this function is only functional for humans');
        _;
    }

    struct ContactMintConfig {
        uint256 MintPriceInWei;
        uint16 MaxMintPerAddress;
        uint256 AuctionStartTime;
        uint256 AuctionDuration;
        uint8 NumberOFTokenForAuction;
        uint8 RoyaltyFeePercent;
    }

    ContactMintConfig public MINTING_CONFIG;

    constructor(
        uint16 maxSupply_,
        ContractAddresses memory addresses_,
        string memory godCID_,
        string memory notRevealedArtCID_,
        ContactMintConfig memory mintConfig_,
        uint256 upgradeRequestFeeInWei_
    ) ERC721A('NepoleiaNFT', 'NepoleiaNFT') Ownable(addresses_.Owner) {
        MaxSupply = maxSupply_;
        STATE = ContractState(false, false, false, false, false, false);
        ADDRESS = addresses_;
        IPFS.GodCID = godCID_;
        IPFS.NotRevealedArtCID = notRevealedArtCID_;
        MINTING_CONFIG = mintConfig_;
        UpgradeRequestFeeInWei = upgradeRequestFeeInWei_;
    }

    function initializer(AuctionConfig[] calldata configs) public onlyOwner {
        require(!STATE.Initialized, 'NFT: contract is already initialized');
        require(!STATE.Finished, 'NFT: contract is already finished');
        require(!STATE.AuctionIsActive, 'NFT: auction is already active');
        STATE.Initialized = true;
        _setupGodAuction(configs);
        STATE.AuctionIsActive = true;

        _setRoyalties(ADDRESS.RoyaltyDistributor, MINTING_CONFIG.RoyaltyFeePercent);
    }

    // auction management functions
    struct AuctionConfig {
        uint256 startPrice;
        uint256 endPrice;
        uint256 discountRate;
    }
    struct Auction {
        uint8 tokenID;
        uint256 startTime;
        uint256 expiresAt;
        uint256 startPrice;
        uint256 endPrice;
        uint256 discountRate;
    }

    // in each day we have one auction
    mapping(uint8 => Auction) public Auctions;

    function buyGod(uint8 day) external payable whileAuctionIsActive {
        // buy god
        // require contract in the state of active auction
        require(1 <= day && day <= MINTING_CONFIG.NumberOFTokenForAuction, 'day is out of range');
        require(Auctions[day].startTime <= block.timestamp, 'auction is not started yet');
        require(Auctions[day].expiresAt >= block.timestamp, 'auction is expired');

        uint8 tokenId = day - 1;
        TokenOwnership memory ownership = ownershipOf(tokenId);
        require(ownership.addr == ADDRESS.DefiTitan, 'auction is has ended');

        Auction memory auction = Auctions[day];
        uint256 currentPrice = _getAuctionPrice(auction);

        require(currentPrice >= auction.endPrice, 'auction has ended because it receive to base price');
        require(currentPrice <= msg.value, 'not enough money');

        transferFrom(ADDRESS.DefiTitan, msg.sender, tokenId);

        _transferEth(ADDRESS.DefiTitan, msg.value);
    }

    function _getAuctionPrice(Auction memory auction_) internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - auction_.startTime;

        uint256 discount = auction_.discountRate * timeElapsed;

        return auction_.startPrice - discount;
    }

    function getAuctionPrice(uint8 day) external view whileAuctionIsActive returns (uint256) {
        require(1 <= day && day <= MINTING_CONFIG.NumberOFTokenForAuction, 'day is out of range');

        uint256 timeElapsed = block.timestamp - Auctions[day].startTime;

        uint256 discount = Auctions[day].discountRate * timeElapsed;
        return Auctions[day].startPrice - discount;
    }

    function _setupGodAuction(AuctionConfig[] memory configs) private {
        require(
            _totalMinted() + MINTING_CONFIG.NumberOFTokenForAuction <= MaxSupply,
            'not enough space for new auctions'
        );
        require(configs.length == MINTING_CONFIG.NumberOFTokenForAuction, 'configs must be the same length as count');

        _safeMint(ADDRESS.DefiTitan, MINTING_CONFIG.NumberOFTokenForAuction);

        // we need set first token id to the token sell in auction for CID availability.
        require(_totalMinted() == MINTING_CONFIG.NumberOFTokenForAuction, 'bad initialization of contract');

        for (uint8 i = 0; i < MINTING_CONFIG.NumberOFTokenForAuction; i++) {
            Auction memory _auction = Auction(
                i,
                MINTING_CONFIG.AuctionStartTime + MINTING_CONFIG.AuctionDuration * i,
                MINTING_CONFIG.AuctionStartTime + MINTING_CONFIG.AuctionDuration * (i + 1),
                configs[i].startPrice,
                configs[i].endPrice,
                configs[i].discountRate
            );
            Auctions[i + 1] = _auction;
            _defiTitanAuctionApproval(i);
            TokenIsGod[i] = true;
        }
    }

    function _defiTitanAuctionApproval(uint8 tokenId) private {
        TokenOwnership memory ownership = ownershipOf(tokenId);
        require(ownership.addr == ADDRESS.DefiTitan, 'this is work only for defi titan assets');
        _approve(address(this), tokenId, ADDRESS.DefiTitan);
    }

    // public minting functions
    function publicMint(uint256 quantity) external payable whileMintingIsActive {
        require(
            _numberMinted(msg.sender) + quantity <= MINTING_CONFIG.MaxMintPerAddress,
            'NFT: you have reached the maximum number of mints per address'
        );
        require(quantity * MINTING_CONFIG.MintPriceInWei <= msg.value, 'not enoughs ether');
        _safeMint(msg.sender, quantity);
        _transferEth(ADDRESS.BuyBackTreasury, msg.value);
    }

    // whitelist minting functions
    enum WhiteListType {
        Normal,
        Royal
    }

    function whitelistMinting(
        address addr_,
        uint8 maxQuantity_,
        uint64 quantity_,
        WhiteListType whiteListType_,
        bytes calldata sig
    ) external payable whileWhiteListMintingIsActive {
        require(isWhitelisted(addr_, maxQuantity_, whiteListType_, sig), 'signature is not valid');
        require(_totalMinted() + quantity_ <= MaxSupply, 'Max supply is reached');

        uint64 _aux = _getAux(addr_);

        require(_aux + quantity_ <= maxQuantity_, 'Quantity is not valid');

        if (whiteListType_ == WhiteListType.Royal) {
            _setAux(addr_, _aux + quantity_);
            _safeMint(addr_, quantity_);
        } else {
            require(quantity_ * MINTING_CONFIG.MintPriceInWei <= msg.value, 'Not enoughs ether.');
            _setAux(addr_, _aux + quantity_);
            _safeMint(addr_, quantity_);
        }
        if (msg.value > 0) {
            _transferEth(ADDRESS.BuyBackTreasury, msg.value);
        }
    }

    function isWhitelisted(
        address account_,
        uint8 maxQuantity_,
        WhiteListType whiteListType_,
        bytes calldata sig_
    ) internal view returns (bool) {
        return
            ECDSA.recover(
                keccak256(abi.encodePacked(account_, maxQuantity_, whiteListType_)).toEthSignedMessageHash(),
                sig_
            ) == ADDRESS.WhiteListVerifier;
    }

    // customize Token URI
    function tokenURI(uint256 tokenId_) public view override returns (string memory) {
        require(_exists(tokenId_), 'token does not exist');

        uint16 id = uint16(tokenId_);

        if (TokenIsUpgraded[id]) {
            return string(abi.encodePacked(_UpgradedTokenCID[id]));
        } else if (TokenIsGod[id]) {
            return string(abi.encodePacked(IPFS.GodCID, Strings.toString(id)));
        } else if (STATE.ArtIsRevealed) {
            return string(abi.encodePacked(IPFS.ArtCID, Strings.toString(id)));
        } else {
            return string(abi.encodePacked(IPFS.NotRevealedArtCID, Strings.toString(id)));
        }
    }

    // State Management functions.
    function revealArt(string memory ipfsCid) external onlyOwner {
        require(!STATE.ArtIsRevealed, 'Art is already revealed');
        uint256 len = bytes(ipfsCid).length;
        require(len > 0, 'CID is empty');
        IPFS.ArtCID = ipfsCid;
        STATE.ArtIsRevealed = true;
    }

    function setPlatform(address platform_) external onlyDefiTitan {
        ADDRESS.Platform = platform_;
    }

    function setBuyBackTreasury(address buyBackTreasury_) external onlyPlatform {
        ADDRESS.BuyBackTreasury = buyBackTreasury_;
    }

    function startWhiteListMinting() external onlyOwner {
        require(STATE.Initialized, 'NFT: contract is not initialized');
        require(!STATE.Finished, 'NFT: Minting is already finished');
        require(!STATE.WhiteListMintingIsActive, 'NFT: WhiteListMinting is already active');
        STATE.WhiteListMintingIsActive = true;
    }

    function startPublicMinting() external onlyOwner {
        require(!STATE.Finished, 'NFT: Minting is already finished');
        require(!STATE.MintingIsActive, 'NFT: Minting is already active');
        require(STATE.WhiteListMintingIsActive, 'NFT: WhiteListMinting should active before Public Minting');
        STATE.WhiteListMintingIsActive = false;
        STATE.MintingIsActive = true;
    }

    function finishAuction() external onlyDefiTitan {
        require(!STATE.Finished, 'NFT: Minting is already finished');
        require(STATE.Initialized, 'NFT: contract is not initialized');
        require(STATE.AuctionIsActive, 'NFT: Auction is not active');
        STATE.AuctionIsActive = false;
    }

    function finishMinting() external onlyDefiTitan {
        require(!STATE.Finished, 'NFT: Minting is already finished');
        require(STATE.MintingIsActive, 'NFT: Minting is not active');
        require(
            !STATE.WhiteListMintingIsActive,
            'NFT: WhiteListMinting should not active in the middle of the Minting'
        );
        STATE.MintingIsActive = false;
        STATE.AuctionIsActive = false;
        STATE.Finished = true;
    }

    function setUpgradeRequestFeeInWei(uint256 upgradeRequestFeeInWei_) external onlyDefiTitan whileMintingDone {
        UpgradeRequestFeeInWei = upgradeRequestFeeInWei_;
    }

    // utility functions

    function _transferEth(address to_, uint256 amount) private {
        address payable to = payable(to_);
        (bool sent, ) = to.call{value: amount}('');
        require(sent, 'Failed to send Ether');
    }

    // Token Upgradeability management functions

    mapping(uint256 => bool) public upgradeRequestFeeIsPaid;

    function upgradeTokenRequestFee(uint16 tokenId) external payable whileMintingDone onlyHuman(tokenId) {
        require(_exists(tokenId), 'token does not exist');
        TokenOwnership memory ownership = ownershipOf(tokenId);
        require(msg.sender == ownership.addr, 'only owner of token can upgrade token');
        require(UpgradeRequestFeeInWei <= msg.value, 'not enoughs ether');

        upgradeRequestFeeIsPaid[tokenId] = true;

        _transferEth(ADDRESS.Platform, msg.value);
        // TODO: emit a special event in here
    }

    function upgradeToken(
        string memory ipfsCid,
        uint16 tokenId,
        bool isGodNow
    ) external whileMintingDone onlyPlatform onlyHuman(tokenId) {
        uint256 len = bytes(ipfsCid).length;
        require(len > 0, 'CID is empty');
        require(upgradeRequestFeeIsPaid[tokenId], 'upgrade fee is not paid');
        upgradeRequestFeeIsPaid[tokenId] = false;
        _UpgradedTokenCID[tokenId] = ipfsCid;
        TokenIsUpgraded[tokenId] = true;
        if (isGodNow) {
            TokenIsGod[tokenId] = true;
        }
        // TODO: emit proper event here
    }

    // Token BuyBack management functions
    function buyBackToken(uint16 tokenId) external onlyHuman(tokenId) nonReentrant {
        require(_exists(tokenId), 'token does not exist');
        TokenOwnership memory ownership = ownershipOf(tokenId);
        require(msg.sender == ownership.addr, 'only owner of token can buy back token');
        _burn(tokenId);
        // TODO: in here we should call function from BuyBack treasury contract and give it the msg.sender
        // TODO: emit proper event here
    }

    // EIP 2981 functions

    struct RoyaltyInfo {
        address recipient;
        uint8 percent;
    }
    RoyaltyInfo private _royalties;

    /// @dev Sets token royalties
    /// @param recipient recipient of the royalties
    /// @param value percentage of the royalties
    function _setRoyalties(address recipient, uint8 value) internal {
        _royalties = RoyaltyInfo(recipient, uint8(value));
    }

    function royaltyInfo(uint256, uint256 value) external view returns (address receiver, uint256 royaltyAmount) {
        RoyaltyInfo memory royalties = _royalties;
        receiver = royalties.recipient;
        royaltyAmount = (value * royalties.percent) / 100;
    }

    // ███████╗██╗░░░░░░█████╗░██╗░░██╗██╗  ██████╗░██████╗░
    // ██╔════╝██║░░░░░██╔══██╗██║░██╔╝██║  ██╔══██╗██╔══██╗
    // █████╗░░██║░░░░░██║░░██║█████═╝░██║  ██████╦╝██████╦╝
    // ██╔══╝░░██║░░░░░██║░░██║██╔═██╗░██║  ██╔══██╗██╔══██╗
    // ██║░░░░░███████╗╚█████╔╝██║░╚██╗██║  ██████╦╝██████╦╝
    // ╚═╝░░░░░╚══════╝░╚════╝░╚═╝░░╚═╝╚═╝  ╚═════╝░╚═════╝░
}
