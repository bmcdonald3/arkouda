/* Processing of Arkouda lambda functions
   This allows users to write simple operations
   involving pdarrays and scalars to be computed
   in a single operation on the server side. This
   works by parsing the code, converting it to an
   AST, generating lisp code, then executing that
   lisp code on the server.
 */

module LispMsg
{
    use ServerConfig;

    use Time only;
    use Math only;
    use Reflection only;

    use MultiTypeSymbolTable;
    use MultiTypeSymEntry;
    use SegmentedString;
    use ServerErrorStrings;

    use Reflection;
    use ServerErrors;
    use Logging;
    use Message;

    use LisExprData;
    use LisExprInterp;
    use TestLisExpr;

    use GenSymIO;
    use Message;

    private config const logLevel = ServerConfig.logLevel;
    const asLogger = new Logger(logLevel);
    const Tasks = {0..#numTasks};

    /*
    Parse, execute, and respond to a setdiff1d message
    :arg reqMsg: request containing (cmd,name,name2,assume_unique)
    :type reqMsg: string
    :arg st: SymTab to act on
    :type st: borrowed SymTab
    :returns: (MsgTuple) response message
    */
    proc lispMsg(cmd: string, payload: string, argSize: int, st: borrowed SymTab): MsgTuple throws {
        param pn = Reflection.getRoutineName();
        var repMsg: string; // response message
        var msgArgs = parseMessageArgs(payload, argSize);

        var retTypeStr = msgArgs.getValueOf("ret_type");
        var size = msgArgs.get("num_elems").getIntValue();
        var lispCode = msgArgs.getValueOf("code");
        retTypeStr = retTypeStr.strip(" ");

        var retName = st.nextName();

        if retTypeStr == "int64" {
          var ret = st.addEntry(retName, size, int);
          evalLisp(lispCode, ret.a, st);
        } else if retTypeStr == "float64" {
          var ret = st.addEntry(retName, size, real);
          evalLisp(lispCode, ret.a, st);
        }
        repMsg = "created " + st.attrib(retName);
        return new MsgTuple(repMsg, MsgType.NORMAL);
    }
    
    proc evalLisp(prog: string, ret: [] ?t, st) throws {
      try {
        coforall loc in Locales {
            on loc {
              coforall task in Tasks {
                    var lD = ret.domain.localSubdomain();
                    var tD = calcBlock(task, lD.low, lD.high);
                    var p = new pool();

                    const ast = parse(prog);
                    var env = new owned Env();
                    setupEnv(ast, env, '', st);
                    ref lst = ast.toListValue(GenList).lv;
                    var ops = new list(string);
                    eval(lst[lst.size-1].toListValue(GenList).lv[1], env, st, p, 0, ops, 0, true).toValue(t).v;
                    for i in tD {
                      // Evaluate for this index
                      // only eval the last statement
                      ret[i] = eval(lst[lst.size-1].toListValue(GenList).lv[1], env, st, p, i, ops, 0, false).toValue(t).v;
                      p.freeAll();
                    }
                    // memtracking size = 0 in makefile 
                }
            }
        }
      } catch e {
        writeln(e!.message());
      }
    }
    use CommandMap;
    registerFunction("lispCode", lispMsg, getModuleName());
}
