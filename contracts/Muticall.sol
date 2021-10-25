// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;
pragma experimental ABIEncoderV2;

/// @title Multicall - Aggregate results from multiple read-only function calls

interface IERC20 {
    function balanceOf(address user) external returns (uint256);
}

contract Multicall {
    address public eth = 0x420000000000000000000000000000000000000A;
    address public metis = 0x4200000000000000000000000000000000000006;
    struct Call {
        address target;
        bytes callData;
    }
    function aggregate(Call[] memory calls) public returns (uint256 blockNumber, bytes[] memory returnData) {
        blockNumber = block.number;
        returnData = new bytes[](calls.length);
        for(uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = calls[i].target.call(calls[i].callData);
            require(success);
            returnData[i] = ret;
        }
    }
    // Helper functions
    function getEthBalance(address addr) public returns (uint256 balance) {
        balance = IERC20(eth).balanceOf(addr);
    }
    function getMetisBalance(address addr) public returns(uint256 balance) {
        balance = IERC20(metis).balanceOf(addr);
    }
    function getCurrentBlockTimestamp() public view returns (uint256 timestamp) {
        timestamp = block.timestamp;
    }
}