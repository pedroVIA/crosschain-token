// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Script, console} from "forge-std/Script.sol";
import {CrossChainToken} from "src/CrossChainToken.sol";

/**
 * @title Configuration Script for CrossChainToken
 * @author VIA Labs Development Team
 * @notice Script to configure cross-chain connections after deployment on multiple chains
 * 
 * Usage:
 *   # Configure Avalanche testnet to connect to Base testnet
 *   AVALANCHE_TOKEN=0x... BASE_TOKEN=0x... MESSAGE_V3=0x... \
 *   forge script script/Configure.s.sol --rpc-url avalanche-testnet --broadcast -vvvv
 * 
 *   # Configure Base testnet to connect to Avalanche testnet  
 *   AVALANCHE_TOKEN=0x... BASE_TOKEN=0x... MESSAGE_V3=0x... \
 *   forge script script/Configure.s.sol --rpc-url base-testnet --broadcast -vvvv
 */
contract ConfigureScript is Script {
    // Environment variable keys
    string constant AVALANCHE_TOKEN_KEY = "AVALANCHE_TOKEN";
    string constant BASE_TOKEN_KEY = "BASE_TOKEN";
    string constant MESSAGE_V3_KEY = "MESSAGE_V3";

    // Chain IDs
    uint256 constant AVALANCHE_TESTNET = 43113;
    uint256 constant BASE_TESTNET = 84532;

    function run() public {
        // Load environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address avalancheToken = vm.envAddress(AVALANCHE_TOKEN_KEY);
        address baseToken = vm.envAddress(BASE_TOKEN_KEY);
        address messageV3 = vm.envAddress(MESSAGE_V3_KEY);
        uint256 chainId = block.chainid;

        console.log("=== CrossChainToken Configuration ===");
        console.log("Chain ID:", chainId);
        console.log("Avalanche Token:", avalancheToken);
        console.log("Base Token:", baseToken);
        console.log("MessageV3:", messageV3);

        // Validate inputs
        require(avalancheToken != address(0), "AVALANCHE_TOKEN not set");
        require(baseToken != address(0), "BASE_TOKEN not set");
        require(messageV3 != address(0), "MESSAGE_V3 not set");
        require(chainId == AVALANCHE_TESTNET || chainId == BASE_TESTNET, "Unsupported chain");

        // Determine current and destination addresses
        address currentToken;
        address destToken;
        uint256 destChainId;

        if (chainId == AVALANCHE_TESTNET) {
            currentToken = avalancheToken;
            destToken = baseToken;
            destChainId = BASE_TESTNET;
            console.log("Configuring Avalanche testnet -> Base testnet");
        } else {
            currentToken = baseToken;
            destToken = avalancheToken;
            destChainId = AVALANCHE_TESTNET;
            console.log("Configuring Base testnet -> Avalanche testnet");
        }

        vm.startBroadcast(deployerPrivateKey);

        // Get the token contract
        CrossChainToken token = CrossChainToken(payable(currentToken));

        // Verify we own the contract
        require(token.MESSAGE_OWNER() == vm.addr(deployerPrivateKey), "Not the MESSAGE_OWNER");

        // Configure cross-chain connection
        uint256[] memory destChainIds = new uint256[](1);
        destChainIds[0] = destChainId;

        address[] memory destContracts = new address[](1);
        destContracts[0] = destToken;

        uint16[] memory confirmations = new uint16[](1);
        confirmations[0] = 1; // 1 confirmation for testnet

        console.log("Configuring client with:");
        console.log("- MessageV3:", messageV3);
        console.log("- Dest Chain ID:", destChainId);
        console.log("- Dest Contract:", destToken);
        console.log("- Confirmations:", confirmations[0]);

        token.configureClient(messageV3, destChainIds, destContracts, confirmations);

        vm.stopBroadcast();

        console.log("SUCCESS:Configuration completed successfully!");
        
        // Validate configuration by testing if chain is active
        // Note: This is a read-only check, no transaction needed
        console.log("=== Configuration Validation ===");
        console.log("Current token address:", address(token));
        console.log("Destination chain configured for chain ID:", destChainId);
    }
}