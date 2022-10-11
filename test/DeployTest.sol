// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../src/Target.sol";

contract TestDeploy is Test {
    address _target;

    function setUp() public {
        _target = address(new Target());
    }

    // This one doesn't work (yet?), just need a bit of precompiled assembly
    function Skip_testDeploy() public {
        address _out;

        assembly {
            // Retrieve target address
            let _targetAddress := sload(_target.slot)
            
            // Get deployed code size
            let _codeSize := extcodesize(_targetAddress)
            
            // Get a bit of freemem to land the bytecode
            let _freeMem := mload(0x40)

            // Copy the bytecode
            extcodecopy(_targetAddress, _freeMem, 0, _codeSize)

            // Deploying is running init which will, un turn, return the bytecode and the evm takes it from there:
            // Insert smart precompiled asm here

            // Deploy the copied bytecode
            _out := create(0, _freeMem, _codeSize)

            // We're tidy people, we update our freemem ptr + 32bytes for the padding - yes, ugly
            mstore(0x40, add(_freeMem, add(_codeSize, 32)))
        }

        emit log_address(_out);
        emit log_bytes(_out.code);

        // Deployment?
        assert(_out != address(0));

        (bool _callStatus, bytes memory _ret) = _out.staticcall(abi.encodeCall(Target.iExist, ()));
        require(_callStatus, "callStatusFail");

        bool _success = abi.decode(_ret, (bool));

        assertTrue(_success);
    }

    function testICopiedItFromStackExchange() public {
        address _out;
      
        assembly{
            // Retrieve target address
            let _targetAddress := sload(_target.slot)

            mstore(0x0, or (0x5880730000000000000000000000000000000000000000803b80938091923cF3 ,mul(_targetAddress,0x1000000000000000000)))
            _out := create(0,0, 32)
        }

        // Deployment?
        assert(_out != address(0));

        (bool _callStatus, bytes memory _ret) = _out.staticcall(abi.encodeCall(Target.iExist, ()));
        require(_callStatus, "callStatusFail");

        bool _success = abi.decode(_ret, (bool));

        assertTrue(_success);
    }

    function testCompareWithDeployment() public {

        address _out = address(new Target());
    
        // Deployment?
        assert(_out != address(0));

        (bool _callStatus, bytes memory _ret) = _out.staticcall(abi.encodeCall(Target.iExist, ()));
        require(_callStatus, "callStatusFail");

        bool _success = abi.decode(_ret, (bool));

        assertTrue(_success);
    }
}