import { IDeployConfig } from "./config/DeployConfig"
import { DeploymentHelper } from "./utils/DeploymentHelper"
import { ethers, upgrades } from "hardhat"
import { Contract, Signer } from "ethers"

export const ZERO_ADDRESS: string = "0x" + "0".repeat(40)

export class Deployer {
	config: IDeployConfig
	helper: DeploymentHelper
	deployer?: Signer

	verificator?: Contract
	priceFeedV2?: Contract
	customOracle?: Contract
	chainlinkOracle?: Contract
	twapOracle?: Contract

	constructor(config: IDeployConfig) {
		this.config = config
		this.helper = new DeploymentHelper(config)
	}

	async run() {
		console.log("run()")
		this.deployer = (await ethers.getSigners())[0]

		this.verificator = await this.helper.deployUpgradeableContractWithName(
			"OracleVerificationV1",
			"OracleVerificationV1"
		)

		this.priceFeedV2 = await this.helper.deployUpgradeableContractWithName(
			"PriceFeedV2",
			"PriceFeedV2",
			"setUp",
			this.verificator.address
		)

		this.customOracle = await this.helper.deployUpgradeableContractWithName(
			"CustomOracleWrapper",
			"CustomOracleWrapper",
			"setUp"
		)

		this.chainlinkOracle = await this.helper.deployUpgradeableContractWithName(
			"ChainlinkWrapper",
			"ChainlinkWrapper",
			"setUp",
			this.config.chainlinkSEQFlag,
			this.config.chainlinkFlagsContract
		)

		this.twapOracle = await this.helper.deployContractByName(
			"TwapOracleWrapper",
			"TwapOracleWrapper",
			this.config.twap?.weth,
			this.config.twap?.chainlinkEth,
			this.config.twap?.chainlingFlagSEQ,
			this.config.twap?.chainlinkFlagsContract
		)

		await this.configOracles()
		await this.configPriceFeedV2()
		await this.transferOwnership()
	}

	async configOracles() {
		console.log("configOracles()")

		if (this.config.isTestnet) {
			//giving wrong decimals for testing -- it should get the decimals of the contract
			await this.helper.sendAndWaitForTransaction(
				this.customOracle?.addOracle(
					this.config.gohm,
					this.config.gohmChainlink.priceOracle,
					18,
					"0x9d1b464a",
					"0x053f14da",
					"0x",
					"0x313ce567"
				)
			)
		} else {
			await this.helper.sendAndWaitForTransaction(
				this.chainlinkOracle?.addOracle(
					this.config.gohm,
					this.config.gohmChainlink.priceOracle,
					this.config.gohmChainlink.indexOracle
				)
			)
		}

		await this.helper.sendAndWaitForTransaction(
			this.chainlinkOracle?.addOracle(ZERO_ADDRESS, this.config.ethChainlink.priceOracle, ZERO_ADDRESS)
		)

		await this.helper.sendAndWaitForTransaction(
			this.chainlinkOracle?.addOracle(this.config.rentBTC, this.config.btcChainlink.priceOracle, ZERO_ADDRESS)
		)

		if (this.config.dopex !== undefined) {
			console.log("Dopex")
			await this.helper.sendAndWaitForTransaction(
				this.customOracle?.addOracle(
					this.config.dopex,
					this.config.dopexOracle?.contract,
					this.config.dopexOracle?.decimals,
					this.config.dopexOracle?.currentPriceHex,
					this.config.dopexOracle?.lastPriceHex,
					this.config.dopexOracle?.lastUpdateHex,
					this.config.dopexOracle?.decimalsHex
				)
			)
		}

		if (this.config.gmx !== undefined) {
			await this.helper.sendAndWaitForTransaction(
				await this.twapOracle?.addOracle(this.config.gmx?.token, this.config.gmx?.pool)
			)
		}
	}

	async configPriceFeedV2() {
		console.log("configPriceFeedV2()")

		await this.helper.sendAndWaitForTransaction(
			this.priceFeedV2?.addOracle(ZERO_ADDRESS, this.chainlinkOracle?.address, ZERO_ADDRESS)
		)
		await this.helper.sendAndWaitForTransaction(
			this.priceFeedV2?.addOracle(this.config.gohm, this.chainlinkOracle?.address, ZERO_ADDRESS)
		)
		await this.helper.sendAndWaitForTransaction(
			this.priceFeedV2?.addOracle(this.config.rentBTC, this.chainlinkOracle?.address, ZERO_ADDRESS)
		)
	}

	async transferOwnership() {
		if ((await this.priceFeedV2?.owner()) == this.deployer?.getAddress()) {
			await this.helper.sendAndWaitForTransaction(this.priceFeedV2?.transferOwnership(this.config.adminAddress))
		}

		if ((await this.customOracle?.owner()) == this.deployer?.getAddress()) {
			await this.helper.sendAndWaitForTransaction(this.customOracle?.transferOwnership(this.config.adminAddress))
		}

		if ((await this.chainlinkOracle?.owner()) == this.deployer?.getAddress()) {
			await this.helper.sendAndWaitForTransaction(
				this.chainlinkOracle?.transferOwnership(this.config.adminAddress)
			)
		}

		upgrades.admin.transferProxyAdminOwnership(this.config.adminAddress)
	}
}
