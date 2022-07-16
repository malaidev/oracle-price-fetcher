# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
update:; forge update

# Build & test
build  :; forge clean && forge build --optimize --optimize-runs 1000000
test   :; forge clean && forge test --optimize --optimize-runs 1000000 -v
test-debug   :; forge clean && forge test --optimize --optimize-runs 1000000 -vv
gas-report :; forge clean && forge test --optimize --optimize-runs 1000000 --gas-report
trace   :; forge clean && forge test --optimize --optimize-runs 1000000 -vvv
clean  :; forge clean
snapshot :; forge clean && forge snapshot --optimize --optimize-runs 1000000

# Hardhat
deploy-testnet :; npx hardhat run --network rinkeby scripts/deploy.testnet.ts
deploy-local :; npx hardhat run --network localhost scripts/deploy.local.ts
deploy-mainnet :; npx hardhat run --network mainnet scripts/deploy.mainnet.ts
