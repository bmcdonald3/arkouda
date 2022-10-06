module Reshape {
  use GenSymIO;
  use SymEntry2D;
  use SymEntry3D;
  use SymEntry4D;
  use Arr2DMsg;
  use Arr3DMsg;
  use Arr4DMsg;

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

//  proc reshape1DMsg(cmd: string, payload: string, st: borrowed SymTab): MsgTuple throws {
  proc reshape1DMsg(cmd: string, payload: string, argSize: int, st: borrowed SymTab): MsgTuple throws {
    param pn = Reflection.getRoutineName();
    var repMsg: string; // response message
//    var (name) = payload.splitMsgToTuple(1); // split request into fields
    var msgArgs = parseMessageArgs(payload, argSize);

    var name = msgArgs.getValueOf("name");

    var rname = st.nextName();
    var gEnt: borrowed GenSymEntry = getGenericTypedArrayEntry(name, st);

    if gEnt.ndim == 1 {
      var inputArr = toSymEntry(gEnt, int);
      var e = st.addEntry(rname, inputArr.size, int);
      e.a = inputArr.a;
    } else if gEnt.ndim == 2 {
      var inputArr = toSymEntry2D(gEnt, int);

      var e = st.addEntry(rname, inputArr.size, int);
      e.a = reshape(inputArr.a, {0..#(inputArr.m*inputArr.n)});
    } else if gEnt.ndim == 3 {
      var inputArr = toSymEntry3D(gEnt, int);

      var e = st.addEntry(rname, inputArr.size, int);
      e.a = reshape(inputArr.a, {0..#(inputArr.m*inputArr.n*inputArr.p)});
    } else {
      var inputArr = toSymEntry4D(gEnt, int);

      var e = st.addEntry(rname, inputArr.size, int);
      e.a = reshape(inputArr.a, {0..#(inputArr.m*inputArr.n*inputArr.p*inputArr.q)});
    }

    repMsg = "created %s".format(st.attrib(rname));
    return new MsgTuple(repMsg, MsgType.NORMAL);
  }

//  proc reshape2DMsg(cmd: string, payload: string, st: borrowed SymTab): MsgTuple throws {
  proc reshape2DMsg(cmd: string, payload: string, argSize: int, st: borrowed SymTab): MsgTuple throws {

    param pn = Reflection.getRoutineName();
    var repMsg: string; // response message
//    var (name, mStr, nStr) = payload.splitMsgToTuple(3); // split request into fields
//
//    var m = mStr:int;
//    var n = nStr:int;
    var msgArgs = parseMessageArgs(payload, argSize);

    var name = msgArgs.getValueOf("name");
    var m = msgArgs.get("m").getIntValue();
    var n = msgArgs.get("n").getIntValue();

    var rname = st.nextName();
    var gEnt: borrowed GenSymEntry = getGenericTypedArrayEntry(name, st);

    if gEnt.ndim == 1 {
      var inputArr = toSymEntry(gEnt, int);

      var e = st.addEntry2D(rname, m, n, int);
      e.a = reshape(inputArr.a, {0..#m, 0..#n});
    } else if gEnt.ndim == 2 {
      var inputArr = toSymEntry2D(gEnt, int);

      var e = st.addEntry2D(rname, m, n, int);
      e.a = reshape(inputArr.a, {0..#m, 0..#n});
    } else if gEnt.ndim == 3 {
      var inputArr = toSymEntry3D(gEnt, int);

      var e = st.addEntry2D(rname, m, n, int);
      e.a = reshape(inputArr.a, {0..#m, 0..#n});
    } else {
      var inputArr = toSymEntry4D(gEnt, int);

      var e = st.addEntry2D(rname, m, n, int);
      e.a = reshape(inputArr.a, {0..#m, 0..#n});
    }

    repMsg = "created %s".format(st.attrib(rname));
    return new MsgTuple(repMsg, MsgType.NORMAL);
  }

//  proc reshape3DMsg(cmd: string, payload: string, st: borrowed SymTab): MsgTuple throws {
  proc reshape3DMsg(cmd: string, payload: string, argSize: int, st: borrowed SymTab): MsgTuple throws {

    param pn = Reflection.getRoutineName();
    var repMsg: string; // response message
//    var (name, mStr, nStr, pStr) = payload.splitMsgToTuple(4); // split request into fields
//
//    var m = mStr:int;
//    var n = nStr:int;
//    var p = pStr:int;
    var msgArgs = parseMessageArgs(payload, argSize);

    var name = msgArgs.getValueOf("name");
    var m = msgArgs.get("m").getIntValue();
    var n = msgArgs.get("n").getIntValue();
    var p = msgArgs.get("p").getIntValue();

    var rname = st.nextName();
    var gEnt: borrowed GenSymEntry = getGenericTypedArrayEntry(name, st);
    if gEnt.ndim == 1 {
      var inputArr = toSymEntry(gEnt, int);

      var e = st.addEntry3D(rname, m, n, p, int);
      e.a = reshape(inputArr.a, {0..#m, 0..#n, 0..#p});
    } else if gEnt.ndim == 2 {
      var inputArr = toSymEntry2D(gEnt, int);

      var e = st.addEntry3D(rname, m, n, p, int);
      e.a = reshape(inputArr.a, {0..#m, 0..#n, 0..#p});
    } else if gEnt.ndim == 3 {
      var inputArr = toSymEntry3D(gEnt, int);

      var e = st.addEntry3D(rname, m, n, p, int);
      e.a = reshape(inputArr.a, {0..#m, 0..#n, 0..#p});
    } else {
      var inputArr = toSymEntry4D(gEnt, int);

      var e = st.addEntry3D(rname, m, n, p, int);
      e.a = reshape(inputArr.a, {0..#m, 0..#n, 0..#p});
    }

    repMsg = "created %s".format(st.attrib(rname));
    return new MsgTuple(repMsg, MsgType.NORMAL);
  }

//  proc reshape4DMsg(cmd: string, payload: string, st: borrowed SymTab): MsgTuple throws {
  proc reshape4DMsg(cmd: string, payload: string, argSize: int, st: borrowed SymTab): MsgTuple throws {

    param pn = Reflection.getRoutineName();
    var repMsg: string; // response message
//    var (name, mStr, nStr, pStr, qStr) = payload.splitMsgToTuple(5); // split request into fields
//
//    var m = mStr:int;
//    var n = nStr:int;
//    var p = pStr:int;
//    var q = qStr:int;
    var msgArgs = parseMessageArgs(payload, argSize);

    var name = msgArgs.getValueOf("name");
    var m = msgArgs.get("m").getIntValue();
    var n = msgArgs.get("n").getIntValue();
    var p = msgArgs.get("p").getIntValue();
    var q = msgArgs.get("q").getIntValue();

    var rname = st.nextName();
    var gEnt: borrowed GenSymEntry = getGenericTypedArrayEntry(name, st);
    if gEnt.ndim == 1 {
      var inputArr = toSymEntry(gEnt, int);

      var e = st.addEntry4D(rname, m, n, p, q, int);
      e.a = reshape(inputArr.a, {0..#m, 0..#n, 0..#p, 0..#q});
    } else if gEnt.ndim == 2 {
      var inputArr = toSymEntry2D(gEnt, int);

      var e = st.addEntry4D(rname, m, n, p, q, int);
      e.a = reshape(inputArr.a, {0..#m, 0..#n, 0..#p, 0..#q});
    } else if gEnt.ndim == 3 {
      var inputArr = toSymEntry3D(gEnt, int);

      var e = st.addEntry4D(rname, m, n, p, q, int);
      e.a = reshape(inputArr.a, {0..#m, 0..#n, 0..#p, 0..#q});
    } else {
      var inputArr = toSymEntry4D(gEnt, int);

      var e = st.addEntry4D(rname, m, n, p, q, int);
      e.a = reshape(inputArr.a, {0..#m, 0..#n, 0..#p, 0..#q});
    }

    repMsg = "created %s".format(st.attrib(rname));
    return new MsgTuple(repMsg, MsgType.NORMAL);
  }

  use CommandMap;
  registerFunction("reshape1D", reshape1DMsg,getModuleName());
  registerFunction("reshape2D", reshape2DMsg,getModuleName());
  registerFunction("reshape3D", reshape3DMsg,getModuleName());
  registerFunction("reshape4D", reshape4DMsg,getModuleName());
}
