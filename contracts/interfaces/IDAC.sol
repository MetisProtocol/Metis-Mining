pragma solidity 0.6.12;

interface IDAC {
    function memberLeave(address _creator, address _member) external returns (bool);
    function dismissDAC(address _creator) external returns (bool);
}
