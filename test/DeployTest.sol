// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../src/Target.sol";

contract TestDeploy is Test {
    address _target;

    function setUp() public {
        _target = address(new Target());
    }

    function testDeploy() public {
        address _out;

        emit log_uint((_target.code).length);

        bytes32 _t;

        assembly {
            // Retrieve target address
            let _targetAddress := sload(_target.slot)
            
            // Get deployed code size
            let _codeSize := extcodesize(_targetAddress)
            
            // Get a bit of freemem to land the bytecode
            let _freeMem := mload(0x40)

            // Copy the bytecode
            extcodecopy(_targetAddress, _freeMem, 0, _codeSize)

            // Deploy the copied bytecode
            _out := create(0, _freeMem, _codeSize)

            // We're tidy poeple are, we update our freemem ptr
            mstore(0x40, add(_freeMem, _codeSize))
        }

        emit log_bytes32(_t);

        // // Deployment?
        // assert(_out != address(0));

        // (bool _callStatus, bytes memory _ret) = _out.staticcall(abi.encodeCall(Target.iExist, ()));
        // require(_callStatus, "callStatusFail");

        // bool _success = abi.decode(_ret, (bool));

        // assertTrue(_success);
    }

}