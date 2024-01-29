import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { time } from '@nomicfoundation/hardhat-network-helpers'
import { expect } from 'chai'
import { ethers } from 'hardhat'
import { NvirLaunchpad, Token } from '../typechain-types'
import { DeployArgs, deploy } from './utils/deploy'

describe('NotEnoughSale', () => {
  let staking: Token
  let sale: Token
  let purchase: Token
  let t: number
  let standardDeployArgs: DeployArgs

  let deployer: HardhatEthersSigner
  let alice: HardhatEthersSigner
  let bob: HardhatEthersSigner
  let carol: HardhatEthersSigner
  let users: HardhatEthersSigner[]

  let lp: NvirLaunchpad

  beforeEach(async () => {
    const signers = await ethers.getSigners()
    deployer = signers[0]
    alice = signers[1]
    bob = signers[2]
    users = [alice, bob]

    staking = await (await ethers.getContractFactory('Token'))
      .connect(deployer)
      .deploy('STK', 18, ethers.parseEther('1000000000'))
    sale = await (await ethers.getContractFactory('Token'))
      .connect(deployer)
      .deploy('SAL', 18, ethers.parseEther('1000000000'))
    purchase = await (await ethers.getContractFactory('Token'))
      .connect(deployer)
      .deploy('PUR', 18, ethers.parseEther('1000000000'))

    await staking.waitForDeployment()
    await sale.waitForDeployment()
    await purchase.waitForDeployment()

    t = await time.latest()

    standardDeployArgs = {
      name: 'Standard Launchpad',
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
    lp = await deploy(deployer, standardDeployArgs)

    for (const user of users) {
      await staking.connect(deployer).transfer(user.address, ethers.parseEther('100000'))
      await purchase.connect(deployer).transfer(user.address, ethers.parseEther('100000'))

      await staking.connect(user).approve(await lp.getAddress(), ethers.MaxUint256)
      await sale.connect(user).approve(await lp.getAddress(), ethers.MaxUint256)
      await purchase.connect(user).approve(await lp.getAddress(), ethers.MaxUint256)
    }

    await staking.connect(deployer).approve(await lp.getAddress(), ethers.MaxUint256)
    await sale.connect(deployer).approve(await lp.getAddress(), ethers.MaxUint256)
    await purchase.connect(deployer).approve(await lp.getAddress(), ethers.MaxUint256)

    // The deployer not provide enough tokens
    // await lp.connect(deployer).depositSaleTokens(ethers.parseEther('100000'))
  })

  describe('NotEnoughSale', () => {
    it('stake -> unstake -> sale -> vesting -> REVERT', async () => {
      // alice stake 1000 ether
      await lp.connect(alice).stake(ethers.parseEther('1000'))

      await time.increaseTo(t + 150)
      await lp.connect(alice).unstake(alice.address)

      const pos = await lp.positions(alice.address)

      await time.increaseTo(t + 200)

      // alice buy 20000 PUR -> buy 2000 SAL
      await expect(lp.connect(alice).participateInSale(ethers.parseEther('20000'))).to.be.revertedWith('Sold out')
    })

    it('stake -> unstake -> sale -> vesting -> success', async () => {
      await lp.connect(deployer).depositSaleTokens(ethers.parseEther('100000'))

      expect(await lp.connect(deployer).saleTotalAmount()).to.equal(ethers.parseEther('100000'))
      expect(await lp.connect(deployer).soldTotalAmount()).to.equal(ethers.parseEther('0'))

      // alice stake 1000 ether
      await lp.connect(alice).stake(ethers.parseEther('1000'))

      await time.increaseTo(t + 150)
      await lp.connect(alice).unstake(alice.address)

      const pos = await lp.positions(alice.address)

      await time.increaseTo(t + 200)

      // alice buy 20000 PUR -> buy 2000 SAL
      await lp.connect(alice).participateInSale(ethers.parseEther('20000'))

      expect(await purchase.balanceOf(alice.address)).to.equal(ethers.parseEther('80000'))

      await time.increaseTo(t + 10000)

      expect(await sale.balanceOf(alice.address)).to.equal(ethers.parseEther('0'))

      // // The balance is not enough so the transaction revert.
      await lp.connect(alice).releaseVestedTokens(alice.address)

      expect(await sale.balanceOf(alice.address)).to.equal(ethers.parseEther('2000'))
    })
  })
})
