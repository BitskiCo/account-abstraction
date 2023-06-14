import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import { ethers } from 'hardhat'
import { getProxyFactoryDeployment, getSafeSingletonDeployment } from '@safe-global/safe-deployments'

const deployGnosisAccountFactory: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const chainId = await hre.getChainId()

  const proxyFactory = '0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67' // getProxyFactoryDeployment()?.networkAddresses[chainId]
  const safeSingleton = '0x41675C099F32341bf84BFc5382aF534df5C7461a' // getSafeSingletonDeployment({ version: '1.4.1', released: undefined })?.defaultAddress

  console.log('Deploying using SAFE', safeSingleton)

  const provider = ethers.provider
  const from = await provider.getSigner().getAddress()

  const entrypoint = await hre.deployments.get('EntryPoint')

  const managerRet = await hre.deployments.deploy(
    'EIP4337Manager', {
    from,
    args: [entrypoint.address],
    gasLimit: 6e6,
    log: true,
    deterministicDeployment: true
  })
  console.log('==EIP4337Manager addr=', managerRet.address)

  const fallbackRet = await hre.deployments.deploy(
    'EIP4337Fallback', {
    from,
    args: [managerRet.address],
    gasLimit: 6e6,
    log: true,
    deterministicDeployment: true
  })
  console.log('==EIP4337Fallback addr=', fallbackRet.address)


  const ret = await hre.deployments.deploy(
    'GnosisSafeAccountFactory', {
    from,
    args: [proxyFactory, safeSingleton, managerRet.address],
    gasLimit: 6e6,
    log: true,
    deterministicDeployment: true
  })
  console.log('==GnosisSafeAccountFactory addr=', ret.address, 'args', [proxyFactory, safeSingleton, managerRet.address])
}

export default deployGnosisAccountFactory
