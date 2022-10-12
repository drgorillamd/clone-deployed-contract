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

        bytes32 _dump;

        assembly {
            // Retrieve target address
            let _targetAddress := sload(_target.slot)
            
            // Get deployed code size
            let _codeSize := extcodesize(_targetAddress)

            // Get a bit of freemem to land the bytecode
            let _freeMem := mload(0x40)
          
            // Shift the length to the length placeholder
            let _mask := mul(_codeSize, 0x100000000000000000000000000000000000000000000000000000000)

            // I built the init by hand (and it was quite fun)
            let _initCode := or(_mask, 0x620000006100118181600039816000f3fe000000000000000000000000000000)

            mstore(_freeMem, _initCode)

            // Copy the bytecode (our initialise part is 17 bytes long)
            extcodecopy(_targetAddress, add(_freeMem, 17), 0, _codeSize)
            
            _dump := mload(_freeMem)
            
            // Deploy the copied bytecode
            _out := create(0, _freeMem, _codeSize)

            // We're tidy people, we update our freemem ptr + 64bytes for the padding - yes, ugly
            mstore(0x40, add(_freeMem, add(_codeSize, 64)))
        }

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

            mstore(0x0, or (0x5880730000000000000000000000000000000000000000803b80938091923cF3, mul(_targetAddress,0x1000000000000000000)))
            _out := create(0, 0, 32)
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