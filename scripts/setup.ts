import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers, upgrades, ethernal } from "hardhat";
import { CollectigameNFT, DAOTreasury, GameTreasuryV0 } from '../src/types';


let DAOMultisigAddress: SignerWithAddress;
let DecentralTitan: SignerWithAddress;
let CollectiGameOwner: SignerWithAddress;
let WhiteListVerifier: SignerWithAddress;
let NFTContract: CollectigameNFT;
let DAOTreasuryContract: DAOTreasury;
let GameTreasuryV0Contract: GameTreasuryV0;


async function deployCollectiGame() {
    const godCID_ = 'ipfs://QmXDwhDEc1seGdaCSccrUMfPBwTx2TL22yTxNxd1UoSXVs';
    const notRevealedArtCID_ = 'ipfs://QmeEHxgXssbcN9bvYszFrHSw5YBYAtKxrA1ypzAzzFENB9';
    const afterRevealArtCID_ = 'ipfs://QmNMgz4h3NHWdy5fFGCZRgxEJzxMVKWRp3ykSsbhDRK5RE';
    const upgradeRequestFeeInWei_ = ethers.utils.parseEther('0.01');

    const Contract = await ethers.getContractFactory("CollectigameNFT");
    Contract.connect(CollectiGameOwner).deploy

    NFTContract = (await Contract.connect(CollectiGameOwner).deploy(
        godCID_,
        notRevealedArtCID_,
        upgradeRequestFeeInWei_,
        CollectiGameOwner.address,
        DAOMultisigAddress.address,
        DecentralTitan.address,
    )) as CollectigameNFT;

    await NFTContract.deployed();
    console.log("NFT Contract deployed to:", NFTContract.address);

    await ethernal.push({
        name: 'CollectigameNFT',
        address: NFTContract.address,
    })
}

async function deployGameTreasury() {
    const GameTreasuryV0 = await ethers.getContractFactory("GameTreasuryV0");
    GameTreasuryV0Contract = (await GameTreasuryV0.deploy(
        DAOMultisigAddress.address
    )) as GameTreasuryV0;
    await GameTreasuryV0Contract.deployed();
    console.log("GameTreasuryV0 deployed to:", GameTreasuryV0Contract.address);
    
    await ethernal.push({
        name: 'GameTreasuryV0',
        address: GameTreasuryV0Contract.address,
    })
}

async function deployDaoTreasury() {
    const DAOTreasury = await ethers.getContractFactory("DAOTreasury");
    const buybackTaxRation = 10;

    DAOTreasuryContract = (await upgrades.deployProxy(DAOTreasury, [
        DAOMultisigAddress.address,
        NFTContract.address,
        GameTreasuryV0Contract.address,
        DecentralTitan.address,
        buybackTaxRation
    ])) as DAOTreasury; // initializer should be added in this line
    await DAOTreasuryContract.deployed();
    console.log("DaoTreasury:", DAOTreasuryContract.address);

    await ethernal.push({
        name: 'DAOTreasury',
        address: DAOTreasuryContract.address,
    })
}

async function callCollectiGameInitializer() {
    // auction formula => AUCTION_DROP_PER_STEP: (START_PRICE - END_PRICE)/ (1 day in seconds(86400)) * (AUCTION_DROP_INTERVAL in seconds)
    const auctionConfig = [
        {
            startPrice: ethers.utils.parseEther('50'),
            endPrice: ethers.utils.parseEther('5'),
            auctionDropPerStep: ethers.utils.parseEther('0.3125'),
        }, {
            startPrice: ethers.utils.parseEther('5'),
            endPrice: ethers.utils.parseEther('2'),
            auctionDropPerStep: ethers.utils.parseEther('0.02083333'),
        }, {
            startPrice: ethers.utils.parseEther('10'),
            endPrice: ethers.utils.parseEther('1'),
            auctionDropPerStep: ethers.utils.parseEther('0.0625'),
        }, {
            startPrice: ethers.utils.parseEther('10'),
            endPrice: ethers.utils.parseEther('1'),
            auctionDropPerStep: ethers.utils.parseEther('0.0625'),
        }, {
            startPrice: ethers.utils.parseEther('10'),
            endPrice: ethers.utils.parseEther('1'),
            auctionDropPerStep: ethers.utils.parseEther('0.0625'),
        }, {
            startPrice: ethers.utils.parseEther('10'),
            endPrice: ethers.utils.parseEther('1'),
            auctionDropPerStep: ethers.utils.parseEther('0.0625'),
        }, {
            startPrice: ethers.utils.parseEther('10'),
            endPrice: ethers.utils.parseEther('1'),
            auctionDropPerStep: ethers.utils.parseEther('0.0625'),
        }, {
            startPrice: ethers.utils.parseEther('10'),
            endPrice: ethers.utils.parseEther('1'),
            auctionDropPerStep: ethers.utils.parseEther('0.0625'),
        }, {
            startPrice: ethers.utils.parseEther('10'),
            endPrice: ethers.utils.parseEther('1'),
            auctionDropPerStep: ethers.utils.parseEther('0.0625'),
        }, {
            startPrice: ethers.utils.parseEther('10'),
            endPrice: ethers.utils.parseEther('1'),
            auctionDropPerStep: ethers.utils.parseEther('0.0625'),
        }];

    await NFTContract.connect(DAOMultisigAddress).initializer(
        auctionConfig,
        DAOTreasuryContract.address,
        GameTreasuryV0Contract.address,
        WhiteListVerifier.address
    );



}
async function activateWhiteListMinting() {
    await NFTContract.connect(DAOMultisigAddress).startWhiteListMinting()
}
async function activatePublicMinting() {
    await NFTContract.connect(DAOMultisigAddress).startPublicMinting()
}

async function setupReleasePlane() {
    await DAOTreasuryContract.connect(DAOMultisigAddress).setupReleasePlan();
}
async function main() {
    const accounts = await ethers.getSigners();
    DAOMultisigAddress = accounts[0]; // same with platform multisig address
    DecentralTitan = accounts[1]; // same with team multisig address
    CollectiGameOwner = accounts[2];
    WhiteListVerifier = accounts[3];

    await deployCollectiGame();
    await deployGameTreasury();
    await deployDaoTreasury();

    await callCollectiGameInitializer();
    await activateWhiteListMinting();
    await activatePublicMinting();
    await setupReleasePlane();
}

main();