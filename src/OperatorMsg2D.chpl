module OperatorMsg2D
{
    use ServerConfig;
    
    use Message;
    use OperatorMsg;
    use Reflection;
    
    use MultiTypeSymbolTable;
    use MultiTypeSymEntry;
    
    proc binopvvMsg2D(cmd: string, msgArgs: borrowed MessageArgs, st: borrowed SymTab): MsgTuple throws {
      return binopvvMsg(cmd, msgArgs, st, 2);
    }

    use CommandMap;
    registerFunction("binopvv2D", binopvvMsg2D, getModuleName());
}

