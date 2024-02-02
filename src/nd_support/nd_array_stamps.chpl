use CommandMap, Message, MultiTypeSymbolTable;

////////////////////////////////////////////MsgProcessing///////////////////////////////////////////
use MsgProcessing;
proc arkouda_nd_stamp_createMsg1D(cmd: string, msgArgs: borrowed MessageArgs, st: borrowed SymTab): MsgTuple throws
    do return createMsg(cmd, msgArgs, st, 1);
registerFunction("create1D", arkouda_nd_stamp_createMsg1D);

proc arkouda_nd_stamp_setMsg1D(cmd: string, msgArgs: borrowed MessageArgs, st: borrowed SymTab): MsgTuple throws
    do return setMsg(cmd, msgArgs, st, 1);
registerFunction("set1D", arkouda_nd_stamp_setMsg1D);
////////////////////////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////GenSymIO//////////////////////////////////////////////
use GenSymIO;
proc arkouda_nd_stamp_tondarrayMsg1D(cmd: string, msgArgs: borrowed MessageArgs, st: borrowed SymTab): bytes throws
    do return tondarrayMsg(cmd, msgArgs, st, 1);
registerBinaryFunction("tondarray1D", arkouda_nd_stamp_tondarrayMsg1D);
////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////broadcasting////////////////////////////////////////////
proc arkouda_nd_stamp_broadcastNDArray1x1D(cmd: string, msgArgs: borrowed MessageArgs, st: borrowed SymTab): MsgTuple throws
    do return broadcastNDArray(cmd, msgArgs, st, 1, 1);
registerFunction("broadcast1x1D", arkouda_nd_stamp_broadcastNDArray1x1D);
////////////////////////////////////////////////////////////////////////////////////////////////////

