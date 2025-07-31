// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Script, console} from "forge-std/Script.sol";
import {CrossChainToken} from "src/CrossChainToken.sol";

/**
 * @title Deploy Script for CrossChainToken
 * @author VIA Labs Development Team
 * @notice Deployment script for CrossChainToken with multi-chain configuration
 * 
 * Usage:
 *   # Deploy to Avalanche testnet
 *   forge script script/Deploy.s.sol --rpc-url avalanche-testnet --broadcast --verify -vvvv
 * 
 *   # Deploy to Base testnet
 *   forge script script/Deploy.s.sol --rpc-url base-testnet --broadcast --verify -vvvv
 * 
 *   # Deploy with interactive private key prompt
 *   forge script script/Deploy.s.sol --rpc-url avalanche-testnet --broadcast --verify --interactives 1
 */
contract DeployScript is Script {
    // Deployment configuration
    struct DeploymentConfig {
        address messageV3;
        uint256[] destChainIds;
        address[] destContracts;
        uint16[] confirmations;
    }

    // Network configurations
    mapping(uint256 => DeploymentConfig) public deploymentConfigs;

    function setUp() public {
        // Avalanche Testnet (43113) - bridge to Base Testnet
        deploymentConfigs[43113] = DeploymentConfig({
            messageV3: 0x8f92F60ffFB05d8c64E755e54A216090D8D6Eaf9, // VIA Labs MessageV3 on Avalanche testnet
            destChainIds: new uint256[](1),
            destContracts: new address[](1),
            confirmations: new uint16[](1)
        });
        deploymentConfigs[43113].destChainIds[0] = 84532; // Base testnet
        deploymentConfigs[43113].destContracts[0] = address(0); // Will be set after deployment
        deploymentConfigs[43113].confirmations[0] = 1;

        // Base Testnet (84532) - bridge to Avalanche Testnet
        deploymentConfigs[84532] = DeploymentConfig({
            messageV3: 0xE700Ee5d8B7dEc62987849356821731591c048cF, // VIA Labs MessageV3 on Base testnet
            destChainIds: new uint256[](1),
            destContracts: new address[](1),
            confirmations: new uint16[](1)
        });
        deploymentConfigs[84532].destChainIds[0] = 43113; // Avalanche testnet
        deploymentConfigs[84532].destContracts[0] = address(0); // Will be set after deployment
        deploymentConfigs[84532].confirmations[0] = 1;
    }

    function run() public {
        // Load environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        uint256 chainId = block.chainid;

        console.log("=== CrossChainToken Deployment ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", chainId);
        console.log("Balance:", deployer.balance);

        // Validate deployment configuration
        require(deploymentConfigs[chainId].messageV3 != address(0), "MessageV3 address not configured for this chain");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy CrossChainToken
        CrossChainToken token = new CrossChainToken();

        console.log("CrossChainToken deployed to:", address(token));
        console.log("Token name:", token.name());
        console.log("Token symbol:", token.symbol());
        console.log("Initial supply:", token.totalSupply());
        console.log("Owner (MESSAGE_OWNER):", token.MESSAGE_OWNER());

        // Configure the cross-chain client if MessageV3 address is provided
        DeploymentConfig memory config = deploymentConfigs[chainId];
        if (config.messageV3 != address(0)) {
            console.log("Configuring cross-chain client...");
            console.log("MessageV3 address:", config.messageV3);
            
            // Note: dest contracts will need to be updated after deployment on other chains
            if (config.destContracts[0] != address(0)) {
                token.configureClient(
                    config.messageV3,
                    config.destChainIds,
                    config.destContracts,
                    config.confirmations
                );
                console.log("Cross-chain client configured successfully");
                console.log("Destination chain ID:", config.destChainIds[0]);
                console.log("Destination contract:", config.destContracts[0]);
            } else {
                console.log("WARNING: Destination contracts not set. Manual configuration required.");
            }
        }

        vm.stopBroadcast();

        // Post-deployment validation
        console.log("=== Deployment Validation ===");
        require(token.MESSAGE_OWNER() == deployer, "MESSAGE_OWNER not set correctly");
        require(token.balanceOf(deployer) == 1_000_000 ether, "Initial balance not correct");
        require(token.totalSupply() == 1_000_000 ether, "Total supply not correct");

        console.log("SUCCESS: Deployment completed successfully!");
        console.log("Contract address:", address(token));
        
        // Save deployment info for cross-chain configuration
        _saveDeploymentInfo(chainId, address(token));
    }

    /**
     * @notice Save deployment information for later cross-chain configuration
     * @param chainId The chain ID where the contract was deployed
     * @param tokenAddress The deployed token contract address
     */
    function _saveDeploymentInfo(uint256 chainId, address tokenAddress) internal {
        string memory deploymentInfo = string(abi.encodePacked(
            "Chain ID: ", vm.toString(chainId), "\n",
            "Token Address: ", vm.toString(tokenAddress), "\n",
            "Deployer: ", vm.toString(msg.sender), "\n",
            "Block Number: ", vm.toString(block.number), "\n",
            "Timestamp: ", vm.toString(block.timestamp), "\n"
        ));
        
        string memory filename = string(abi.encodePacked(
            "deployment_", vm.toString(chainId), "_", vm.toString(block.timestamp), ".txt"
        ));
        
        // Note: This would require fs_permissions in foundry.toml to write files
        // vm.writeFile(filename, deploymentInfo);
        
        console.log("Deployment info:");
        console.log(deploymentInfo);
    }
}