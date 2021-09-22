// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./common/IERC20.sol";
import "./common/SafeERC20.sol";
import "./common/Ownable.sol";

contract Distributor is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public metisToken;
    // Mining Contract
    address public mining;

    constructor(IERC20 _metisToken) public {
        metisToken = _metisToken;
    }

    function distribute(address _to, uint256 _amount) external onlyMining returns (uint256) {
        uint256 realAmount = _amount;
        if (_amount > metisToken.balanceOf(address(this))) {
            realAmount = metisToken.balanceOf(address(this));
        }
        metisToken.safeTransfer(_to, realAmount);
        emit Distribute(_to, realAmount);
        return realAmount;
    }

    // Allow owner to rescue tokens
    function rescue(address _token) external onlyOwner {
        uint _balance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(msg.sender, _balance);
        emit RescueTriggerd(msg.sender, _token, _balance);
    }

    function setMiningContract(address _mining) external onlyOwner {
        mining = _mining;
    }

    /* ========== MODIFIERS ========== */

    modifier onlyMining() {
        require(msg.sender == address(mining), "Not mining contract");
        _;
    }

    event Distribute(address indexed to, uint256 amount);
    event RescueTriggerd(address indexed operator, address indexed token, uint256 amount);
}