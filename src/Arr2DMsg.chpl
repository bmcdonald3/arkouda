module Arr2DMsg {
  use GenSymIO;
  use SymEntry2D;

  use ServerConfig;
  use MultiTypeSymbolTable;
  use MultiTypeSymEntry;
  use Message;
  use ServerErrors;
  use Reflection;
  use RandArray;
  use Logging;
  use ServerErrorStrings;

  use BinOp;

  private config const logLevel = ServerConfig.logLevel;
  const randLogger = new Logger(logLevel);

  proc array2DMsg(cmd: string, payload: string, argSize: int, st: borrowed SymTab): MsgTuple throws {
    var msgArgs = parseMessageArgs(payload, argSize);

    var val = msgArgs.getValueOf("val");
    var dtype = DType.UNDEF;
    var m: int;
    var n: int;
    var rname:string = "";

    try {
      dtype = str2dtype(msgArgs.getValueOf("dtype"));
      m = msgArgs.get("m").getIntValue();
      n = msgArgs.get("n").getIntValue();
    } catch {
      var errorMsg = "Error parsing/decoding either dtypeBytes, m, or n";
      gsLogger.error(getModuleName(), getRoutineName(), getLineNumber(), errorMsg);
      return new MsgTuple(errorMsg, MsgType.ERROR);
    }

    overMemLimit(2*m*n);

    if dtype == DType.Int64 {
      var entry = new shared SymEntry2D(m, n, int);
      var localA: [{0..#m, 0..#n}] int = val:int;
      entry.a = localA;
      rname = st.nextName();
      st.addEntry(rname, entry);
    } else if dtype == DType.Float64 {
      var entry = new shared SymEntry2D(m, n, real);
      var localA: [{0..#m, 0..#n}] real = val:real;
      entry.a = localA;
      rname = st.nextName();
      st.addEntry(rname, entry);
    } else if dtype == DType.Bool {
      var entry = new shared SymEntry2D(m, n, bool);
      var localA: [{0..#m, 0..#n}] bool = if val == "True" then true else false;
      entry.a = localA;
      rname = st.nextName();
      st.addEntry(rname, entry);
    }

    var msgType = MsgType.NORMAL;
    var msg:string = "";

    if (MsgType.ERROR != msgType) {
      if (msg.isEmpty()) {
        msg = "created " + st.attrib(rname);
      }
      gsLogger.debug(getModuleName(),getRoutineName(),getLineNumber(),msg);
    }
    return new MsgTuple(msg, msgType);
  }

  proc randint2DMsg(cmd: string, payload: string, argSize: int, st: borrowed SymTab): MsgTuple throws {

    param pn = Reflection.getRoutineName();
    var repMsg: string; // response message
    var msgArgs = parseMessageArgs(payload, argSize);

    var dtype = str2dtype(msgArgs.getValueOf("dtype"));
    var m = msgArgs.get("m").getIntValue();
    var n = msgArgs.get("n").getIntValue();
    var rname = st.nextName();

    select (dtype) {
      when (DType.Int64) {
        overMemLimit(8*m*n);
        var aMin = msgArgs.get("low").getIntValue();
        var aMax = msgArgs.get("high").getIntValue();
        var seed = msgArgs.getValueOf("seed");

        var entry = new shared SymEntry2D(m, n, int);
        st.addEntry(rname, entry);
        fillInt(entry.a, aMin, aMax, seed);
      }
      when (DType.Float64) {
        var seed = msgArgs.getValueOf("seed");
        overMemLimit(8*m*n);
        var aMin = msgArgs.get("low").getRealValue();
        var aMax = msgArgs.get("high").getRealValue();

        var entry = new shared SymEntry2D(m, n, real);
        st.addEntry(rname, entry);
        fillReal(entry.a, aMin, aMax, seed);
      }
      when (DType.Bool) {
        var seed = msgArgs.getValueOf("seed");
        overMemLimit(8*m*n);

        var entry = new shared SymEntry2D(m, n, bool);
        st.addEntry(rname, entry);
        fillBool(entry.a, seed);
      }
      otherwise {
        var errorMsg = notImplementedError(pn,dtype);
        randLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);
        return new MsgTuple(errorMsg, MsgType.ERROR);
      }
    }

    repMsg = "created " + st.attrib(rname);
    return new MsgTuple(repMsg, MsgType.NORMAL);
  }


  proc binopvv2DMsg(cmd: string, payload: string, argSize: int, st: borrowed SymTab): MsgTuple throws {

   param pn = Reflection.getRoutineName();
    var repMsg: string; // response message

    // split request into fields
    var msgArgs = parseMessageArgs(payload, argSize);

    const op = msgArgs.getValueOf("op");
    var aname = msgArgs.getValueOf("a");
    var bname = msgArgs.getValueOf("b");

    var rname = st.nextName();
    var left: borrowed GenSymEntry = getGenericTypedArrayEntry(aname, st);
    var right: borrowed GenSymEntry = getGenericTypedArrayEntry(bname, st);

    use Set;
    var boolOps: set(string);
    boolOps.add("<");
    boolOps.add("<=");
    boolOps.add(">");
    boolOps.add(">=");
    boolOps.add("==");
    boolOps.add("!=");

    select (left.dtype, right.dtype) {
      when (DType.Int64, DType.Int64) {
        var l = left: SymEntry2D(int);
        var r = right: SymEntry2D(int);
        if boolOps.contains(op) {
          var e = st.addEntry2D(rname, l.m, l.n, bool);
          return doBinOpvv(l, r, e, op, rname, pn, st);
        } else if op == "/" {
          var e = st.addEntry2D(rname, l.m, l.n, real);
          return doBinOpvv(l, r, e, op, rname, pn, st);
        }
        var e = st.addEntry2D(rname, l.m, l.n, int);
        return doBinOpvv(l, r, e, op, rname, pn, st);
      }
      when (DType.Int64, DType.Float64) {
        var l = left: SymEntry2D(int);
        var r = right: SymEntry2D(real);
        if boolOps.contains(op) {
          var e = st.addEntry2D(rname, l.m, l.n, bool);
          return doBinOpvv(l, r, e, op, rname, pn, st);
        }
        var e = st.addEntry2D(rname, l.m, l.n, real);
        return doBinOpvv(l, r, e, op, rname, pn, st);
      }
      when (DType.Float64, DType.Int64) {
        var l = left: SymEntry2D(real);
        var r = right: SymEntry2D(int);
        if boolOps.contains(op) {
          var e = st.addEntry2D(rname, l.m, l.n, bool);
          return doBinOpvv(l, r, e, op, rname, pn, st);
        }
        var e = st.addEntry2D(rname, l.m, l.n, real);
        return doBinOpvv(l, r, e, op, rname, pn, st);
      }
      when (DType.Float64, DType.Float64) {
        var l = left: SymEntry2D(real);
        var r = right: SymEntry2D(real);
        if boolOps.contains(op) {
          var e = st.addEntry2D(rname, l.m, l.n, bool);
          return doBinOpvv(l, r, e, op, rname, pn, st);
        }
        var e = st.addEntry2D(rname, l.m, l.n, real);
        return doBinOpvv(l, r, e, op, rname, pn, st);
      }
      when (DType.Bool, DType.Bool) {
        var l = left: SymEntry2D(bool);
        var r = right: SymEntry2D(bool);
        var e = st.addEntry2D(rname, l.m, l.n, bool);
        return doBinOpvv(l, r, e, op, rname, pn, st);
      }
      when (DType.Bool, DType.Int64) {
        var l = left: SymEntry2D(bool);
        var r = right: SymEntry2D(int);
        var e = st.addEntry2D(rname, l.m, l.n, int);
        return doBinOpvv(l, r, e, op, rname, pn, st);
      }
      when (DType.Int64, DType.Bool) {
        var l = left: SymEntry2D(int);
        var r = right: SymEntry2D(bool);
        var e = st.addEntry2D(rname, l.m, l.n, int);
        return doBinOpvv(l, r, e, op, rname, pn, st);
      }
      when (DType.Bool, DType.Float64) {
        var l = left: SymEntry2D(bool);
        var r = right: SymEntry2D(real);
        var e = st.addEntry2D(rname, l.m, l.n, real);
        return doBinOpvv(l, r, e, op, rname, pn, st);
      }
      when (DType.Float64, DType.Bool) {
        var l = left: SymEntry2D(real);
        var r = right: SymEntry2D(bool);
        var e = st.addEntry2D(rname, l.m, l.n, real);
        return doBinOpvv(l, r, e, op, rname, pn, st);
      }
    }
    return new MsgTuple("Bin op not supported", MsgType.NORMAL);
  }

  proc SymTab.addEntry2D(name: string, m, n, type t): borrowed SymEntry2D(t) throws {
    if t == bool {overMemLimit(m*n);} else {overMemLimit(m*n*numBytes(t));}

    var entry = new shared SymEntry2D(m, n, t);
    if (tab.contains(name)) {
      mtLogger.debug(getModuleName(),getRoutineName(),getLineNumber(),
                     "redefined symbol: %s ".format(name));
    } else {
      mtLogger.debug(getModuleName(),getRoutineName(),getLineNumber(),
                     "adding symbol: %s ".format(name));
    }

    tab.addOrSet(name, entry);
    return (tab.getBorrowed(name):borrowed GenSymEntry): SymEntry2D(t);
  }


  proc rowIndex2DMsg(cmd: string, payload: string, argSize: int, st: borrowed SymTab): MsgTuple throws {

    param pn = Reflection.getRoutineName();
    var repMsg: string; // response message
    var msgArgs = parseMessageArgs(payload, argSize);

    var name = msgArgs.getValueOf("name");
    var row: int;
    try {
       row = msgArgs.get("key").getIntValue();
    } catch {
          var errorMsg = "Error parsing/decoding key";
          gsLogger.error(getModuleName(), getRoutineName(), getLineNumber(), errorMsg);
    }

    // get next symbol name
    var rname = st.nextName();
    var gEnt: borrowed GenSymEntry = getGenericTypedArrayEntry(name, st);

    proc getRowHelper(type t) throws {
      var e = toSymEntry2D(gEnt, t);
      var a = st.addEntry(rname, e.m, t);
      a.a = e.a[row,..];
      var repMsg = "created " + st.attrib(rname);
      return new MsgTuple(repMsg, MsgType.NORMAL);
    }

    select(gEnt.dtype) {
      when (DType.Int64) {
        return getRowHelper(int);
      }
      when (DType.Float64) {
        return getRowHelper(real);
      }
      when (DType.Bool) {
        return getRowHelper(bool);
      }
      otherwise {
        var errorMsg = notImplementedError(pn,dtype2str(gEnt.dtype));
        return new MsgTuple(errorMsg,MsgType.ERROR);              
      }
    }
  }

  proc partialReduction2DMsg(cmd: string, payload: string, argSize: int, st: borrowed SymTab): MsgTuple throws {
    var msgArgs = parseMessageArgs(payload, argSize);
    var repMsg: string;

    var name = msgArgs.getValueOf("name");
    var op = msgArgs.getValueOf("op");
    var axis: int;
    try {
      axis = msgArgs.get("axis").getIntValue();
    } catch {
      var errorMsg = "Error parsing/decoding key";
      gsLogger.error(getModuleName(), getRoutineName(), getLineNumber(), errorMsg);
    }
    
    // TODO: why is this type real when I pass 5 to array2d?
    var gEnt: borrowed GenSymEntry = getGenericTypedArrayEntry(name, st);

    var rname = st.nextName();
    var errorMsg = "";
    var hadError = false;

    proc partialReductionHelper(type inputType, type resType, op: string) throws {
      var e = toSymEntry2D(gEnt, inputType);
      if axis == 0 { // sum column-wise
        var dD = e.a.domain[0..0, ..];
        writeln(dD.size);
        var numCols = e.n;
        var res = st.addEntry(rname, numCols, resType);
        select (op) {
          when ("sum") {
            forall (_,j) in dD {
              res.a[j] = + reduce e.a[.., j..j];
            }
          }
          when ("product") {
            if inputType == bool {
              errorMsg = "product not supported on boolean pdarrays";
              hadError = true;
            } else {
              forall (_,j) in dD {
                res.a[j] = * reduce e.a[.., j..j];
              }
            }
          }
          when ("min") {
            if inputType == bool {
              errorMsg = "min not supported on boolean pdarrays";
              hadError = true;
            } else {
              forall (_,j) in dD {
                (res.a[j], _) = minloc reduce zip(e.a[.., j..j], dD);
              }
            }
          }
          when ("max") {
            if inputType == bool {
              errorMsg = "max not supported on boolean pdarrays";
              hadError = true;
            } else {
              forall (_,j) in dD {
                (res.a[j], _) = maxloc reduce zip(e.a[.., j..j], dD);
              }
            }
          }
          otherwise {
            errorMsg = "unrecognized partial reduction op";;
            hadError = true;
          }
        }
      } else if axis == 1 {
        var dD = e.a.domain[..,0..0];
        writeln(dD.size);
        var numRows = e.m;
        var res = st.addEntry(rname, numRows, resType);
        select (op) {
          when ("sum") {
            forall (i,_) in dD {
              res.a[i] = + reduce e.a[i..i, ..];
            }
          }
          when ("product") {
            if inputType == bool {
              errorMsg = "product not supported on boolean pdarrays";
              hadError = true;
            } else {
              forall (i,_) in dD {
                res.a[i] = * reduce e.a[i..i, ..];
              }
            }
          }
          when ("min") {
            if inputType == bool {
              errorMsg = "min not supported on boolean pdarrays";
              hadError = true;
            } else {
              forall (i,_) in dD {
                writeln("dD: ", dD);
                writeln("arr: ", e.a[.., i..i]);
                (res.a[i], _) = minloc reduce zip(e.a[i..i,..], dD);
              }
            }
          }
          when ("max") {
            if inputType == bool {
              errorMsg = "max not supported on boolean pdarrays";
              hadError = true;
            } else {
              forall (i,_) in dD {
                (res.a[i], _) = maxloc reduce zip(e.a[i..i, ..], dD);
              }
            }
          }
          otherwise {
            errorMsg = "unrecognized partial reduction op: " + op;
            hadError = true;
          }
        }
      }
    }

    // TODO: Select on op (product, sum, etc.)
    select (gEnt.dtype) {
      when (DType.Int64) {
        partialReductionHelper(int, int, op);
      }
      when (DType.Float64) {
        partialReductionHelper(real, real, op);
      }
      when (DType.Bool) {
        partialReductionHelper(bool, int, op);
      }
    }

    if hadError then
      return new MsgTuple(errorMsg, MsgType.ERROR);
    repMsg = "created " + st.attrib(rname);
    return new MsgTuple(repMsg, MsgType.NORMAL);
  }

  use CommandMap;
  registerFunction("array2d", array2DMsg,getModuleName());
  registerFunction("randint2d", randint2DMsg,getModuleName());
  registerFunction("binopvv2d", binopvv2DMsg,getModuleName());
  registerFunction("[int2d]", rowIndex2DMsg,getModuleName());
  registerFunction("partialReduction2D", partialReduction2DMsg, getModuleName());
}
