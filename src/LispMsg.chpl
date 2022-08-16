/* Array set operations
 includes intersection, union, xor, and diff

 currently, only performs operations with integer arrays 
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

    /*
    Parse, execute, and respond to a setdiff1d message
    :arg reqMsg: request containing (cmd,name,name2,assume_unique)
    :type reqMsg: string
    :arg st: SymTab to act on
    :type st: borrowed SymTab
    :returns: (MsgTuple) response message
    */
    proc lispMsg(cmd: string, payload: string, st: borrowed SymTab): MsgTuple throws {
        param pn = Reflection.getRoutineName();
        var repMsg: string; // response message
        var (jsonTypes, jsonVals, sizeStr, pdaCountStr, code) = payload.splitMsgToTuple("|", 5);
        if (!checkCast(sizeStr, int)) {
          var errMsg = "Number of values:`%s` could not be cast to an integer".format(sizeStr);
          return new MsgTuple(errMsg, MsgType.ERROR);
        }
        if (!checkCast(pdaCountStr, int)) {
          var errMsg = "Number of values:`%s` could not be cast to an integer".format(sizeStr);
          return new MsgTuple(errMsg, MsgType.ERROR);
        }
        var size = sizeStr: int;
        var pdaCount = pdaCountStr: int;
        var argTypes: [0..#size] string = jsonToPdArray(jsonTypes, size);
        var argNames: [0..#size] string = jsonToPdArray(jsonVals, size);
        
        /*
        writeln(avalStr, xId, yId, code);
        // Received: {'bindings': "{'a': {'type': 'float64', 'value': '5.0'}, 'x': {'type': 'pdarray', 'name': 'id_ej8Pi4s_1'}, 'y': {'type': 'pdarray', 'name': 'id_ej8Pi4s_2'}}", 'code': "'( begin ( return ( + ( * a x ) y ) ) )'"}
        var gEnt: borrowed GenSymEntry = getGenericTypedArrayEntry(xId, st);
        var gEnt2: borrowed GenSymEntry = getGenericTypedArrayEntry(yId, st);

        var x = toSymEntry(gEnt, real);
        var y = toSymEntry(gEnt2, real);
        
        var ret = evalLisp(code, arrs=(x.a, y.a), arrNames=("x","y"),
                           vals=(avalStr:real,), valNames=("a",));
        writeln(ret);
        */
        return new MsgTuple(repMsg, MsgType.NORMAL);
    }

    // arrs is a tuple of the incoming arrays
    // arrNames is a list of names corresponding to arrs (so is same length as arrs)
    // vals are the values passed in
    // valNames are the names of those values (so is same length as vals)
    proc evalLisp(prog: string, arrs, arrNames, vals, valNames) {
      var ret: [0..#arrs[0].size] real;

      try {
        if arrs.size == 1 {
          for (val, r) in zip(arrs[0], ret) do {
            var ast = parse(prog);
            var env = new owned Env();
          
            // Add array values to environment
            env.addEntry(arrNames[0], val);

            // Add values to environment
            for (val, name) in zip(vals,valNames) do
              env.addEntry(name, val);

            // Evaluate for this index
            var ans = eval(ast, env);
            r = ans.toValue(real).v;
          }
        } else if arrs.size == 2 {
          for (val1, val2, r) in zip(arrs[0], arrs[1], ret) {
            var ast = parse(prog);
            var env = new owned Env();
          
            // Add array values to environment
            env.addEntry(arrNames[0], val1);
            env.addEntry(arrNames[1], val2);

            // Add values to environment
            for (val, name) in zip(vals,valNames) do
              env.addEntry(name, val);

            // Evaluate for this index
            var ans = eval(ast, env);
            r = ans.toValue(real).v;
          }
        }
      } catch e {
        writeln(e!.message());
      }
      return ret;
    }

    /*
    proc evalLisp(prog: string, arrs ...?n) {
      // arrs is a list of arrays and their corresponding names
      var ret: [0..#arrs[0].size] real;
      try {
        for i in 0..#arrs[0].size {
          var ast = parse(prog);
          var env = new owned Env();

          for param j in 0..#n by 2{
            // arrs[j+1] is name, arrs[j][i] is val at current index of current array
            env.addEntry(arrs[j+1], arrs[j][i]);
          }
          var ans = eval(ast, env);
          ret[i] = ans.toValue(real).v;
        }
      }
        catch e: Error {
            writeln(e.message());
        }
        return ret;
        } */
    
    use CommandMap;
    registerFunction("lispCode", lispMsg, getModuleName());
}
