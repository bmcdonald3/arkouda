use CommandMap, Message, MultiTypeSymbolTable;

                proc _nd_gen_createMsg1D(cmd: string, msgArgs: borrowed MessageArgs, st: borrowed SymTab): MsgTuple throws do
                    return createMsg(cmd, msgArgs, st, 1);

                registerFunction("create1D", _nd_gen_createMsg1D);
                
                proc _nd_gen_createMsg2D(cmd: string, msgArgs: borrowed MessageArgs, st: borrowed SymTab): MsgTuple throws do
                    return createMsg(cmd, msgArgs, st, 2);

                registerFunction("create2D", _nd_gen_createMsg2D);
                
                proc _nd_gen_createMsg3D(cmd: string, msgArgs: borrowed MessageArgs, st: borrowed SymTab): MsgTuple throws do
                    return createMsg(cmd, msgArgs, st, 3);

                registerFunction("create3D", _nd_gen_createMsg3D);
                
                proc _nd_gen_setMsg1D(cmd: string, msgArgs: borrowed MessageArgs, st: borrowed SymTab): MsgTuple throws do
                    return setMsg(cmd, msgArgs, st, 1);

                registerFunction("set1D", _nd_gen_setMsg1D);
                
                proc _nd_gen_setMsg2D(cmd: string, msgArgs: borrowed MessageArgs, st: borrowed SymTab): MsgTuple throws do
                    return setMsg(cmd, msgArgs, st, 2);

                registerFunction("set2D", _nd_gen_setMsg2D);
                
                proc _nd_gen_setMsg3D(cmd: string, msgArgs: borrowed MessageArgs, st: borrowed SymTab): MsgTuple throws do
                    return setMsg(cmd, msgArgs, st, 3);

                registerFunction("set3D", _nd_gen_setMsg3D);
                use MsgProcessing;
