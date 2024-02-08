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
