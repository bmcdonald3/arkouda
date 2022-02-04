
module OperatorMsg
{
    use ServerConfig;

    use Time;
    use Math;
    use BitOps;
    use Reflection;
    use ServerErrors;
    use BinOp;

    use MultiTypeSymbolTable;
    use MultiTypeSymEntry;
    use ServerErrorStrings; 
    use Reflection;
    use Logging;
    use Message;
    
    private config const logLevel = ServerConfig.logLevel;
    const omLogger = new Logger(logLevel);
    
    /*
    Parse and respond to binopvv message.
    vv == vector op vector

    :arg reqMsg: request containing (cmd,op,aname,bname,rname)
    :type reqMsg: string 

    :arg st: SymTab to act on
    :type st: borrowed SymTab 

    :returns: (MsgTuple) 
    :throws: `UndefinedSymbolError(name)`
    */
    proc binopvvMsg(cmd: string, payload: string, st: borrowed SymTab): MsgTuple throws {       
        param pn = Reflection.getRoutineName();
        var repMsg: string; // response message

        // split request into fields
        var (op, aname, bname) = payload.splitMsgToTuple(3);

        var rname = st.nextName();
        var left: borrowed GenSymEntry = getGenericTypedArrayEntry(aname, st);
        var right: borrowed GenSymEntry = getGenericTypedArrayEntry(bname, st);
        
        omLogger.debug(getModuleName(), getRoutineName(), getLineNumber(), 
             "cmd: %t op: %t left pdarray: %t right pdarray: %t".format(
                                          cmd,op,st.attrib(aname),st.attrib(bname)));

        use Set;
        // This boolOps set is a filter to determine the output type for the operation.
        // All operations that involve one of these operations result in a `bool` symbol
        // table entry.
        var boolOps: set(string);
        boolOps.add("<");
        boolOps.add("<=");
        boolOps.add(">");
        boolOps.add(">=");
        boolOps.add("==");
        boolOps.add("!=");

        select (left.dtype, right.dtype) {
          when (DType.Int64, DType.Int64) {
            var l = toSymEntry(left,int);
            var r = toSymEntry(right,int);
            
            if boolOps.contains(op) {
              var e = st.addEntry(rname, l.size, bool);
              return doBinOpvv(l, r, e, op, rname, pn, st);
            } else if op == "/" {
              // True division is the only case in this int, int case
              // that results in a `real` symbol table entry.
              var e = st.addEntry(rname, l.size, real);
              return doBinOpvv(l, r, e, op, rname, pn, st);
            }
            var e = st.addEntry(rname, l.size, int);
            return doBinOpvv(l, r, e, op, rname, pn, st);
          }
          when (DType.Int64, DType.Float64) {
            var l = toSymEntry(left,int);
            var r = toSymEntry(right,real);
            // Only two possible resultant types are `bool` and `real`
            // for this case
            if boolOps.contains(op) {
              var e = st.addEntry(rname, l.size, bool);
              return doBinOpvv(l, r, e, op, rname, pn, st);
            }
            var e = st.addEntry(rname, l.size, real);
            return doBinOpvv(l, r, e, op, rname, pn, st);
          }
          when (DType.Float64, DType.Int64) {
            var l = toSymEntry(left,real);
            var r = toSymEntry(right,int);
            if boolOps.contains(op) {
              var e = st.addEntry(rname, l.size, bool);
              return doBinOpvv(l, r, e, op, rname, pn, st);
            }
            var e = st.addEntry(rname, l.size, real);
            return doBinOpvv(l, r, e, op, rname, pn, st);
          }
          when (DType.Float64, DType.Float64) {
            var l = toSymEntry(left,real);
            var r = toSymEntry(right,real);
            if boolOps.contains(op) {
              var e = st.addEntry(rname, l.size, bool);
              return doBinOpvv(l, r, e, op, rname, pn, st);
            }
            var e = st.addEntry(rname, l.size, real);
            return doBinOpvv(l, r, e, op, rname, pn, st);
          }
          // For cases where a boolean operand is involved, the only
          // possible resultant type is `bool`
          when (DType.Bool, DType.Bool) {
            var l = toSymEntry(left,bool);
            var r = toSymEntry(right,bool);
            var e = st.addEntry(rname, l.size, bool);
            return doBinOpvv(l, r, e, op, rname, pn, st);
          }
          when (DType.Bool, DType.Int64) {
            var l = toSymEntry(left,bool);
            var r = toSymEntry(right,int);
            var e = st.addEntry(rname, l.size, int);
            return doBinOpvv(l, r, e, op, rname, pn, st);
          }
          when (DType.Int64, DType.Bool) {
            var l = toSymEntry(left,int);
            var r = toSymEntry(right,bool);
            var e = st.addEntry(rname, l.size, int);
            return doBinOpvv(l, r, e, op, rname, pn, st);
          }
          when (DType.Bool, DType.Float64) {
            var l = toSymEntry(left,bool);
            var r = toSymEntry(right,real);
            var e = st.addEntry(rname, l.size, real);
            return doBinOpvv(l, r, e, op, rname, pn, st);
          }
          when (DType.Float64, DType.Bool) {
            var l = toSymEntry(left,real);
            var r = toSymEntry(right,bool);
            var e = st.addEntry(rname, l.size, real);
            return doBinOpvv(l, r, e, op, rname, pn, st);
          }
          when (DType.UInt64, DType.UInt64) {
            var l = toSymEntry(left,uint);
            var r = toSymEntry(right,uint);
            var e = st.addEntry(rname, l.size, uint);
            return doBinOpvv(l, r, e, op, rname, pn, st);
          }
        }
        return new MsgTuple("Bin op not supported", MsgType.NORMAL);
    }
    
