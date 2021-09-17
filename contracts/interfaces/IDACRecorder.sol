// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IDACRecorder {
    enum Role { Creator, Member, None }
    enum DACState{ Active, Inactive }

    function checkUserInfo(address _user) 
        external 
        view 
        returns (Role userRole, uint256 accPower, uint256 amount);
    function checkDACInfo(uint256 _dacId) 
        external 
        view 
        returns (DACState state, uint256 userCount, uint256 accMetisPerShare, address creator, uint256 initialDACPower);
    function isCreator(address _user) external view returns (bool);
    function getUserAccPower(address _user) external view returns (uint256);
    function addCreator(address _user) external returns (bool);
    function removeCreator(address _user) external returns (bool);
    function addMember(uint256 _dacId, address _member) external returns (bool);
    function delMember(uint256 _dacId, address _member) external returns (bool);
    function updateCreatorInfo(
        address _user,
        uint256 _dacId,
        uint256 _DACMemberCount, 
        uint256 _initialDACPower,
        uint256 _amount,
        uint256 _accMetisPerShare,
        bool _withdrawAll
    ) external returns (bool);
    function updateMemberInfo(
        address _user,
        uint256 _dacId,
        uint256 _DACMemberCount, 
        uint256 _initialDACPower,
        uint256 _amount,
        bool _withdrawAll,
        bool _isDeposit
    ) external returns (bool);
    function subCreatorPower(uint256 _dacId, uint256 _amount) external returns (bool);
    function creatorOf(address _member) external returns (address);
    function setCreatorOf(address _creator, address _user) external;
    function totalWeight() external view returns (uint256);
    function MIN_MEMBER_COUNT() external view returns (uint256);
    function DAO_OPEN() external view returns (bool);
    function stakedMetis() external view returns (uint256);
    function sendRewardToVault(address _user, uint256 _amount) external returns (bool);
}
