#!/bin/bash

# IPDerivativeAgent Setup Script
# This script helps you set up the project quickly

set -e

echo "========================================="
echo "  IPDerivativeAgent Setup Script"
echo "========================================="
echo ""

# Check if foundry is installed
if ! command -v forge &> /dev/null; then
    echo "❌ Foundry is not installed!"
    echo ""
    echo "Please install Foundry first:"
    echo "  curl -L https://foundry.paradigm.xyz | bash"
    echo "  foundryup"
    echo ""
    exit 1
fi

echo "✅ Foundry is installed"
echo ""

# Initialize git repository if not already initialized
if [ ! -d .git ]; then
    echo "📦 Initializing git repository..."
    git init
    echo "✅ Git repository initialized"
    echo ""
fi

# Install dependencies
echo "📦 Installing dependencies..."
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts@v4.9.3
echo "✅ Dependencies installed"
echo ""

# Build project
echo "🔨 Building project..."
forge build
echo "✅ Build successful"
echo ""

# Run tests
echo "🧪 Running tests..."
forge test
echo "✅ Tests passed"
echo ""

# Create .env if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "✅ .env created - PLEASE EDIT IT WITH YOUR VALUES"
    echo ""
    echo "⚠️  IMPORTANT: Edit .env file and add:"
    echo "   - Your PRIVATE_KEY"
    echo "   - AGENT_ADDRESS"
    echo "   - LICENSING_MODULE address"
    echo "   - ROYALTY_MODULE address"
    echo ""
else
    echo "✅ .env file already exists"
    echo ""
fi

# Summary
echo "========================================="
echo "  Setup Complete! 🎉"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Edit .env file with your configuration"
echo "  2. Run 'make check-env' to verify setup"
echo "  3. Run 'make deploy-testnet-dry' for a dry run"
echo "  4. Run 'make deploy-testnet' to deploy"
echo ""
echo "For detailed instructions, see:"
echo "  - README.md"
echo "  - DEPLOYMENT_GUIDE.md"
echo ""
echo "Run 'make help' to see all available commands"
echo ""
