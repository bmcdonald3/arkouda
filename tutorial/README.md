
# Adding Features to Arkouda

Arkouda arrays are stored on the server, and pointed to on the
client. In general, if you want things to perform well, you
need to have it added as a server function.

Bad Arkouda usage:
```python3
a = ak.randint(0,2**32,10*3)
add1(a)

def add1(ak_arr):
    for val in ak_arr:
        val += 1
```

Good Arkouda usage:
```python3
a = ak.randint(0,2**32,10*3)
a += 1 # sends single message to server to handle addition
```

For quick functions that only rely on existing features (such
as sorting), adding a client-side Python function like you
would for any Python code is a good approach, but if you would
like to add an entirely new function that touches many different
elements of the array, it is probably a good idea to add it to
the server.

## Let's create a server-side add1 function!

First, let's handle the server side of things and write some
Chapel code!

In Arkouda, the bulk of the code is going to be working with the
existing Arkouda client/server interface and symbol table.

Here is the boilerplate code to add a function to the Arkouda
server:
```chpl
module AddOneMsg {
  use ServerConfig;
  use MultiTypeSymbolTable;
  use MultiTypeSymEntry;
  use ServerErrorStrings;
  use Reflection;
  use ServerErrors;
  use Logging;
  use Message;
    
  proc addOneMsg(cmd: string, msgArgs: borrowed MessageArgs, st: borrowed SymTab): MsgTuple throws {
    var repMsg: string; // response message
    var vName = st.nextName(); // symbol table key for resulting array
    var gEnt: borrowed GenSymEntry = getGenericTypedArrayEntry(msgArgs.getValueOf("arg1"), st);
    
    select gEnt.dtype {
      when DType.Int64 {
        var e = toSymEntry(gEnt,int);

        var ret = createSymEntry(e.a);

        // Add code for functionality here!
        ret.a += 1;

        st.addEntry(vName, ret);

        repMsg = "created " + st.attrib(vName);
        return new MsgTuple(repMsg, MsgType.NORMAL);
      }
      // add additional when blocks for different data types...
      otherwise {
        var errorMsg = notImplementedError("addOne",gEnt.dtype);
        return new MsgTuple(errorMsg, MsgType.ERROR);
      }
    }
  }

  use CommandMap;
  registerFunction("addOne", addOneMsg, getModuleName());
}
```

Now that we've gotten our server side code written, how do we call
that from the client?

The way that the client communicates with the server is by sending
a message containing the client representation of the array, the
name of the function to execute, and any other information the
server needs!

So, for our code here, which is creating a new array, here are the
steps that are needed:

1. Define Python function in the `arkouda` subdirectory as a method of the Arkouda library
2. Send a request message using `generic_msg(...)` with the array pointer and command message
3. Receive reply message and create client-side link to server array

Here is the code you'll need:

```python3
def addOne(pda: pdarray) -> pdarray:
    if isinstance(pda, pdarray):
        repMsg = generic_msg(cmd="addOne", args={"arg1" : pda})
        return create_pdarray(repMsg)
    else:
        raise TypeError("addOne only supports pdarrays.")
```

Let's add that in the `pdarraycreation.py` file!

First, add "addOne" to the `__all__` list:
```python3
__all__ = [
    "array",
    ...
    "addOne"
]
```
