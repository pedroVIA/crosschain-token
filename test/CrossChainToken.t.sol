// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Test.sol";
import "../src/CrossChainToken.sol";
import "@vialabs-io/npm-contracts/IMessageV3.sol";

// Mock MessageV3 contract for testing
contract MockMessageV3 is IMessageV3 {
    mapping(address => uint) public override maxgas;
    mapping(address => address) public override exsig;
    address public override feeToken;
    address public override weth;
    
    constructor() {
        feeToken = address(0); // No fee token for testing
        weth = address(0); // No WETH for testing
    }
    
    function chainsig() external pure override returns (address) { return address(0); }
    function feeTokenDecimals() external pure override returns (uint) { return 18; }
    function minFee() external pure override returns (uint) { return 0; }
    function bridgeEnabled() external pure override returns (bool) { return true; }
    function takeFeesOffline() external pure override returns (bool) { return false; }
    function whitelistOnly() external pure override returns (bool) { return false; }
    function enabledChains(uint) external pure override returns (bool) { return true; }
    function customSourceFee(address) external pure override returns (uint) { return 0; }
    function minTokenForChain(uint) external pure override returns (uint) { return 0; }
    function getSourceFee(uint, bool) external pure override returns (uint) { return 0; }
    
    function sendMessage(address, uint, bytes calldata, uint16, bool) external pure override returns (uint) {
        return 1; // Mock transaction ID
    }
    
    function sendRequest(address, uint, uint, address, bytes calldata, uint16) external pure override returns (uint) {
        return 1; // Mock transaction ID
    }
    
    function setExsig(address _signer) external override {
        exsig[msg.sender] = _signer;
    }
    
    function setMaxgas(uint _maxgas) external override {
        maxgas[msg.sender] = _maxgas;
    }
    
    function setMaxfee(uint) external pure override {
        // Mock implementation
    }
}

