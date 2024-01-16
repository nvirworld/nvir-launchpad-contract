import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { time } from '@nomicfoundation/hardhat-network-helpers'
import { expect } from 'chai'
import { ethers } from 'hardhat'
import { Token } from '../typechain-types'
import { DeployArgs, deploy } from './utils/deploy'

describe('DeployRevert', () => {
  let staking: Token
  let sale: Token
  let purchase: Token
  let t: number
  let standardDeployArgs: DeployArgs
  let deployer: HardhatEthersSigner

  beforeEach(async () => {
    staking = await (await ethers.getContractFactory('Token')).deploy('STK', 18, 1000000000)
    sale = await (await ethers.getContractFactory('Token')).deploy('SAL', 18, 1000000000)
    purchase = await (await ethers.getContractFactory('Token')).deploy('PUR', 18, 1000000000)

    await staking.waitForDeployment()
    await sale.waitForDeployment()
    await purchase.waitForDeployment()

    t = await time.latest()

    const signers = await ethers.getSigners()
    deployer = signers[0]

    standardDeployArgs = {
      name: 'Reverted Launchpad',
      stakingSalePurchaseToken: {
        staking: await staking.getAddress(),
        sale: await sale.getAddress(),
        purchase: await purchase.getAddress()
      },
      stakingStartEnd: [t + 60, t + 120],
      stakingVolumeMinMax: [ethers.parseEther('100'), ethers.parseEther('100000')],
      stakingVolumeTier: [ethers.parseEther('1000'), ethers.parseEther('5000')],
      saleStartEnd: [t + 180, t + 240],
      salePrice: ethers.parseEther('10'),
      saleRatioTier: [ethers.parseEther('1000'), ethers.parseEther('1200'), ethers.parseEther('1300')],
      vestingStartPeriodRatio: [t + 300, 60, ethers.parseEther('0.1')]
    }
  })

  describe('Time', () => {
    it('staking start -> end', async () => {
      standardDeployArgs.stakingStartEnd = [t + 120, t + 60]
      await expect(deploy(deployer, standardDeployArgs)).to.be.revertedWith(
        'Staking start time must be earlier than end time'
      )
    })

    it('sale start -> end', async () => {
      standardDeployArgs.saleStartEnd = [t + 240, t + 180]
      await expect(deploy(deployer, standardDeployArgs)).to.be.revertedWith(
        'Sale start time must be earlier than end time'
      )
    })

    it('staking end -> sale start', async () => {
      standardDeployArgs.stakingStartEnd = [t + 60, t + 210]
      await expect(deploy(deployer, standardDeployArgs)).to.be.revertedWith(
        'Staking end time must be earlier than sale start time'
      )
    })

    it('sale end -> vesting start', async () => {
      standardDeployArgs.saleStartEnd = [t + 180, t + 360]
      standardDeployArgs.vestingStartPeriodRatio = [t + 300, 60, 10]
      await expect(deploy(deployer, standardDeployArgs)).to.be.revertedWith(
        'Vesting start time must be later than sale end time'
      )
    })
  })

  describe('Price & Volume', () => {
    it('staking volume min < max', async () => {
      standardDeployArgs.stakingVolumeMinMax = [ethers.parseEther('1000'), ethers.parseEther('500')]
      await expect(deploy(deployer, standardDeployArgs)).to.be.revertedWith(
        'Staking volume max must be greater than min'
      )
    })

    it('sale price > 0', async () => {
      standardDeployArgs.salePrice = 0
      await expect(deploy(deployer, standardDeployArgs)).to.be.revertedWith('Sale price must be greater than zero')
    })
  })
})
