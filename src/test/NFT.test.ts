import { expect } from 'chai';
import { ethers } from 'hardhat';
import { NFT } from '../types';

describe('NFT', function () {
    let NFTContract: NFT;

    const maxSupply_ = 100;

    let ownerAddress: string;
    let platformMultisigAddress: string;
    let defiTitanAddress: string;
    let buyBackTreasuryContractAddress: string;
    let whiteListVerifierAddress: string;
    let royaltyDistributorAddress: string;

    const godCID_ = 'ipfs://GodCID';
    const notRevealedArtCID_ = 'ipfs://NotRevealedArtCID';

    const MintPriceInWei_ = ethers.utils.parseEther('0.05');
    const MaxMintPerAddress_ = 3;
    const AuctionStartTime_ = 0; // set current epoch time
    const AuctionDuration_ = 86400 // 1 day
    const NumberOFTokenForAuction_ = 10;
    const RoyaltyFeePercent_ = 10;

    const upgradeRequestFeeInWei_ = ethers.utils.parseEther('0.01');


    beforeEach(async () => {
        const accounts = await ethers.getSigners();
        ownerAddress = accounts[0].address;
        platformMultisigAddress = accounts[1].address;
        defiTitanAddress = accounts[2].address;
        buyBackTreasuryContractAddress = accounts[3].address;
        whiteListVerifierAddress = accounts[4].address;
        royaltyDistributorAddress = accounts[5].address;
        const Contract = await ethers.getContractFactory("NFT");
        NFTContract = (await Contract.deploy(
            maxSupply_,
            [
                ownerAddress,
                platformMultisigAddress,
                defiTitanAddress,
                buyBackTreasuryContractAddress,
                whiteListVerifierAddress,
                royaltyDistributorAddress,
            ],
            godCID_,
            notRevealedArtCID_,
            [
                MintPriceInWei_,
                MaxMintPerAddress_,
                AuctionStartTime_,
                AuctionDuration_,
                NumberOFTokenForAuction_,
                RoyaltyFeePercent_,
            ],
            upgradeRequestFeeInWei_
        )) as NFT;
    });

    

});