contract CrossChainTokenTest is Test {
    CrossChainToken public token;
    MockMessageV3 public mockMessage;
    address public owner;
    address public alice;
    address public bob;
    
    // Test constants
    uint256 constant INITIAL_SUPPLY = 1_000_000 ether;
    uint256 constant BRIDGE_AMOUNT = 100 ether;
    uint256 constant DEST_CHAIN_ID = 43113; // Avalanche testnet
    
    // Events to test
    event TokensBridged(address indexed sender, uint indexed destChainId, address indexed recipient, uint amount);
    event TokensReceived(uint indexed sourceChainId, address indexed recipient, uint amount);
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    function setUp() public {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        
        // Deploy the mock message contract first
        mockMessage = new MockMessageV3();
        
        // Deploy the token contract
        token = new CrossChainToken();
    }
    
    function testDeployment() public {
        // Test token properties
        assertEq(token.name(), "Cross Chain Native Token");
        assertEq(token.symbol(), "CCNT");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        
        // Test initial balance
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
        
        // Test MESSAGE_OWNER is set correctly
        assertEq(token.MESSAGE_OWNER(), owner);
    }
    
    function testTransfer() public {
        // Transfer tokens to alice
        uint256 transferAmount = 1000 ether;
        
        vm.expectEmit(true, true, false, true);
        emit Transfer(owner, alice, transferAmount);
        
        token.transfer(alice, transferAmount);
        
        assertEq(token.balanceOf(alice), transferAmount);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - transferAmount);
    }
    
    function testBurn() public {
        uint256 burnAmount = 500 ether;
        uint256 initialBalance = token.balanceOf(owner);
        
        token.burn(burnAmount);
        
        assertEq(token.balanceOf(owner), initialBalance - burnAmount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - burnAmount);
    }
    
    function testBurnFrom() public {
        uint256 burnAmount = 500 ether;
        
        // Transfer tokens to alice
        token.transfer(alice, 1000 ether);
        
        // Alice approves owner to burn
        vm.prank(alice);
        token.approve(owner, burnAmount);
        
        // Owner burns alice's tokens
        token.burnFrom(alice, burnAmount);
        
        assertEq(token.balanceOf(alice), 1000 ether - burnAmount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - burnAmount);
    }
    
    function testBridge() public {
        // First configure the client to make the chain active
        uint256[] memory destChainIds = new uint256[](1);
        destChainIds[0] = DEST_CHAIN_ID;
        
        address[] memory destContracts = new address[](1);
        destContracts[0] = makeAddr("destContract");
        
        uint16[] memory confirmations = new uint16[](1);
        confirmations[0] = 1;
        
        token.configureClient(address(mockMessage), destChainIds, destContracts, confirmations);
        
        // Give alice some tokens
        token.transfer(alice, BRIDGE_AMOUNT * 2);
        
        // Alice bridges tokens
        vm.startPrank(alice);
        
        // Expect the bridge event
        vm.expectEmit(true, true, true, true);
        emit TokensBridged(alice, DEST_CHAIN_ID, bob, BRIDGE_AMOUNT);
        
        // Execute bridge
        token.bridge(DEST_CHAIN_ID, bob, BRIDGE_AMOUNT);
        
        vm.stopPrank();
        
        // Verify tokens were burned
        assertEq(token.balanceOf(alice), BRIDGE_AMOUNT);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - BRIDGE_AMOUNT);
    }
    
    function testBridgeRevertsInactiveChain() public {
        // Give alice some tokens
        token.transfer(alice, BRIDGE_AMOUNT);
        
        // Try to bridge to an inactive chain (should revert)
        vm.prank(alice);
        vm.expectRevert("MessageClient: destination chain not active");
        token.bridge(9999, bob, BRIDGE_AMOUNT); // Non-configured chain
    }
    
    function testMessageProcess() public {
        // First configure the client
        uint256[] memory destChainIds = new uint256[](1);
        destChainIds[0] = 84532; // Base testnet
        
        address[] memory destContracts = new address[](1);
        destContracts[0] = address(token); // This contract on the other chain
        
        uint16[] memory confirmations = new uint16[](1);
        confirmations[0] = 1;
        
        token.configureClient(address(mockMessage), destChainIds, destContracts, confirmations);
        
        // Simulate receiving a cross-chain message
        uint256 sourceChainId = 84532; // Base testnet
        address recipient = alice;
        uint256 amount = 250 ether;
        
        // Encode the message data
        bytes memory messageData = abi.encode(recipient, amount);
        
        // Set up the context as if the message contract is calling
        // MessageProcess expects specific parameters
        vm.prank(address(mockMessage));
        
        // Expect the TokensReceived event
        vm.expectEmit(true, true, false, true);
        emit TokensReceived(sourceChainId, recipient, amount);
        
        // Call messageProcess (the actual function that gets called by the bridge)
        token.messageProcess(
            1, // txId
            sourceChainId,
            destContracts[0], // sender should be the contract on source chain
            address(0), // target (not used)
            0, // value (not used)
            messageData
        );
        
        // Verify tokens were minted
        assertEq(token.balanceOf(recipient), amount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + amount);
    }
    
    function testOnlyMessageContractCanProcessMessage() public {
        // Configure first
        uint256[] memory destChainIds = new uint256[](1);
        destChainIds[0] = 84532;
        address[] memory destContracts = new address[](1);
        destContracts[0] = address(token);
        uint16[] memory confirmations = new uint16[](1);
        confirmations[0] = 1;
        
        token.configureClient(address(mockMessage), destChainIds, destContracts, confirmations);
        
        bytes memory messageData = abi.encode(alice, 100 ether);
        
        // Try to call messageProcess directly from non-message contract (should revert)
        vm.expectRevert("MessageClient: not authorized");
        token.messageProcess(1, 84532, address(token), address(0), 0, messageData);
    }
    
    function testConfigureClient() public {
        uint256[] memory destChainIds = new uint256[](2);
        destChainIds[0] = 43113; // Avalanche testnet
        destChainIds[1] = 84532; // Base testnet
        
        address[] memory destContracts = new address[](2);
        destContracts[0] = makeAddr("avalancheContract");
        destContracts[1] = makeAddr("baseContract");
        
        uint16[] memory confirmations = new uint16[](2);
        confirmations[0] = 1;
        confirmations[1] = 1;
        
        // Only MESSAGE_OWNER can configure
        token.configureClient(address(mockMessage), destChainIds, destContracts, confirmations);
        
        // Verify configuration by checking if chains are active
        // We can test this by trying to bridge (it should not revert for configured chains)
        token.transfer(alice, 1000 ether);
        vm.prank(alice);
        // This should not revert since chain is configured
        token.bridge(43113, bob, 100 ether);
    }
    
    function testOnlyOwnerCanConfigureClient() public {
        uint256[] memory destChainIds = new uint256[](1);
        address[] memory destContracts = new address[](1);
        uint16[] memory confirmations = new uint16[](1);
        
        // Non-owner tries to configure (should revert)
        vm.prank(alice);
        vm.expectRevert("MessageClient: not authorized");
        token.configureClient(address(mockMessage), destChainIds, destContracts, confirmations);
    }
    
    // Fuzz testing for bridge amounts
    function testFuzzBridge(uint256 amount) public {
        // Bound the amount to reasonable values
        amount = bound(amount, 1, INITIAL_SUPPLY / 2);
        
        // Configure client first
        uint256[] memory destChainIds = new uint256[](1);
        destChainIds[0] = DEST_CHAIN_ID;
        address[] memory destContracts = new address[](1);
        destContracts[0] = makeAddr("destContract");
        uint16[] memory confirmations = new uint16[](1);
        confirmations[0] = 1;
        
        token.configureClient(address(mockMessage), destChainIds, destContracts, confirmations);
        
        // Give alice tokens
        token.transfer(alice, amount);
        
        // Bridge the tokens
        vm.prank(alice);
        token.bridge(DEST_CHAIN_ID, bob, amount);
        
        // Verify
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - amount);
    }
    
    // Fuzz testing for processMessage amounts
    function testFuzzMessageProcess(uint256 amount, address recipient) public {
        // Bound inputs
        amount = bound(amount, 1, type(uint256).max / 2); // Avoid overflow
        vm.assume(recipient != address(0));
        
        // Configure client
        uint256[] memory destChainIds = new uint256[](1);
        destChainIds[0] = 84532;
        address[] memory destContracts = new address[](1);
        destContracts[0] = address(token);
        uint16[] memory confirmations = new uint16[](1);
        confirmations[0] = 1;
        
        token.configureClient(address(mockMessage), destChainIds, destContracts, confirmations);
        
        // Process message
        vm.prank(address(mockMessage));
        token.messageProcess(
            1, // txId
            84532, // sourceChainId
            address(token), // sender
            address(0), // target
            0, // value
            abi.encode(recipient, amount)
        );
        
        // Verify
        assertEq(token.balanceOf(recipient), amount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + amount);
    }
}