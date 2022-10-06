module Arr3DMsg {
  use GenSymIO;
  use SymEntry3D;

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

  proc array3DMsg(cmd: string, payload: string, argSize: int, st: borrowed SymTab): MsgTuple throws {
    var msgArgs = parseMessageArgs(payload, argSize);

    var val = msgArgs.getValueOf("val");
    var dtype = DType.UNDEF;
    var m: int;
    var n: int;
    var p: int;
    var rname:string = "";

    try {
      dtype = str2dtype(msgArgs.getValueOf("dtype"));
      m = msgArgs.get("m").getIntValue();
      n = msgArgs.get("n").getIntValue();
      p = msgArgs.get("p").getIntValue();
    } catch {
      var errorMsg = "Error parsing/decoding either dtypeBytes, m, n, or p";
      gsLogger.error(getModuleName(), getRoutineName(), getLineNumber(), errorMsg);
      return new MsgTuple(errorMsg, MsgType.ERROR);
    }

    overMemLimit(2*m*n*p);

    if dtype == DType.Int64 {
      var entry = new shared SymEntry3D(m, n, p, int);
      var localA: [{0..#m, 0..#n, 0..#p}] int = val:int;
      entry.a = localA;
      rname = st.nextName();
      st.addEntry(rname, entry);
    } else if dtype == DType.Float64 {
      var entry = new shared SymEntry3D(m, n, p, real);
      var localA: [{0..#m, 0..#n, 0..#p}] real = val:real;
      entry.a = localA;
      rname = st.nextName();
      st.addEntry(rname, entry);
    } else if dtype == DType.Bool {
      var entry = new shared SymEntry3D(m, n, p, bool);
      var localA: [{0..#m, 0..#n, 0..#p}] bool = if val == "True" then true else false;
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

  proc randint3DMsg(cmd: string, payload: string, argSize: int, st: borrowed SymTab): MsgTuple throws {

    param pn = Reflection.getRoutineName();
    var repMsg: string; // response message
    var msgArgs = parseMessageArgs(payload, argSize);

    var dtype = str2dtype(msgArgs.getValueOf("dtype"));
    var m = msgArgs.get("m").getIntValue();
    var n = msgArgs.get("n").getIntValue();
    var p = msgArgs.get("p").getIntValue();

    var rname = st.nextName();

    select (dtype) {
      when (DType.Int64) {
        overMemLimit(8*m*n*p);
        var aMin = msgArgs.get("low").getIntValue();
        var aMax = msgArgs.get("high").getIntValue();
        var seed = msgArgs.getValueOf("seed");

        var entry = new shared SymEntry3D(m, n, p, int);
        var localA: [{0..#m, 0..#n, 0..#p}] int;
        entry.a = localA;
        st.addEntry(rname, entry);
        fillInt(entry.a, aMin, aMax, seed);
      }
      when (DType.Float64) {
        var seed = msgArgs.getValueOf("seed");
        overMemLimit(8*m*n*p);
        var aMin = msgArgs.get("low").getRealValue();
        var aMax = msgArgs.get("high").getRealValue();

        var entry = new shared SymEntry3D(m, n, p, real);
        var localA: [{0..#m, 0..#n, 0..#p}] real;
        entry.a = localA;
        st.addEntry(rname, entry);
        fillReal(entry.a, aMin, aMax, seed);
      }
      when (DType.Bool) {
        var seed = msgArgs.getValueOf("seed");
        overMemLimit(8*m*n*p);

        var entry = new shared SymEntry3D(m, n, p, bool);
        var localA: [{0..#m, 0..#n, 0..#p}] bool;
        entry.a = localA;
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

  proc binopvv3DMsg(cmd: string, payload: string, argSize: int, st: borrowed SymTab): MsgTuple throws {
    param pn = Reflection.getRoutineName();
    var repMsg: string; // response message

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
        var l = left: SymEntry3D(int);
        var r = right: SymEntry3D(int);
        if boolOps.contains(op) {
          var e = st.addEntry3D(rname, l.m, l.n, l.p, bool);
          return doBinOpvv(l, r, e, op, rname, pn, st);
        } else if op == "/" {
          var e = st.addEntry3D(rname, l.m, l.n, l.p, real);
          return doBinOpvv(l, r, e, op, rname, pn, st);
        }
        var e = st.addEntry3D(rname, l.m, l.n, l.p, int);
        return doBinOpvv(l, r, e, op, rname, pn, st);
      }
      when (DType.Int64, DType.Float64) {
        var l = left: SymEntry3D(int);
        var r = right: SymEntry3D(real);
        if boolOps.contains(op) {
          var e = st.addEntry3D(rname, l.m, l.n, l.p, bool);
          return doBinOpvv(l, r, e, op, rname, pn, st);
        }
        var e = st.addEntry3D(rname, l.m, l.n, l.p, real);
        return doBinOpvv(l, r, e, op, rname, pn, st);
      }
      when (DType.Float64, DType.Int64) {
        var l = left: SymEntry3D(real);
        var r = right: SymEntry3D(int);
        if boolOps.contains(op) {
          var e = st.addEntry3D(rname, l.m, l.n, l.p, bool);
          return doBinOpvv(l, r, e, op, rname, pn, st);
        }
        var e = st.addEntry3D(rname, l.m, l.n, l.p, real);
        return doBinOpvv(l, r, e, op, rname, pn, st);
      }
      when (DType.Float64, DType.Float64) {
        var l = left: SymEntry3D(real);
        var r = right: SymEntry3D(real);
        if boolOps.contains(op) {
          var e = st.addEntry3D(rname, l.m, l.n, l.p, bool);
          return doBinOpvv(l, r, e, op, rname, pn, st);
        }
        var e = st.addEntry3D(rname, l.m, l.n, l.p, real);
        return doBinOpvv(l, r, e, op, rname, pn, st);
      }
      when (DType.Bool, DType.Bool) {
        var l = left: SymEntry3D(bool);
        var r = right: SymEntry3D(bool);
        var e = st.addEntry3D(rname, l.m, l.n, l.p, bool);
        return doBinOpvv(l, r, e, op, rname, pn, st);
      }
      when (DType.Bool, DType.Int64) {
        var l = left: SymEntry3D(bool);
        var r = right: SymEntry3D(int);
        var e = st.addEntry3D(rname, l.m, l.n, l.p, int);
        return doBinOpvv(l, r, e, op, rname, pn, st);
      }
      when (DType.Int64, DType.Bool) {
        var l = left: SymEntry3D(int);
        var r = right: SymEntry3D(bool);
        var e = st.addEntry3D(rname, l.m, l.n, l.p, int);
        return doBinOpvv(l, r, e, op, rname, pn, st);
      }
      when (DType.Bool, DType.Float64) {
        var l = left: SymEntry3D(bool);
        var r = right: SymEntry3D(real);
        var e = st.addEntry3D(rname, l.m, l.n, l.p, real);
        return doBinOpvv(l, r, e, op, rname, pn, st);
      }
      when (DType.Float64, DType.Bool) {
        var l = left: SymEntry3D(real);
        var r = right: SymEntry3D(bool);
        var e = st.addEntry3D(rname, l.m, l.n, l.p, real);
        return doBinOpvv(l, r, e, op, rname, pn, st);
      }
    }
    return new MsgTuple("Bin op not supported", MsgType.NORMAL);
  }

  proc SymTab.addEntry3D(name: string, m, n, p, type t): borrowed SymEntry3D(t) throws {
    if t == bool {overMemLimit(m*n*p);} else {overMemLimit(m*n*p*numBytes(t));}

    var entry = new shared SymEntry3D(m, n, p, t);
    if (tab.contains(name)) {
      mtLogger.debug(getModuleName(),getRoutineName(),getLineNumber(),
                     "redefined symbol: %s ".format(name));
    } else {
      mtLogger.debug(getModuleName(),getRoutineName(),getLineNumber(),
                     "adding symbol: %s ".format(name));
    }

    tab.addOrSet(name, entry);
    return (tab.getBorrowed(name):borrowed GenSymEntry): SymEntry3D(t);
  }

  use CommandMap;
  registerFunction("array3d", array3DMsg,getModuleName());
  registerFunction("randint3d", randint3DMsg,getModuleName());
  registerFunction("binopvv3d", binopvv3DMsg,getModuleName());
}
