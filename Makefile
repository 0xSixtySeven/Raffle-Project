-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil 

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
ETHERSCAN_API_KEY := X17UXE6UMNEEKYX85DGPUG53FWCPNYVBR4
# etherscan api key is to verify the contract on etherscan, its in the etherscan site under the account settings

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""
	@echo ""
	@echo "  make fund [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install Cyfrin/foundry-devops@0.0.11 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@0.6.1 --no-commit && forge install foundry-rs/forge-std@v1.5.3 --no-commit && forge install transmissions11/solmate@v6 --no-commit

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test 

snapshot :; forge snapshot

format :; forge fmt

# --steps-tracing is to show the steps of the transaction
# --bock-time is to set the block time to 1 second
#  both this commands are very useful when debugging
anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

# if do not put an argument after ARGS(--network sepolia), it will use the default network
NETWORK_ARGS := --rpc-url http://127.0.0.1:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast
# := is a variable assignment operator, it will assign the value to the variable when the makefile is read

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif
# this is how we assing the arguments we need to use after ARGS(in this case --network sepolia) so it will trigger sepolia instead of the local network.
# if we do not put the arguments after ARGS, it will use the default network


deploy:
	@forge script script/DeployRaffle.s.sol:DeployRaffle $(NETWORK_ARGS) 
#script script/fileName.s.sol/contractName $(The ARGS you have defined) 
# the @ sign is to hide the command in the terminal, if not it will print all the command in the terminal.
# to run the command, type:     make deploy ARGS="--network sepolia"     in the terminal

createSubscription:
	@forge script script/Interactions.s.sol:CreateSubscription $(NETWORK_ARGS)

addConsumer:
	@forge script script/Interactions.s.sol:AddConsumer $(NETWORK_ARGS)

fundSubscription:
	@forge script script/Interactions.s.sol:FundSubscription $(NETWORK_ARGS)

testRaffle:
	@forge test --fork-url $(SEPOLIA_RPC_URL) -vvvv