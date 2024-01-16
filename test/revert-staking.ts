// import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
// import { time } from '@nomicfoundation/hardhat-network-helpers'
// import { expect } from 'chai'
// import { ethers } from 'hardhat'
// import { NvirLaunchpad, Token } from '../typechain-types'
// import { DeployArgs, GU, deploy } from './utils/deploy'

// describe('StakingRevert', () => {
//   let staking: Token
//   let sale: Token
//   let purchase: Token
//   let t: number
//   let standardDeployArgs: DeployArgs

//   let deployer: HardhatEthersSigner
//   let alice: HardhatEthersSigner
//   let bob: HardhatEthersSigner
//   let carol: HardhatEthersSigner
//   let users: HardhatEthersSigner[]

//   let lp: NvirLaunchpad

//   beforeEach(async () => {
//     const signers = await ethers.getSigners()
//     deployer = signers[0]
//     alice = signers[1]
//     bob = signers[2]
//     carol = signers[3]
//     users = [alice, bob, carol]

//     staking = await (await ethers.getContractFactory('Token')).connect(deployer).deploy('STK', 18, 1000000000)
//     sale = await (await ethers.getContractFactory('Token')).connect(deployer).deploy('SAL', 18, 1000000000)
//     purchase = await (await ethers.getContractFactory('Token')).connect(deployer).deploy('PUR', 18, 1000000000)

//     await staking.waitForDeployment()
//     await sale.waitForDeployment()
//     await purchase.waitForDeployment()

//     t = await time.latest()

//     staking.connect(deployer).transfer(alice.address, 100000 * GU)
//     staking.connect(deployer).transfer(bob.address, 100000 * GU)
//     staking.connect(deployer).transfer(carol.address, 100000 * GU)

//     standardDeployArgs = {
//       name: 'Standard Launchpad',
//       stakingSalePurchaseToken: {
//         staking: await staking.getAddress(),
//         sale: await sale.getAddress(),
//         purchase: await purchase.getAddress()
//       },
//       stakingStartEnd: [t + 60, t + 120],
//       stakingVolumeMinMax: [100 * GU, 100000 * GU],
//       stakingVolumeTier: [1000 * GU, 5000 * GU],
//       saleStartEnd: [t + 180, t + 240],
//       salePrice: 10 * GU,
//       saleRatioTier: [1000 * GU, 1200 * GU, 1300 * GU],
//       vestingStartPeriodRatio: [t + 300, 60, 10]
//     }
//     lp = await deploy(deployer, standardDeployArgs)
//   })

//   describe('isset', () => {
//     it("alice's STK balance", async () => {
//       expect(await staking.balanceOf(alice.address)).to.be.equal(100000 * GU)
//     })
//   })
// })
