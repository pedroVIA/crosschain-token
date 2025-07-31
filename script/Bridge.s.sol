// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Script, console} from "forge-std/Script.sol";
import {CrossChainToken} from "src/CrossChainToken.sol";

/**
 * @title Bridge Script for CrossChainToken
 * @author VIA Labs Development Team
 * @notice Script to bridge tokens between chains
 * 
 * Usage:
 *   # Bridge 100 tokens from Avalanche to Base
 *   TOKEN_ADDRESS=0x... RECIPIENT=0x... AMOUNT=100000000000000000000 DEST_CHAIN_ID=84532 \
 *   forge script script/Bridge.s.sol --rpc-url avalanche-testnet --broadcast -vvvv
 * 
 *   # Bridge 50 tokens from Base to Avalanche
 *   TOKEN_ADDRESS=0x... RECIPIENT=0x... AMOUNT=50000000000000000000 DEST_CHAIN_ID=43113 \
 *   forge script script/Bridge.s.sol --rpc-url base-testnet --broadcast -vvvv
 */
contract BridgeScript is Script {
    // Environment variable keys
    string constant TOKEN_ADDRESS_KEY = "TOKEN_ADDRESS";
    string constant RECIPIENT_KEY = "RECIPIENT";
    string constant AMOUNT_KEY = "AMOUNT";
    string constant DEST_CHAIN_ID_KEY = "DEST_CHAIN_ID";

    // Chain IDs
    uint256 constant AVALANCHE_TESTNET = 43113;
    uint256 constant BASE_TESTNET = 84532;

    function run() public {
        // Load environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address tokenAddress = vm.envAddress(TOKEN_ADDRESS_KEY);
        address recipient = vm.envAddress(RECIPIENT_KEY);
        uint256 amount = vm.envUint(AMOUNT_KEY);
        uint256 destChainId = vm.envUint(DEST_CHAIN_ID_KEY);
        
        address sender = vm.addr(deployerPrivateKey);
        uint256 chainId = block.chainid;

        console.log("=== CrossChainToken Bridge ===");
        console.log("Current Chain ID:", chainId);
        console.log("Token Address:", tokenAddress);
        console.log("Sender:", sender);
        console.log("Recipient:", recipient);
        console.log("Amount (wei):", amount);
        console.log("Amount (tokens):", amount / 1e18);
        console.log("Destination Chain ID:", destChainId);

        // Validate inputs
        require(tokenAddress != address(0), "TOKEN_ADDRESS not set");
        require(recipient != address(0), "RECIPIENT not set");
        require(amount > 0, "AMOUNT must be greater than 0");
        require(destChainId == AVALANCHE_TESTNET || destChainId == BASE_TESTNET, "Invalid destination chain");
        require(destChainId != chainId, "Cannot bridge to same chain");

        // Get the token contract
        CrossChainToken token = CrossChainToken(payable(tokenAddress));

        // Check sender's balance
        uint256 senderBalance = token.balanceOf(sender);
        require(senderBalance >= amount, "Insufficient balance");

        console.log("Sender balance before bridge:", senderBalance / 1e18, "tokens");
        uint256 initialTotalSupply = token.totalSupply();
        console.log("Total supply before bridge:", initialTotalSupply / 1e18, "tokens");

        vm.startBroadcast(deployerPrivateKey);

        // Execute the bridge transaction
        console.log("Executing bridge transaction...");
        token.bridge(destChainId, recipient, amount);

        vm.stopBroadcast();

        // Post-bridge validation
        uint256 senderBalanceAfter = token.balanceOf(sender);
        uint256 totalSupplyAfter = token.totalSupply();

        console.log("=== Bridge Transaction Completed ===");
        console.log("Sender balance after bridge:", senderBalanceAfter / 1e18, "tokens");
        console.log("Total supply after bridge:", totalSupplyAfter / 1e18, "tokens");
        console.log("Tokens burned:", (senderBalance - senderBalanceAfter) / 1e18, "tokens");
        console.log("Total supply reduced:", (token.totalSupply() - totalSupplyAfter) / 1e18, "tokens");

        // Validate the bridge operation
        require(senderBalanceAfter == senderBalance - amount, "Balance not updated correctly");
        require(totalSupplyAfter == initialTotalSupply - amount, "Total supply not updated correctly");

        console.log("SUCCESS: Bridge transaction completed successfully!");
        console.log("Tokens will be minted to", recipient, "on chain", destChainId);
    }

    /**
     * @notice Helper function to check if a chain is configured for bridging
     * @param tokenAddress The token contract address
     * @param destChainId The destination chain ID to check
     */
    function checkChainConfiguration(address tokenAddress, uint256 destChainId) public view returns (bool) {
        CrossChainToken token = CrossChainToken(payable(tokenAddress));
        
        // Try to call a view function that would revert if chain is not configured
        // This is a simple check - in production you might want more sophisticated validation
        try token.MESSAGE_OWNER() returns (address) {
            // If we can call this, the contract exists
            // Additional checks could be added here
            return true;
        } catch {
            return false;
        }
    }
}