pragma solidity 0.6.12;

interface IDAC {
    function memberLeave(address _creator, address _member) external returns (bool);
    function creatorLeave(address _creator) external returns (bool);
}
