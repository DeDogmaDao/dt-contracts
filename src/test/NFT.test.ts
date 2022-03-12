import { expect } from 'chai'
import { ethers } from 'hardhat'
import { NFT } from '../types'

describe('NFT', function () {
  let NFTContract: NFT

  const maxSupply_ = 100

  let ownerAddress: string
  let platformMultisigAddress: string
  let defiTitanAddress: string
  let buyBackTreasuryContractAddress: string
  let whiteListVerifierAddress: string
  let royaltyDistributorAddress: string

  const godCID_ = 'ipfs://GodCID'
  const notRevealedArtCID_ = 'ipfs://NotRevealedArtCID'

  const MintPriceInWei_ = ethers.utils.parseEther('0.05')
  const MaxMintPerAddress_ = 3
  const AuctionStartTime_ = 0 // set current epoch time
  const AuctionDuration_ = 86400 // 1 day
  const NumberOFTokenForAuction_ = 10
  const RoyaltyFeePercent_ = 10

  const upgradeRequestFeeInWei_ = ethers.utils.parseEther('0.01')

  beforeEach(async () => {
    const accounts = await ethers.getSigners()
    ownerAddress = accounts[0].address
    platformMultisigAddress = accounts[1].address
    defiTitanAddress = accounts[2].address
    buyBackTreasuryContractAddress = accounts[3].address
    whiteListVerifierAddress = accounts[4].address
    royaltyDistributorAddress = accounts[5].address
    const Contract = await ethers.getContractFactory('NFT')
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
    )) as NFT
  })

  describe('#constructor', () => {
    it('should have correct max supply', async () => {
      const maxSupply = await NFTContract.MaxSupply()
      expect(maxSupply).to.equal(maxSupply_)
    })

    it('should have correct owner address', async () => {
      const OwnableOwner = await NFTContract.owner()
      const AddressesOwner = (await NFTContract.ADDRESS()).Owner
      expect(OwnableOwner).to.equal(ownerAddress)
      expect(AddressesOwner).to.equal(ownerAddress)
    })

    it('should have correct platform multisig address', async () => {
      const platformMultisig = (await NFTContract.ADDRESS()).Platform
      expect(platformMultisig).to.equal(platformMultisigAddress)
    })

    it('should have correct defi titan address', async () => {
      const defiTitan = (await NFTContract.ADDRESS()).DefiTitan
      expect(defiTitan).to.equal(defiTitanAddress)
    })

    it('should have correct buy back treasury contract address', async () => {
      const buyBackTreasuryContract = (await NFTContract.ADDRESS()).BuyBackTreasury
      expect(buyBackTreasuryContract).to.equal(buyBackTreasuryContractAddress)
    })

    it('should have correct white list verifier address', async () => {
      const whiteListVerifier = (await NFTContract.ADDRESS()).WhiteListVerifier
      expect(whiteListVerifier).to.equal(whiteListVerifierAddress)
    })

    it('should have correct royalty distributor address', async () => {
      const royaltyDistributor = (await NFTContract.ADDRESS()).RoyaltyDistributor
      expect(royaltyDistributor).to.equal(royaltyDistributorAddress)
    })

    it('should have correct god cid', async () => {
      const godCID = (await NFTContract.IPFS()).GodCID
      expect(godCID).to.equal(godCID_)
    })

    it('should have correct not revealed art cid', async () => {
      const notRevealedArtCID = (await NFTContract.IPFS()).NotRevealedArtCID
      expect(notRevealedArtCID).to.equal(notRevealedArtCID_)
    })
  })
})
