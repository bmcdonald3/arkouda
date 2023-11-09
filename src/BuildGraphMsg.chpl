module BuildGraphMsg {
    // Chapel modules.
    use Reflection;
    use Set;
    use Time; 
    use Sort; 
    use List;
    use ReplicatedDist;

    // Package modules.
    use CopyAggregation;
    
    
    // Arkouda modules.
    use MultiTypeSymbolTable;
    use MultiTypeSymEntry;
    use ServerConfig;
    use ServerErrors;
    use ServerErrorStrings;
    use ArgSortMsg;
    use AryUtil;
    use Logging;
    use Message;
    
    // Server message logger. 
    private config const logLevel = ServerConfig.logLevel;
    private config const logChannel = ServerConfig.logChannel;
    const bgmLogger = new Logger(logLevel, logChannel);
    var outMsg:string;

    /**
    * Convert akarrays to a graph object. 
    *
    * cmd: operation to perform. 
    * msgArgs: arugments passed to backend. 
    * SymTab: symbol table used for storage. 
    *
    * returns: message back to Python.
    */
    proc addEdgesFromMsg(cmd: string, msgArgs: borrowed MessageArgs, st: borrowed SymTab): MsgTuple throws {
      halt();
        var D_sbdmn = {0..numLocales-1} dmapped Replicated();
        var ranges2: [D_sbdmn] (int,locale);
        var repMsg = "hi";
        return new MsgTuple(repMsg, MsgType.NORMAL);
    } // end of addEdgesFromMsg

    use CommandMap;
    registerFunction("addEdgesFrom", addEdgesFromMsg, getModuleName());
}