pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./common/SafeMath.sol";
import "./common/Ownable.sol";
import "./common/EnumerableSet.sol";
import "./interfaces/IMining.sol";
import "./interfaces/IMetisToken.sol";
import "./interfaces/IVault.sol";

contract DACRecorder is Ownable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    enum Role { Creator, Member, None }

    struct UserInfo {
        Role userRole;
        uint256 DACMemberCount; // How many members this user invite.
        uint256 accPower; // Accumulated power for user mining.
        EnumerableSet.AddressSet members; // members of creator's DAC
    }

    // The Metis TOKEN!
    IMetisToken public Metis;
    // Vault
    IVault public vault;
    // Mining Contract
    IMining public mining;
    // Addresses of creators
    EnumerableSet.AddressSet private creators;
    mapping(address => UserInfo) private userInfo;
    // Return creator of the specific member address
    mapping(address => address) public creatorOf;
    mapping(address => uint256) public userWeight;

    uint256 public totalWeight;
    uint256 public MAX_ACC_POWER = 500;
    uint256 public POWER_STEP_SIZE = 5; 
    uint256 public INITIAL_POWER_STEP_SIZE = 10;
    uint256 public MEMBER_POWER = 80;
    uint256 public MIN_MEMBER_COUNT = 10;
    uint256 public stakedMetis;
    bool public DAO_OPEN;

    /* ========== CONSTRUCTOR ========== */

    constructor(IMetisToken _Metis, IVault _vault) public {
        Metis = _Metis;
        vault = _vault;
    }

    /* ========== VIEW FUNCTIONS ========== */

    function checkUserInfo(address _user) 
        public view returns (Role userRole, uint256 DACMemberCount, uint256 accPower) {
        userRole = userInfo[_user].userRole;
        DACMemberCount = userInfo[_user].DACMemberCount;
        accPower = userInfo[_user].accPower;
    }

    function isCreator(address _user) public view returns (bool) {
        return creators.contains(_user);
    }

    function getMemberLength(address _creator) public view returns (uint256) {
        return userInfo[_creator].members.length();
    }

    function getMember(address _creator, uint256 _index) public view returns (address) {
        require(isCreator(_creator), "Creator is not found");
        return userInfo[_creator].members.at(_index);
    }

    function getUserAccPower(address _user) external view returns (uint256) {
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
    
    function addCreator(address _user) external onlyMining returns (bool) {
        require(!isCreator(_user), "Duplicate creator");
        creators.add(_user);
        return true;
    }

    function removeCreator(address _user) external onlyMining returns (bool) {
        require(isCreator(_user), "Creator is not found");
        creators.remove(_user);
        return true;
    }

    function addMember(address _creator, address _member) external onlyMining returns (bool) {
        require(isCreator(_creator), "Creator is not found");
        userInfo[_creator].members.add(_member);
        return true;
    }

    function setCreatorOf(address _creator, address _member) external onlyMining returns (bool) {
        creatorOf[_member] = _creator;
    }

    function delMember(address _creator, address _member) external onlyMining returns (bool) {
        require(isCreator(_creator), "Creator is not found");
        userInfo[_creator].members.remove(_member);
        return true;
    }

    function updateUser(
        address _creator, 
        address _user, 
        uint256 _DACMemberCount, 
        uint256 _initialDACPower,
        uint256 _amount
    ) external onlyMining returns (bool) {
        if (_creator == address(0)) {
            require(creatorOf[_user] == address(0), "This user is an existing member");
            if (_initialDACPower == 0) {
                totalWeight = totalWeight.sub(userWeight[_user]);
                stakedMetis = stakedMetis.sub(_amount);
                userInfo[_user].userRole = Role.None;
                userInfo[_user].accPower = 0;
                userInfo[_user].DACMemberCount = 0;
                userWeight[_user] = 0;
            } else {
                userInfo[_user].userRole = Role.Creator;
                userInfo[_user].accPower = _calcAccPowerForCreator(_initialDACPower, _DACMemberCount);
                userInfo[_user].DACMemberCount = _DACMemberCount;
                totalWeight = totalWeight.sub(userWeight[_user]);
                userWeight[_user] = userInfo[_user].accPower.mul(_amount);
                stakedMetis = stakedMetis.add(_amount);
                totalWeight = totalWeight.add(userWeight[_user]);
            }
        } else {
            require(!isCreator(_user), "This user is an existing creator");
            if (_DACMemberCount == 0) {
                totalWeight = totalWeight.sub(userWeight[_user]);
                stakedMetis = stakedMetis.sub(_amount);
                userInfo[_user].userRole = Role.None;
                userInfo[_user].accPower = 0;
                userWeight[_user] = 0;
            } else {
                userInfo[_user].userRole = Role.Member;
                userInfo[_user].accPower = MEMBER_POWER;
                userWeight[_user] = userInfo[_user].accPower.mul(_amount);
                stakedMetis = stakedMetis.add(_amount);
                totalWeight = totalWeight.add(userWeight[_user]);
            }
        }
        return true;
    }

    function subCreatorPower(address _creator, uint256 _amount) external onlyMining returns (bool) {
        userInfo[_creator].DACMemberCount = userInfo[_creator].DACMemberCount.sub(1);
        uint256 subPower = 0;
        userInfo[_creator].DACMemberCount == 1 ? subPower = INITIAL_POWER_STEP_SIZE : subPower = POWER_STEP_SIZE;
        userInfo[_creator].accPower = userInfo[_creator].accPower.sub(subPower);
        totalWeight = totalWeight.sub(userWeight[_creator]);
        userWeight[_creator] = userInfo[_creator].accPower.mul(_amount);
        totalWeight = totalWeight.add(userWeight[_creator]);
    }

    function sendRewardToVault(address _user, uint256 _amount) external onlyMining returns (bool) {
        _safeMetisTransferToVault(_user, _amount);
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