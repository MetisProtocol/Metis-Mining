pragma solidity 0.6.12;

import "../interfaces/IDAC.sol";
import "../interfaces/IMining.sol";
import "../interfaces/IMetisToken.sol";
import "../common/Ownable.sol";

contract MockDAC is IDAC, Ownable {
    event MemberLeave(address indexed creator, address indexed member);
    event DismissDAC(address indexed creator);

    IMining public miningContract;
    IMetisToken public metis;
    bool public DAO_OPEN = false;

    constructor(IMining _miningContract, IMetisToken _metis) public {
        miningContract = _miningContract;
        metis = _metis;
    }

    function memberLeave(address _creator, address _member) external override returns (bool) {
        emit MemberLeave(_creator, _member);
        return true;
    }

    function creatorDeposit(uint256 _amount, uint256 _DACMemberCount, uint256 _initialDACPower) public {
        // check allowance of spender
        require(
            metis.allowance(msg.sender, address(miningContract)) >= _amount, 
            "Not enough allowance for mining contract"
        );
        miningContract.creatorDeposit(msg.sender, address(metis), _amount, _DACMemberCount, _initialDACPower);
    }

    function memberDeposit(address _creator, uint256 _amount, uint256 _DACMemberCount, uint256 _initialDACPower) public {
        // check allowance of spender
        require(
            metis.allowance(msg.sender, address(miningContract)) >= _amount, 
            "Not enough allowance for mining contract"
        );
        miningContract.memberDeposit(_creator, msg.sender, address(metis), _amount, _DACMemberCount, _initialDACPower);
    }

    function dismissDAC(address _creator) public override returns (bool) {
        emit DismissDAC(_creator);
    }

    function DAODismiss() public returns (bool) {
        require(DAO_OPEN, "DAO is not opened");
        miningContract.dismissDAC(address(metis), msg.sender);
        emit DismissDAC(msg.sender);
    }

    function setDAOOpen(bool _daoOpen) external onlyOwner {
        DAO_OPEN = _daoOpen;
    }
}
