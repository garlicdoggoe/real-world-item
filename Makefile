-include .env

build:; forge build

deploy-sepolia:
	forge script script/DeployLogistics.s.sol:DeployLogistics --rpc-url ${SEPOLIA_RPC_URL} --private-key ${PRIVATE_KEY} --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY} -vvvv
	