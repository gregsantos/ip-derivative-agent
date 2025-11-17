# IPDerivativeAgent Deployment Guide

This guide provides step-by-step instructions for deploying IPDerivativeAgent to Story Protocol networks.

## Prerequisites Check

Before starting, ensure you have:

✅ Foundry installed (`foundryup`)  
✅ Git installed  
✅ A wallet with testnet/mainnet tokens  
✅ Story Protocol contract addresses  
✅ Basic understanding of Ethereum transactions

## Step 1: Initial Setup

### 1.1 Extract and Navigate to Project

```bash
cd ip-derivative-agent
```

### 1.2 Install Dependencies

```bash
make install
```

**What happens**: This installs OpenZeppelin contracts and Forge Standard Library.

**Expected output**:

```
Installing foundry-rs/forge-std in lib/forge-std
Installing OpenZeppelin/openzeppelin-contracts in lib/openzeppelin-contracts
Dependencies installed!
```

### 1.3 Build Project

```bash
make build
```

**Expected output**:

```
[⠊] Compiling...
[⠒] Solc 0.8.26 finished in 3.45s
Compiler run successful!
```

## Step 2: Run Tests

### 2.1 Execute Test Suite

```bash
make test
```

**Expected output**:

```
Running 20 tests for test/IPDerivativeAgent.t.sol:IPDerivativeAgentTest
[PASS] test_Constructor_Success() (gas: 2345678)
[PASS] test_AddToWhitelist_Success() (gas: 89234)
...
Test result: ok. 20 passed; 0 failed; 0 skipped; finished in 12.34ms
```

### 2.2 Verify Gas Costs

```bash
make gas-report
```

Review the gas costs to ensure they're acceptable for your use case.

## Step 3: Configuration

### 3.1 Get Story Protocol Addresses

Visit: https://docs.story.foundation/developers/smart-contracts-guide/deployed-smart-contracts

For **Testnet (Aeneid)**, note down:

- LicensingModule address
- RoyaltyModule address

For **Mainnet (Odyssey)**, note down:

- LicensingModule address
- RoyaltyModule address

### 3.2 Prepare Your Wallet

**For Testnet:**

1. Create a new wallet or use an existing testnet wallet
2. Get testnet tokens from Story faucet
3. Export the private key (keep it secure!)

**For Mainnet:**

1. Use a hardware wallet or secure software wallet
2. Ensure you have sufficient mainnet tokens for:
   - Deployment gas (~2.5M gas)
   - Future transaction costs
3. Export the private key (KEEP IT VERY SECURE!)

### 3.3 Configure Environment

```bash
cp .env.example .env
nano .env  # or vim, code, etc.
```

Fill in the values:

```bash
# Your wallet's private key (without 0x prefix)
PRIVATE_KEY=abcdef0123456789...

# The address that will own the IPDerivativeAgent
# This should be YOUR address or a multisig
AGENT_OWNER_ADDRESS=0x1234567890123456789012345678901234567890

# Story Protocol addresses from Step 3.1
LICENSING_MODULE=0x[from_story_docs]
ROYALTY_MODULE=0x[from_story_docs]

# Optional: For contract verification
STORYSCAN_API_KEY=your_api_key
```

### 3.4 Verify Configuration

```bash
make check-env
```

**Expected output**:

```
✅ PRIVATE_KEY set
✅ AGENT_OWNER_ADDRESS: 0x1234...
✅ LICENSING_MODULE: 0x5678...
✅ ROYALTY_MODULE: 0x9abc...
```

## Step 4: Testnet Deployment

### 4.1 Dry Run First (IMPORTANT!)

Always simulate deployment before broadcasting:

```bash
make deploy-testnet-dry
```

**Review the output carefully**:

- Check deployer address is correct
- Verify Agent owner address
- Confirm LicensingModule address
- Confirm RoyaltyModule address
- Check estimated gas costs

### 4.2 Deploy to Testnet

If the dry run looks good:

```bash
make deploy-testnet
```

**This will**:

1. Deploy IPDerivativeAgent contract
2. Transfer ownership to AGENT_OWNER_ADDRESS
3. Verify contract on StoryScan
4. Save deployment info to `deployment.txt`

**Expected output**:

