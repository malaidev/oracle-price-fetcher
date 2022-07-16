import { IDeployConfig } from "./config/DeployConfig"
import { Deployer, ZERO_ADDRESS } from "./Deployer"
import { DeploymentHelper } from "./utils/DeploymentHelper"

const config: IDeployConfig = {
	isTestnet: true,
	outputFile: "./testnet_deployments.json",
	TX_CONFIRMATIONS: 1,
	chainlinkSEQFlag: "0xa438451D6458044c3c8CD2f6f31c91ac882A6d91",
	chainlinkFlagsContract: "0x491B1dDA0A8fa069bbC1125133A975BF4e85a91b",
	adminAddress: "0x87209dc4B76b14B67BC5E5e5c0737E7d002a219c",
	rentBTC: ZERO_ADDRESS,
	gohm: ZERO_ADDRESS,
	ethChainlink: { priceOracle: "0x5f0423B1a6935dc5596e7A24d98532b67A0AeFd8", indexOracle: ZERO_ADDRESS },
	btcChainlink: { priceOracle: "0x0c9973e7a27d00e656B9f153348dA46CaD70d03d", indexOracle: ZERO_ADDRESS },
	gohmChainlink: { priceOracle: ZERO_ADDRESS, indexOracle: ZERO_ADDRESS },
}

async function main() {
	const helper = new DeploymentHelper(config)

	const gohm20 = await helper.deployUpgradeableContractWithName("MockERC20", "gohm", "setUp", "gohm", "gohm", "18")
	const btc20 = await helper.deployUpgradeableContractWithName("MockERC20", "btc", "setUp", "btc", "btc", 8)

	const mockGohmPriceOracle = await helper.deployContractByName("MockOracle", "gohmOracle")
	await mockGohmPriceOracle.setUp("2735860000000", "2735860000000", 9)

	config.rentBTC = btc20.address
	config.gohm = gohm20.address
	config.gohmChainlink = { priceOracle: mockGohmPriceOracle.address, indexOracle: ZERO_ADDRESS }

	await new Deployer(config).run()
}

main().catch(error => {
	console.error(error)
	process.exitCode = 1
})
