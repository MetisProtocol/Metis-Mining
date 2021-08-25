pragma solidity 0.6.12;

interface IMining {
    function creatorDeposit(
        address _user, 
        address _token, 
        uint256 _amount,
        uint256 _DACMemberCount,
        uint256 _initialDACPower
    ) external returns (bool);

    function memberDeposit(
        address _creator,
        address _user, 
        address _token, 
        uint256 _amount,
        uint256 _DACMemberCount,
        uint256 _initialDACPower
    ) external returns (bool);

    function creatorWithdraw(address _token, uint256 _amount) external returns (bool);

    function memberWithdraw(address _creator, address _token, uint256 _amount) external returns (bool);

    function dismissDAC(address _token, address _creator) external returns (bool);
}
