// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IDistributor {
    function distribute(address _to, uint256 _amount) external returns (bool);
}