```
========================================
Deployment Configuration
========================================
Deployer: 0xYourAddress...
Agent Owner: 0xAgentAddress...
LicensingModule: 0xLicensingModule...
RoyaltyModule: 0xRoyaltyModule...
========================================

Starting Broadcast...
...

========================================
Deployment Successful!
========================================
IPDerivativeAgent: 0xNewAgentAddress...
Agent Owner: 0xAgentAddress...
Paused: false
========================================

Deployment info saved to deployment.txt
```

### 4.3 Save Deployment Address

```bash
# Save to environment variable
export AGENT_OWNER_ADDRESS=0xNewAgentAddress...

# Or add to .env file
echo "AGENT_OWNER_ADDRESS=0xNewAgentAddress123..." >> .env
```

### 4.4 Verify Deployment

```bash
# Check owner
cast call $AGENT_OWNER_ADDRESS "owner()(address)" --rpc-url story-testnet

# Check licensing module
cast call $AGENT_OWNER_ADDRESS "LICENSING_MODULE()(address)" --rpc-url story-testnet

# Check royalty module
cast call $AGENT_OWNER_ADDRESS "ROYALTY_MODULE()(address)" --rpc-url story-testnet

# Check if paused
cast call $AGENT_OWNER_ADDRESS "paused()(bool)" --rpc-url story-testnet
```

## Step 5: Test Contract on Testnet

### 5.1 Add a Test Whitelist Entry

```bash
# Set test addresses
export TEST_PARENT=0xParentIPAddress...
export TEST_CHILD=0xChildIPAddress...
export TEST_LICENSEE=0xLicenseeAddress...
export TEST_TEMPLATE=0xLicenseTemplateAddress...
export TEST_LICENSE_TERMS_ID=1

# Add to whitelist (requires owner key)
cast send $AGENT_OWNER_ADDRESS \
  "addToWhitelist(address,address,address,address,uint256)" \
  $TEST_PARENT \
  $TEST_CHILD \
  $TEST_LICENSEE \
  $TEST_TEMPLATE \
  $TEST_LICENSE_TERMS_ID \
  --rpc-url story-testnet \
  --private-key $PRIVATE_KEY
```

### 5.2 Verify Whitelist Entry

```bash
cast call $AGENT_OWNER_ADDRESS \
  "isWhitelisted(address,address,address,uint256,address)(bool)" \
  $TEST_PARENT \
  $TEST_CHILD \
  $TEST_TEMPLATE \
  $TEST_LICENSE_TERMS_ID \
  $TEST_LICENSEE \
  --rpc-url story-testnet
```

**Expected output**: `true`

### 5.3 Test Registration (if applicable)

If you have a real test scenario:

```bash
# 1. Get minting fee
cast call $LICENSING_MODULE \
  "predictMintingLicenseFee(address,address,uint256,uint256,address,bytes)(address,uint256)" \
  $TEST_PARENT \
  $TEST_TEMPLATE \
  $TEST_LICENSE_TERMS_ID \
  1 \
  $TEST_LICENSEE \
  0x \
  --rpc-url story-testnet

# 2. Approve fee token (if fee > 0)
cast send $FEE_TOKEN \
  "approve(address,uint256)" \
  $AGENT_OWNER_ADDRESS \
  $FEE_AMOUNT \
  --rpc-url story-testnet \
  --private-key $LICENSEE_KEY

# 3. Register derivative
cast send $AGENT_OWNER_ADDRESS \
  "registerDerivativeViaAgent(address,address,uint256,address,uint256)" \
  $TEST_CHILD \
  $TEST_PARENT \
  $TEST_LICENSE_TERMS_ID \
  $TEST_TEMPLATE \
  0 \
  --rpc-url story-testnet \
  --private-key $LICENSEE_KEY
```

## Step 6: Mainnet Deployment (When Ready)

⚠️ **CRITICAL WARNINGS**:

- This will use real tokens
- Double-check ALL addresses
- Consider using a multisig for AGENT_OWNER_ADDRESS
- Have a rollback/emergency plan
- Notify your team

### 6.1 Update Configuration

```bash
nano .env
```

Update to mainnet addresses:

```bash
LICENSING_MODULE=0x[mainnet_licensing_module]
ROYALTY_MODULE=0x[mainnet_royalty_module]
```

### 6.2 Final Pre-Deployment Checks

```bash
# Verify environment
make check-env

# Run all tests again
make test

# Generate final gas report
make gas-report

# Dry run mainnet deployment
make deploy-mainnet-dry
```

