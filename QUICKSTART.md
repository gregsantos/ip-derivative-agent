# Quick Start Guide

Get up and running with IPDerivativeAgent in 5 minutes!

## Prerequisites

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

## 1. Setup Project (1 minute)

```bash
# Extract and navigate
cd yokoa-agent-deploy

# Run setup script
chmod +x setup.sh
./setup.sh
```

## 2. Configure (2 minutes)

```bash
# Edit environment file
nano .env
```

Fill in:

```bash
PRIVATE_KEY=your_key_here
AGENT_ADDRESS=0xYourOwnerAddress
LICENSING_MODULE=0xLicensingModuleAddress
ROYALTY_MODULE=0xRoyaltyModuleAddress
```

Get Story Protocol addresses from:
https://docs.story.foundation/developers/smart-contracts-guide/deployed-smart-contracts

## 3. Test (1 minute)

```bash
# Verify environment
make check-env

# Run tests
make test
```

## 4. Deploy Testnet (1 minute)

```bash
# Dry run first
make deploy-testnet-dry

# Deploy for real
make deploy-testnet
```

## 5. Verify Deployment

```bash
# Check deployment.txt for your contract address
cat deployment.txt

# Set as environment variable
export AGENT_ADDRESS=0xYourDeployedAddress

# Verify it's working
cast call $AGENT_ADDRESS "owner()(address)" --rpc-url story-testnet
```

## Next Steps

1. **Add to Whitelist**:

   ```bash
   cast send $AGENT_ADDRESS \
     "addToWhitelist(address,address,address,address,uint256)" \
     $PARENT_IP $CHILD_IP $LICENSEE $TEMPLATE $LICENSE_ID \
     --rpc-url story-testnet --private-key $PRIVATE_KEY
   ```

2. **Test Registration**:

   - See DEPLOYMENT_GUIDE.md for detailed testing instructions

3. **Deploy to Mainnet**:
   - When ready, update .env with mainnet addresses
   - Run `make deploy-mainnet`

## Common Commands

```bash
make help              # Show all commands
make test              # Run tests
make build             # Compile contracts
make deploy-testnet    # Deploy to testnet
make check-env         # Verify configuration
```

## Need Help?

- **Detailed Guide**: See DEPLOYMENT_GUIDE.md
- **Full Documentation**: See README.md
- **Security Info**: See SECURITY.md

---

**That's it! You're ready to go! 🚀**
