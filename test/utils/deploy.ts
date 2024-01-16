import { AddressLike, BigNumberish, ContractRunner } from 'ethers'
import { ethers } from 'hardhat'

export interface DeployArgs {
  name: string
  stakingSalePurchaseToken: StakingSalePurchaseToken
  stakingStartEnd: [BigNumberish, BigNumberish]
  stakingVolumeMinMax: [BigNumberish, BigNumberish]
  stakingVolumeTier: [BigNumberish, BigNumberish]
  saleStartEnd: [BigNumberish, BigNumberish]
  salePrice: BigNumberish
  saleRatioTier: [BigNumberish, BigNumberish, BigNumberish]
  vestingStartPeriodRatio: [BigNumberish, BigNumberish, BigNumberish]
}

export interface StakingSalePurchaseToken {
  staking: AddressLike
  sale: AddressLike
  purchase: AddressLike
}

export async function deploy(owner: ContractRunner, args: DeployArgs) {
  const lpFactory = await ethers.getContractFactory('NvirLaunchpad')
  const lp = await lpFactory
    .connect(owner)
    .deploy(
      args.name,
      [
        args.stakingSalePurchaseToken.staking,
        args.stakingSalePurchaseToken.sale,
        args.stakingSalePurchaseToken.purchase
      ],
      args.stakingStartEnd,
      args.stakingVolumeMinMax,
      args.stakingVolumeTier,
      args.saleStartEnd,
      args.salePrice,
      args.saleRatioTier,
      args.vestingStartPeriodRatio
    )
  await lp.waitForDeployment()
  return lp
}
