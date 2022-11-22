So I ran into this issue recently: how to clone a contract already deployed. Here's a how-to:

There is an opcode `EXTCODECOPY` which takes 4 arguments (from evm.codes):
> address: 20-byte address of the contract to query.

> destOffset: byte offset in the memory where the result will be copied.

> offset: byte offset in the code to copy.

> size: byte size to copy.

This opcode is accessible in Yul, [`extcodecopy(a, t, f, s)`](https://docs.soliditylang.org/en/latest/yul.html#evm-dialect), which is obviously more comfy than raw assembly.
Quickly trying to copy the bytecode and then deploy it will not work tho (been there, tried that):
```Solidity
    function deploy(address _a) external returns(address _out) {
        bytes memory byteCode = _a.code;
        uint256 _length = byteCode.length; // asm easy access

        require(_length != 0, "retrieveFail");

        assembly {
            _out := create(0, byteCode, _length)
        }

        require(_out != address(0), "deployFail");
    }
```

This will not revert (create returns a valid address) but logging the address content (eg `_out.code` in Solidity) will show this dramatic result: `0x`.
Wtf, thou shall exclaim?!

Well, let's dig a bit in what's really going on when deploying a contract (Ill just scratch the surface, check this brilliant post for details: https://mirror.xyz/0xB38709B8198d147cc9Ff9C133838a044d78B064B/Hh69VJWM5eiFYFINxYWrIYWcRRtPm8tw3VFjpdpx6T8).
Everyone knows deploying a contract is sending a transaction with
the bytecode as calldata and an empty `to: ` field, then you favorite eth client does its magic. This is slightly erroneous: the initial part of this calldata is not 
to be found in the deployed version, and account for a big difference between deployment bytecode and runtime bytecode, it's Le Constructor (yes, even if you don't declare 
a constructor in your Solidity Safemoon Fork, solc will do it). To deploy your contract, this constructor, on top of doing its logic, needs to *return* the runtime bytecode (and *then* only, the EVM takes it from there and do its deployment thingy). If you think about immutable variables for instance, it makes sense, the constructor inline them then they are part of the bytecode.


That's it, that was the missing link with extcodecopy - no constructor returning the bytecode as initial part == no deployment.

Ok, but how we gonna do this? The deployed/runtime bytecode has got the constructor code anymore?! Well, we're going to code the constructor bytecode (yes, if you don't write your bytecode in hex, you are weak and your entire bloodline is makinf fun out of you).


To have a first draft, I started from this Yul empty contract, only having a basic deployer and no bytecode (see the mirror post above):

```Yul
    object "EmptyContract" {
        code {
            let runtime_size := datasize("runtime")
            let runtime_offset := dataoffset("runtime")
            datacopy(0, runtime_offset, runtime_size)
            return(0, runtime_size)
        }

        object "runtime" {
            code {
                // I feel so empty
            }
        }
    }
```

Remix compiles it as `6000600e8181600039816000f3fe`:

```json
{
	"functionDebugData": {},
	"generatedSources": [],
	"linkReferences": {},
	"object": "6000600e8181600039816000f3fe",
	"opcodes": "PUSH1 0x0 PUSH1 0xE DUP2 DUP2 PUSH1 0x0 CODECOPY DUP2 PUSH1 0x0 RETURN INVALID ",
	"sourceMap": "64:19:0:-:0;114:21;172:12;156:14;153:1;144:41;204:12;201:1;194:23"
}
```

The opcodes are basically running the following logic:
```assembly
    PUSH1 0x0 // push the runtime_size to stack (0 here)
    PUSH1 0xE // push the code offset (in deployment bytecode, where is
            // the bytecode starting, here right after this small hex string which is 14 nibbles long==0xE
    DUP2      // duplicate the second elt in stack (runtime_size)
    DUP2      // duplicate the second elt in stack (runtime_offset)
    PUSH1 0x0 // push the 0 arg in datacopy, the mem offset where to copy the bytecode (these 3 last op are to
            // craft the datacopy args)
    CODECOPY  // copy the code, taking the 3 args on top of the stack
    DUP2      // duplicate runtime_size
    PUSH1 0x0 // push a 0 in front
    RETURN    // return with the 2 last elt in stack as arg (0, code_size)
    INVALID   // unreachable unless you're really messing things up
```

We optimise it (ie less op code used) and push 3 empty bytes for the code length (which we get in Yul and mask, for readability, more on this later). Stack state is in [], with the top to the right:

```assembly
    PUSH3 0x000000 // [length] runtime code length, 0-padded to 3bytes, to have a fixed length for this init
    PUSH1 0x00     // [length, 0x0]
    DUP2           // [length, 0x0, length]
    PUSH offset    // [length, 0x0, length, offset] push the offset were the runtime bytecode is (after this constructor)
    DUP3           // [length, 0x0, length, offset, 0x0]
    CODECOPY       // [length, 0x0] - codecopy(0, 0x11, 0xlength) copy at 0 the code starting at the offset 
    RETURN         // []                               (0, length) - returned code is at 0 and is length long
    INVALID        // irreachable, separator
```

This is 26 nibbles long, aka 13 bytes, less than a word, we good, this is our home made constructor (take every assembly op and replace by their hex opcode, from http://www.evm.codes for instance): `62000000600081600d8239f3fe` - we still need to add the offset (remember the third push?), 0x0d, 6200000060008160*0d*8239f3fe

We then need to append our bytecode at the end + include the correct length, in Yul (see DeployTest):

```Yul
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

        // Deploy the copied bytecode, including the constructor
        _out := create(0, _freeMem, add(_codeSize, 13))
    }
```

We use a push3/3 bytes to store length as Spurious Dragon limits contract size to 24_576 bytes (= 196_608 bits),
3 bytes can store 16_777_216 bits and we don't know the size upfront (alt would be to conditionnaly branch and
use push1/push2/push3 accordingly or do everything in assembly, like https://gist.github.com/holiman/069de8d056a531575d2b786df3345665, which is quite nifty, almost same cost but a tad tougher to read imo)
