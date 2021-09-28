pragma solidity 0.6.12;

import "../interfaces/IDAC.sol";
import "../interfaces/IMining.sol";
import "../interfaces/IMetisToken.sol";
import "../common/Ownable.sol";

contract MockDAC is IDAC, Ownable {
    event MemberLeave(uint256 dacId, address indexed member);
    event DismissDAC(uint256 dacId, address indexed creator);

    IMining public miningContract;
    IMetisToken public metis;
    bool public DAO_OPEN = false;

    mapping(address => uint256) public override userToDAC;

    constructor(IMining _miningContract, IMetisToken _metis) public {
        miningContract = _miningContract;
        metis = _metis;
    }

    function memberLeaveDAC(uint256 dacId, address member) external override returns (bool) {
        emit MemberLeave(dacId, member);
        return true;
    }

    function creatorDeposit(uint256 _amount, uint256 _DACMemberCount, uint256 _initialDACPower, uint256 _dacId) public {
        // check allowance of spender
        require(
            metis.allowance(msg.sender, address(miningContract)) >= _amount, 
            "Not enough allowance for mining contract"
        );
        userToDAC[msg.sender] = _dacId;
        miningContract.deposit(
            address(0), 
            msg.sender, 
            miningContract.tokenToPid(address(metis)), 
            _amount, 
            _DACMemberCount, 
            _initialDACPower,
            _dacId
        );
    }

    function memberDeposit(address _creator, uint256 _amount, uint256 _DACMemberCount, uint256 _initialDACPower, uint256 _dacId) public {
        // check allowance of spender
        require(
            metis.allowance(msg.sender, address(miningContract)) >= _amount, 
            "Not enough allowance for mining contract"
        );
        userToDAC[msg.sender] = _dacId;
        miningContract.deposit(
            _creator, 
            msg.sender, 
            miningContract.tokenToPid(address(metis)), 
            _amount, 
            _DACMemberCount, 
            _initialDACPower,
            _dacId
        );
    }

    function dismissDAC(uint256 dacId, address creator) public override returns (bool) {
        emit DismissDAC(dacId, creator);
        return true;
    }

    function DAODismiss(uint256 _dacId) public returns (bool) {
        require(DAO_OPEN, "DAO is not opened");
        miningContract.dismissDAC(_dacId, miningContract.tokenToPid(address(metis)), msg.sender);
        emit DismissDAC(_dacId, msg.sender);
    }

    function setDAOOpen(bool _daoOpen) external onlyOwner {
        DAO_OPEN = _daoOpen;
    }

    function setMiningContract(IMining _miningContract) external onlyOwner {
        miningContract = _miningContract;
    }

}
