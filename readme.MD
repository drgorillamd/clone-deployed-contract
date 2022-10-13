// I started from this Yul empty contract, only having a basic deployer:

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

Compilation result (Remix ftw) is:
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

This is doing:
```assembly
PUSH1 0x0 // push the runtime_size to stack
PUSH1 0xE // push the code offset (in this really long hex chain, where is
          // the bytecode starting, here right after this small hex string which is 14 nibbles long==0xE
DUP2      // duplicate the second elt in stack (runtime_size)
DUP2      // duplicate the second elt in stack (runtime_offset)
PUSH1 0x0 // push the 0 arg in datacopy, the mem offset where to copy the bytecode (these 3 last op are to
          // craft the datacopy args
CODECOPY  // copy the code, taking the 3 args in stack
DUP2      // duplicate runtime_size
PUSH1 0x0 // push a 0 in front
RETURN    // return with the 2 lst elt in stack as arg (0, code_size)
INVALID   // unreachable/revert if something really odd happened
```

We optimise it (ie less op code used) and push 3 empty bytes for the code length (which we get in Yul and mask, for readability):

```assembly
PUSH3 0x000000 // [length] code length, 0 padded to 3bytes, to have a fixed length for this init
PUSH1 0x00     // [length, 0x0]
DUP2           // [length, 0x0, length]
PUSH offset    // [length, 0x0, length, offset] push the offset were the runtime bytecode is (after this constructor)
DUP3           // [length, 0x0, length, offset, 0x0]
CODECOPY       // [length, 0x0] - codecopy(0, 0x11, 0xlength) copy at 0 the code starting at the offset 
RETURN         // []                               (0, length) - returned code is at 0 and is length long
INVALID        // irreachable, separator
```

This is 26 nibbles long, aka 13 bytes, less than a word, we good, this is our constructor: `62000000600081600d8239f3fe`

We then need to append our bytecode at the end + include the correct length, in Yul (see DeployTest)

We use a push3/3 bytes to store length as Spurious Dragon limits contract size to 24_576 bytes (= 196_608 bits),
3 bytes can store 16_777_216 bits and we don't know the size upfront (alt would be to conditionnaly branch and
use push1/push2/push3 accordingly or do everything in assembly, like https://gist.github.com/holiman/069de8d056a531575d2b786df3345665)
*/