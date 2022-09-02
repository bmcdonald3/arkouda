module LisExprInterp
{

    use LisExprData;
    use ObjectPool;

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

    /*
      evaluate the expression
    */
    proc eval(ast: BGenListValue, env: borrowed Env, st, ref p: pool, idx: int): GenValue throws {
        select (ast.lvt) {
            when (LVT.Sym) {
              return env.getRealVal(ast.toListValue(Symbol).lv, idx);
            }
            when (LVT.Lst) {
                ref lst = ast.toListValue(GenList).lv;
                // no empty lists allowed
                checkGEqLstSize(lst,1);
                // currently first list element must be a symbol of operator
                checkSymbol(lst[0]);
                var op = lst[0].toListValue(Symbol).lv;
                select (op) {
                    when "+"   {checkEqLstSize(lst,3); return poolAdd(eval(lst[1], env, st, p, idx), eval(lst[2], env, st, p, idx),p);}
                    when "-"   {checkEqLstSize(lst,3); return eval(lst[1], env, st, p, idx) - eval(lst[2], env, st, p, idx);}
                    when "*"   {checkEqLstSize(lst,3); return poolMul(eval(lst[1], env, st, p, idx), eval(lst[2], env, st, p, idx),p);}
                    when "=="  {checkEqLstSize(lst,3); return eval(lst[1], env, st, p, idx) == eval(lst[2], env, st, p, idx);}
                    when "!="  {checkEqLstSize(lst,3); return eval(lst[1], env, st, p, idx) != eval(lst[2], env, st, p, idx);}
                    when "<"   {checkEqLstSize(lst,3); return eval(lst[1], env, st, p, idx) < eval(lst[2], env, st, p, idx);}
                    when "<="  {checkEqLstSize(lst,3); return eval(lst[1], env, st, p, idx) <= eval(lst[2], env, st, p, idx);}
                    when ">"   {checkEqLstSize(lst,3); return eval(lst[1], env, st, p, idx) > eval(lst[2], env, st, p, idx);}
                    when ">="  {checkEqLstSize(lst,3); return eval(lst[1], env, st, p, idx) >= eval(lst[2], env, st, p, idx);}
                    when "or"  {checkEqLstSize(lst,3); return or(eval(lst[1], env, st, p, idx), eval(lst[2], env, st, p, idx));}
                    when "and" {checkEqLstSize(lst,3); return and(eval(lst[1], env, st, p, idx), eval(lst[2], env, st, p, idx));}
                    when "not" {checkEqLstSize(lst,2); return not(eval(lst[1], env, st, p, idx));}
                    when "if" {
                        checkEqLstSize(lst,4);
                        if isTrue(eval(lst[1], env, st, p, idx)) {return eval(lst[2], env, st, p, idx);} else {return eval(lst[3], env, st, p, idx);}
                    }
                    when "begin" {
                      checkGEqLstSize(lst, 1);
                      // env already setup, only eval last statement
                      return eval(lst[lst.size-1], env, st, p, idx);
                    }
                    when "return" { // for now, just eval the next line, in time, might want to coerce return value
                        return eval(lst[1], env, st, p, idx);
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

    proc setupEnv(ast: BGenListValue, env: borrowed Env, name: string, st) throws {
      select (ast.lvt) {
        when (LVT.R) {
          env.addReal(name, new Value(ast.toListValue(real).lv));
          return;
        }
        when (LVT.Lst) {
          ref lst = ast.toListValue(GenList).lv;
          // no empty lists allowed
          checkGEqLstSize(lst,1);
          // currently first list element must be a symbol of operator
          checkSymbol(lst[0]);
          var op = lst[0].toListValue(Symbol).lv;
          select (op) {
            when ":=" {
                checkEqLstSize(lst,3);
                checkSymbol(lst[1]);
                var name = lst[1].toListValue(Symbol).lv;
                setupEnv(lst[2],env,name,st);
                return;
            }
            when "lookup_and_index_float64" {
                var id = lst[1].toListValue(Symbol).lv;
                env.addArr(name, id, st);
                return;
            }
            when "begin" {
              checkGEqLstSize(lst, 1);
              // setup the environment
              for i in 1..#lst.size-2 do
                setupEnv(lst[i], env, '', st);
              // don't eval the return statement
              return;
            }
            when "return" { // for now, just eval the next line, in time, might want to coerce return value
              // skip for setup
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
