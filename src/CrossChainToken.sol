// SPDX-License-Identifier: MIT
// (c)2024 Atlas (atlas@vialabs.io)
pragma solidity =0.8.17;

import "@vialabs-io/npm-contracts/MessageClient.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract CrossChainToken is ERC20Burnable, MessageClient {
    // Events for tracking cross-chain transfers
    event TokensBridged(address indexed sender, uint indexed destChainId, address indexed recipient, uint amount);
    event TokensReceived(uint indexed sourceChainId, address indexed recipient, uint amount);

    constructor() ERC20("Cross Chain Native Token", "CCNT") {
        MESSAGE_OWNER = msg.sender;
        _mint(msg.sender, 1_000_000 ether);
    }

    function bridge(uint _destChainId, address _recipient, uint _amount) external onlyActiveChain(_destChainId) {
        _burn(msg.sender, _amount);
        _sendMessage(_destChainId, abi.encode(_recipient, _amount));
        
        // Emit event when tokens are bridged
        emit TokensBridged(msg.sender, _destChainId, _recipient, _amount);
    }

    function _processMessage(uint, uint _sourceChainId, bytes calldata _data) internal virtual override {
        (address _recipient, uint _amount) = abi.decode(_data, (address, uint));
        _mint(_recipient, _amount);
        
        // Emit event when tokens are received
        emit TokensReceived(_sourceChainId, _recipient, _amount);
    }
}