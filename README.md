# IPDerivativeAgent - Story Protocol Derivative Registration Agent

A production-ready smart contract for delegated derivative registration on Story Protocol. This agent manages a whitelist system allowing authorized licensees to register derivatives through a trusted intermediary, handling ERC-20 minting fees automatically.

## 📋 Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Testing](#testing)
- [Deployment](#deployment)
- [Contract Interaction](#contract-interaction)
- [Security](#security)
- [Troubleshooting](#troubleshooting)

## ✨ Features

- **Whitelist Management**: Owner-controlled whitelist for (parentIp, childIp, licenseTemplate, licenseId, licensee) tuples
- **Wildcard Support**: Use address(0) as licensee to allow any caller
- **Automatic Fee Handling**: Pulls ERC-20 minting fees from licensees and manages RoyaltyModule approvals
- **Security Features**:
  - ReentrancyGuard protection
  - Pausable for emergency stops
  - Emergency withdrawal (only when paused)
  - Fee validation against maximum limits
- **Gas Optimized**: Batch operations with unchecked increments
- **Production Ready**: Comprehensive tests, audit-ready code

## 🏗️ Architecture

```
┌─────────────────┐
│    Licensee     │
│  (Derivative    │
│     Owner)      │
└────────┬────────┘
         │ 1. Approve tokens
         │ 2. Call registerDerivativeViaAgent
         ▼
┌─────────────────────────┐
│    IPDerivativeAgent    │
│  ┌──────────────────┐   │
│  │   Whitelist      │   │
│  │   Management     │   │
│  └──────────────────┘   │
│  ┌──────────────────┐   │
│  │  Fee Handling    │   │
│  └──────────────────┘   │
└────────┬────────────────┘
         │ 3. Transfer tokens
         │ 4. Approve RoyaltyModule
         │ 5. Call registerDerivative
         ▼
┌─────────────────────────┐
│   LicensingModule       │
│   (Story Protocol)      │
└─────────────────────────┘
```

## 📦 Prerequisites

Before you begin, ensure you have the following installed:

- **Foundry**: The Ethereum development toolkit

  ```bash
  curl -L https://foundry.paradigm.xyz | bash
  foundryup
  ```

- **Git**: For version control

  ```bash
  # On macOS
  brew install git

  # On Ubuntu/Debian
  sudo apt-get install git
  ```

- **Make** (optional but recommended): For running convenient commands

  ```bash
  # On macOS
  xcode-select --install

  # On Ubuntu/Debian
  sudo apt-get install build-essential
  ```

## 🚀 Installation

### 1. Clone or Extract the Repository

```bash
# If you have the zip file
unzip ip-derivative-agent.zip
cd ip-derivative-agent

# Or if cloning from a repo
git clone <your-repo-url>
cd ip-derivative-agent
```

### 2. Install Dependencies

```bash
# Using Make (recommended)
make install

# Or manually with Foundry
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts@v4.9.3
```

### 3. Build the Project

```bash
# Using Make
make build

# Or with Foundry
forge build
```

You should see output like:

```
[⠊] Compiling...
[⠒] Compiling 30 files with 0.8.26
[⠑] Solc 0.8.26 finished in 3.45s
Compiler run successful!
```

## ⚙️ Configuration

### 1. Environment Setup

Copy the example environment file and fill in your values:

```bash
cp .env.example .env
```

### 2. Edit `.env` File

Open `.env` in your favorite editor and configure:

```bash
# Your deployer wallet private key (without 0x prefix)
PRIVATE_KEY=your_private_key_here

# Owner address (will control the agent)
AGENT_OWNER_ADDRESS=0x1234567890123456789012345678901234567890

# Story Protocol contract addresses
# For Testnet (Aeneid):
LICENSING_MODULE=0x[testnet_licensing_module_address]
ROYALTY_MODULE=0x[testnet_royalty_module_address]

# For Mainnet (Odyssey):
# LICENSING_MODULE=0x[mainnet_licensing_module_address]
# ROYALTY_MODULE=0x[mainnet_royalty_module_address]

# Optional: StoryScan API key for contract verification
STORYSCAN_API_KEY=your_api_key_here
```

### 3. Get Story Protocol Contract Addresses

Visit the official Story documentation to get current contract addresses:

**📚 [Story Protocol Deployed Contracts](https://docs.story.foundation/developers/deployed-smart-contracts)**

### 4. Verify Configuration

```bash
make check-env
```

Expected output:

```
✅ PRIVATE_KEY set
✅ AGENT_OWNER_ADDRESS: 0x1234...
✅ LICENSING_MODULE: 0x5678...
✅ ROYALTY_MODULE: 0x9abc...
```

## 🧪 Testing

### Run All Tests

```bash
# Using Make (with detailed output)
make test

# Or with Foundry
forge test
```

### Run Tests with Verbosity

```bash
# Maximum verbosity (shows all traces)
make test-verbose

# Or
forge test -vvvv
```

### Generate Coverage Report

```bash
make coverage
```

### Generate Gas Report

```bash
make gas-report
```

### Run Specific Tests

```bash
# Test only whitelist functionality
forge test --match-contract IPDerivativeAgentTest --match-test test_AddToWhitelist

# Test only registration
forge test --match-test test_RegisterDerivative
```

Expected test output:

```
Running 20 tests for test/IPDerivativeAgent.t.sol:IPDerivativeAgentTest
[PASS] test_AddToWhitelist_Success() (gas: 89234)
[PASS] test_RegisterDerivative_Success_WithFee() (gas: 234567)
[PASS] test_EmergencyWithdraw_ERC20_Success() (gas: 123456)
...
Test result: ok. 20 passed; 0 failed; finished in 12.34ms
```

## 🚀 Deployment

### Testnet Deployment (Aeneid)

#### 1. Dry Run (Simulation)

Always test your deployment first:

```bash
make deploy-testnet-dry
```

This simulates the deployment without broadcasting transactions. Review the output carefully.

#### 2. Actual Deployment

```bash
make deploy-testnet
```

The deployment will:

1. Validate all environment variables
2. Deploy the IPDerivativeAgent contract
3. Verify the contract on StoryScan
4. Save deployment info to `deployment.txt`

**Expected Output:**

```
========================================
Deployment Configuration
========================================
Deployer: 0xYourAddress...
Agent Owner: 0xAgentAddress...
LicensingModule: 0xLicensingModule...
RoyaltyModule: 0xRoyaltyModule...
========================================

[Deployment transactions...]

========================================
Deployment Successful!
========================================
IPDerivativeAgent: 0xNewAgentAddress...
Agent Owner: 0xAgentAddress...
Paused: false
========================================

Deployment info saved to deployment.txt
```

### Mainnet Deployment (Odyssey)

⚠️ **WARNING**: Deploying to mainnet will use real tokens. Double-check everything!

#### 1. Update Environment

```bash
# In your .env file, update to mainnet addresses
LICENSING_MODULE=0x[mainnet_licensing_module_address]
ROYALTY_MODULE=0x[mainnet_royalty_module_address]
```

#### 2. Dry Run

```bash
make deploy-mainnet-dry
```

#### 3. Deploy to Mainnet

```bash
# This includes a 5-second safety delay
make deploy-mainnet
```

### Manual Deployment

If you prefer more control:

```bash
# Testnet
forge script script/DeployAndVerify.s.sol:DeployAndVerifyScript \
  --rpc-url https://rpc.testnet.story.foundation \
  --broadcast \
  --verify

# Mainnet
forge script script/DeployAndVerify.s.sol:DeployAndVerifyScript \
  --rpc-url https://rpc.story.foundation \
  --broadcast \
  --verify
```

## 🔧 Contract Interaction

### After Deployment

Save your deployment address:

```bash
export AGENT_OWNER_ADDRESS=0x[your_deployed_AGENT_OWNER_ADDRESS]
```

### Owner Operations (Using Cast)

#### 1. Add to Whitelist

```bash
cast send $AGENT_OWNER_ADDRESS \
  "addToWhitelist(address,address,address,address,uint256)" \
  $PARENT_IP \
  $CHILD_IP \
  $LICENSEE \
  $LICENSE_TEMPLATE \
  $LICENSE_ID \
  --rpc-url https://rpc.testnet.story.foundation \
  --private-key $PRIVATE_KEY
```

#### 2. Add Wildcard Entry (Any Caller Allowed)

```bash
cast send $AGENT_OWNER_ADDRESS \
  "addWildcardToWhitelist(address,address,address,uint256)" \
  $PARENT_IP \
  $CHILD_IP \
  $LICENSE_TEMPLATE \
  $LICENSE_ID \
  --rpc-url https://rpc.testnet.story.foundation \
  --private-key $PRIVATE_KEY
```

#### 3. Check Whitelist Status

```bash
cast call $AGENT_OWNER_ADDRESS \
  "isWhitelisted(address,address,address,uint256,address)(bool)" \
  $PARENT_IP \
  $CHILD_IP \
  $LICENSE_TEMPLATE \
  $LICENSE_ID \
  $LICENSEE \
  --rpc-url https://rpc.testnet.story.foundation
```

#### 4. Pause Contract

```bash
cast send $AGENT_OWNER_ADDRESS \
  "pause()" \
  --rpc-url https://rpc.testnet.story.foundation \
  --private-key $PRIVATE_KEY
```

#### 5. Emergency Withdraw (While Paused)

```bash
# Withdraw ERC20 tokens
cast send $AGENT_OWNER_ADDRESS \
  "emergencyWithdraw(address,address,uint256)" \
  $TOKEN_ADDRESS \
  $RECIPIENT \
  $AMOUNT \
  --rpc-url https://rpc.testnet.story.foundation \
  --private-key $PRIVATE_KEY

# Withdraw native tokens (use address(0) for token)
cast send $AGENT_OWNER_ADDRESS \
  "emergencyWithdraw(address,address,uint256)" \
  0x0000000000000000000000000000000000000000 \
  $RECIPIENT \
  $AMOUNT \
  --rpc-url https://rpc.testnet.story.foundation \
  --private-key $PRIVATE_KEY
```

### Licensee Operations

#### 1. Approve Minting Fee Token

**CRITICAL**: Licensees must approve the agent to spend minting fee tokens before registering derivatives.

```bash
# First, get the minting fee
cast call $LICENSING_MODULE \
  "predictMintingLicenseFee(address,address,uint256,uint256,address,bytes)(address,uint256)" \
  $PARENT_IP \
  $LICENSE_TEMPLATE \
  $LICENSE_ID \
  1 \
  $LICENSEE \
  0x \
  --rpc-url https://rpc.testnet.story.foundation

# Then approve the agent
cast send $FEE_TOKEN \
  "approve(address,uint256)" \
  $AGENT_OWNER_ADDRESS \
  $FEE_AMOUNT \
  --rpc-url https://rpc.testnet.story.foundation \
  --private-key $LICENSEE_PRIVATE_KEY
```

#### 2. Register Derivative

```bash
cast send $AGENT_OWNER_ADDRESS \
  "registerDerivativeViaAgent(address,address,uint256,address,uint256)" \
  $CHILD_IP \
  $PARENT_IP \
  $LICENSE_ID \
  $LICENSE_TEMPLATE \
  0 \
  --rpc-url https://rpc.testnet.story.foundation \
  --private-key $LICENSEE_PRIVATE_KEY
```

## 🔒 Security

### Audit Status

✅ **Internal Audit Completed** - All critical and high severity issues resolved

- Fixed compilation errors
- Implemented fee validation
- Simplified allowance management
- Added comprehensive input validation
- Implemented emergency pause mechanism

### Security Features

- **ReentrancyGuard**: Protects against reentrancy attacks
- **Pausable**: Emergency circuit breaker
- **Access Control**: Owner-only administrative functions
- **Fee Validation**: Prevents overpaying minting fees
- **Safe Token Operations**: Uses OpenZeppelin's SafeERC20
- **Immutable Addresses**: Critical contract addresses cannot be changed

### Best Practices

1. **Always test on testnet first**
2. **Verify all addresses before deployment**
3. **Use hardware wallets for mainnet deployments**
4. **Monitor contract events for unusual activity**
5. **Keep private keys secure and never commit them**
6. **Use pause() in case of suspicious activity**

### Known Limitations

- No token recovery mechanism while unpaused (by design)
- Emergency withdraw requires contract to be paused
- No upgrade mechanism (deploy new version if needed)

## 🐛 Troubleshooting

### Common Issues

#### 1. "Module not found" Error

```bash
Error: Could not find artifact: @openzeppelin/contracts/...
```

**Solution:**

```bash
make install
# or
forge install
```

#### 2. Compilation Errors

```bash
Error: Solc version mismatch
```

**Solution:**

```bash
forge clean
forge build
```

#### 3. RPC Connection Issues

```bash
Error: Failed to connect to RPC
```

**Solution:**

- Check your internet connection
- Verify RPC URL in foundry.toml
- Try alternative RPC endpoints
- Check if Story network is operational

#### 4. Gas Estimation Failed

```bash
Error: Gas estimation failed
```

**Solution:**

- Check if you have enough native tokens for gas
- Verify all addresses are correct
- Ensure contract is not paused (for registration calls)
- Check if you're whitelisted (for registration calls)

#### 5. Insufficient Allowance

```bash
Error: ERC20: insufficient allowance
```

**Solution:**

```bash
# Approve the agent to spend your tokens first
cast send $TOKEN_ADDRESS "approve(address,uint256)" $AGENT_OWNER_ADDRESS $AMOUNT ...
```

### Getting Help

- **Story Protocol Docs**: https://docs.story.foundation
- **Story Discord**: Join the Story community
- **Foundry Book**: https://book.getfoundry.sh

## 📊 Gas Estimates

Approximate gas costs (may vary):

| Operation                      | Gas Cost   |
| ------------------------------ | ---------- |
| Deploy Contract                | ~2,500,000 |
| Add to Whitelist               | ~50,000    |
| Register Derivative (with fee) | ~200,000   |
| Register Derivative (no fee)   | ~100,000   |
| Pause/Unpause                  | ~30,000    |
| Emergency Withdraw             | ~60,000    |

## 📝 Development Workflow

### Typical Development Flow

```bash
# 1. Make changes to contracts
vim src/IPDerivativeAgent.sol

# 2. Format code
make format

# 3. Build
make build

# 4. Run tests
make test

# 5. Check gas usage
make gas-report

# 6. Test deployment (dry run)
make deploy-testnet-dry

# 7. Deploy to testnet
make deploy-testnet

# 8. Test on testnet
# ... interact with contract ...

# 9. Deploy to mainnet when ready
make deploy-mainnet
```

## 📄 License

BUSL-1.1 - See LICENSE file for details

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## ✅ Deployment Checklist

Before deploying to mainnet:

- [ ] All tests passing
- [ ] Code reviewed
- [ ] Configuration verified
- [ ] Deployed and tested on testnet
- [ ] Story Protocol addresses verified
- [ ] Owner address verified
- [ ] Gas costs reviewed
- [ ] Emergency procedures documented
- [ ] Team notified

## 📚 Additional Resources

- [Story Protocol Documentation](https://docs.story.foundation)
- [Foundry Book](https://book.getfoundry.sh)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts)
- [Solidity Documentation](https://docs.soliditylang.org)

---

**Built with ❤️ for Story Protocol**
