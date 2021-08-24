pragma solidity 0.6.12;

interface IVault {
    function enter(uint256 _amount, address _user) external;
    function leave(uint256 _share) external;
    function shares(address) external view returns (uint);
}
