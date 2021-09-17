// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./common/IERC20.sol";
import "./common/SafeERC20.sol";
import "./common/SafeMath.sol";
import "./common/Ownable.sol";

import "./interfaces/IMining.sol";
import "./interfaces/IMetisToken.sol";
import "./interfaces/IDAC.sol";
import "./interfaces/IDACRecorder.sol";
import "./interfaces/IDistributor.sol";

contract Mining is Ownable, IMining {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many staked tokens the user has provided.
        uint256 rewardDebt; // Reward debt
    }

    // Info of each pool.
    struct PoolInfo {
        address token; // Address of staked token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. Metis to distribute per 3min.
        uint256 lastRewardTimestamp; // Last block timestamp that Metis distribution occurs.
        uint256 accMetisPerShare; // Accumulated Metis per share, times 1e18. See below.
    }

    // The Metis TOKEN!
    IMetisToken public Metis;
    // DAC
    IDAC public DAC;
    // DACRecorder
    IDACRecorder public DACRecorder;
    // Metis distributor
    IDistributor public distributor;
    // Dev address.
    address public teamAddr;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // mapping of token to pool id
    mapping(address => uint) public override tokenToPid;
    // Info of each user that stakes staked tokens.
    mapping(uint => mapping(address => UserInfo)) public userInfo;
    // Metis tokens created per second.
    uint256 public MetisPerSecond;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block timestamp when Metis mining starts.
    uint256 public startTimestamp;
    uint256 public MIN_DEPOSIT = 10 * 1e18;
    uint256 public MAX_DEPOSIT = 2000 * 1e18;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        IMetisToken _Metis,
        IDACRecorder _DACRecorder,
        IDistributor _distributor,
        uint256 _MetisPerSecond,
        uint256 _startTimestamp
    ) public {
        Metis = _Metis;
        DACRecorder = _DACRecorder;
        distributor = _distributor;
        MetisPerSecond = _MetisPerSecond;
        startTimestamp = _startTimestamp;
    }

    /* ========== VIEW FUNCTIONS ========== */

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function calcMetisReward(
        uint256 timestamp, 
        uint256 allocPoint 
    ) public view returns (uint256 accTime, uint256 MetisReward) {
        accTime = block.timestamp.sub(timestamp);
        MetisReward = MetisPerSecond.mul(accTime).mul(allocPoint).div(totalAllocPoint);
    }

    // View function to see pending Metis on frontend.
    function pendingMetis(uint256 _dacId, uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];
        (IDACRecorder.DACState dacState,, uint256 accMetisPerShare,,) = DACRecorder.checkDACInfo(_dacId);
        bool isActiveDAC = dacState == IDACRecorder.DACState.Active;
        uint256 share = isActiveDAC ? pool.accMetisPerShare : accMetisPerShare;
        uint256 totalWeight = DACRecorder.totalWeight();
        if (isActiveDAC && block.timestamp > pool.lastRewardTimestamp && totalWeight != 0) {
            (,uint256 MetisReward) = calcMetisReward(pool.lastRewardTimestamp, pool.allocPoint);
            share = share.add(MetisReward.mul(1e18).div(totalWeight));
        }
        (, uint256 accPower,) = DACRecorder.checkUserInfo(_user);
        return user.amount.mul(accPower).mul(share).div(1e18).sub(user.rewardDebt);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid <= length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTimestamp) {
            return;
        }
        uint256 totalWeight = DACRecorder.totalWeight();
        if (totalWeight == 0) {
            pool.lastRewardTimestamp = block.timestamp;
            return;
        }
        (,uint256 MetisReward) = calcMetisReward(pool.lastRewardTimestamp, pool.allocPoint);
        if (teamAddr != address(0)) {
            distributor.distribute(teamAddr, MetisReward.div(9));
        }
        distributor.distribute(address(DACRecorder), MetisReward);
        emit Mint(MetisReward);
        pool.accMetisPerShare = pool.accMetisPerShare.add(
            MetisReward.mul(1e18).div(totalWeight)
        );
        pool.lastRewardTimestamp = block.timestamp;
    }

    function deposit(
        address _creator,
        address _user, 
        uint256 _pid, 
        uint256 _amount,
        uint256 _DACMemberCount,
        uint256 _initialDACPower,
        uint256 _dacId
    ) onlyDAC external override returns (bool) {
        (IDACRecorder.DACState dacState,,,,) = DACRecorder.checkDACInfo(_dacId);
        bool isCreator = _creator == address(0);
        address existedCreator = DACRecorder.creatorOf(_user);
        if (isCreator) {
            require(DACRecorder.creatorOf(_user) == address(0), "existed member");
            if (!DACRecorder.isCreator(_user)) {
                DACRecorder.addCreator(_user);
            } 
        } else {
            if (existedCreator != address(0)) {
                // old member
                require(_creator == existedCreator, "mismatched creator");
            } else {
                // new member
                DACRecorder.setCreatorOf(_creator, _user);
                DACRecorder.addMember(_dacId, _user);
            }
        }
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        updatePool(_pid);
        if (user.amount > 0) {
            _sendPending(_dacId, _pid, _user);
        }
        if (_amount > 0 && dacState == IDACRecorder.DACState.Active) {
            uint256 remainingAmount = user.amount.add(_amount);
            require(remainingAmount >= MIN_DEPOSIT && remainingAmount <= MAX_DEPOSIT, "amount is invalid");
            user.amount = remainingAmount;
            if (isCreator) {
                DACRecorder.updateCreatorInfo(_user, _dacId, _DACMemberCount, _initialDACPower, user.amount, 0, false);
            } else {
                DACRecorder.updateMemberInfo(_user, _dacId, _DACMemberCount, _initialDACPower, user.amount, false, true);
            }
            IERC20(pool.token).safeTransferFrom(_user, address(this), _amount);
        }
        (, uint256 accPower,) = DACRecorder.checkUserInfo(_user);
        user.rewardDebt = user.amount.mul(accPower).mul(pool.accMetisPerShare).div(1e18);
        emit Deposit(_creator, _user, _pid, _amount, _DACMemberCount);
        return true;
    }

    function withdraw(
        address _creator, 
        uint256 _pid, 
        uint256 _amount,
        uint256 _dacId
    ) external override returns (bool) {
        bool isCreator = _creator == address(0);
        if (!isCreator) {
            require(!DACRecorder.isCreator(msg.sender), "sender is a creator");
            require(_creator == DACRecorder.creatorOf(msg.sender), "Wrong creator");
        } else {
            require(DACRecorder.isCreator(msg.sender), "sender is not a creator ");
        }
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        _sendPending(_dacId, _pid, msg.sender);
        if(_amount > 0) {
            uint256 remainingAmount = user.amount.sub(_amount);
            (,uint256 userCount,,,uint256 initialDACPower) = DACRecorder.checkDACInfo(_dacId);
            if (isCreator) {
                if (userCount > DACRecorder.MIN_MEMBER_COUNT() || DACRecorder.DAO_OPEN()) {
                    require(
                        remainingAmount >= MIN_DEPOSIT, 
                        "creatorWithdraw: Creator can't dismiss this DAC"
                    );
                }
                // means that the creator dismiss DAC without DAO opening
                if (remainingAmount == 0) {
                    DACRecorder.updateCreatorInfo(msg.sender, _dacId, 0, 0, remainingAmount, pool.accMetisPerShare, true);
                    DACRecorder.removeCreator(msg.sender);
                    DAC.dismissDAC(msg.sender);
                } else {
                    DACRecorder.updateCreatorInfo(msg.sender, _dacId, userCount, initialDACPower, remainingAmount, 0, false);
                }
            } else {
                require(
                    remainingAmount == 0 || remainingAmount >= MIN_DEPOSIT, 
                    "Member must left required amount of Metis token or withdraw all"
                );
                // means that the member leave a specific DAC
                if (remainingAmount == 0) {
                    DACRecorder.updateMemberInfo(msg.sender, _dacId, 0, 0, 0, true, false);
                    DACRecorder.subCreatorPower(_dacId, userInfo[_pid][_creator].amount);
                    DACRecorder.delMember(_dacId, msg.sender);
                    DAC.memberLeave(_creator, msg.sender);
                } else {
                    DACRecorder.updateMemberInfo(msg.sender, _dacId, userCount, initialDACPower, remainingAmount, false, false);
                }
            }
            user.amount = remainingAmount;
            IERC20(pool.token).safeTransfer(address(msg.sender), _amount);
        }
        (,uint256 accPower,) = DACRecorder.checkUserInfo(msg.sender);
        user.rewardDebt = user.amount.mul(accPower).mul(pool.accMetisPerShare).div(1e18);
        emit Withdraw(_creator, msg.sender, _pid, _amount);
        return true;
    }

    function dismissDAC(uint256 _dacId, uint256 _pid, address _creator) onlyDAC external override returns (bool) {
        require(DACRecorder.DAO_OPEN(), "DAO is not opened");
        require(DACRecorder.isCreator(_creator), "dismissDAC: not a creator");
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage creator = userInfo[_pid][_creator];
        updatePool(_pid);
        _sendPending(_dacId, _pid, _creator);
        DACRecorder.updateCreatorInfo(_creator, _dacId, 0, 0, creator.amount, pool.accMetisPerShare, true);
        DACRecorder.removeCreator(_creator);
        DAC.dismissDAC(msg.sender);
        IERC20(pool.token).safeTransfer(_creator, creator.amount);
        creator.amount = 0;
        return true;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _sendPending(uint256 _dacId, uint256 _pid, address _user) internal {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];
        (,uint256 accPower,) = DACRecorder.checkUserInfo(_user);
        (IDACRecorder.DACState dacState,, uint256 accMetisPerShare,,) = DACRecorder.checkDACInfo(_dacId);
        uint256 share = dacState == IDACRecorder.DACState.Active ? pool.accMetisPerShare : accMetisPerShare;
        uint256 pending = user.amount.mul(accPower).mul(share).div(1e18).sub(user.rewardDebt);
        if(pending > 0) {
            DACRecorder.sendRewardToVault(_user, pending);
        }
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    // Add a new staked token to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, address _token, bool _withUpdate) external onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardTimestamp = block.timestamp > startTimestamp ? block.timestamp : startTimestamp;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                token: _token,
                allocPoint: _allocPoint,
                lastRewardTimestamp: lastRewardTimestamp,
                accMetisPerShare: 0
            })
        );
        tokenToPid[_token] = poolInfo.length - 1;
    }

    // Update the given pool's Metis allocation point. Can only be called by the owner.
    // In our case there will be only one pool, this is just in case of multi pool extension
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) external onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        } else {
            updatePool(_pid);
        }
        if (poolInfo[_pid].allocPoint != _allocPoint) {
            totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        }
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    function setMetisPerSecond(uint256 _MetisPerSecond) external onlyOwner {
        massUpdatePools();
        MetisPerSecond = _MetisPerSecond;
        emit MetisPerSecondChanged(_MetisPerSecond);
    }

    function setMetisToken(IMetisToken _metis) external onlyOwner {
        Metis = _metis;
    }

    function setDAC(IDAC _DAC) external onlyOwner {
        DAC = _DAC;
    }

    function setDACRecorder(IDACRecorder _DACRecorder) external onlyOwner {
        DACRecorder = _DACRecorder;
    }

    function setMinDeposit(uint256 _minDeposit) external onlyOwner {
        MIN_DEPOSIT = _minDeposit;
        emit MinDepositChanged(_minDeposit);
    }

    function setMaxDeposit(uint256 _maxDeposit) external onlyOwner {
        MAX_DEPOSIT = _maxDeposit;
        emit MaxDepositChanged(_maxDeposit);
    }

    function setStartTimestamp(uint256 _startTimestamp) external onlyOwner {
        require(block.number < _startTimestamp, "Cannot change startTime after starting");
        startTimestamp = _startTimestamp;
        // reinitialize lastRewardTimestamp of all existing pools (if any)
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid <= length; ++pid) {
            PoolInfo storage pool = poolInfo[pid];
            pool.lastRewardTimestamp = _startTimestamp;
        }
        emit StartTimestampChanged(_startTimestamp);
    }

    function setTeamAddr(address _teamAddr) external onlyOwner {
        teamAddr = _teamAddr;
        emit TeamAddrChanged(_teamAddr);
    }

    /* ========== MODIFIERS ========== */

    modifier onlyDAC() {
        require(msg.sender == address(DAC), "not DAC");
        _;
    }

    /* ========== EVENTS ========== */

    event Deposit(address indexed creator, address indexed user, uint256 pid, uint256 amount, uint256 DACMemberCount);
    event Withdraw(address indexed creator, address indexed user, uint256 pid, uint256 amount);
    event Mint(uint256 amount);
    event TeamAddrChanged(address indexed team);
    event StartTimestampChanged(uint256 newStartTime);
    event MinDepositChanged(uint256 newMin);
    event MaxDepositChanged(uint256 newMax);
    event MetisPerSecondChanged(uint256 newPerSecond);
}