pragma solidity ^0.8.16;

contract Target {
    uint256 a;

    function read(uint256 _in, uint256 _index) internal view returns(bool){
        return (_in >> _index) & 1 == 1;
    }

    function flip(uint256 _in, uint256 _index) internal {
    }

    function retrieveDepth(uint256 _index) internal pure returns(uint256) {
        return _index / 256;
    }

    function iExist() external view returns(bool) {
        return true;
    }
}