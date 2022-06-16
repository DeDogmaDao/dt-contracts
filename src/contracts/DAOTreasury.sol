// SPDX-License-Identifier: MIT
// Creator: DDD(DeDogma DAO)

pragma solidity ^0.8.4;

import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import './library/DTAuthUpgradable.sol';
import './interfaces/ICollectiGame.sol';
import './interfaces/IDAOTreasury.sol';
import './interfaces/IGameTreasury.sol';

// Note: add pauseable contract
contract DAOTreasury is UUPSUpgradeable, DTAuthUpgradable, IDAOTreasury {
    uint256 public START_TIME;
    uint8 public DAO_ROLE_ID;

    address public collectigame;
    address public gameTreasury;
    address public teamMultisig;
    uint256 public guaranteedFlorPrice;
    uint256 public buybackTaxRation;
    uint256 public collectigameSupply;
    uint256 public daoProposalFundingStartTime;
    bool private isSetup;

    mapping(uint8 => Release) public ethReleasesPlan;
    mapping(uint8 => string) public ethReleasesPlanDescription;

    mapping(string => Proposal) public daoProposals;
    string[] public daoProposalIds;

    event ChangeAnnouncement(address daoMultisig, address newImplementation);

    enum ProposalStatus {
        PENDING,
        FUNDED,
        REJECTED
    }

    modifier OnlyCollectigame() {
        require(msg.sender == collectigame, 'Caller Is Not Collectigame');
        _;
    }
    modifier whenSetup() {
        require(isSetup, 'DAO Treasury Is Not Setup');
        _;
    }
    modifier isDaoReady() {
        require(daoProposalFundingStartTime <= block.timestamp, 'DAO Is Not Ready');
        _;
    }

    function initialize(
        address daoMultisig_,
        address collectigame_,
        address gameTreasury_,
        address teamMultisig_,
        uint256 buybackTaxRation_
    ) public initializer {
        DAO_ROLE_ID = 0;
        START_TIME = block.timestamp;
        isSetup = false;

        address[] memory authorizedAddresses = new address[](1);
        authorizedAddresses[0] = daoMultisig_;

        uint8[] memory authorizedActors = new uint8[](1);
        authorizedActors[0] = DAO_ROLE_ID;

        uint8 countOfContractRole = 1;
        init(countOfContractRole, authorizedAddresses, authorizedActors);

        collectigame = collectigame_;
        gameTreasury = gameTreasury_;
        teamMultisig = teamMultisig_;

        guaranteedFlorPrice = ICollectiGame(collectigame).MINT_PRICE_IN_WEI();
        collectigameSupply = uint256(ICollectiGame(collectigame).MAX_SUPPLY());

        buybackTaxRation = buybackTaxRation_;

        uint256 month = 30 * 24 * 60 * 60;
        daoProposalFundingStartTime = START_TIME + (8 * month);
    }

    function getTreasuryBalance() public view virtual returns (uint256) {
        return address(this).balance;
    }

    function buybackNFT(address nftOwner) external virtual override OnlyCollectigame returns (bool) {
        ICollectiGame.ContractState memory collectigameState = ICollectiGame(collectigame).getState();
        require(collectigameState.initialized == true, 'CollectiGame contract has not initialized yet');

        uint256 tresuryBalance = getTreasuryBalance();
        require(tresuryBalance > guaranteedFlorPrice, 'Treasury balance is not enough to buyback');

        uint256 tax = (guaranteedFlorPrice * buybackTaxRation) / 100;
        bool taxPayingStatus = IGameTreasury(gameTreasury).buybackTax{value: tax}(tax);
        require(taxPayingStatus, 'Tax paying failed');

        uint256 buybackAmount = guaranteedFlorPrice - tax;
        collectigameSupply -= 1;

        _transferEth(nftOwner, buybackAmount);

        return true;
    }

    function newDaoFundRequestProposal(
        string calldata snapShotId,
        string calldata title,
        uint256 fundRequestAmount,
        uint256 votingStartTime,
        uint256 votingEndTime,
        address fundReceiver
    ) external virtual isDaoReady {
        uint256 tresuryBalance = getTreasuryBalance();
        require(tresuryBalance > fundRequestAmount, 'Treasury balance is not enough to fund the proposal');
        require(votingStartTime < votingEndTime, 'Voting start time should be earlier than voting end time');

        Proposal memory proposal = Proposal(
            title,
            fundRequestAmount,
            votingStartTime,
            votingEndTime,
            fundReceiver,
            false
        );
        daoProposals[snapShotId] = proposal;
        daoProposalIds.push(snapShotId);
    }

    function acceptDaoFundRequestProposal(string calldata snapShotId)
        external
        virtual
        hasAuthorized(DAO_ROLE_ID)
        isDaoReady
    {
        Proposal storage proposal = daoProposals[snapShotId];
        require(!proposal.isFunded, 'Proposal has already been funded');
        uint256 week = 7 * 24 * 60 * 60;
        require(proposal.votingEndTime <= block.timestamp, 'Proposal is not ready to be funded');
        require(proposal.votingEndTime + week >= block.timestamp, 'Proposal funding time is past');
        uint256 tresuryBalance = getTreasuryBalance();
        require(tresuryBalance >= proposal.fundRequestAmount, 'Treasury balance is not enough to fund the proposal');
        proposal.isFunded = true;

        _transferEth(proposal.proposer, proposal.fundRequestAmount);
    }

    function proposalStatus(string calldata id) external view virtual returns (ProposalStatus) {
        Proposal memory proposal = daoProposals[id];

        uint256 week = 7 * 24 * 60 * 60;

        if (proposal.isFunded) {
            return ProposalStatus.FUNDED;
        } else if ((proposal.votingEndTime + week) < block.timestamp) {
            return ProposalStatus.REJECTED;
        } else {
            return ProposalStatus.PENDING;
        }
    }

    function setupReleasePlan() external virtual {
        require(!isSetup, 'Already Setup');
        uint8 releaseId = 0;

        uint256 duringMintingReleaseAmount = (collectigameSupply * guaranteedFlorPrice * 20) / 100;
        Release memory duringMintingRelease = Release(
            duringMintingReleaseAmount,
            START_TIME,
            roles[DAO_ROLE_ID].addr,
            false
        );
        ethReleasesPlan[releaseId] = duringMintingRelease;
        ethReleasesPlanDescription[releaseId] = 'Market making and bootstrapping';
        releaseId++;

        uint256 month = 3 * 30 * 24 * 60 * 60;
        for (releaseId; releaseId < 4; releaseId++) {
            uint256 releasePercent = 10;
            uint256 releaseDate = START_TIME + (3 * month) + ((releaseId - 1) * month);

            Release memory release = Release(releasePercent, releaseDate, teamMultisig, false);
            ethReleasesPlan[releaseId] = release;
            ethReleasesPlanDescription[releaseId] = 'The team';
        }

        for (releaseId; releaseId < 7; releaseId++) {
            uint256 releasePercent = 10;
            uint256 releaseDate = START_TIME + (3 * month) + ((releaseId - 1) * month);

            Release memory release = Release(releasePercent, releaseDate, roles[DAO_ROLE_ID].addr, false);
            ethReleasesPlan[releaseId] = release;
            ethReleasesPlanDescription[releaseId] = 'DDD platform expansion';
        }

        isSetup = true;
    }

    function mintPriceDeposit(uint256 amount) external payable virtual override returns (bool) {
        require(msg.value >= amount, 'Amount is not enough');
        return true;
    }

    function generalDeposit(uint256 amount) external payable virtual override returns (bool) {
        require(msg.value >= amount, 'Amount is not enough');
        return true;
    }

    function gameTresuryDeposit(uint256 amount) external payable virtual override returns (bool) {
        require(msg.value >= amount, 'Amount is not enough');
        return true;
    }

    function setBuybackTaxRatio(uint256 buybackTaxRation_) external virtual hasAuthorized(DAO_ROLE_ID) {
        buybackTaxRation = buybackTaxRation_;
    }

    function increaseGuaranteedFlorPrice(uint256 increaseAmount) external virtual hasAuthorized(DAO_ROLE_ID) {
        uint256 numberOfGod = uint256(ICollectiGame(collectigame).NUMBER_OF_TOKEN_FOR_AUCTION());
        uint256 neededBalance = (collectigameSupply - numberOfGod) * guaranteedFlorPrice;
        uint256 treasuryBalance = getTreasuryBalance();
        require(treasuryBalance >= neededBalance, 'Treasury balance is not enough to increase guaranteed flor price');
        guaranteedFlorPrice += increaseAmount;
    }

    function releaseFund(uint8 releaseId) external virtual whenSetup {
        Release storage release = ethReleasesPlan[releaseId];
        require(!release.isReleased, 'Fund has been released');
        require(release.releaseDate <= block.timestamp, 'Release date is not reached');
        require(release.releaseDate > START_TIME, 'Release date is not reached');

        if (releaseId == 0) {
            release.isReleased = true;

            _transferEth(release.receiver, release.amountOrPercent);
        } else {
            release.isReleased = true;

            uint256 treasuryBalance = getTreasuryBalance();
            uint256 releaseAmount = (treasuryBalance * release.amountOrPercent) / 100;
            _transferEth(release.receiver, releaseAmount);
        }
    }

    function _transferEth(address to_, uint256 amount) internal virtual {
        address payable to = payable(to_);
        (bool sent, ) = to.call{value: amount}('');
        require(sent, 'Transfer Failed');
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override {
        address daoMultisig = roles[DAO_ROLE_ID].addr;
        require(msg.sender == daoMultisig, 'Unauthorized Upgrade');
        emit ChangeAnnouncement(daoMultisig, newImplementation);
    }
}
