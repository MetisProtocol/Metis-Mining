pragma solidity 0.6.12;

import "../interfaces/IDAC.sol";

contract MockDAC is IDAC {
    event MemberLeave(address indexed creator, address indexed member);
    event CreatorLeave(address indexed creator);

    function memberLeave(address _creator, address _member) external override returns (bool) {
        emit MemberLeave(_creator, _member);
        return true;
    }
    function creatorLeave(address _creator) external override returns (bool) {
        emit CreatorLeave(_creator);
        return true;
    }
}
