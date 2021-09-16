pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./common/SafeMath.sol";
import "./common/Ownable.sol";
import "./common/EnumerableSet.sol";
import "./interfaces/IMining.sol";
import "./interfaces/IMetisToken.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IDACRecorder.sol";

contract DACRecorder is Ownable, IDACRecorder {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    struct DAC {
        DACState state; 
        uint256 id;
        uint256 userCount; // How many users this DAC has
        uint256 accMetisPerShare; // When state is set to inactive, save pool.accMetisPerShare
        uint256 initialDACPower;
        address creator;
        EnumerableSet.AddressSet members;
    }

    struct UserInfo {
        Role userRole;
        uint256 accPower; // Accumulated power for user mining.
        uint256 amount;
    }

    // The Metis TOKEN!
    IMetisToken public Metis;
    // Vault
    IVault public vault;
    // Mining Contract
    IMining public mining;
    // Addresses of creators
    EnumerableSet.AddressSet private creators;
    // DAC id mapping to DAC info
    mapping(uint256 => DAC) private dacInfo;
    // User address mapping to user info
    mapping(address => UserInfo) private userInfo;
    // Return creator of the specific member address
    mapping(address => address) public override creatorOf;
    mapping(address => uint256) public userWeight;

    uint256 public override totalWeight;
    uint256 public MAX_ACC_POWER = 500;
    uint256 public POWER_STEP_SIZE = 5; 
    uint256 public INITIAL_POWER_STEP_SIZE = 10;
    uint256 public MEMBER_POWER = 80;
    uint256 public override MIN_MEMBER_COUNT = 10;
    uint256 public override stakedMetis;
    bool public override DAO_OPEN;

    /* ========== CONSTRUCTOR ========== */

    constructor(IMetisToken _Metis, IVault _vault) public {
        Metis = _Metis;
        vault = _vault;
    }

    /* ========== VIEW FUNCTIONS ========== */

    function checkUserInfo(address _user) 
        external 
        view 
        override
        returns (Role userRole, uint256 accPower, uint256 amount) 
    {
        userRole = userInfo[_user].userRole;
        accPower = userInfo[_user].accPower;
        amount = userInfo[_user].amount;
    }

    function checkDACInfo(uint256 _dacId) 
        external 
        view 
        override
        returns (DACState state, uint256 userCount, uint256 accMetisPerShare, address creator, uint256 initialDACPower) {
            state = dacInfo[_dacId].state;
            userCount = dacInfo[_dacId].userCount;
            accMetisPerShare = dacInfo[_dacId].accMetisPerShare;
            creator = dacInfo[_dacId].creator;
            initialDACPower = dacInfo[_dacId].initialDACPower;
    }

    function isCreator(address _user) public view override returns (bool) {
        return creators.contains(_user);
    }

    function getUserAccPower(address _user) external view override returns (uint256) {
        return userInfo[_user].accPower;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _calcAccPowerForCreator(uint256 _initialDACPower, uint256 _DACMemberCount) internal view returns (uint256 accPower) {
        uint256 addedPower = 0;
        if (_DACMemberCount == 2) {
            addedPower = addedPower.add(INITIAL_POWER_STEP_SIZE);
        } else if (_DACMemberCount > 2) {
            uint256 totalStep = _DACMemberCount.sub(2).mul(POWER_STEP_SIZE);
            addedPower = addedPower.add(INITIAL_POWER_STEP_SIZE).add(totalStep);
        }
        accPower = _initialDACPower.add(addedPower);
        accPower = accPower > MAX_ACC_POWER ? MAX_ACC_POWER : accPower;
    }

    function _safeMetisTransferToVault(address _user, uint256 _amount) internal {
        uint256 MetisBal = Metis.balanceOf(address(this));
        if (_amount > MetisBal) {
            Metis.approve(address(vault), MetisBal);
            vault.enter(MetisBal, _user);
        } else {
            Metis.approve(address(vault), _amount);
            vault.enter(_amount, _user);
        }
    }

    /* ========== RESTRICTED FUNCTIONS ========== */
    
    function addCreator(address _user) external onlyMining override returns (bool) {
        require(!isCreator(_user), "Duplicate creator");
        creators.add(_user);
        return true;
    }

    function removeCreator(address _user) external onlyMining override returns (bool) {
        require(isCreator(_user), "Creator is not found");
        creators.remove(_user);
        return true;
    }

    function addMember(uint256 _dacId, address _member) external onlyMining override returns (bool) {
        require(dacInfo[_dacId].state == DACState.Active, "DAC is inactive");
        dacInfo[_dacId].members.add(_member);
        return true;
    }

    function delMember(uint256 _dacId, address _member) external onlyMining override returns (bool) {
        dacInfo[_dacId].members.remove(_member);
        return true;
    }

    function updateCreatorInfo(
        address _user,
        uint256 _dacId,
        uint256 _DACMemberCount, 
        uint256 _initialDACPower,
        uint256 _amount,
        uint256 _accMetisPerShare,
        bool _withdrawAll
    ) external onlyMining override returns (bool) {
        DAC storage dac = dacInfo[_dacId];
        UserInfo storage user = userInfo[_user];

        require(dac.state == DACState.Active, "This DAC is inactive");

        if (_withdrawAll) {
            // creator withdraw all => dismiss DAC
            totalWeight = totalWeight.sub(userWeight[_user]);
            stakedMetis = stakedMetis.sub(user.amount);
            user.amount = _amount;
            user.userRole = Role.None;
            user.accPower = 0;
            userWeight[_user] = 0;
            dac.userCount = dac.userCount.sub(1);
            dac.state = DACState.Inactive;
            dac.accMetisPerShare = _accMetisPerShare;
        } else {
            // update stakedMetis
            stakedMetis = stakedMetis.sub(user.amount);
            user.amount = _amount;
            stakedMetis = stakedMetis.add(user.amount);
            // update user & dac info
            user.userRole = Role.Creator;
            user.accPower = _calcAccPowerForCreator(_initialDACPower, _DACMemberCount);
            dac.userCount = _DACMemberCount;
            dac.state = DACState.Active;
            dac.creator = _user;
            dac.initialDACPower = _initialDACPower;
            // update weight info
            totalWeight = totalWeight.sub(userWeight[_user]);
            userWeight[_user] = user.accPower.mul(_amount);
            totalWeight = totalWeight.add(userWeight[_user]);
        }
        return true;
    }

    function updateMemberInfo(
        address _user,
        uint256 _dacId,
        uint256 _DACMemberCount, 
        uint256 _initialDACPower,
        uint256 _amount,
        bool _withdrawAll,
        bool _isDeposit
    ) external onlyMining override returns (bool) {
        DAC storage dac = dacInfo[_dacId];
        UserInfo storage user = userInfo[_user];
        UserInfo storage creator = userInfo[dac.creator];

        require(dac.members.contains(_user), "This user is not included in this DAC");

        if (_withdrawAll) {
            totalWeight = totalWeight.sub(userWeight[_user]);
            stakedMetis = stakedMetis.sub(user.amount);
            user.amount = _amount;
            user.userRole = Role.None;
            user.accPower = 0;
            userWeight[_user] = 0;
            creatorOf[_user] = address(0);
            dac.userCount = dac.userCount.sub(1);
        } else {
            if (_isDeposit) {
                require(dac.state == DACState.Active, "This DAC is inactive");
            }
            user.userRole = Role.Member;
            user.accPower = MEMBER_POWER;
            dac.userCount = _DACMemberCount;
            // update stakedMetis
            stakedMetis = stakedMetis.sub(user.amount);
            user.amount = _amount;
            stakedMetis = stakedMetis.add(user.amount);
            userWeight[_user] = user.accPower.mul(_amount);
            totalWeight = totalWeight.add(userWeight[_user]);
            if (creator.accPower > 0) {
                creator.accPower = _calcAccPowerForCreator(_initialDACPower, _DACMemberCount);
                totalWeight = totalWeight.sub(userWeight[dac.creator]);
                userWeight[dac.creator] = creator.accPower.mul(_amount);
                totalWeight = totalWeight.add(userWeight[dac.creator]);
            }
        }
        return true;
    }

    function setCreatorOf(address _creator, address _user) external override onlyMining {
        creatorOf[_user] = _creator;
    }

    function subCreatorPower(uint256 _dacId, uint256 _amount) external onlyMining override returns (bool) {
        DAC storage dac = dacInfo[_dacId];
        if (dac.state == DACState.Inactive) {
            return false;
        }
        UserInfo storage creator = userInfo[dac.creator];
        if (creator.accPower > 0) {
            uint256 subPower = 0;
            dac.userCount == 1 ? subPower = INITIAL_POWER_STEP_SIZE : subPower = POWER_STEP_SIZE;
            creator.accPower = creator.accPower.sub(subPower);
            totalWeight = totalWeight.sub(userWeight[dac.creator]);
            userWeight[dac.creator] = creator.accPower.mul(_amount);
            totalWeight = totalWeight.add(userWeight[dac.creator]);
        }
        return true;
    }

    function sendRewardToVault(address _user, uint256 _amount) external onlyMining override returns (bool) {
        _safeMetisTransferToVault(_user, _amount);
        return true;
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

    function setMinMemberCount(uint256 _minMemberCount) external onlyOwner {
        MIN_MEMBER_COUNT = _minMemberCount;
    }

    function setDAOOpen(bool _daoOpen) external onlyOwner {
        DAO_OPEN = _daoOpen;
    }

    function setMiningContract(IMining _mining) external onlyOwner {
        mining = _mining;
    }

    function setMetisToken(IMetisToken _metis) external onlyOwner {
        Metis = _metis;
    }

    function setVault(IVault _vault) external onlyOwner {
        vault = _vault;
    }

    /* ========== MODIFIERS ========== */

    modifier onlyMining() {
        require(msg.sender == address(mining), "Not mining contract");
        _;
    }

}