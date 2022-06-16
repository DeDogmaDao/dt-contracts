// SPDX-License-Identifier: MIT
// Creator: DDD(DeDogma DAO)

pragma solidity 0.8.4;

import './library/DTERC721A.sol';
import './library/DTOwnable.sol';
import './library/DTAuth.sol';
import './interfaces/IERC2981Royalties.sol';
import './interfaces/IDAOTreasury.sol';
import './interfaces/ICollectiGame.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

// add test for setOwnersExplicit
// add test for transferFrom and approve
contract CollectigameNFT is DTERC721A, ICollectiGame, DTOwnable, DTAuth, ReentrancyGuard, IERC2981Royalties {
    using ECDSA for bytes32;

    // *******************************************************************************
    //           |                   |                  |                     |
    //  _________|________________.=""_;=.______________|_____________________|_______
    // |                   |  ,-"_,=""     `"=.|                  |
    // |___________________|__"=._o`"-._        `"=.______________|___________________
    //           |                `"=._o`"=._      _`"=._                     |
    //  _________|_____________________:=._o "=._."_.-="'"=.__________________|_______
    // |                   |    __.--" , ; `"=._o." ,-"""-._ ".   |
    // |___________________|_._"  ,. .` ` `` ,  `"-._"-._   ". '__|___________________
    //           |           |o`"=._` , "` `; .". ,  "-._"-._; ;              |
    //  _________|___________| ;`-.o`"=._; ." ` '`."\` . "-._ /_______________|_______
    // |                   | |o;    `"-.o`"=._``  '` " ,__.--o;   |
    // |___________________|_| ;     (#) `-.o `"=.`_.--"_o.-; ;___|___________________
    // ____/______/______/___|o;._    "      `".o|o_.--"    ;o;____/______/______/____
    // /______/______/______/_"=._o--._        ; | ;        ; ;/______/______/______/_
    // ____/______/______/______/__"=._o--._   ;o|o;     _._;o;____/______/______/____
    // /______/______/______/______/____"=._o._; | ;_.--"o.--"_/______/______/______/_
    // ____/______/______/______/______/_____"=.o|o_.--""___/______/______/______/____
    // /______/______/______/______/______/______/______/______/______/______/____/___
    // *******************************************************************************

    // State variables
    uint16 public constant override MAX_SUPPLY = 7777;
    uint256 public upgradeRequestFeeInWei;

    ContractState private state;
    ContractAddresses private addresses;
    ContractIPFS private ipfs;

    uint256 public constant override MINT_PRICE_IN_WEI = 0.07 * 10**18;
    uint16 public constant MAX_MINT_PER_ADDRESS = 3;
    uint256 public immutable AUCTION_START_TIME; // epoch time
    uint8 public constant override NUMBER_OF_TOKEN_FOR_AUCTION = 10;
    uint256 public constant AUCTION_DURATION = 86400; // in seconds
    uint8 public constant ROYALTY_FEE_PERCENT = 10;
    uint256 public constant AUCTION_DROP_INTERVAL = 600; // in seconds
    uint8 private constant NUMBER_OF_ACTOR = 2;
    uint8 public constant PLATFORM_MULTISIG_ROLE_ID = 0;
    uint8 public constant DECENTRAL_TITAN_ROLE_ID = 1;

    RoyaltyInfo private _royalties;

    mapping(uint16 => bool) public tokenIsUpgraded;
    mapping(uint16 => string) private _upgradedTokenCIDs;
    mapping(uint16 => bool) public isGodToken;
    mapping(uint8 => Auction) public auctions;
    mapping(uint256 => bool) public upgradeRequestFeeIsPaid;

    // Events
    event UpgradeRequestPayment(uint16 tokenId, uint256 value);
    event TokenUpgraded(uint16 tokenId);
    event AuctionsInitialized(uint8 numberOfGods, uint256 startTimeStamp);

    // Enums
    enum WhiteListType {
        NORMAL,
        ROYAL
    }

    // Modifiers
    modifier whileInitialized() {
        require(state.initialized, 'Not Initialized');
        _;
    }
    modifier whileAuctionIsActive() {
        require(state.auctionIsActive, 'Not Activated');
        _;
    }
    modifier whileMintingIsActive() {
        require(state.mintingIsActive, 'Not Activated');
        _;
    }
    modifier whileWhiteListMintingIsActive() {
        require(state.whitelistMintingIsActive, 'Not Activated');
        _;
    }
    modifier whileMintingDone() {
        require(state.finished, 'Not Finished');
        require(state.initialized, 'Not Initialized');
        _;
    }

    modifier onlyHuman(uint16 tokenId_) {
        require(!isGodToken[tokenId_], 'Only Humans');
        _;
    }

    constructor(
        string memory godCID_,
        string memory _notRevealedArtCID,
        uint256 _upgradeRequestFeeInWei,
        address _owner,
        address platformMultisig,
        address decentralTitan
    ) DTERC721A('DemmortalTreasure', 'DT') DTOwnable(_owner) DTAuth(NUMBER_OF_ACTOR) {
        state = ContractState(false, false, false, false, false, false);

        address[] memory authorizedAddresses = new address[](2);
        authorizedAddresses[0] = platformMultisig;
        authorizedAddresses[1] = decentralTitan;

        uint8[] memory authorizedActors = new uint8[](2);
        authorizedActors[0] = PLATFORM_MULTISIG_ROLE_ID;
        authorizedActors[1] = DECENTRAL_TITAN_ROLE_ID;

        init(authorizedAddresses, authorizedActors);

        ipfs.godCID = godCID_;
        ipfs.notRevealedArtCID = _notRevealedArtCID;

        upgradeRequestFeeInWei = _upgradeRequestFeeInWei;
        //Todo remove it during final deploy and input it as constant variable
        AUCTION_START_TIME = block.timestamp;
    }

    receive() external payable {
        revert('Not Allowed');
    }

    fallback() external payable {
        revert('Call Valid Function');
    }

    // State Management related functions.
    function initializer(
        AuctionConfig[] calldata configs,
        address daoTreasury,
        address royaltyReceiverContract,
        address whiteListVerifier
    ) external hasAuthorized(PLATFORM_MULTISIG_ROLE_ID) {
        require(!state.initialized, 'Already Initialized');
        require(!state.finished, 'Already Finished');
        require(!state.auctionIsActive, 'Already Activated');
        state.initialized = true;
        _setupGodAuction(configs);
        state.auctionIsActive = true;

        addresses = ContractAddresses(daoTreasury, whiteListVerifier, royaltyReceiverContract);
        _setRoyalties(addresses.gameTreasuryContract, ROYALTY_FEE_PERCENT);
    }

    function revealArt(string memory ipfsCid) external hasAuthorized(PLATFORM_MULTISIG_ROLE_ID) {
        require(!state.artIsRevealed, 'Already Revealed');
        uint256 len = bytes(ipfsCid).length;
        require(len > 0, 'CID Is Empty');
        ipfs.artCID = ipfsCid;
        state.artIsRevealed = true;
    }

    function setDaoTreasury(address daoTreasuryContract) external hasAuthorized(PLATFORM_MULTISIG_ROLE_ID) {
        addresses.daoTreasuryContract = daoTreasuryContract;
    }

    function setRoyaltyReceiver(address royaltyDistributerContract) external hasAuthorized(PLATFORM_MULTISIG_ROLE_ID) {
        addresses.gameTreasuryContract = royaltyDistributerContract;
        _setRoyalties(addresses.gameTreasuryContract, ROYALTY_FEE_PERCENT);
    }

    function setUpgradeRequestFeeInWei(uint256 _upgradeRequestFeeInWei)
        external
        hasAuthorized(PLATFORM_MULTISIG_ROLE_ID)
        whileMintingDone
    {
        upgradeRequestFeeInWei = _upgradeRequestFeeInWei;
    }

    function startWhiteListMinting() external hasAuthorized(PLATFORM_MULTISIG_ROLE_ID) {
        require(state.initialized, 'Not Initialized');
        require(!state.finished, 'Already Finished');
        require(!state.whitelistMintingIsActive, 'Already Activated');
        state.whitelistMintingIsActive = true;
    }

    function startPublicMinting() external hasAuthorized(PLATFORM_MULTISIG_ROLE_ID) {
        require(!state.finished, 'Already Finished');
        require(!state.mintingIsActive, 'Already Activated');
        require(state.whitelistMintingIsActive, 'Priority Issue');
        state.mintingIsActive = true;
    }

    function finishAuction() external hasAuthorized(PLATFORM_MULTISIG_ROLE_ID) {
        require(!state.finished, 'Already Finished');
        require(state.initialized, 'Not Initialized');
        require(state.auctionIsActive, 'Not Activated');
        state.auctionIsActive = false;
    }

    function finishMinting() external hasAuthorized(PLATFORM_MULTISIG_ROLE_ID) {
        require(!state.finished, 'Already Finished');
        require(state.mintingIsActive, 'Not Activated');
        state.mintingIsActive = false;
        state.auctionIsActive = false;
        state.whitelistMintingIsActive = false;
        state.finished = true;
    }

    function updateCID(string memory GodCid, string memory HumanCid) external hasAuthorized(PLATFORM_MULTISIG_ROLE_ID) {
        uint256 len1 = bytes(GodCid).length;
        if (len1 > 0) {
            ipfs.godCID = GodCid;
        }

        uint256 len2 = bytes(HumanCid).length;
        if (len2 > 0) {
            ipfs.artCID = HumanCid;
        }
    }

    // Auction related functions.

    function buyAGodInAuction(uint8 day) external payable whileAuctionIsActive {
        require(1 <= day && day <= NUMBER_OF_TOKEN_FOR_AUCTION, 'Day Is Out Of Range');
        require(auctions[day].startAt <= block.timestamp, 'Not Started Yet');
        require(auctions[day].expireAt >= block.timestamp, 'Expired');

        Auction memory auction = auctions[day];
        TokenOwnership memory ownership = ownershipOf(auction.tokenId);
        address decentralTitan = roles[DECENTRAL_TITAN_ROLE_ID].addr;

        uint256 currentPrice = _getAuctionPrice(auction);
        require(ownership.addr == decentralTitan, 'Bad Initialization');

        require(auction.endPrice <= currentPrice, 'Receive To Base Price');
        require(currentPrice <= msg.value, 'Not Enough Ether');

        _auctionTransfer(decentralTitan, msg.sender, auction.tokenId);

        auctions[day].isSold = true;
        auctions[day].purchasedPrice = msg.value;
        auctions[day].owner = msg.sender;
        _transferEth(decentralTitan, msg.value);
    }

    function getAuctionPrice(uint8 day) external view whileAuctionIsActive returns (uint256) {
        require(1 <= day && day <= NUMBER_OF_TOKEN_FOR_AUCTION, 'day is out of range');
        Auction memory auction = auctions[day];
        return _getAuctionPrice(auction);
    }

    function getAuctionsData() external view returns (Auction[] memory) {
        Auction[] memory result = new Auction[](NUMBER_OF_TOKEN_FOR_AUCTION);
        for (uint8 i = 1; i <= NUMBER_OF_TOKEN_FOR_AUCTION; i++) {
            result[i - 1] = auctions[i];
        }
        return result;
    }

    function whitelistMinting(
        uint8 maxQuantity,
        uint8 quantity,
        WhiteListType whiteListType,
        bytes calldata sig
    ) external payable whileWhiteListMintingIsActive {
        require(isWhitelisted(msg.sender, maxQuantity, whiteListType, sig), 'Bad Signature');
        require(_totalMinted() + quantity <= MAX_SUPPLY, 'Receive To Max Supply');

        uint8 _aux = _getAux(msg.sender);

        require(_aux + quantity <= maxQuantity, 'Receive To Max Quantity');

        if (whiteListType == WhiteListType.ROYAL) {
            _setAux(msg.sender, _aux + quantity);
            _safeMint(msg.sender, quantity);
        } else {
            require(quantity * MINT_PRICE_IN_WEI <= msg.value, 'Not Enoughs Ether');
            _setAux(msg.sender, _aux + quantity);
            _safeMint(msg.sender, quantity);
        }
        if (msg.value > 0) {
            bool depositStatus = IDAOTreasury(addresses.daoTreasuryContract).mintPriceDeposit{value: msg.value}(
                msg.value
            );
            require(depositStatus, 'eth transfer failed');
        }
    }

    function publicMint(uint256 quantity) external payable whileMintingIsActive {
        require(_totalMinted() + quantity <= MAX_SUPPLY, 'Receive To Max Supply');
        require(_numberMinted(msg.sender) + quantity <= MAX_MINT_PER_ADDRESS, 'Receive To Max Mint Per Address');
        require(quantity * MINT_PRICE_IN_WEI <= msg.value, 'Not Enoughs Ether');
        _safeMint(msg.sender, quantity);

        bool depositStatus = IDAOTreasury(addresses.daoTreasuryContract).mintPriceDeposit{value: msg.value}(msg.value);
        require(depositStatus, 'eth transfer failed');
    }

    // Token Upgradeability related functions.
    function upgradeTokenRequestFee(uint16 tokenId) external payable whileMintingDone onlyHuman(tokenId) {
        require(_exists(tokenId), 'Token Not Exists');
        require(upgradeRequestFeeInWei <= msg.value, 'Not Enoughs Ether');

        upgradeRequestFeeIsPaid[tokenId] = true;

        address platformMultisig = roles[PLATFORM_MULTISIG_ROLE_ID].addr;
        _transferEth(platformMultisig, msg.value);
        emit UpgradeRequestPayment(tokenId, msg.value);
    }

    function upgradeToken(
        string memory ipfsCid,
        uint16 tokenId,
        bool isGodNow
    ) external whileMintingDone hasAuthorized(PLATFORM_MULTISIG_ROLE_ID) onlyHuman(tokenId) {
        uint256 len = bytes(ipfsCid).length;
        require(len > 0, 'CID is empty');
        require(upgradeRequestFeeIsPaid[tokenId], 'Upgrade Request Fee Not Paid');
        upgradeRequestFeeIsPaid[tokenId] = false;
        _upgradedTokenCIDs[tokenId] = ipfsCid;
        tokenIsUpgraded[tokenId] = true;
        if (isGodNow) {
            isGodToken[tokenId] = true;
        }
        emit TokenUpgraded(tokenId);
    }

    function buyBackToken(uint16 tokenId) external onlyHuman(tokenId) nonReentrant whileInitialized {
        require(_exists(tokenId), 'Token Not Exists');
        TokenOwnership memory ownership = ownershipOf(tokenId);
        require(msg.sender == ownership.addr, 'Is Not Owner');
        _burn(tokenId);
        bool buybackStatus = IDAOTreasury(addresses.daoTreasuryContract).buybackNFT(ownership.addr);
        require(buybackStatus, 'buyback failed');
    }

    function royaltyInfo(uint256, uint256 value)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        receiver = _royalties.recipient;
        royaltyAmount = (value * _royalties.percent) / 100;
    }

    function setOwnersExplicit(uint256 quantity) external {
        _setOwnersExplicit(quantity);
    }

    function getState() external view override returns (ICollectiGame.ContractState memory) {
        return state;
    }

    function getAddresses() external view override returns (ICollectiGame.ContractAddresses memory) {
        return addresses;
    }

    function tokenURI(uint256 tokenId_) public view override returns (string memory) {
        require(_exists(tokenId_), 'Token Not Exists');

        uint16 id = uint16(tokenId_);

        if (tokenIsUpgraded[id]) {
            return string(abi.encodePacked(_upgradedTokenCIDs[id]));
        } else if (isGodToken[id]) {
            return string(abi.encodePacked(ipfs.godCID, '/', Strings.toString(id)));
        } else if (state.artIsRevealed) {
            return string(abi.encodePacked(ipfs.artCID, '/', Strings.toString(id)));
        } else {
            return string(abi.encodePacked(ipfs.notRevealedArtCID));
        }
    }

    function isWhitelisted(
        address account_,
        uint8 maxQuantity_,
        WhiteListType whiteListType_,
        bytes calldata sig_
    ) public view whileInitialized returns (bool) {
        bytes32 msgHash = prefixed(keccak256(abi.encodePacked(account_, maxQuantity_, whiteListType_)));
        return ECDSA.recover(msgHash, sig_) == addresses.whiteListVerifier;
    }

    function _setRoyalties(address recipient, uint8 value) private {
        _royalties = RoyaltyInfo(recipient, uint8(value));
    }

    function _getAuctionPrice(Auction memory auction) private view returns (uint256) {
        require(!auction.isSold, 'Already Sold');
        if (block.timestamp < auction.startAt) {
            return auction.startPrice;
        }
        if (block.timestamp > auction.expireAt) {
            return auction.endPrice;
        }
        uint256 elapsedTime = block.timestamp - auction.startAt;
        uint256 steps = elapsedTime / AUCTION_DROP_INTERVAL;
        return auction.startPrice - (steps * auction.auctionDropPerStep);
    }

    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked('\x19Ethereum Signed Message:\n32', hash));
    }

    function _setupGodAuction(AuctionConfig[] memory configs) private {
        require(_totalMinted() + NUMBER_OF_TOKEN_FOR_AUCTION <= MAX_SUPPLY, 'Receive To Max Supply');
        require(configs.length == NUMBER_OF_TOKEN_FOR_AUCTION, 'Bad Configs Length');

        address decentralTitan = roles[DECENTRAL_TITAN_ROLE_ID].addr;
        _safeMint(decentralTitan, NUMBER_OF_TOKEN_FOR_AUCTION);

        // we need set first token id to the token sell in auction for CID availability.
        require(_totalMinted() == NUMBER_OF_TOKEN_FOR_AUCTION, 'Bad Initialization');

        for (uint8 i = 0; i < NUMBER_OF_TOKEN_FOR_AUCTION; i++) {
            require(configs[i].startPrice > configs[i].endPrice, 'Bad Configs');
            Auction memory _auction = Auction(
                i,
                AUCTION_START_TIME + AUCTION_DURATION * i,
                AUCTION_START_TIME + AUCTION_DURATION * (i + 1),
                configs[i].startPrice,
                configs[i].endPrice,
                configs[i].auctionDropPerStep,
                false,
                configs[i].endPrice,
                decentralTitan
            );
            auctions[i + 1] = _auction;
            isGodToken[i] = true;
        }
    }

    function _transferEth(address to_, uint256 amount) private {
        address payable to = payable(to_);
        (bool sent, ) = to.call{value: amount}('');
        require(sent, 'Transfer Failed');
    }

    function transferEthToDao() external payable whileMintingDone {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, 'Contract Balance is Zero');
        bool depositStatus = IDAOTreasury(addresses.daoTreasuryContract).generalDeposit{value: contractBalance}(
            contractBalance
        );
        require(depositStatus, 'eth transfer failed');
    }
}
