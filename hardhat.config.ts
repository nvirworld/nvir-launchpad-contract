import '@nomicfoundation/hardhat-toolbox'
import fs from 'fs'
import { HardhatUserConfig } from 'hardhat/config'

const privateKey = fs.readFileSync('.secret.main').toString().trim()

const config: HardhatUserConfig = {
  solidity: '0.8.20',
  networks: {
    hardhat: {
      allowBlocksWithSameTimestamp: true
    },
    mainnet: {
      url: 'https://mainnet.infura.io/v3/a92d3f6424df4ba799962a849910e93a',
      chainId: 1,
      gasPrice: 'auto',
      accounts: [privateKey]
    },
    sepolia: {
      url: 'https://ethereum-sepolia.blockpi.network/v1/rpc/public',
      chainId: 11155111,
      gasPrice: 'auto',
      accounts: [privateKey]
    },
    goerli: {
      url: 'https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161',
      chainId: 5,
      gasPrice: 'auto',
      accounts: [privateKey]
    },
    bsc: {
      url: 'https://bsc-dataseed1.binance.org/',
      chainId: 56,
      gasPrice: 'auto',
      accounts: [privateKey]
    },
    bsctest: {
      url: 'https://bsc-testnet.publicnode.com',
      chainId: 97,
      gasPrice: 'auto',
      accounts: [privateKey]
    }
  }
}

export default config