### 6.3 Deploy to Mainnet

⚠️ **LAST CHANCE TO CANCEL**

```bash
# This includes a 5-second delay
make deploy-mainnet
```

Press Ctrl+C within 5 seconds to cancel.

### 6.4 Verify Mainnet Deployment

```bash
# Check contract on StoryScan
# Visit: https://storyscan.xyz/address/$AGENT_OWNER_ADDRESS

# Verify owner
cast call $AGENT_OWNER_ADDRESS "owner()(address)" --rpc-url story-mainnet

# Verify addresses
cast call $AGENT_OWNER_ADDRESS "LICENSING_MODULE()(address)" --rpc-url story-mainnet
cast call $AGENT_OWNER_ADDRESS "ROYALTY_MODULE()(address)" --rpc-url story-mainnet
```

## Step 7: Post-Deployment

### 7.1 Document Everything

Create a deployment record with:

- Deployment date and time
- Network (testnet/mainnet)
- Contract address
- Deployer address
- Owner address
- Transaction hashes
- Gas costs
- Any issues encountered

### 7.2 Setup Monitoring

Consider setting up:

- Event monitoring for WhitelistedAdded, DerivativeRegistered
- Balance monitoring for the contract
- Alerting for unusual activity

### 7.3 Share Information

Share with your team:

- Contract address
- Owner address (who can manage whitelist)
- How to interact with the contract
- Emergency procedures

### 7.4 Backup Critical Information

Securely backup:

- `.env` file (encrypted!)
- `deployment.txt`
- All transaction hashes
- Contract source code

## Troubleshooting Common Deployment Issues

### Issue: "Failed to verify contract"

**Solution**:

```bash
# Manual verification
forge verify-contract \
  $AGENT_OWNER_ADDRESS \
  src/IPDerivativeAgent.sol:IPDerivativeAgent \
  --chain story-testnet \
  --constructor-args $(cast abi-encode "constructor(address,address,address)" $AGENT_OWNER_ADDRESS $LICENSING_MODULE $ROYALTY_MODULE)
```

### Issue: "Insufficient funds for gas"

**Solution**:

- Get more testnet tokens from faucet
- For mainnet, ensure wallet has enough tokens
- Check current gas prices

### Issue: "RPC request failed"

**Solution**:

- Check internet connection
- Verify RPC URL is correct
- Try alternative RPC endpoint
- Check if Story network is operational

### Issue: "Nonce too low"

**Solution**:

```bash
# Reset nonce
cast nonce $YOUR_ADDRESS --rpc-url story-testnet
```

Then retry deployment with correct nonce.

## Emergency Procedures

### If Contract is Compromised

1. **Pause immediately**:

```bash
cast send $AGENT_OWNER_ADDRESS "pause()" \
  --rpc-url [network] \
  --private-key $OWNER_KEY
```

2. **Assess the situation**:

   - What went wrong?
   - Are funds at risk?
   - Can the issue be fixed?

3. **Emergency withdraw** (if funds are stuck):

```bash
# While paused, owner can withdraw
cast send $AGENT_OWNER_ADDRESS \
  "emergencyWithdraw(address,address,uint256)" \
  $TOKEN_ADDRESS \
  $SAFE_ADDRESS \
  $AMOUNT \
  --rpc-url [network] \
  --private-key $OWNER_KEY
```

4. **Communication**:
   - Notify all users
   - Post status updates
   - Provide timeline for resolution

### If Owner Key is Lost

- If using a single owner: Funds and control are **permanently lost**
- This is why using a multisig for AGENT_OWNER_ADDRESS is recommended
- No recovery mechanism exists in the contract

## Best Practices Checklist

Before mainnet deployment:

- [ ] All tests passing
- [ ] Successfully deployed to testnet
- [ ] Tested all critical functions on testnet
- [ ] Verified contract on StoryScan
- [ ] Reviewed all addresses multiple times
- [ ] Considered using multisig for owner
- [ ] Documented emergency procedures
- [ ] Team is aware of deployment
- [ ] Monitoring is set up
- [ ] Have emergency contact list

## Support

If you encounter issues:

1. Check the main README.md
2. Review Foundry documentation
3. Check Story Protocol documentation
4. Join Story Discord community
5. Create detailed issue reports

---

**Good luck with your deployment! 🚀**
