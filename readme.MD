// edit: this is more gas optimal: https://gist.github.com/holiman/069de8d056a531575d2b786df3345665

// I started from this Yul empty contract, only having a basic deployer:

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

/*
Compilation result (Remix ftw) is:

{
	"functionDebugData": {},
	"generatedSources": [],
	"linkReferences": {},
	"object": "6000600e8181600039816000f3fe",
	"opcodes": "PUSH1 0x0 PUSH1 0xE DUP2 DUP2 PUSH1 0x0 CODECOPY DUP2 PUSH1 0x0 RETURN INVALID ",
	"sourceMap": "64:19:0:-:0;114:21;172:12;156:14;153:1;144:41;204:12;201:1;194:23"
}

This is doing:
PUSH1 0x0 - push the runtime_size to stack
PUSH1 0xE - push the code offset (in this really long hex chain, where is
            the bytecode starting, here right after this small hex string which is 14 nibbles long==0xE
DUP2      - duplicate the second elt in stack (runtime_size)
DUP2      - duplicate the second elt in stack (runtime_offset)
PUSH1 0x0 - push the 0 arg in datacopy, the mem offset where to copy the bytecode (these 3 last op are to
            craft the datacopy args
CODECOPY  - copy the code, taking the 3 args in stack
DUP2      - duplicate runtime_size
PUSH1 0x0 - push a 0 in front
RETURN    - return with the 2 lst elt in stack as arg (0, code_size)
INVALID   - unreachable/revert if something really odd happened

What we do with it is:
62length   // PUSH3 length = code length, 0 padded to 3bytes, to have a fixed
           // length for this init()                                                     stack:[length]
610012     // PUSH2 0012 = offset of the code, now fixed (using the push4 before)              [0012, length]
81         // DUP2                                                                             [length, 0012, length]
81         // DUP2                                                                             [0012, length, 0012, length]
6000       // PUSH1 0 = the 0 arg in datacopy (where to copy the bytecode in memory)           [0, 0012, length, 0012, length]
39         // CODECOPY(0, 0x11, 0xlength) copy at 0 the code
           // starting after this/offset 0x12, 0xFF.. long                                     [0012, length]
81         // DUP2                                                                             [length, 0012, length]
6000       // PUSH1 0                                                                          [0, length, 0012, length]
f3         // RETURN(0, length) - returned code is at 0 and is length long                     [0012, length]
fe         // INVALID -> unreachable


This is 36 nibbles long, aka 18 bytes, less than a word, we good (note the end-part is 13 bytes long == 104 bits)
62 000000 6100118181600039816000f3fe

We then need to append our bytecode at the end + includ the correct length, in Yul (see DeployTest)

We use a push3/3 bytes to store length as Spurious Dragon limits contract size to 24_576 bytes (= 196_608 bits),
3 bytes can store 16_777_216 bits and we don't know the size upfront (alt would be to conditionnaly branch and
use push1/push2/push3 accordingly)
*/