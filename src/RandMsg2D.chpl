module RandMsg2D
{
    use ServerConfig;
    
    use Message;
    use RandMsg;
    use Reflection;
    
    use MultiTypeSymbolTable;
    use MultiTypeSymEntry;

    /*
    parse, execute, and respond to randint message
    uniform int in half-open interval [min,max)

    :arg reqMsg: message to process (contains cmd,aMin,aMax,len,dtype)
    */
    proc randintMsg2D(cmd: string, msgArgs: borrowed MessageArgs, st: borrowed SymTab): MsgTuple throws {
      return randintMsg(cmd, msgArgs, st, 2);
    }

    use CommandMap;
    registerFunction("randint2D", randintMsg2D, getModuleName());
}
