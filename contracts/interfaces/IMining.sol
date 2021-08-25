pragma solidity 0.6.12;

interface IMining {
    function deposit(
        address _creator,
        address _user, 
        uint256 _pid, 
        uint256 _amount,
        uint256 _DACMemberCount,
        uint256 _initialDACPower
    ) external returns (bool);

    function withdraw(address _creator, uint256 _pid, uint256 _amount) external returns (bool);

    function dismissDAC(uint256 _pid, address _creator) external returns (bool);

    function tokenToPid(address _token) external view returns (uint256);
}
