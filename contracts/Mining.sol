pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./common/IERC20.sol";
import "./common/SafeERC20.sol";
import "./common/SafeMath.sol";
import "./common/Ownable.sol";
import "./common/EnumerableSet.sol";

import "./interfaces/IMining.sol";
import "./interfaces/IMetisToken.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IDAC.sol";

contract Mining is Ownable, IMining {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    enum Role { Creator, Member, None }

    // Info of each user.
    struct UserInfo {
        Role userRole;
        uint256 amount; // How many staked tokens the user has provided.
        uint256 DACMemberCount; // How many members this user invite.
        uint256 accPower; // Accumulated power for user mining.
        uint256 rewardDebt; // Reward debt
        EnumerableSet.AddressSet members; // members of creator's DAC
    }

    // Info of each pool.
    struct PoolInfo {
        address token; // Address of staked token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. Metis to distribute per 3min.
        uint256 lastRewardTimestamp; // Last block timestamp that Metis distribution occurs.
        uint256 accMetisPerShare; // Accumulated Metis per share, times 1e18. See below.
        uint256 totalStakedAmount;
    }

    // The Metis TOKEN!
    IMetisToken public Metis;
    // Vault
    IVault public vault;
    // DAC
    IDAC public DAC;
    // Dev address.
    address public teamAddr;
    // Metis tokens created per second.
    uint256 public MetisPerSecond;
    // mapping of token to pool id
    mapping(address => uint) public tokenToPid;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Addresses of creators
    EnumerableSet.AddressSet private creators;
    // Info of each user that stakes staked tokens.
    mapping(uint => mapping(address => UserInfo)) private userInfo;
    // Return creator of the specific member address
    mapping(address => address) public creatorOf;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block timestamp when Metis mining starts.
    uint256 public startTimestamp;
    uint256 public MIN_DEPOSIT = 100 * 1e18;
    uint256 public MAX_DEPOSIT = 2000 * 1e18;
    uint256 public MAX_ACC_POWER = 500;
    uint256 public POWER_STEP_SIZE = 5; 
    uint256 public INITIAL_POWER_STEP_SIZE = 10;
    uint256 public MEMBER_POWER = 80;
    uint256 public MIN_MEMBER_COUNT = 10;
    bool public DAO_OPEN;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        IMetisToken _Metis,
        IVault _vault,
        uint256 _MetisPerSecond,
        uint256 _startTimestamp
    ) public {
        Metis = _Metis;
        vault = _vault;
        MetisPerSecond = _MetisPerSecond;
        startTimestamp = _startTimestamp;
    }

    /* ========== VIEW FUNCTIONS ========== */

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // View function to see pending Metis on frontend.
    function pendingMetis(address _token, address _user) onlyValidPool(_token) external view returns (uint256) {
        uint pid = tokenToPid[_token];
        PoolInfo storage pool = poolInfo[pid - 1];
        UserInfo storage user = userInfo[pid][_user];
        uint256 accMetisPerShare = pool.accMetisPerShare;
        uint256 totalStakedAmount = pool.totalStakedAmount;
        if (block.timestamp > pool.lastRewardTimestamp && totalStakedAmount != 0) {
            uint256 MetisReward = MetisPerSecond.mul(block.timestamp.sub(pool.lastRewardTimestamp))
                                             .mul(pool.allocPoint)
                                             .div(totalAllocPoint);
            accMetisPerShare = accMetisPerShare.add(MetisReward.mul(1e18).div(totalStakedAmount));
        }
        return user.amount.mul(user.accPower).mul(accMetisPerShare).div(1e18).sub(user.rewardDebt);
    }

    function checkUserInfo(uint256 _pid, address _user) 
        external view returns (Role userRole, uint256 amount, uint256 DACMemberCount, uint256 accPower) {
        userRole = userInfo[_pid][_user].userRole;
        amount = userInfo[_pid][_user].amount;
        DACMemberCount = userInfo[_pid][_user].DACMemberCount;
        accPower = userInfo[_pid][_user].accPower;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 1; pid <= length; ++pid) {
            PoolInfo storage pool = poolInfo[pid - 1];
            updatePool(pool.token);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(address _token) onlyValidPool(_token) public {
        uint pid = tokenToPid[_token];
        PoolInfo storage pool = poolInfo[pid - 1];
        if (block.timestamp <= pool.lastRewardTimestamp) {
            return;
        }
        uint256 totalStakedAmount = pool.totalStakedAmount;
        if (totalStakedAmount == 0) {
            pool.lastRewardTimestamp = block.timestamp;
            return;
        }
        uint256 MetisReward = MetisPerSecond.mul(block.timestamp.sub(pool.lastRewardTimestamp))
                                         .mul(pool.allocPoint)
                                         .div(totalAllocPoint);
        if (teamAddr != address(0)) {
            Metis.mint(teamAddr, MetisReward.div(9));
        }
        Metis.mint(address(this), MetisReward);
        emit Mint(MetisReward);
        pool.accMetisPerShare = pool.accMetisPerShare.add(
            MetisReward.mul(1e18).div(totalStakedAmount)
        );
        pool.lastRewardTimestamp = block.timestamp;
    }

    function creatorDeposit(
        address _user, 
        address _token, 
        uint256 _amount,
        uint256 _DACMemberCount,
        uint256 _initialDACPower
    ) onlyValidPool(_token) onlyDAC external override returns (bool) {
        require(creatorOf[_user] == address(0), "this user is a member of an existed DAC");
        uint pid = tokenToPid[_token];
        PoolInfo storage pool = poolInfo[pid - 1];
        UserInfo storage user = userInfo[pid][_user];
        updatePool(pool.token);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(user.accPower).mul(pool.accMetisPerShare).div(1e18).sub(user.rewardDebt);
            if(pending > 0) {
                safeMetisTransferToVault(_user, pending);
            }
        }
        if (_amount > 0) {
            uint256 remainingAmount = user.amount.add(_amount);
            require(remainingAmount >= MIN_DEPOSIT && remainingAmount <= MAX_DEPOSIT, "Deposit amount is invalid");
            user.amount = remainingAmount;
            user.DACMemberCount = _DACMemberCount;
            uint256 addedPower = 0;
            if (_DACMemberCount == 2) {
                addedPower = addedPower.add(INITIAL_POWER_STEP_SIZE);
            } else if (_DACMemberCount > 2) {
                uint256 totalStep = _DACMemberCount.sub(2).mul(POWER_STEP_SIZE);
                addedPower = addedPower.add(INITIAL_POWER_STEP_SIZE).add(totalStep);
            }
            user.accPower = _initialDACPower.add(addedPower);
            user.userRole = Role.Creator;
            pool.totalStakedAmount = pool.totalStakedAmount.add(_amount);
            IERC20(pool.token).safeTransferFrom(_user, address(this), _amount);
        }
        if (!creators.contains(_user)) {
            creators.add(_user);
        }
        user.rewardDebt = user.amount.mul(user.accPower).mul(pool.accMetisPerShare).div(1e18);
        emit CreatorDeposit(_user, _token, _amount, _DACMemberCount);
        return true;
    }

    function memberDeposit(
        address _creator,
        address _user, 
        address _token, 
        uint256 _amount,
        uint256 _DACMemberCount,
        uint256 _initialDACPower
    ) onlyValidPool(_token) onlyDAC external override returns (bool) {
        require(creators.contains(_creator), "The creator is not found");
        require(!creators.contains(_user), "This user is a creator");
        uint pid = tokenToPid[_token];
        PoolInfo storage pool = poolInfo[pid - 1];
        UserInfo storage user = userInfo[pid][_user];
        UserInfo storage creator = userInfo[pid][_creator];
        if (creatorOf[_user] != address(0)) {
            // old member
            require(_creator == creatorOf[_user], "Wrong creator for this member user");
        } else {
            // new member
            creatorOf[_user] = _creator;
            creator.members.add(_user);
        }
        updatePool(pool.token);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(user.accPower).mul(pool.accMetisPerShare).div(1e18).sub(user.rewardDebt);
            if(pending > 0) {
                safeMetisTransferToVault(_user, pending);
            }
        }
        if (_amount > 0) {
            uint256 remainingAmount = user.amount.add(_amount);
            require(remainingAmount >= MIN_DEPOSIT && remainingAmount <= MAX_DEPOSIT, "Deposit amount is invalid");
            user.amount = remainingAmount;
            user.accPower = MEMBER_POWER;
            user.userRole = Role.Member;
            pool.totalStakedAmount = pool.totalStakedAmount.add(_amount);

            // update creator information
            creator.DACMemberCount = _DACMemberCount;
            uint256 addedPower = 0;
            if (_DACMemberCount == 2) {
                addedPower = addedPower.add(INITIAL_POWER_STEP_SIZE);
            } else if (_DACMemberCount > 2) {
                uint256 totalStep = _DACMemberCount.sub(2).mul(POWER_STEP_SIZE);
                addedPower = addedPower.add(INITIAL_POWER_STEP_SIZE).add(totalStep);
            }
            uint256 accPower = _initialDACPower.add(addedPower);
            if (accPower > MAX_ACC_POWER) {
                accPower = MAX_ACC_POWER;
            }
            creator.accPower = accPower;
            IERC20(pool.token).safeTransferFrom(_user, address(this), _amount);
        }
        user.rewardDebt = user.amount.mul(user.accPower).mul(pool.accMetisPerShare).div(1e18);
        emit MemberDeposit(_creator, _user, _token, _amount, _DACMemberCount);
        return true;
    }

    function dismissDAC(address _token, address _creator) onlyDAC external override returns (bool) {
        require(DAO_OPEN, "DAO is not opened");
        require(creators.contains(msg.sender), "dismissDAC: not a creator");
        uint pid = tokenToPid[_token];
        PoolInfo storage pool = poolInfo[pid - 1];
        UserInfo storage creator = userInfo[pid][_creator];
        updatePool(pool.token);
        uint256 pending = creator.amount.mul(creator.accPower).mul(pool.accMetisPerShare).div(1e18).sub(creator.rewardDebt);
        if(pending > 0) {
            safeMetisTransferToVault(msg.sender, pending);
        }
        creator.accPower = 0;
        creator.DACMemberCount = 0;
        creator.userRole = Role.None;
        creators.remove(msg.sender);
        pool.totalStakedAmount = pool.totalStakedAmount.sub(creator.amount);
        IERC20(pool.token).safeTransfer(address(msg.sender), creator.amount);
        creator.amount = 0;
        _dismissDAC(pid, _creator);
        require(DAC.dismissDAC(msg.sender), "Dismiss failed");
        return true;
    }

    function _dismissDAC(uint256 _pid, address _creator) internal {
        PoolInfo storage pool = poolInfo[_pid - 1];
        UserInfo storage creator = userInfo[_pid][_creator];
        uint256 memberLength = creator.members.length();
        for (uint256 index = 0; index < memberLength; index++) {
            address memberAddr = creator.members.at(index);
            UserInfo storage member = userInfo[_pid][memberAddr];
            updatePool(pool.token);
            uint256 pending = member.amount.mul(member.accPower).mul(pool.accMetisPerShare).div(1e18).sub(member.rewardDebt);
            if(pending > 0) {
                safeMetisTransferToVault(memberAddr, pending);
            }
            member.accPower = 0;
            member.userRole = Role.None;

            creatorOf[memberAddr] = address(0);
            creator.members.remove(memberAddr);

            require(DAC.memberLeave(_creator, memberAddr));

            pool.totalStakedAmount = pool.totalStakedAmount.sub(member.amount);
            IERC20(pool.token).safeTransfer(address(msg.sender), member.amount);
            member.amount = 0;
        }
    }

    function creatorWithdraw(address _token, uint256 _amount) onlyValidPool(_token) external override returns (bool) {
        uint pid = tokenToPid[_token];
        PoolInfo storage pool = poolInfo[pid - 1];
        UserInfo storage user = userInfo[pid][msg.sender];
        require(creators.contains(msg.sender), "creatorWithdraw: not a creator");
        require(user.amount >= _amount, "creatorWithdraw: not good");
        updatePool(pool.token);
        uint256 pending = user.amount.mul(user.accPower).mul(pool.accMetisPerShare).div(1e18).sub(user.rewardDebt);
        if(pending > 0) {
            safeMetisTransferToVault(msg.sender, pending);
        }
        if(_amount > 0) {
            uint256 remainingAmount = user.amount.sub(_amount);
            if (user.members.length() > MIN_MEMBER_COUNT || DAO_OPEN) {
                require(
                    remainingAmount >= MIN_DEPOSIT, 
                    "creatorWithdraw: Creator can't dismiss this DAC"
                );
            }
            // means that the creator dismiss his/her DAC
            if (remainingAmount == 0) {
                user.accPower = 0;
                user.DACMemberCount = 0;
                user.userRole = Role.None;
                creators.remove(msg.sender);
                _dismissDAC(pid, msg.sender);
                require(DAC.dismissDAC(msg.sender), "Dismiss failed");
            }
            user.amount = remainingAmount;
            pool.totalStakedAmount = pool.totalStakedAmount.sub(_amount);
            IERC20(pool.token).safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(user.accPower).mul(pool.accMetisPerShare).div(1e18);
        emit CreatorWithdraw(msg.sender, _token, _amount);
        return true;
    }

    function memberWithdraw(
        address _creator, 
        address _token, 
        uint256 _amount
    ) onlyValidPool(_token) external override returns (bool) {
        require(creators.contains(_creator), "The creator is not found");
        require(!creators.contains(msg.sender), "This user is a creator");
        require(_creator == creatorOf[msg.sender], "Wrong creator for this member user");
        uint pid = tokenToPid[_token];
        PoolInfo storage pool = poolInfo[pid - 1];
        UserInfo storage user = userInfo[pid][msg.sender];
        UserInfo storage creator = userInfo[pid][_creator];
        updatePool(pool.token);
        uint256 pending = user.amount.mul(user.accPower).mul(pool.accMetisPerShare).div(1e18).sub(user.rewardDebt);
        if(pending > 0) {
            safeMetisTransferToVault(msg.sender, pending);
        }
        if(_amount > 0) {
            uint256 remainingAmount = user.amount.sub(_amount);
            require(remainingAmount == 0 || remainingAmount >= MIN_DEPOSIT, "Member must left miniuem 100 Metis token or withdraw all");
            
            // means that the member leave a specific DAC
            if (remainingAmount == 0) {
                user.accPower = 0;
                user.userRole = Role.None;

                // update creator information
                creator.DACMemberCount = creator.DACMemberCount.sub(1);
                uint256 subPower = 0;
                if (creator.DACMemberCount == 1) {
                    subPower = INITIAL_POWER_STEP_SIZE;
                } else {
                    subPower = POWER_STEP_SIZE;
                }
                creator.accPower = creator.accPower.sub(subPower);

                creatorOf[msg.sender] = address(0);
                creator.members.remove(msg.sender);

                require(DAC.memberLeave(_creator, msg.sender));
            }
            user.amount = remainingAmount;
            pool.totalStakedAmount = pool.totalStakedAmount.sub(_amount);
            IERC20(pool.token).safeTransfer(address(msg.sender), _amount);
        }
        emit MemberWithdraw(_creator, msg.sender, _token, _amount);
        return true;
    }

    function safeMetisTransferToVault(address _user, uint256 _amount) internal {
        uint metisPid = tokenToPid[address(Metis)];
        PoolInfo memory metisPool = poolInfo[metisPid - 1];
        uint256 MetisRewardsBal = Metis.balanceOf(address(this)).sub(metisPool.totalStakedAmount);
        if (_amount > MetisRewardsBal) {
            Metis.approve(address(vault), MetisRewardsBal);
            vault.enter(MetisRewardsBal, _user);
        } else {
            Metis.approve(address(vault), _amount);
            vault.enter(_amount, _user);
        }
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    // Add a new staked token to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, address _token, bool _withUpdate) external onlyOwner checkDuplicatePool(_token) {
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
                accMetisPerShare: 0,
                totalStakedAmount: 0
            })
        );
        tokenToPid[_token] = poolInfo.length; // pid 0 reserved for 'pool does not exist'
    }

    // Update the given pool's Metis allocation point. Can only be called by the owner.
    function set(address _token, uint256 _allocPoint, bool _withUpdate) external onlyOwner onlyValidPool(_token){
        if (_withUpdate) {
            massUpdatePools();
        }
        uint pid = tokenToPid[_token];
        totalAllocPoint = totalAllocPoint.sub(poolInfo[pid - 1].allocPoint).add(_allocPoint);
        poolInfo[pid - 1].allocPoint = _allocPoint;
    }

    function setMetisPerSecond(uint256 _MetisPerSecond) external onlyOwner {
        massUpdatePools();
        MetisPerSecond = _MetisPerSecond;
    }

    function setVault(IVault _vault) external onlyOwner {
        vault = _vault;
    }

    function setDAC(IDAC _DAC) external onlyOwner {
        DAC = _DAC;
    }

    function setMinDeposit(uint256 _minDeposit) external onlyOwner {
        MIN_DEPOSIT = _minDeposit;
    }

    function setMaxDeposit(uint256 _maxDeposit) external onlyOwner {
        MAX_DEPOSIT = _maxDeposit;
    }

    function setMaxAccPower(uint256 _maxAccPower) external onlyOwner {
        MAX_ACC_POWER = _maxAccPower;
    }

    function setPowerStepSize(uint256 _powerStepSize) external onlyOwner {
        POWER_STEP_SIZE = _powerStepSize;
    }

    function setInitialPowerStepSize(uint256 _initialPowerStepSize) external onlyOwner {
        INITIAL_POWER_STEP_SIZE = _initialPowerStepSize;
    }

    function setMemberPower(uint256 _memberPower) external onlyOwner {
        MEMBER_POWER = _memberPower;
    }

    function setStartTimestamp(uint256 _startTimestamp) external onlyOwner {
        require(block.number < _startTimestamp, "Cannot change startTimestamp after reward start");
        startTimestamp = _startTimestamp;
        // reinitialize lastRewardTimestamp of all existing pools (if any)
        uint256 length = poolInfo.length;
        for (uint256 pid = 1; pid <= length; ++pid) {
            PoolInfo storage pool = poolInfo[pid - 1];
            pool.lastRewardTimestamp = _startTimestamp;
        }
    }

    function setMinMemberCount(uint256 _minMemberCount) external onlyOwner {
        MIN_MEMBER_COUNT = _minMemberCount;
    }

    function setDAOOpen(bool _daoOpen) external onlyOwner {
        DAO_OPEN = _daoOpen;
    }

    // Update team address by the previous team address.
    function setTeamAddr(address _teamAddr) external {
        require(msg.sender == teamAddr, "dev: wut?");
        teamAddr = _teamAddr;
    }

    /* ========== MODIFIERS ========== */

    modifier onlyValidPool(address _token) {
        uint pid = tokenToPid[_token];
        require(pid != 0, "pool does not exist");
        _;
    }

    modifier checkDuplicatePool(address _token) {
        for (uint256 pid = 1; pid <= poolInfo.length; pid++) {
            require(poolInfo[pid - 1].token != _token,  "pool already exist");
        }
        _;
    }

    modifier onlyDAC() {
        require(msg.sender == address(DAC), "only DAC can call this function");
        _;
    }

    /* ========== EVENTS ========== */

    event CreatorDeposit(address indexed user, address indexed token, uint256 amount, uint256 DACMemberCount);
    event MemberDeposit(address indexed creator, address indexed user, address indexed token, uint256 amount, uint256 DACMemberCount);
    event CreatorWithdraw(address indexed user, address indexed token, uint256 amount);
    event MemberWithdraw(address indexed creator, address indexed user, address indexed token, uint256 amount);
    event EmergencyWithdraw(address indexed user, address indexed token, uint256 amount);
    event Mint(uint256 amount);
}