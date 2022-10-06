module Arr4DMsg {
  use GenSymIO;
  use SymEntry4D;

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

  proc array4DMsg(cmd: string, payload: string, argSize: int, st: borrowed SymTab): MsgTuple throws {
    var msgArgs = parseMessageArgs(payload, argSize);

    var val = msgArgs.getValueOf("val");
    var dtype = DType.UNDEF;
    var m: int;
    var n: int;
    var p: int;
    var q: int;
    var rname:string = "";

    try {
      dtype = str2dtype(msgArgs.getValueOf("dtype"));
      m = msgArgs.get("m").getIntValue();
      n = msgArgs.get("n").getIntValue();
      p = msgArgs.get("p").getIntValue();
      q = msgArgs.get("q").getIntValue();
    } catch {
      var errorMsg = "Error parsing/decoding either dtypeBytes, m, n, p, or q";
      gsLogger.error(getModuleName(), getRoutineName(), getLineNumber(), errorMsg);
      return new MsgTuple(errorMsg, MsgType.ERROR);
    }

    overMemLimit(2*m*n*p*q);

    if dtype == DType.Int64 {
      var entry = new shared SymEntry4D(m, n, p, q, int);
      var localA: [{0..#m, 0..#n, 0..#p, 0..#q}] int = val:int;
      entry.a = localA;
      rname = st.nextName();
      st.addEntry(rname, entry);
    } else if dtype == DType.Float64 {
      var entry = new shared SymEntry4D(m, n, p, q, real);
      var localA: [{0..#m, 0..#n, 0..#p, 0..#q}] real = val:real;
      entry.a = localA;
      rname = st.nextName();
      st.addEntry(rname, entry);
    } else if dtype == DType.Bool {
      var entry = new shared SymEntry4D(m, n, p, q, bool);
      var localA: [{0..#m, 0..#n, 0..#p, 0..#q}] bool = if val == "True" then true else false;
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

  proc randint4DMsg(cmd: string, payload: string, argSize: int, st: borrowed SymTab): MsgTuple throws {
    param pn = Reflection.getRoutineName();
    var repMsg: string; // response message
    var msgArgs = parseMessageArgs(payload, argSize);

    var dtype = str2dtype(msgArgs.getValueOf("dtype"));
    var m = msgArgs.get("m").getIntValue();
    var n = msgArgs.get("n").getIntValue();
    var p = msgArgs.get("p").getIntValue();
    var q = msgArgs.get("q").getIntValue();
    var rname = st.nextName();

    select (dtype) {
      when (DType.Int64) {
        overMemLimit(8*m*n*p*q);
        var aMin = msgArgs.get("low").getIntValue();
        var aMax = msgArgs.get("high").getIntValue();
        var seed = msgArgs.getValueOf("seed");

        var entry = new shared SymEntry4D(m, n, p, q, int);
        var localA: [{0..#m, 0..#n, 0..#p, 0..#q}] int;
        entry.a = localA;
        st.addEntry(rname, entry);
        fillInt(entry.a, aMin, aMax, seed);
      }
      when (DType.Float64) {
        var seed = msgArgs.getValueOf("seed");
        overMemLimit(8*m*n*p*q);
        var aMin = msgArgs.get("low").getRealValue();
        var aMax = msgArgs.get("high").getRealValue();

        var entry = new shared SymEntry4D(m, n, p, q, real);
        var localA: [{0..#m, 0..#n, 0..#p, 0..#q}] real;
        entry.a = localA;
        st.addEntry(rname, entry);
        fillReal(entry.a, aMin, aMax, seed);
      }
      when (DType.Bool) {
        var seed = msgArgs.getValueOf("seed");
        overMemLimit(8*m*n*p*q);

        var entry = new shared SymEntry4D(m, n, p, q, bool);
        var localA: [{0..#m, 0..#n, 0..#p, 0..#q}] bool;
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

  proc binopvv4DMsg(cmd: string, payload: string, argSize: int, st: borrowed SymTab): MsgTuple throws {
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
        var l = left: SymEntry4D(int);
        var r = right: SymEntry4D(int);
        if boolOps.contains(op) {
          var e = st.addEntry4D(rname, l.m, l.n, l.p, l.q, bool);
          return doBinOpvv(l, r, e, op, rname, pn, st);
        } else if op == "/" {
          var e = st.addEntry4D(rname, l.m, l.n, l.p, l.q, real);
          return doBinOpvv(l, r, e, op, rname, pn, st);
        }
        var e = st.addEntry4D(rname, l.m, l.n, l.p, l.q, int);
        return doBinOpvv(l, r, e, op, rname, pn, st);
      }
      when (DType.Int64, DType.Float64) {
        var l = left: SymEntry4D(int);
        var r = right: SymEntry4D(real);
        if boolOps.contains(op) {
          var e = st.addEntry4D(rname, l.m, l.n, l.p, l.q, bool);
          return doBinOpvv(l, r, e, op, rname, pn, st);
        }
        var e = st.addEntry4D(rname, l.m, l.n, l.p, l.q, real);
        return doBinOpvv(l, r, e, op, rname, pn, st);
      }
      when (DType.Float64, DType.Int64) {
        var l = left: SymEntry4D(real);
        var r = right: SymEntry4D(int);
        if boolOps.contains(op) {
          var e = st.addEntry4D(rname, l.m, l.n, l.p, l.q, bool);
          return doBinOpvv(l, r, e, op, rname, pn, st);
        }
        var e = st.addEntry4D(rname, l.m, l.n, l.p, l.q, real);
        return doBinOpvv(l, r, e, op, rname, pn, st);
      }
      when (DType.Float64, DType.Float64) {
        var l = left: SymEntry4D(real);
        var r = right: SymEntry4D(real);
        if boolOps.contains(op) {
          var e = st.addEntry4D(rname, l.m, l.n, l.p, l.q, bool);
          return doBinOpvv(l, r, e, op, rname, pn, st);
        }
        var e = st.addEntry4D(rname, l.m, l.n, l.p, l.q, real);
        return doBinOpvv(l, r, e, op, rname, pn, st);
      }
      when (DType.Bool, DType.Bool) {
        var l = left: SymEntry4D(bool);
        var r = right: SymEntry4D(bool);
        var e = st.addEntry4D(rname, l.m, l.n, l.p, l.q, bool);
        return doBinOpvv(l, r, e, op, rname, pn, st);
      }
      when (DType.Bool, DType.Int64) {
        var l = left: SymEntry4D(bool);
        var r = right: SymEntry4D(int);
        var e = st.addEntry4D(rname, l.m, l.n, l.p, l.q, int);
        return doBinOpvv(l, r, e, op, rname, pn, st);
      }
      when (DType.Int64, DType.Bool) {
        var l = left: SymEntry4D(int);
        var r = right: SymEntry4D(bool);
        var e = st.addEntry4D(rname, l.m, l.n, l.p, l.q, int);
        return doBinOpvv(l, r, e, op, rname, pn, st);
      }
      when (DType.Bool, DType.Float64) {
        var l = left: SymEntry4D(bool);
        var r = right: SymEntry4D(real);
        var e = st.addEntry4D(rname, l.m, l.n, l.p, l.q, real);
        return doBinOpvv(l, r, e, op, rname, pn, st);
      }
      when (DType.Float64, DType.Bool) {
        var l = left: SymEntry4D(real);
        var r = right: SymEntry4D(bool);
        var e = st.addEntry4D(rname, l.m, l.n, l.p, l.q, real);
        return doBinOpvv(l, r, e, op, rname, pn, st);
      }
    }
    return new MsgTuple("Bin op not supported", MsgType.NORMAL);
  }

  proc SymTab.addEntry4D(name: string, m, n, p, q, type t): borrowed SymEntry4D(t) throws {
    if t == bool {overMemLimit(m*n*p*q);} else {overMemLimit(m*n*p*q*numBytes(t));}

    var entry = new shared SymEntry4D(m, n, p, q, t);
    if (tab.contains(name)) {
      mtLogger.debug(getModuleName(),getRoutineName(),getLineNumber(),
                     "redefined symbol: %s ".format(name));
    } else {
      mtLogger.debug(getModuleName(),getRoutineName(),getLineNumber(),
                     "adding symbol: %s ".format(name));
    }

    tab.addOrSet(name, entry);
    return (tab.getBorrowed(name):borrowed GenSymEntry): SymEntry4D(t);
  }

  use CommandMap;
  registerFunction("array4d", array4DMsg,getModuleName());
  registerFunction("randint4d", randint4DMsg,getModuleName());
  registerFunction("binopvv4d", binopvv4DMsg,getModuleName());
}
