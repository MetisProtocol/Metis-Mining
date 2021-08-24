pragma solidity 0.6.12;

import "./common/IERC20.sol";
import "./common/SafeMath.sol";
import "./common/SafeERC20.sol";

contract Vault {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public governance;
    address public miningContract;
    IERC20 public metisToken;

    uint public leaveDistributionMin = 1000; // 10% distributed to remaining vault
    uint public constant MAX = 10000;

    // stats tracking
    uint public totalDistributionAmount = 0;

    uint public totalShares;
    mapping(address => uint) public shares;

    /* ========== CONSTRUCTOR ========== */

    constructor(IERC20 _metisToken) public {
        metisToken = _metisToken;
        governance = msg.sender;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    // Enter staking pool. Pay some Metis. Earn some shares.
    function enter(uint256 _amount, address _user) external onlyMining {
        // Gets the amount of Metis locked in the contract
        uint256 totalMetis = metisToken.balanceOf(address(this));
        // If no share exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalMetis == 0) {
            mintShares(_user, _amount);
        }
        // Calculate and mint the amount of share the Metis is worth. The ratio will change overtime, as share is burned/minted and Metis deposited + gained from fees / withdrawn.
        else {
            uint256 what = _amount.mul(totalShares).div(totalMetis);
            mintShares(_user, what);
        }
        // Lock the Metis in the contract
        metisToken.transferFrom(msg.sender, address(this), _amount);

        emit Enter(_user, _amount);
    }

    // Leave staking pool. Claim back your Metis.
    // Returned Metis = Original Metis + Gained Metis - Penalty
    function leave(uint256 _share) external {
        // Calculates the amount of Metis the share is worth
        uint256 what = _share.mul(metisToken.balanceOf(address(this))).div(totalShares);
        // Calculate penalties
        uint256 distributionAmount = what.mul(leaveDistributionMin).div(MAX);

        burnShares(msg.sender, _share);

        // Transfer to withdrawer
        uint256 withdrawAmount = what.sub(distributionAmount);
        // update stats: not crutial so do not use SafeMath to avoid overflow revert
        totalDistributionAmount += distributionAmount;

        // send the rest to user
        metisToken.transfer(msg.sender, withdrawAmount);

        emit Leave(msg.sender, what, distributionAmount);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function setGov(address _governance) external onlyGov {
        governance = _governance;
    }

    function setLeaveDistributionMin(uint _leaveDistributionMin) external onlyGov {
        leaveDistributionMin = _leaveDistributionMin;
    }
    
    function setMiningContract(address _miningContract) external onlyGov {
        miningContract = _miningContract;
    }

    // Allow governance to rescue tokens
    function rescue(address _token) external onlyGov {
        require(_token != address(metisToken), "cannot take user's Metis");
        uint _balance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(governance, _balance);
    }

    /* ========== MODIFIERS ========== */

    modifier onlyGov() {
        require(msg.sender == governance, "!gov");
        _;
    }

    modifier onlyMining() {
        require(msg.sender == miningContract, "!gov");
        _;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function mintShares(address _user, uint _amount) internal {
        totalShares = totalShares.add(_amount);
        shares[_user] = shares[_user].add(_amount);
    }

    function burnShares(address _user, uint _amount) internal {
        shares[_user] = shares[_user].sub(_amount, "burn amount exceeds shares");
        totalShares = totalShares.sub(_amount);
    }

    event Enter(address indexed user, uint256 amount);
    event Leave(address indexed user, uint256 withdrawAmount, uint256 distribution);
}