    /*
    Parse and respond to binopvs message.
    vs == vector op scalar

    :arg reqMsg: request containing (cmd,op,aname,dtype,value)
    :type reqMsg: string 

    :arg st: SymTab to act on
    :type st: borrowed SymTab 

    :returns: (MsgTuple) 
    :throws: `UndefinedSymbolError(name)`
    */
    proc binopvsMsg(cmd: string, payload: string, st: borrowed SymTab): MsgTuple throws {
        param pn = Reflection.getRoutineName();
        var repMsg: string = ""; // response message

        // split request into fields
        var (op, aname, dtypeStr, value) = payload.splitMsgToTuple(4);

        var dtype = str2dtype(dtypeStr);
        var rname = st.nextName();
        var left: borrowed GenSymEntry = getGenericTypedArrayEntry(aname, st);

        omLogger.debug(getModuleName(),getRoutineName(),getLineNumber(),
                           "op: %s dtype: %t pdarray: %t scalar: %t".format(
                                                     op,dtype,st.attrib(aname),value));

        select (left.dtype, dtype) {
            when (DType.Int64, DType.Int64) {
                var l = toSymEntry(left,int);
                var val = try! value:int;
                select op
                {
                    when "+" {
                        var e = st.addEntry(rname, l.size, int);
                        e.a = l.a + val;
                    }
                    when "-" {
                        var e = st.addEntry(rname, l.size, int);
                        e.a = l.a - val;
                    }
                    when "*" {
                        var e = st.addEntry(rname, l.size, int);
                        e.a = l.a * val;
                    }
                    when "/" { // truediv
                        var e = st.addEntry(rname, l.size, real);
                        e.a = l.a:real / val:real;
                    } 
                    when "//" { // floordiv
                        var e = st.addEntry(rname, l.size, int);
                        ref ea = e.a;
                        ref la = l.a;
                        [(ei,li) in zip(ea,la)] ei = if val != 0 then li/val else 0;
                    }
                    when "%" { // modulo
                        var e = st.addEntry(rname, l.size, int);
                        ref ea = e.a;
                        ref la = l.a;
                        [(ei,li) in zip(ea,la)] ei = if val != 0 then li%val else 0;
                    } 
                    when "<" {
                        var e = st.addEntry(rname, l.size, bool);
                        e.a = l.a < val;
                    }
                    when ">" {
                        var e = st.addEntry(rname, l.size, bool);
                        e.a = l.a > val;
                    }
                    when "<=" {
                        var e = st.addEntry(rname, l.size, bool);
                        e.a = l.a <= val;
                    }
                    when ">=" {
                        var e = st.addEntry(rname, l.size, bool);
                        e.a = l.a >= val;
                    }
                    when "==" {
                        var e = st.addEntry(rname, l.size, bool);
                        e.a = l.a == val;
                    }
                    when "!=" {
                        var e = st.addEntry(rname, l.size, bool);
                        e.a = l.a != val;
                    }
                    when "<<" {
                        var e = st.addEntry(rname, l.size, int);
                        e.a = l.a << val;
                    }
                    when ">>" {
                        var e = st.addEntry(rname, l.size, int);
                        e.a = l.a >> val;
                    }
                    when "<<<" {
                        var e = st.addEntry(rname, l.size, int);
                        e.a = rotl(l.a, val);
                    }
                    when ">>>" {
                        var e = st.addEntry(rname, l.size, int);
                        e.a = rotr(l.a, val);
                    }
                    when "&" {
                        var e = st.addEntry(rname, l.size, int);
                        e.a = l.a & val;
                    }
                    when "|" {
                        var e = st.addEntry(rname, l.size, int);
                        e.a = l.a | val;
                    }
                    when "^" {
                        var e = st.addEntry(rname, l.size, int);
                        e.a = l.a ^ val;
                    }
                    when "**" { 
                        if (val<0){
                            var errorMsg = "Attempt to exponentiate base of type Int64 to negative exponent";
                            omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);                                                             
                            return new MsgTuple(errorMsg, MsgType.ERROR); 
                        }
                        var e = st.addEntry(rname, l.size, int);
                        e.a= l.a**val;
                    }
                    otherwise {
                        var errorMsg = notImplementedError(pn,left.dtype,op,dtype);
                        omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);       
                        return new MsgTuple(errorMsg, MsgType.ERROR);                         
                    }
                }
            }
            when (DType.Int64, DType.Float64) {
                var l = toSymEntry(left,int);
                var val = try! value:real;
                select op
                {
                    when "+" {
                        var e = st.addEntry(rname, l.size, real);
                        e.a = l.a + val;
                    }
                    when "-" {
                        var e = st.addEntry(rname, l.size, real);
                        e.a = l.a - val;
                    }
                    when "*" {
                        var e = st.addEntry(rname, l.size, real);
                        e.a = l.a * val;
                    }
                    when "/" { // truediv
                        var e = st.addEntry(rname, l.size, real);
                        e.a = l.a:real / val;
                    } 
                    when "//" { // floordiv
                        var e = st.addEntry(rname, l.size, real);
                        ref ea = e.a;
                        ref la = l.a;
                        [(ei,li) in zip(ea,la)] ei = if val != 0 then floor(li:real / val) else NAN;
                    }
                    when "<" {
                        var e = st.addEntry(rname, l.size, bool);
                        e.a = l.a < val;
                    }
                    when ">" {
                        var e = st.addEntry(rname, l.size, bool);
                        e.a = l.a > val;
                    }
                    when "<=" {
                        var e = st.addEntry(rname, l.size, bool);
                        e.a = l.a <= val;
                    }
                    when ">=" {
                        var e = st.addEntry(rname, l.size, bool);
                        e.a = l.a >= val;
                    }
                    when "==" {
                        var e = st.addEntry(rname, l.size, bool);
                        e.a = l.a == val;
                    }
                    when "!=" {
                        var e = st.addEntry(rname, l.size, bool);
                        e.a = l.a != val;
                    }
                    when "**" { 
                        var e = st.addEntry(rname, l.size, real);
                        e.a= l.a**val;
                    }
                    otherwise {
                        var errorMsg = notImplementedError(pn,left.dtype,op,dtype);
                        omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);                                
                        return new MsgTuple(errorMsg, MsgType.ERROR);  
                    }
                }
            }
            when (DType.Float64, DType.Int64) {
                var l = toSymEntry(left,real);
                var val = try! value:int;
                select op
                {
                    when "+" {
                        var e = st.addEntry(rname, l.size, real);
                        e.a = l.a + val;
                    }
                    when "-" {
                        var e = st.addEntry(rname, l.size, real);
                        e.a = l.a - val;
                    }
                    when "*" {
                        var e = st.addEntry(rname, l.size, real);
                        e.a = l.a * val;
                    }
                    when "/" { // truediv
                        var e = st.addEntry(rname, l.size, real);
                        e.a = l.a / val:real;
                    } 
                    when "//" { // floordiv
                        var e = st.addEntry(rname, l.size, real);
                        ref ea = e.a;
                        ref la = l.a;
                        [(ei,li) in zip(ea,la)] ei = if val != 0 then floor(li / val:real) else NAN;
                    }
                    when "<" {
                        var e = st.addEntry(rname, l.size, bool);
                        e.a = l.a < val;
                    }
                    when ">" {
                        var e = st.addEntry(rname, l.size, bool);
                        e.a = l.a > val;
                    }
                    when "<=" {
                        var e = st.addEntry(rname, l.size, bool);
                        e.a = l.a <= val;
                    }
                    when ">=" {
                        var e = st.addEntry(rname, l.size, bool);
                        e.a = l.a >= val;
                    }
                    when "==" {
                        var e = st.addEntry(rname, l.size, bool);
                        e.a = l.a == val;
                    }
                    when "!=" {
                        var e = st.addEntry(rname, l.size, bool);
                        e.a = l.a != val;
                    }
                    when "**" { 
                        var e = st.addEntry(rname, l.size, real);
                        e.a= l.a**val;
                    }
                    otherwise {
                        var errorMsg = notImplementedError(pn,left.dtype,op,dtype);
                        omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);        
                        return new MsgTuple(errorMsg, MsgType.ERROR);                         
                    }
                }
            }
            when (DType.Float64, DType.Float64) {
                var l = toSymEntry(left,real);
                var val = try! value:real;
                select op
                {
                    when "+" {
                        var e = st.addEntry(rname, l.size, real);
                        e.a = l.a + val;
                    }
                    when "-" {
                        var e = st.addEntry(rname, l.size, real);
                        e.a = l.a - val;
                    }
                    when "*" {
                        var e = st.addEntry(rname, l.size, real);
                        e.a = l.a * val;
                    }
                    when "/" { // truediv
                        var e = st.addEntry(rname, l.size, real);
                        e.a = l.a / val;
                    } 
                    when "//" { // floordiv
                        var e = st.addEntry(rname, l.size, real);
                        ref ea = e.a;
                        ref la = l.a;
                        [(ei,li) in zip(ea,la)] ei = if val != 0 then floor(li / val) else NAN;
                    }
                    when "<" {
                        var e = st.addEntry(rname, l.size, bool);
                        e.a = l.a < val;
                    }
                    when ">" {
                        var e = st.addEntry(rname, l.size, bool);
                        e.a = l.a > val;
                    }
                    when "<=" {
                        var e = st.addEntry(rname, l.size, bool);
                        e.a = l.a <= val;
                    }
                    when ">=" {
                        var e = st.addEntry(rname, l.size, bool);
                        e.a = l.a >= val;
                    }
                    when "==" {
                        var e = st.addEntry(rname, l.size, bool);
                        e.a = l.a == val;
                    }
                    when "!=" {
                        var e = st.addEntry(rname, l.size, bool);
                        e.a = l.a != val;
                    }
                    when "**" { 
                        var e = st.addEntry(rname, l.size, real);
                        e.a= l.a**val;
                    }
                    otherwise {
                        var errorMsg = notImplementedError(pn,left.dtype,op,dtype);
                        omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);                          
                        return new MsgTuple(errorMsg, MsgType.ERROR);                             
                    }
                }
            }
            when (DType.Bool, DType.Bool) {
                var l = toSymEntry(left, bool);
                var val = try! value.toLower():bool;
                select op {
                    when "|" {
                        var e = st.addEntry(rname, l.size, bool);
                        e.a = l.a | val;
                    }
                    when "&" {
                        var e = st.addEntry(rname, l.size, bool);
                        e.a = l.a & val;
                    }
                    when "^" {
                        var e = st.addEntry(rname, l.size, bool);
                        e.a = l.a ^ val;
                    }
                    otherwise {
                        var errorMsg = notImplementedError(pn,left.dtype,op,dtype);
                        omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);   
                        return new MsgTuple(errorMsg, MsgType.ERROR);                            
                    }
                }
            }
            when (DType.Bool, DType.Int64) {
                var l = toSymEntry(left, bool);
                var val = try! value:int;
                select op {
                    when "+" {
                        var e = st.addEntry(rname, l.size, int);
                        e.a = l.a:int + val;
                    }
                    when "-" {
                        var e = st.addEntry(rname, l.size, int);
                        e.a = l.a:int - val;
                    }
                    when "*" {
                        var e = st.addEntry(rname, l.size, int);
                        e.a = l.a:int * val;
                    }
                    otherwise {
                         var errorMsg = notImplementedError(pn,left.dtype,op,dtype);
                         omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);                        
                         return new MsgTuple(errorMsg, MsgType.ERROR); 
                    }
                }
            }
            when (DType.Int64, DType.Bool) {
                var l = toSymEntry(left, int);
                var val = try! value.toLower():bool;
                select op {
                    when "+" {
                        var e = st.addEntry(rname, l.size, int);
                        e.a = l.a + val:int;
                    }
                    when "-" {
                        var e = st.addEntry(rname, l.size, int);
                        e.a = l.a - val:int;
                    }
                    when "*" {
                        var e = st.addEntry(rname, l.size, int);
                        e.a = l.a * val:int;
                    }
                    otherwise {
                        var errorMsg = notImplementedError(pn,left.dtype,op,dtype);
                        omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);                        
                        return new MsgTuple(errorMsg, MsgType.ERROR);                         
                    }
                }
            }
            when (DType.Bool, DType.Float64) {
                var l = toSymEntry(left, bool);
                var val = try! value:real;
                select op {
                    when "+" {
                        var e = st.addEntry(rname, l.size, real);
                        e.a = l.a:real + val;
                    }
                    when "-" {
                        var e = st.addEntry(rname, l.size, real);
                        e.a = l.a:real - val;
                    }
                    when "*" {
                        var e = st.addEntry(rname, l.size, real);
                        e.a = l.a:real * val;
                    }
                    otherwise {
                        var errorMsg = notImplementedError(pn,left.dtype,op,dtype);
                        omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);                        
                        return new MsgTuple(errorMsg, MsgType.ERROR);                           
                    }
                }
            }
            when (DType.Float64, DType.Bool) {
                var l = toSymEntry(left, real);
                var val = try! value.toLower():bool;
                select op {
                    when "+" {
                        var e = st.addEntry(rname, l.size, real);
                        e.a = l.a + val:real;
                    }
                    when "-" {
                        var e = st.addEntry(rname, l.size, real);
                        e.a = l.a - val:real;
                    }
                    when "*" {
                        var e = st.addEntry(rname, l.size, real);
                        e.a = l.a * val:real;
                    }
                    otherwise {
                        var errorMsg = notImplementedError(pn,left.dtype,op,dtype);
                        omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);                        
                        return new MsgTuple(errorMsg, MsgType.ERROR);                         
                    }
                }
            }
            otherwise {
                 var errorMsg = unrecognizedTypeError(pn, 
                                            "("+dtype2str(left.dtype)+","+dtype2str(dtype)+")");
                 omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);                        
                 return new MsgTuple(errorMsg, MsgType.ERROR);                      
            }
        }
        
        repMsg = "created %s".format(st.attrib(rname));
        omLogger.debug(getModuleName(),getRoutineName(),getLineNumber(),
             "created pdarray %t from %s with scalar %t on pdarray".format(
                                                                    st.attrib(rname),op,value));
        return new MsgTuple(repMsg, MsgType.NORMAL);
    }

    /*
    Parse and respond to binopsv message.
    sv == scalar op vector

    :arg reqMsg: request containing (cmd,op,dtype,value,aname)
    :type reqMsg: string 

    :arg st: SymTab to act on
    :type st: borrowed SymTab 

    :returns: (MsgTuple) 
    :throws: `UndefinedSymbolError(name)`
    */
    proc binopsvMsg(cmd: string, payload: string, st: borrowed SymTab): MsgTuple throws {
        param pn = Reflection.getRoutineName();
        var repMsg: string = ""; // response message

        // split request into fields
        var (op, dtypeStr, value, aname) = payload.splitMsgToTuple(4);

        var dtype = str2dtype(dtypeStr);
        var rname = st.nextName();
        var right: borrowed GenSymEntry = getGenericTypedArrayEntry(aname, st);
        
        omLogger.debug(getModuleName(),getRoutineName(),getLineNumber(),
                 "command = %t op = %t scalar dtype = %t scalar = %t pdarray = %t".format(
                                   cmd,op,dtype2str(dtype),value,st.attrib(aname)));

        select (dtype, right.dtype) {
            when (DType.Int64, DType.Int64) {
                var val = try! value:int;
                var r = toSymEntry(right,int);
                select op
                {
                    when "+" {
                        var e = st.addEntry(rname, r.size, int);
                        e.a = val + r.a;
                    }
                    when "-" {
                        var e = st.addEntry(rname, r.size, int);
                        e.a = val - r.a;
                    }
                    when "*" {
                        var e = st.addEntry(rname, r.size, int);
                        e.a = val * r.a;
                    }
                    when "/" { // truediv
                        var e = st.addEntry(rname, r.size, real);
                        e.a =  val:real / r.a:real;
                    } 
                    when "//" { // floordiv
                        var e = st.addEntry(rname, r.size, int);
                        ref ea = e.a;
                        ref ra = r.a;
                        [(ei,ri) in zip(ea,ra)] ei = if ri != 0 then val/ri else 0;
                    }
                    when "%" { // modulo
                        var e = st.addEntry(rname, r.size, int);
                        ref ea = e.a;
                        ref ra = r.a;
                        [(ei,ri) in zip(ea,ra)] ei = if ri != 0 then val%ri else 0;
                    }
                    when "<" {
                        var e = st.addEntry(rname, r.size, bool);
                        e.a = val < r.a;
                    }
                    when ">" {
                        var e = st.addEntry(rname, r.size, bool);
                        e.a = val > r.a;
                    }
                    when "<=" {
                        var e = st.addEntry(rname, r.size, bool);
                        e.a = val <= r.a;
                    }
                    when ">=" {
                        var e = st.addEntry(rname, r.size, bool);
                        e.a = val >= r.a;
                    }
                    when "==" {
                        var e = st.addEntry(rname, r.size, bool);
                        e.a = val == r.a;
                    }
                    when "!=" {
                        var e = st.addEntry(rname, r.size, bool);
                        e.a = val != r.a;
                    }
                    when "<<" {
                        var e = st.addEntry(rname, r.size, int);
                        e.a = val << r.a;
                    }
                    when ">>" {
                        var e = st.addEntry(rname, r.size, int);
                        e.a = val >> r.a;
                    }
                    when "<<<" {
                        var e = st.addEntry(rname, r.size, int);
                        e.a = rotl(val, r.a);
                    }
                    when ">>>" {
                        var e = st.addEntry(rname, r.size, int);
                        e.a = rotr(val, r.a);
                    }
                    when "&" {
                        var e = st.addEntry(rname, r.size, int);
                        e.a = val & r.a;
                    }
                    when "|" {
                        var e = st.addEntry(rname, r.size, int);
                        e.a = val | r.a;
                    }
                    when "^" {
                        var e = st.addEntry(rname, r.size, int);
                        e.a = val ^ r.a;
                    }
                    when "**" { 
                        if || reduce (r.a<0){
                            var errorMsg = "Attempt to exponentiate base of type Int64 to negative exponent";
                            omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);
                            return new MsgTuple(errorMsg, MsgType.ERROR); 
                        }
                        var e = st.addEntry(rname, r.size, int);
                        e.a= val**r.a;
                    }
                    otherwise {
                        var errorMsg = notImplementedError(pn,dtype,op,right.dtype);
                        omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);
                        return new MsgTuple(errorMsg, MsgType.ERROR); 
                    }
                }
            }
            when (DType.Int64, DType.Float64) {
                var val = try! value:int;
                var r = toSymEntry(right,real);
                select op
                {
                    when "+" {
                        var e = st.addEntry(rname, r.size, real);
                        e.a = val + r.a;
                    }
                    when "-" {
                        var e = st.addEntry(rname, r.size, real);
                        e.a = val - r.a;
                    }
                    when "*" {
                        var e = st.addEntry(rname, r.size, real);
                        e.a = val * r.a;
                    }
                    when "/" { // truediv
                        var e = st.addEntry(rname, r.size, real);
                        e.a = val:real / r.a;
                    }
                    when "//" { // floordiv
                        var e = st.addEntry(rname, r.size, real);
                        ref ea = e.a;
                        ref ra = r.a;
                        [(ei,ri) in zip(ea,ra)] ei = if ri != 0 then floor(val:real / ri) else NAN;
                    }
                    when "<" {
                        var e = st.addEntry(rname, r.size, bool);
                        e.a = val < r.a;
                    }
                    when ">" {
                        var e = st.addEntry(rname, r.size, bool);
                        e.a = val > r.a;
                    }
                    when "<=" {
                        var e = st.addEntry(rname, r.size, bool);
                        e.a = val <= r.a;
                    }
                    when ">=" {
                        var e = st.addEntry(rname, r.size, bool);
                        e.a = val >= r.a;
                    }
                    when "==" {
                        var e = st.addEntry(rname, r.size, bool);
                        e.a = val == r.a;
                    }
                    when "!=" {
                        var e = st.addEntry(rname, r.size, bool);
                        e.a = val != r.a;
                    }
                    when "**" { 
                        var e = st.addEntry(rname, r.size, real);
                        e.a= val**r.a;
                    }
                    otherwise {
                        var errorMsg = notImplementedError(pn,dtype,op,right.dtype);
                        omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);
                        return new MsgTuple(errorMsg, MsgType.ERROR);                     
                    }
                }
            }
            when (DType.Float64, DType.Int64) {
                var val = try! value:real;
                var r = toSymEntry(right,int);
                select op
                {
                    when "+" {
                        var e = st.addEntry(rname, r.size, real);
                        e.a = val + r.a;
                    }
                    when "-" {
                        var e = st.addEntry(rname, r.size, real);
                        e.a = val - r.a;
                    }
                    when "*" {
                        var e = st.addEntry(rname, r.size, real);
                        e.a = val * r.a;
                    }
                    when "/" { // truediv
                        var e = st.addEntry(rname, r.size, real);
                        e.a = val / r.a:real;
                    } 
                    when "//" { // floordiv
                        var e = st.addEntry(rname, r.size, real);
                        ref ea = e.a;
                        ref ra = r.a;
                        [(ei,ri) in zip(ea,ra)] ei = if ri != 0 then floor(val / ri:real) else NAN;
                    }
                    when "<" {
                        var e = st.addEntry(rname, r.size, bool);
                        e.a = val < r.a;
                    }
                    when ">" {
                        var e = st.addEntry(rname, r.size, bool);
                        e.a = val > r.a;
                    }
                    when "<=" {
                        var e = st.addEntry(rname, r.size, bool);
                        e.a = val <= r.a;
                    }
                    when ">=" {
                        var e = st.addEntry(rname, r.size, bool);
                        e.a = val >= r.a;
                    }
                    when "==" {
                        var e = st.addEntry(rname, r.size, bool);
                        e.a = val == r.a;
                    }
                    when "!=" {
                        var e = st.addEntry(rname, r.size, bool);
                        e.a = val != r.a;
                    }
                    when "**" { 
                        var e = st.addEntry(rname, r.size, real);
                        e.a= val**r.a;
                    }
                    otherwise {
                        var errorMsg = notImplementedError(pn,dtype,op,right.dtype);
                        omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);
                        return new MsgTuple(errorMsg, MsgType.ERROR); 
                    }
                }
            }
            when (DType.Float64, DType.Float64) {
                var val = try! value:real;
                var r = toSymEntry(right,real);
                select op
                {
                    when "+" {
                        var e = st.addEntry(rname, r.size, real);
                        e.a = val + r.a;
                    }
                    when "-" {
                        var e = st.addEntry(rname, r.size, real);
                        e.a = val - r.a;
                    }
                    when "*" {
                        var e = st.addEntry(rname, r.size, real);
                        e.a = val * r.a;
                    }
                    when "/" { // truediv
                        var e = st.addEntry(rname, r.size, real);
                        e.a = val / r.a;
                    } 
                    when "//" { // floordiv
                        var e = st.addEntry(rname, r.size, real);
                        ref ea = e.a;
                        ref ra = r.a;
                        [(ei,ri) in zip(ea,ra)] ei = if ri != 0 then floor(val / ri) else NAN;
                    }
                    when "<" {
                        var e = st.addEntry(rname, r.size, bool);
                        e.a = val < r.a;
                    }
                    when ">" {
                        var e = st.addEntry(rname, r.size, bool);
                        e.a = val > r.a;
                    }
                    when "<=" {
                        var e = st.addEntry(rname, r.size, bool);
                        e.a = val <= r.a;
                    }
                    when ">=" {
                        var e = st.addEntry(rname, r.size, bool);
                        e.a = val >= r.a;
                    }
                    when "==" {
                        var e = st.addEntry(rname, r.size, bool);
                        e.a = val == r.a;
                    }
                    when "!=" {
                        var e = st.addEntry(rname, r.size, bool);
                        e.a = val != r.a;
                    }
                    when "**" { 
                        var e = st.addEntry(rname, r.size, real);
                        e.a= val**r.a;
                    }
                    otherwise {
                        var errorMsg = notImplementedError(pn,dtype,op,right.dtype);
                        omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);
                        return new MsgTuple(errorMsg, MsgType.ERROR); 
                    }                        
                }
            }
            when (DType.Bool, DType.Bool) {
                var val = try! value.toLower():bool;
                var r = toSymEntry(right, bool);
                select op {
                    when "|" {
                        var e = st.addEntry(rname, r.size, bool);
                         e.a = val | r.a;
                    }
                    when "&" {
                        var e = st.addEntry(rname, r.size, bool);
                         e.a = val & r.a;
                    }
                    when "^" {
                        var e = st.addEntry(rname, r.size, bool);
                         e.a = val ^ r.a;
                    }
                    otherwise {
                        var errorMsg = notImplementedError(pn,dtype,op,right.dtype);
                        omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);
                        return new MsgTuple(errorMsg, MsgType.ERROR); 
                    }
                }
            }
            when (DType.Bool, DType.Int64) {
                var val = try! value.toLower():bool;
                var r = toSymEntry(right, int);
                select op {
                    when "+" {
                        var e = st.addEntry(rname, r.size, int);
                        e.a = val:int + r.a;
                    }
                    when "-" {
                        var e = st.addEntry(rname, r.size, int);
                        e.a = val:int - r.a;
                    }
                    when "*" {
                        var e = st.addEntry(rname, r.size, int);
                        e.a = val:int * r.a;
                    }
                    otherwise {
                        var errorMsg = notImplementedError(pn,dtype,op,right.dtype);
                        omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);
                        return new MsgTuple(errorMsg, MsgType.ERROR); 
                    }
                }
            }
            when (DType.Int64, DType.Bool) {
                var val = try! value:int;
                var r = toSymEntry(right, bool);
                select op {
                    when "+" {
                        var e = st.addEntry(rname, r.size, int);
                        e.a = val + r.a:int;
                    }
                    when "-" {
                        var e = st.addEntry(rname, r.size, int);
                        e.a = val - r.a:int;
                    }
                    when "*" {
                        var e = st.addEntry(rname, r.size, int);
                        e.a = val * r.a:int;
                    }
                    otherwise {
                        var errorMsg = notImplementedError(pn,dtype,op,right.dtype);
                        omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);
                        return new MsgTuple(errorMsg, MsgType.ERROR); 
                    }
                }
            }
            when (DType.Bool, DType.Float64) {
                var val = try! value.toLower():bool;
                var r = toSymEntry(right, real);
                select op {
                    when "+" {
                        var e = st.addEntry(rname, r.size, real);
                        e.a = val:real + r.a;
                    }
                    when "-" {
                        var e = st.addEntry(rname, r.size, real);
                        e.a = val:real - r.a;
                    }
                    when "*" {
                        var e = st.addEntry(rname, r.size, real);
                        e.a = val:real * r.a;
                    }
                    otherwise {
                        var errorMsg = notImplementedError(pn,dtype,op,right.dtype);
                        omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);
                        return new MsgTuple(errorMsg, MsgType.ERROR); 
                    }
                }
            }
            when (DType.Float64, DType.Bool) {
                var val = try! value:real;
                var r = toSymEntry(right, bool);
                select op {
                    when "+" {
                        var e = st.addEntry(rname, r.size, real);
                        e.a = val + r.a:real;
                    }
                    when "-" {
                        var e = st.addEntry(rname, r.size, real);
                        e.a = val - r.a:real;
                    }
                    when "*" {
                        var e = st.addEntry(rname, r.size, real);
                        e.a = val * r.a:real;
                    }
                    otherwise {
                        var errorMsg = notImplementedError(pn,dtype,op,right.dtype);
                        omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);
                        return new MsgTuple(errorMsg, MsgType.ERROR); 
                    }
                }
            }
            otherwise {
                var errorMsg = unrecognizedTypeError(pn,
                                     "("+dtype2str(dtype)+","+dtype2str(right.dtype)+")");
                omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);
                return new MsgTuple(errorMsg, MsgType.ERROR); 
            }
        }
        
        repMsg = "created %s".format(st.attrib(rname));
        omLogger.debug(getModuleName(),getRoutineName(),getLineNumber(),repMsg);
        return new MsgTuple(repMsg, MsgType.NORMAL);
    }

    /*
    Parse and respond to opeqvv message.
    vector op= vector

    :arg reqMsg: request containing (cmd,op,aname,bname)
    :type reqMsg: string 

    :arg st: SymTab to act on
    :type st: borrowed SymTab 

    :returns: (MsgTuple) 
    :throws: `UndefinedSymbolError(name)`
    */
    proc opeqvvMsg(cmd: string, payload: string, st: borrowed SymTab): MsgTuple throws {
        param pn = Reflection.getRoutineName();
        var repMsg: string; // response message

        // split request into fields
        var (op, aname, bname) = payload.splitMsgToTuple(3);

        // retrieve left and right pdarray objects      
        var left: borrowed GenSymEntry = getGenericTypedArrayEntry(aname, st);
        var right: borrowed GenSymEntry = getGenericTypedArrayEntry(bname, st);

        omLogger.debug(getModuleName(),getRoutineName(),getLineNumber(),
                    "cmd: %s op: %s left pdarray: %s right pdarray: %s".format(cmd,op,
                                                         st.attrib(aname),st.attrib(bname)));

        select (left.dtype, right.dtype) {
            when (DType.Int64, DType.Int64) {
                var l = toSymEntry(left,int);
                var r = toSymEntry(right,int);
                select op
                {
                    when "+=" { l.a += r.a; }
                    when "-=" { l.a -= r.a; }
                    when "*=" { l.a *= r.a; }
                    when "//=" {
                        //l.a /= r.a;
                        ref la = l.a;
                        ref ra = r.a;
                        [(li,ri) in zip(la,ra)] li = if ri != 0 then li/ri else 0;
                    }//floordiv
                    when "%=" {
                        //l.a /= r.a;
                        ref la = l.a;
                        ref ra = r.a;
                        [(li,ri) in zip(la,ra)] li = if ri != 0 then li%ri else 0;
                    }
                    when "**=" { 
                        if || reduce (r.a<0){
                            var errorMsg =  "Attempt to exponentiate base of type Int64 to negative exponent";
                            return new MsgTuple(errorMsg, MsgType.ERROR);                              
                        }
                        else{ l.a **= r.a; }
                    }
                    otherwise {
                        var errorMsg = notImplementedError(pn,left.dtype,op,right.dtype);
                        omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);
                        return new MsgTuple(errorMsg, MsgType.ERROR);                          
                    }
                }
            }
            when (DType.Int64, DType.Float64) {
                var l = toSymEntry(left,int);
                var r = toSymEntry(right,real);

                var errorMsg = notImplementedError(pn,left.dtype,op,right.dtype);
                omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);
                return new MsgTuple(errorMsg, MsgType.ERROR);  
            }
            when (DType.Float64, DType.Int64) {
                var l = toSymEntry(left,real);
                var r = toSymEntry(right,int);

                select op
                {
                    when "+=" {l.a += r.a;}
                    when "-=" {l.a -= r.a;}
                    when "*=" {l.a *= r.a;}
                    when "/=" {l.a /= r.a:real;} //truediv
                    when "//=" { //floordiv
                        ref la = l.a;
                        ref ra = r.a;
                        [(li,ri) in zip(la,ra)] li = if ri != 0 then floor(li / ri) else NAN;
                    }
                    when "**=" { l.a **= r.a; }
                    otherwise {
                        var errorMsg = notImplementedError(pn,left.dtype,op,right.dtype);
                        omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);
                        return new MsgTuple(errorMsg, MsgType.ERROR);  
                    }
                }
            }
            when (DType.Float64, DType.Float64) {
                var l = toSymEntry(left,real);
                var r = toSymEntry(right,real);
                select op
                {
                    when "+=" {l.a += r.a;}
                    when "-=" {l.a -= r.a;}
                    when "*=" {l.a *= r.a;}
                    when "/=" {l.a /= r.a;}//truediv
                    when "//=" { //floordiv
                        ref la = l.a;
                        ref ra = r.a;
                        [(li,ri) in zip(la,ra)] li = if ri != 0 then floor(li / ri) else NAN;
                    }
                    when "**=" { l.a **= r.a; }
                    otherwise {
                        var errorMsg = notImplementedError(pn,left.dtype,op,right.dtype);
                        omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);
                        return new MsgTuple(errorMsg, MsgType.ERROR);      
                    }
                }
            }
            when (DType.Bool, DType.Bool) {
                var l = toSymEntry(left, bool);
                var r = toSymEntry(right, bool);
                select op
                {
                    when "|=" {l.a |= r.a;}
                    when "&=" {l.a &= r.a;}
                    when "^=" {l.a ^= r.a;}
                    otherwise {
                        var errorMsg = notImplementedError(pn,left.dtype,op,right.dtype);
                        omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);
                        return new MsgTuple(errorMsg, MsgType.ERROR);                          
                    }
                }
            }
            when (DType.Int64, DType.Bool) {
                var l = toSymEntry(left, int);
                var r = toSymEntry(right, bool);
                select op
                { 
                    when "+=" {l.a += r.a:int;}
                    when "-=" {l.a -= r.a:int;}
                    when "*=" {l.a *= r.a:int;}
                    otherwise {
                        var errorMsg = notImplementedError(pn,left.dtype,op,right.dtype);
                        omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);
                        return new MsgTuple(errorMsg, MsgType.ERROR);                          
                    }
                }
            }
            when (DType.Float64, DType.Bool) {
                var l = toSymEntry(left, real);
                var r = toSymEntry(right, bool);
                select op
                {
                    when "+=" {l.a += r.a:real;}
                    when "-=" {l.a -= r.a:real;}
                    when "*=" {l.a *= r.a:real;}
                    otherwise {
                        var errorMsg = notImplementedError(pn,left.dtype,op,right.dtype);
                        omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);
                        return new MsgTuple(errorMsg, MsgType.ERROR);                          
                    }
                }
            }
            otherwise {
                var errorMsg = unrecognizedTypeError(pn,
                                  "("+dtype2str(left.dtype)+","+dtype2str(right.dtype)+")");
                omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);
                return new MsgTuple(errorMsg, MsgType.ERROR);                                 
            }
        }

        repMsg = "opeqvv success";
        omLogger.debug(getModuleName(),getRoutineName(),getLineNumber(),repMsg);
        return new MsgTuple(repMsg, MsgType.NORMAL);
    }

    /*
    Parse and respond to opeqvs message.
    vector op= scalar

    :arg reqMsg: request containing (cmd,op,aname,bname,rname)
    :type reqMsg: string 

    :arg st: SymTab to act on
    :type st: borrowed SymTab 

    :returns: (MsgTuple)
    :throws: `UndefinedSymbolError(name)`
    */
    proc opeqvsMsg(cmd: string, payload: string, st: borrowed SymTab): MsgTuple throws {
        param pn = Reflection.getRoutineName();
        var repMsg: string; // response message

        // split request into fields
        var (op, aname, dtypeStr, value) = payload.splitMsgToTuple(4);
        var dtype = str2dtype(dtypeStr);

        omLogger.debug(getModuleName(),getRoutineName(),getLineNumber(),
                        "cmd: %s op: %s aname: %s dtype: %s scalar: %s".format(
                                                 cmd,op,aname,dtype2str(dtype),value));

        var left: borrowed GenSymEntry = getGenericTypedArrayEntry(aname, st);
 
        omLogger.debug(getModuleName(),getRoutineName(),getLineNumber(),
                         "op: %t pdarray: %t scalar: %t".format(op,st.attrib(aname),value));
        select (left.dtype, dtype) {
            when (DType.Int64, DType.Int64) {
                var l = toSymEntry(left,int);
                var val = try! value:int;
                select op
                {
                    when "+=" { l.a += val; }
                    when "-=" { l.a -= val; }
                    when "*=" { l.a *= val; }
                    when "//=" { 
                        if val != 0 {l.a /= val;} else {l.a = 0;}
                    }//floordiv
                    when "%=" { 
                        if val != 0 {l.a %= val;} else {l.a = 0;}
                    }
                    when "**=" { 
                        if (val<0){
                            var errorMsg = "Attempt to exponentiate base of type Int64 to negative exponent";
                            omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),
                                                                              errorMsg);
                            return new MsgTuple(errorMsg, MsgType.ERROR);                              
                        }
                        else{ l.a **= val; }

                    }
                    otherwise {
                        var errorMsg = notImplementedError(pn,left.dtype,op,dtype);
                        omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);
                        return new MsgTuple(errorMsg, MsgType.ERROR);                         
                    }
                }
            }
            when (DType.Int64, DType.Float64) {
                var errorMsg = notImplementedError(pn,left.dtype,op,dtype);
                omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);
                return new MsgTuple(errorMsg, MsgType.ERROR);  
            }
            when (DType.Float64, DType.Int64) {
                var l = toSymEntry(left,real);
                var val = try! value:int;
                select op
                {
                    when "+=" {l.a += val;}
                    when "-=" {l.a -= val;}
                    when "*=" {l.a *= val;}
                    when "/=" {l.a /= val:real;} //truediv
                    when "//=" { //floordiv
                        if val != 0 {l.a = floor(l.a / val);} else {l.a = NAN;}
                    }
                    when "**=" { l.a **= val; }
                    otherwise {
                        var errorMsg = notImplementedError(pn,left.dtype,op,dtype);
                        omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);
                        return new MsgTuple(errorMsg, MsgType.ERROR);                          
                    }
                }
            }
            when (DType.Float64, DType.Float64) {
                var l = toSymEntry(left,real);
                var val = try! value:real;
                select op
                {
                    when "+=" {l.a += val;}
                    when "-=" {l.a -= val;}
                    when "*=" {l.a *= val;}
                    when "/=" {l.a /= val;}//truediv
                    when "//=" { //floordiv
                        if val != 0 {l.a = floor(l.a / val);} else {l.a = NAN;}
                    }
                    when "**=" { l.a **= val; }
                    otherwise {
                        var errorMsg = notImplementedError(pn,left.dtype,op,dtype);
                        omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);
                        return new MsgTuple(errorMsg, MsgType.ERROR);                         
                    }
                }
            }
            when (DType.Int64, DType.Bool) {
                var l = toSymEntry(left, int);
                var val = try! value: bool;
                select op {
                    when "+=" {l.a += val:int;}
                    when "-=" {l.a -= val:int;}
                    when "*=" {l.a *= val:int;}
                    otherwise {
                        var errorMsg = notImplementedError(pn,left.dtype,op,dtype);
                        omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);
                        return new MsgTuple(errorMsg, MsgType.ERROR);                         
                    }
                }
            }
            when (DType.Float64, DType.Bool) {
                var l = toSymEntry(left, real);
                var val = try! value: bool;
                select op {
                    when "+=" {l.a += val:real;}
                    when "-=" {l.a -= val:real;}
                    when "*=" {l.a *= val:real;}
                    otherwise {
                        var errorMsg = notImplementedError(pn,left.dtype,op,dtype);
                        omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);
                        return new MsgTuple(errorMsg, MsgType.ERROR);                          
                    }
                }
            }
            otherwise {
                var errorMsg = unrecognizedTypeError(pn,
                                   "("+dtype2str(left.dtype)+","+dtype2str(dtype)+")");
                omLogger.error(getModuleName(),getRoutineName(),getLineNumber(),errorMsg);                                           
                return new MsgTuple(errorMsg, MsgType.ERROR);                
            }
        }

        repMsg = "opeqvs success";
        omLogger.debug(getModuleName(),getRoutineName(),getLineNumber(),repMsg);
        return new MsgTuple(repMsg, MsgType.NORMAL);
    }

    proc registerMe() {
      use CommandMap;
      registerFunction("binopvv", binopvvMsg, getModuleName());
      registerFunction("binopvs", binopvsMsg, getModuleName());
      registerFunction("binopsv", binopsvMsg, getModuleName());
      registerFunction("opeqvv", opeqvvMsg, getModuleName());
      registerFunction("opeqvs", opeqvsMsg, getModuleName());
    }
}
