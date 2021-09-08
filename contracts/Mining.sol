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
    function pendingMetis(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];
        uint256 accMetisPerShare = pool.accMetisPerShare;
        uint256 totalWeight = DACRecorder.totalWeight();
        if (block.timestamp > pool.lastRewardTimestamp && totalWeight != 0) {
            (,uint256 MetisReward) = calcMetisReward(pool.lastRewardTimestamp, pool.allocPoint);
            accMetisPerShare = accMetisPerShare.add(MetisReward.mul(1e18).div(totalWeight));
        }
        (, , uint256 accPower) = DACRecorder.checkUserInfo(_user);
        return user.amount.mul(accPower).mul(accMetisPerShare).div(1e18).sub(user.rewardDebt);
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
        uint256 _initialDACPower
    ) onlyDAC external override returns (bool) {
        bool isCreator = _creator == address(0);
        if (isCreator) {
            require(DACRecorder.creatorOf(_user) == address(0), "this user is a member of an existing DAC");
            if (!DACRecorder.isCreator(_user)) {
                DACRecorder.addCreator(_user);
            }
        } else {
            require(DACRecorder.isCreator(_creator), "The creator is not found");
            require(!DACRecorder.isCreator(_user), "This user is a creator");
            if (DACRecorder.creatorOf(_user) != address(0)) {
                // old member
                require(_creator == DACRecorder.creatorOf(_user), "Wrong creator for this member user");
            } else {
                // new member
                DACRecorder.setCreatorOf(_creator, _user);
                DACRecorder.addMember(_creator, _user);
            }
        }
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        updatePool(_pid);
        if (user.amount > 0) {
            _sendPending(_pid, _user);
        }
        if (_amount > 0) {
            uint256 remainingAmount = user.amount.add(_amount);
            require(remainingAmount >= MIN_DEPOSIT && remainingAmount <= MAX_DEPOSIT, "Deposit amount is invalid");
            user.amount = remainingAmount;
            DACRecorder.updateUser(_creator, _user, _DACMemberCount, _initialDACPower, user.amount);
            IERC20(pool.token).safeTransferFrom(_user, address(this), _amount);
        }
        (, , uint256 accPower) = DACRecorder.checkUserInfo(_user);
        user.rewardDebt = user.amount.mul(accPower).mul(pool.accMetisPerShare).div(1e18);
        emit Deposit(_creator, _user, _pid, _amount, _DACMemberCount);
        return true;
    }

    function withdraw(
        address _creator, 
        uint256 _pid, 
        uint256 _amount
    ) external override returns (bool) {
        bool isCreator = _creator == address(0);
        if (!isCreator) {
            require(DACRecorder.isCreator(_creator), "The creator is not found");
            require(!DACRecorder.isCreator(msg.sender), "This user is a creator");
            require(_creator == DACRecorder.creatorOf(msg.sender), "Wrong creator for this member user");
        } else {
            require(DACRecorder.isCreator(msg.sender), "The msg.sender is not a creator ");
            require(DACRecorder.creatorOf(msg.sender) == address(0), "this msg.sender is a member of an existing DAC");
        }
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        _sendPending(_pid, msg.sender);
        if(_amount > 0) {
            uint256 remainingAmount = user.amount.sub(_amount);
            if (isCreator) {
                if (DACRecorder.getMemberLength(msg.sender) > DACRecorder.MIN_MEMBER_COUNT() || DACRecorder.DAO_OPEN()) {
                    require(
                        remainingAmount >= MIN_DEPOSIT, 
                        "creatorWithdraw: Creator can't dismiss this DAC"
                    );
                }
                // means that the creator dismiss his/her DAC without DAO opening
                if (remainingAmount == 0) {
                    _dismissDAC(_pid, msg.sender);
                    DAC.dismissDAC(msg.sender);
                    DACRecorder.updateUser(address(0), msg.sender, 0, 0, 0);
                    DACRecorder.removeCreator(msg.sender);
                }
            } else {
                require(
                    remainingAmount == 0 || remainingAmount >= MIN_DEPOSIT, 
                    "Member must left miniuem 100 Metis token or withdraw all"
                );
                // means that the member leave a specific DAC
                if (remainingAmount == 0) {
                    _clearMemberInfo(msg.sender, _creator, user.amount);

                    // update creator information
                    DACRecorder.subCreatorPower(_creator, userInfo[_pid][_creator].amount);

                    DAC.memberLeave(_creator, msg.sender);
                }
            }
            user.amount = remainingAmount;
            IERC20(pool.token).safeTransfer(address(msg.sender), _amount);
        }
        (, , uint256 accPower) = DACRecorder.checkUserInfo(msg.sender);
        user.rewardDebt = user.amount.mul(accPower).mul(pool.accMetisPerShare).div(1e18);
        emit Withdraw(_creator, msg.sender, _pid, _amount);
        return true;
    }

    function dismissDAC(uint256 _pid, address _creator) onlyDAC external override returns (bool) {
        require(DACRecorder.DAO_OPEN(), "DAO is not opened");
        require(DACRecorder.isCreator(_creator), "dismissDAC: not a creator");
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage creator = userInfo[_pid][_creator];
        updatePool(_pid);
        _sendPending(_pid, _creator);
        _dismissDAC(_pid, _creator);
        DAC.dismissDAC(msg.sender);
        DACRecorder.updateUser(address(0), _creator, 0, 0, 0);
        DACRecorder.removeCreator(_creator);
        IERC20(pool.token).safeTransfer(address(msg.sender), creator.amount);
        creator.amount = 0;
        return true;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _sendPending(uint256 _pid, address _user) internal {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];
        (, , uint256 accPower) = DACRecorder.checkUserInfo(_user);
        uint256 pending = user.amount.mul(accPower).mul(pool.accMetisPerShare).div(1e18).sub(user.rewardDebt);
        if(pending > 0) {
            DACRecorder.sendRewardToVault(_user, pending);
        }
    }

    function _clearMemberInfo(address _member, address _creator, uint256 _amount) internal {
        DACRecorder.updateUser(_creator, _member, 0, 0, _amount);
        DACRecorder.setCreatorOf(address(0), _member);
        DACRecorder.delMember(_creator, _member);
    }

    function _dismissDAC(uint256 _pid, address _creator) internal {
        PoolInfo memory pool = poolInfo[_pid];
        uint256 memberLength = DACRecorder.getMemberLength(_creator);
        for (uint256 index = 0; index < memberLength; index++) {
            address memberAddr = DACRecorder.getMember(_creator, index);
            UserInfo storage member = userInfo[_pid][memberAddr];
            updatePool(_pid);
            _sendPending(_pid, memberAddr);
            _clearMemberInfo(memberAddr, _creator, member.amount);

            require(DAC.memberLeave(_creator, memberAddr));
            IERC20(pool.token).safeTransfer(address(msg.sender), member.amount);
            member.amount = 0;
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
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) external onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    function setMetisPerSecond(uint256 _MetisPerSecond) external onlyOwner {
        massUpdatePools();
        MetisPerSecond = _MetisPerSecond;
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
    }

    function setMaxDeposit(uint256 _maxDeposit) external onlyOwner {
        MAX_DEPOSIT = _maxDeposit;
    }

    function setStartTimestamp(uint256 _startTimestamp) external onlyOwner {
        require(block.number < _startTimestamp, "Cannot change startTimestamp after reward start");
        startTimestamp = _startTimestamp;
        // reinitialize lastRewardTimestamp of all existing pools (if any)
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid <= length; ++pid) {
            PoolInfo storage pool = poolInfo[pid];
            pool.lastRewardTimestamp = _startTimestamp;
        }
    }

    // Update team address by the previous team address.
    function setTeamAddr(address _teamAddr) external {
        require(msg.sender == teamAddr, "dev: wut?");
        teamAddr = _teamAddr;
    }

    /* ========== MODIFIERS ========== */

    modifier onlyDAC() {
        require(msg.sender == address(DAC), "only DAC can call this function");
        _;
    }

    /* ========== EVENTS ========== */

    event Deposit(address indexed creator, address indexed user, uint256 pid, uint256 amount, uint256 DACMemberCount);
    event Withdraw(address indexed creator, address indexed user, uint256 pid, uint256 amount);
    event Mint(uint256 amount);
}