module LisExprInterp
{

    use LisExprData;
    use ObjectPool;
    use Time;

    /*
      tokenize the prog
    */
    proc tokenize(line: string) {
        var l: list(string) = line.replace("("," ( ").replace(")"," ) ").split();
        return l;
    }
    
    /*
      parse, check, and validate code and all symbols in the tokenized prog
    */ 
    proc parse(line: string): GenListValue throws {
        // Want:
        //   return read_from_tokens(tokenize(line));
        //
        // Workaround (see https://github.com/chapel-lang/chapel/issues/16170):

        var l: list(string) = tokenize(line);
        return read_from_tokens(l);
    }
    
    /*
      parse throught the list of tokens generating the parse tree / AST
      as a list of atoms and lists
    */
    proc read_from_tokens(ref tokens: list(string)): GenListValue throws {
        if (tokens.size == 0) then
            throw new owned Error("SyntaxError: unexpected EOF");

        // Open Q: If we were to parse from the back of the string to the
        // front, could this be more efficient since popping from the
        // front of a list is an expensive operation?

        var token = tokens.pop(0);
        if (token == "(") {
            var L = new GenList();
            while (tokens.first() != ")") {
                L.append(read_from_tokens(tokens));
                if (tokens.size == 0) then
                    throw new owned Error("SyntaxError: unexpected EOF");
            }
            tokens.pop(0); // pop off ")"
            return new ListValue(L);
        }
        else if (token == ")") {
            throw new owned Error("SyntaxError: unexpected )");
        }
        else {
            return atom(token);
        }
    }
    
    /* determine atom type and values */
    proc atom(token: string): GenListValue {
        try { // try to interpret as an integer ?
            return new ListValue(token:int); 
        } catch {
            try { //try to interpret it as a real ?
                return new ListValue(token:real);
            } catch { // return it as a symbol
                return new ListValue(token);
            }
        }
    }
    
    /* check to see if list value is a symbol otherwise throw error */
    inline proc checkSymbol(arg: BGenListValue) throws {
        if (arg.lvt != LVT.Sym) {
          throw new owned Error("arg must be a symbol " + arg:string);
        }
    }

    /* check to see if size is greater than or equal to size otherwise throw error */
    inline proc checkGEqLstSize(lst: GenList, sz: int) throws {
        if (lst.size < sz) {
          throw new owned Error("list must be at least size " + sz:string + " " + lst:string);
        }
    }

    /* check to see if size is equal to size otherwise throw error */
    inline proc checkEqLstSize(lst: GenList, sz: int) throws {
        if (lst.size != sz) {
          throw new owned Error("list must be size" + sz:string + " " +  lst:string);
        }
    }

    var gStrSymbolT: real;
    var gSymbolT: real;
    var gCheckT: real;
    var gLookupT: real;
    var gAssignT: real;
    
