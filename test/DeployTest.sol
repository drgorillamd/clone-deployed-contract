// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../src/Target.sol";

// Diferent contract to use the same function selector, removing difference due to the routing table

contract TestDeployMix is Test {
    address _target;

    function setUp() public {
        _target = address(new Target());
    }

    function testDeploy() public {
        address _out;

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
            let _initCode := or(_mask, 0x62000000600081600d8239f3fe00000000000000000000000000000000000000)

            mstore(_freeMem, _initCode)

            // Copy the bytecode (our initialise part is 13 bytes long)
            extcodecopy(_targetAddress, add(_freeMem, 13), 0, _codeSize)

            // Deploy the copied bytecode
            _out := create(0, _freeMem, add(_codeSize, 13))
        }

        // Check: successful deployment?
        assertTrue(_out != address(0), "deployment failed");

        // Interact with the clone
        (bool _callStatus, bytes memory _ret) = _out.staticcall(abi.encodeCall(Target.iExist, ()));
        
        // Check: function call successful?
        assertTrue(_callStatus, "contract call failed");

        // Check: function works as expected?
        bool _success = abi.decode(_ret, (bool));
        assertTrue(_success, "function logic failed");

        // Check: bytecodes match, including metadata?
        address _compare = address(new Target());
        assertEq(_out.code, _compare.code, "bytecode mismatch");
    }
}

contract TestDeployPureBytecode is Test {
    address _target;

    function setUp() public {
        _target = address(new Target());
    }

    function testDeploy() public {
        address _out;
      
        assembly{
            // Retrieve target address
            let _targetAddress := sload(_target.slot)

            mstore(0x0, or (0x5880730000000000000000000000000000000000000000803b80938091923cF3, mul(_targetAddress,0x1000000000000000000)))
            _out := create(0, 0, 32)
        }

        // Check: successful deployment?
        assertTrue(_out != address(0), "deployment failed");

        // Interact with the clone
        (bool _callStatus, bytes memory _ret) = _out.staticcall(abi.encodeCall(Target.iExist, ()));
        
        // Check: function call successful?
        assertTrue(_callStatus, "contract call failed");

        // Check: function works as expected?
        bool _success = abi.decode(_ret, (bool));
        assertTrue(_success, "function logic failed");

        // Check: bytecodes match, including metadata?
        address _compare = address(new Target());
        assertEq(_out.code, _compare.code, "bytecode mismatch");
    }
}

contract TestDeployStd is Test {
    address _target;

    function setUp() public {
        _target = address(new Target());
    }

    function testDeploy() public {

        address _out = address(new Target());
    
        // Deployment?
        assert(_out != address(0));

        (bool _callStatus, bytes memory _ret) = _out.staticcall(abi.encodeCall(Target.iExist, ()));
        require(_callStatus, "callStatusFail");

        bool _success = abi.decode(_ret, (bool));

        assertTrue(_success);
    }

}
