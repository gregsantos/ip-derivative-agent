.PHONY: help install build test clean deploy-testnet deploy-mainnet verify-testnet verify-mainnet

# Load environment variables
-include .env

help: ## Display this help message
	@echo "IPDerivativeAgent Deployment Makefile"
	@echo ""
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

install: ## Install dependencies
	@echo "Installing Foundry dependencies..."
	@if [ ! -d .git ]; then git init; fi
	forge install foundry-rs/forge-std
	forge install OpenZeppelin/openzeppelin-contracts@v4.9.3
	@echo "Dependencies installed!"

build: ## Compile contracts
	@echo "Building contracts..."
	forge build
	@echo "Build complete!"

test: ## Run tests
	@echo "Running tests..."
	forge test -vv
	@echo "Tests complete!"

test-verbose: ## Run tests with maximum verbosity
	@echo "Running tests with full verbosity..."
	forge test -vvvv

coverage: ## Generate test coverage report
	@echo "Generating coverage report..."
	forge coverage

clean: ## Clean build artifacts
	@echo "Cleaning build artifacts..."
	forge clean
	rm -rf out cache broadcast deployment.txt
	@echo "Clean complete!"

format: ## Format code
	@echo "Formatting code..."
	forge fmt

gas-report: ## Generate gas report
	@echo "Generating gas report..."
	forge test --gas-report

# Deployment commands

deploy-testnet: ## Deploy to Story Testnet (Aeneid)
	@echo "Deploying to Story Testnet..."
	@if [ -z "$(PRIVATE_KEY)" ]; then echo "Error: PRIVATE_KEY not set in .env"; exit 1; fi
	@if [ -z "$(AGENT_OWNER_ADDRESS)" ]; then echo "Error: AGENT_OWNER_ADDRESS not set in .env"; exit 1; fi
	@if [ -z "$(LICENSING_MODULE)" ]; then echo "Error: LICENSING_MODULE not set in .env"; exit 1; fi
	@if [ -z "$(ROYALTY_MODULE)" ]; then echo "Error: ROYALTY_MODULE not set in .env"; exit 1; fi
	forge script script/DeployAndVerify.s.sol:DeployAndVerifyScript \
		--rpc-url story-testnet \
		--broadcast \
		--verify \
		-vvvv

deploy-testnet-dry: ## Dry run deployment to Story Testnet
	@echo "Dry run deployment to Story Testnet..."
	forge script script/DeployAndVerify.s.sol:DeployAndVerifyScript \
		--rpc-url story-testnet \
		-vvvv

deploy-mainnet: ## Deploy to Story Mainnet (Odyssey) - USE WITH CAUTION
	@echo "WARNING: Deploying to Story Mainnet!"
	@echo "Press Ctrl+C to cancel, or wait 5 seconds to continue..."
	@sleep 5
	@if [ -z "$(PRIVATE_KEY)" ]; then echo "Error: PRIVATE_KEY not set in .env"; exit 1; fi
	@if [ -z "$(AGENT_OWNER_ADDRESS)" ]; then echo "Error: AGENT_OWNER_ADDRESS not set in .env"; exit 1; fi
	@if [ -z "$(LICENSING_MODULE)" ]; then echo "Error: LICENSING_MODULE not set in .env"; exit 1; fi
	@if [ -z "$(ROYALTY_MODULE)" ]; then echo "Error: ROYALTY_MODULE not set in .env"; exit 1; fi
	forge script script/DeployAndVerify.s.sol:DeployAndVerifyScript \
		--rpc-url story-mainnet \
		--broadcast \
		--verify \
		-vvvv

deploy-mainnet-dry: ## Dry run deployment to Story Mainnet
	@echo "Dry run deployment to Story Mainnet..."
	forge script script/DeployAndVerify.s.sol:DeployAndVerifyScript \
		--rpc-url story-mainnet \
		-vvvv

# Verification commands

verify-testnet: ## Verify contract on Story Testnet
	@if [ -z "$(CONTRACT_ADDRESS)" ]; then echo "Error: CONTRACT_ADDRESS not set"; exit 1; fi
	forge verify-contract $(CONTRACT_ADDRESS) \
		src/IPDerivativeAgent.sol:IPDerivativeAgent \
		--chain story-testnet \
		--constructor-args $$(cast abi-encode "constructor(address,address,address)" $(AGENT_OWNER_ADDRESS) $(LICENSING_MODULE) $(ROYALTY_MODULE))

verify-mainnet: ## Verify contract on Story Mainnet
	@if [ -z "$(CONTRACT_ADDRESS)" ]; then echo "Error: CONTRACT_ADDRESS not set"; exit 1; fi
	forge verify-contract $(CONTRACT_ADDRESS) \
		src/IPDerivativeAgent.sol:IPDerivativeAgent \
		--chain story-mainnet \
		--constructor-args $$(cast abi-encode "constructor(address,address,address)" $(AGENT_OWNER_ADDRESS) $(LICENSING_MODULE) $(ROYALTY_MODULE))

# Utility commands

check-env: ## Check if environment variables are set
	@echo "Checking environment variables..."
	@if [ -z "$(PRIVATE_KEY)" ]; then echo "❌ PRIVATE_KEY not set"; else echo "✅ PRIVATE_KEY set"; fi
	@if [ -z "$(AGENT_OWNER_ADDRESS)" ]; then echo "❌ AGENT_OWNER_ADDRESS not set"; else echo "✅ AGENT_OWNER_ADDRESS: $(AGENT_OWNER_ADDRESS)"; fi
	@if [ -z "$(LICENSING_MODULE)" ]; then echo "❌ LICENSING_MODULE not set"; else echo "✅ LICENSING_MODULE: $(LICENSING_MODULE)"; fi
	@if [ -z "$(ROYALTY_MODULE)" ]; then echo "❌ ROYALTY_MODULE not set"; else echo "✅ ROYALTY_MODULE: $(ROYALTY_MODULE)"; fi

snapshot: ## Create gas snapshot
	@echo "Creating gas snapshot..."
	forge snapshot

flatten: ## Flatten contract for verification
	@echo "Flattening IPDerivativeAgent..."
	forge flatten src/IPDerivativeAgent.sol > IPDerivativeAgent-flattened.sol
	@echo "Flattened contract saved to IPDerivativeAgent-flattened.sol"