    /*
      evaluate the expression
    */
    proc eval(ast: BGenListValue, env: borrowed Env, st, ref p: pool): GenValue throws {
      var strSymbolT: Timer;
      var symbolT: Timer;
      var checkT: Timer;
      var lookupT: Timer;
      var assignT: Timer;
      
        select (ast.lvt) {
            when (LVT.Sym) {
              strSymbolT.start();
                var gv = env.lookup(ast.toListValue(Symbol).lv);
                var asd = gv.copy();
                strSymbolT.stop(); gStrSymbolT += strSymbolT.elapsed(); 
                return asd;
            }
            when (LVT.I) {
              //symbolT.start();
                var ret: int = ast.toListValue(int).lv;
                var asd = new Value(ret);
                //symbolT.stop(); gSymbolT += symbolT.elapsed(); 
                return asd;
            }
            when (LVT.R) {
              symbolT.start();
                var ret: real = ast.toListValue(real).lv;
                var asd = p.getReal(ret);
                symbolT.stop(); gSymbolT += symbolT.elapsed(); 
                return asd;
            }
            when (LVT.Lst) {
                ref lst = ast.toListValue(GenList).lv;
                // no empty lists allowed
                checkT.start();
                checkGEqLstSize(lst,1);
                // currently first list element must be a symbol of operator
                checkSymbol(lst[0]);
                checkT.stop();
                var op = lst[0].toListValue(Symbol).lv;
                select (op) {
                    when "+"   {checkT.start();checkEqLstSize(lst,3);checkT.stop(); gCheckT+=checkT.elapsed();  return poolAdd(eval(lst[1], env, st, p), eval(lst[2], env, st, p),p);}
                    when "-"   {checkT.start();checkEqLstSize(lst,3);checkT.stop(); gCheckT+=checkT.elapsed();  return eval(lst[1], env, st, p) - eval(lst[2], env, st, p);}
                    when "*"   {checkT.start();checkEqLstSize(lst,3);checkT.stop(); gCheckT+=checkT.elapsed();  return poolMul(eval(lst[1], env, st, p), eval(lst[2], env, st, p),p);}
                    when "=="  {checkT.start();checkEqLstSize(lst,3);checkT.stop(); gCheckT+=checkT.elapsed();  return eval(lst[1], env, st, p) == eval(lst[2], env, st, p);}
                    when "!="  {checkT.start();checkEqLstSize(lst,3);checkT.stop(); gCheckT+=checkT.elapsed();  return eval(lst[1], env, st, p) != eval(lst[2], env, st, p);}
                    when "<"   {checkT.start();checkEqLstSize(lst,3);checkT.stop(); gCheckT+=checkT.elapsed();  return eval(lst[1], env, st, p) < eval(lst[2], env, st, p);}
                    when "<="  {checkT.start();checkEqLstSize(lst,3);checkT.stop(); gCheckT+=checkT.elapsed();  return eval(lst[1], env, st, p) <= eval(lst[2], env, st, p);}
                    when ">"   {checkT.start();checkEqLstSize(lst,3);checkT.stop(); gCheckT+=checkT.elapsed();  return eval(lst[1], env, st, p) > eval(lst[2], env, st, p);}
                    when ">="  {checkT.start();checkEqLstSize(lst,3);checkT.stop(); gCheckT+=checkT.elapsed();  return eval(lst[1], env, st, p) >= eval(lst[2], env, st, p);}
                    when "or"  {checkT.start();checkEqLstSize(lst,3);checkT.stop(); gCheckT+=checkT.elapsed();  return or(eval(lst[1], env, st, p), eval(lst[2], env, st, p));}
                    when "and" {checkT.start();checkEqLstSize(lst,3);checkT.stop(); gCheckT+=checkT.elapsed();  return and(eval(lst[1], env, st, p), eval(lst[2], env, st, p));}
                    when "not" {checkT.start();checkEqLstSize(lst,2);checkT.stop(); gCheckT+=checkT.elapsed();  return not(eval(lst[1], env, st, p));}
                    when ":=" {
                      checkT.start();
                        checkEqLstSize(lst,3);
                        checkSymbol(lst[1]);
                        checkT.stop(); gCheckT+=checkT.elapsed(); 

                        assignT.start();
                        var name = lst[1].toListValue(Symbol).lv;
                        // addEnrtry redefines values for already existing entries
                        var gv = env.addEntry(name, eval(lst[2],env, st, p));
                        //TODO: how to continue evaling after an assignment?
                        var asd = gv.copy();
                        assignT.stop(); gAssignT += assignT.elapsed(); 
                        return asd; // return value assigned to symbol
                    }
                    when "lookup_and_index_float64" {
                      lookupT.start();
                        var entry = st.lookup(lst[1].toListValue(Symbol).lv);
                        var e = toSymEntry(toGenSymEntry(entry), real);
                        var i = eval(lst[2],env,st,p).toValue(int).v;
                        var asd = p.getReal(e.a[i]);
                        lookupT.stop();
                        gLookupT+= lookupT.elapsed();
                        return asd;
                    }
                    when "lookup_and_index_int64" {
                      lookupT.start();
                        var entry = st.lookup(lst[1].toListValue(Symbol).lv);
                        var e = toSymEntry(toGenSymEntry(entry), int);
                        var i = eval(lst[2],env,st,p).toValue(int).v;
                        var asd =new Value(e.a[i]);
                        lookupT.stop();
                        gLookupT+= lookupT.elapsed();
                        return asd;
                    }
                    when "if" {
                        checkEqLstSize(lst,4);
                        if isTrue(eval(lst[1], env, st, p)) {return eval(lst[2], env, st, p);} else {return eval(lst[3], env, st, p);}
                    }
                    when "begin" {
                      checkT.start();
                      checkGEqLstSize(lst, 1);
                      checkT.stop(); gCheckT+=checkT.elapsed(); 
                      // setup the environment
                      for i in 1..#lst.size-1 do
                        eval(lst[i], env, st, p);
                      // eval the return expression
                      return eval(lst[lst.size-1], env, st, p);
                    }
                    when "return" { // for now, just eval the next line, in time, might want to coerce return value
                        return eval(lst[1], env, st, p);
                    }
                    otherwise {
                        throw new owned Error("op not implemented " + op);
                    }
                }
            }
            otherwise {
              throw new owned Error("undefined ast node type " + ast:string);
            }
        }
    }


}
