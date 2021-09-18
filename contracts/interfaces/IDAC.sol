// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IDAC {
    function memberLeaveDAC(uint256 dacId, address member) external returns(bool);
    function dismissDAC(uint256 dacId, address creator) external returns(bool);
}
