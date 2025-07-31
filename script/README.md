# CrossChainToken Deployment Scripts

This directory contains Foundry scripts for deploying and managing the CrossChainToken contract across multiple chains.

## Scripts Overview

- **Deploy.s.sol** - Deploys CrossChainToken to a single chain
- **Configure.s.sol** - Configures cross-chain connections after deployment on both chains
- **Bridge.s.sol** - Executes token bridging between configured chains

## Prerequisites

1. **Environment Setup**
   ```bash
   # Copy environment template
   cp .env.example .env
   
   # Edit .env with your values
   PRIVATE_KEY=your_private_key_here
   AVALANCHE_TESTNET_RPC=https://api.avax-test.network/ext/bc/C/rpc
   BASE_TESTNET_RPC=https://sepolia.base.org
   SNOWTRACE_API_KEY=your_snowtrace_api_key
   BASESCAN_API_KEY=your_basescan_api_key
   ```

2. **Foundry Configuration**
   - Ensure `foundry.toml` has proper RPC endpoints and API keys configured
   - Scripts require the contracts to be compiled: `forge build`

## Deployment Workflow

### Step 1: Deploy to First Chain (Avalanche Testnet)

```bash
# Deploy to Avalanche testnet
forge script script/Deploy.s.sol \
  --rpc-url avalanche-testnet \
  --broadcast \
  --verify \
  -vvvv
```

**Note the deployed contract address** from the output.

### Step 2: Deploy to Second Chain (Base Testnet)

```bash
# Deploy to Base testnet
forge script script/Deploy.s.sol \
  --rpc-url base-testnet \
  --broadcast \
  --verify \
  -vvvv
```

**Note the deployed contract address** from the output.

### Step 3: Configure Cross-Chain Connections

After deploying to both chains, configure the cross-chain connections:

```bash
# Set environment variables for configuration
export AVALANCHE_TOKEN=0x... # Address from Step 1
export BASE_TOKEN=0x...      # Address from Step 2  
export MESSAGE_V3=0x...      # VIA Labs MessageV3 contract address

# Configure Avalanche -> Base connection
forge script script/Configure.s.sol \
  --rpc-url avalanche-testnet \
  --broadcast \
  -vvvv

# Configure Base -> Avalanche connection  
forge script script/Configure.s.sol \
  --rpc-url base-testnet \
  --broadcast \
  -vvvv
```

## Usage Examples

### Bridge Tokens

After deployment and configuration, use the Bridge script to transfer tokens:

```bash
# Bridge 100 tokens from Avalanche to Base
export TOKEN_ADDRESS=0x...        # Avalanche token address
export RECIPIENT=0x...           # Recipient address on Base
export AMOUNT=100000000000000000000  # 100 tokens (18 decimals)
export DEST_CHAIN_ID=84532       # Base testnet chain ID

forge script script/Bridge.s.sol \
  --rpc-url avalanche-testnet \
  --broadcast \
  -vvvv
```

```bash
# Bridge 50 tokens from Base to Avalanche
export TOKEN_ADDRESS=0x...        # Base token address
export RECIPIENT=0x...           # Recipient address on Avalanche
export AMOUNT=50000000000000000000   # 50 tokens (18 decimals)
export DEST_CHAIN_ID=43113       # Avalanche testnet chain ID

forge script script/Bridge.s.sol \
  --rpc-url base-testnet \
  --broadcast \
  -vvvv
```

## Chain Information

| Network | Chain ID | RPC Endpoint | Explorer |
|---------|----------|--------------|----------|
| Avalanche Testnet | 43113 | https://api.avax-test.network/ext/bc/C/rpc | https://testnet.snowtrace.io |
| Base Testnet | 84532 | https://sepolia.base.org | https://sepolia.basescan.org |

## Script Parameters

### Deploy.s.sol
- **Environment Variables Required:**
  - `PRIVATE_KEY` - Deployer's private key
- **Network Configuration:**
  - Automatically detects chain ID and uses appropriate configuration
  - MessageV3 addresses need to be configured in the script

### Configure.s.sol
- **Environment Variables Required:**
  - `PRIVATE_KEY` - Must be the MESSAGE_OWNER of the contracts
  - `AVALANCHE_TOKEN` - Address of token deployed on Avalanche testnet
  - `BASE_TOKEN` - Address of token deployed on Base testnet
  - `MESSAGE_V3` - Address of VIA Labs MessageV3 contract

### Bridge.s.sol
- **Environment Variables Required:**
  - `PRIVATE_KEY` - Must have tokens to bridge
  - `TOKEN_ADDRESS` - Address of token contract on current chain
  - `RECIPIENT` - Address to receive tokens on destination chain
  - `AMOUNT` - Amount to bridge in wei (18 decimals)
  - `DEST_CHAIN_ID` - Destination chain ID (43113 or 84532)

## Security Considerations

1. **Private Key Management:**
   - Use `--interactives 1` flag for secure private key input
   - Never commit private keys to version control
   - Consider using hardware wallets for mainnet deployments

2. **Contract Verification:**
   - Always verify contracts on block explorers
   - Use `--verify` flag during deployment
   - Ensure API keys are properly configured

3. **Testing:**
   - Test all scripts on testnets before mainnet deployment
   - Verify cross-chain functionality with small amounts first
   - Run the comprehensive test suite: `forge test`

## Troubleshooting

### Common Issues

1. **Gas Estimation Failures:**
   - Add `--gas-estimate-multiplier 120` to script commands
   - Ensure sufficient ETH balance for gas fees

2. **Verification Failures:**
   - Check API keys in foundry.toml
   - Retry with `--resume` flag if deployment succeeded but verification failed

3. **Configuration Errors:**
   - Ensure MessageV3 addresses are correct for each network
   - Verify deployer is the MESSAGE_OWNER of contracts

### Debugging

Use different verbosity levels:
- `-v` - Basic logs
- `-vv` - More detailed logs  
- `-vvv` - Include traces
- `-vvvv` - Include traces and setup
- `-vvvvv` - Maximum verbosity

## Production Deployment

For mainnet deployment:

1. **Update Configuration:**
   - Replace testnet RPC URLs with mainnet endpoints
   - Update MessageV3 addresses for mainnet
   - Use mainnet chain IDs (1 for Ethereum, 43114 for Avalanche, 8453 for Base)

2. **Security Measures:**
   - Use multisig wallets for contract ownership
   - Implement timelock controllers for critical functions
   - Conduct thorough security audits

3. **Monitoring:**
   - Set up monitoring for cross-chain transactions
   - Implement alerting for failed bridge operations
   - Monitor contract balances and total supply consistency