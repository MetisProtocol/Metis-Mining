pragma solidity 0.6.12;

interface IDACRecorder {
    enum Role { Creator, Member, None }
    function checkUserInfo(address _user) 
        external 
        view 
        returns (Role userRole, uint256 DACMemberCount, uint256 accPower);
    function isCreator(address _user) external view returns (bool);
    function getMemberLength(address _creator) external view returns (uint256);
    function getMember(address _creator, uint256 _index) external view returns (address);
    function getUserAccPower(address _user) external view returns (uint256);
    function addCreator(address _user) external returns (bool);
    function removeCreator(address _user) external returns (bool);
    function addMember(address _creator, address _member) external returns (bool);
    function delMember(address _creator, address _member) external returns (bool);
    function updateUser(
        address _creator, 
        address _user, 
        uint256 _DACMemberCount, 
        uint256 _initialDACPower,
        uint256 _stakedAmount
    ) external returns (bool);
    function setCreatorOf(address _creator, address _member) external returns (bool);
    function subCreatorPower(address _creator, uint256 _amount) external returns (bool);
    function creatorOf(address _member) external returns (address);
    function totalWeight() external view returns (uint256);
    function MIN_MEMBER_COUNT() external view returns (uint256);
    function DAO_OPEN() external view returns (bool);
    function stakedMetis() external view returns (uint256);
}
