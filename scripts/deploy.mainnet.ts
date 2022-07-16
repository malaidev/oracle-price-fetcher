import { IDeployConfig } from "./config/DeployConfig"
import { Deployer, ZERO_ADDRESS } from "./Deployer"
import { colorLog, Colors, addColor } from "./utils/ColorConsole"
import * as readline from "readline-sync"

const config: IDeployConfig = {
	isTestnet: false,
	outputFile: "./mainnet_deployments.json",
	TX_CONFIRMATIONS: 3,
	chainlinkSEQFlag: "0xa438451D6458044c3c8CD2f6f31c91ac882A6d91",
	chainlinkFlagsContract: "0x3C14e07Edd0dC67442FA96f1Ec6999c57E810a83",
	adminAddress: "0x4A4651B31d747D1DdbDDADCF1b1E24a5f6dcc7b0",
	rentBTC: "0xdbf31df14b66535af65aac99c32e9ea844e14501",
	gohm: "0x8d9ba570d6cb60c7e3e0f31343efe75ab8e65fb1",
	ethChainlink: { priceOracle: "0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612", indexOracle: ZERO_ADDRESS },
	btcChainlink: { priceOracle: "0x6ce185860a4963106506C203335A2910413708e9", indexOracle: ZERO_ADDRESS },
	gohmChainlink: {
		priceOracle: "0x761aaeBf021F19F198D325D7979965D0c7C9e53b",
		indexOracle: "0x48C4721354A3B29D80EF03C65E6644A37338a0B1",
	},
	dopex: "0x6C2C06790b3E3E3c38e12Ee22F8183b37a13EE55",
	dopexOracle: {
		contract: "0x252C07E0356d3B1a8cE273E39885b094053137b9",
		decimals: 8,
		currentPriceHex: "0xe1aa6036",
		lastPriceHex: "0x053f14da",
		lastUpdateHex: "0x",
		decimalsHex: "0x",
	},

	twap: {
		weth: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
		chainlinkEth: "0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612",
		chainlingFlagSEQ: "0xa438451D6458044c3c8CD2f6f31c91ac882A6d91",
		chainlinkFlagsContract: "0x3C14e07Edd0dC67442FA96f1Ec6999c57E810a83",
	},

	gmx: {
		token: "0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a",
		pool: "0x80A9ae39310abf666A87C743d6ebBD0E8C42158E",
	},
}

async function main() {
	var userinput: string = "0"

	userinput = readline.question(
		addColor(Colors.yellow, `\nYou are about to deploy on the mainnet, is it fine? [y/N]\n`)
	)

	if (userinput.toLowerCase() !== "y") {
		colorLog(Colors.blue, `User cancelled the deployment!\n`)
		return
	}

	colorLog(Colors.green, `User approved the deployment\n`)

	await new Deployer(config).run()
}

main().catch(error => {
	console.error(error)
	process.exitCode = 1
})
