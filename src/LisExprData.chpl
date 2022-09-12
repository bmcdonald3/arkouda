module LisExprData
{

    public use List;
    public use Map;
    use MultiTypeSymEntry;
    
    type Symbol = string;

   /* allowed list value types */
    enum LVT {Lst, Sym, I, R};
    
    /* allowed value types in the eval */
    /* in a real scheme/lisp interpreter these two enums (LVT and VT) would be the same */
    enum VT {I, R};

    /* type: generic list values */
    type GenListValue = shared GenListValueClass;
    type BGenListValue = borrowed GenListValueClass;
    type ListValue = shared ListValueClass;
    type BListValue = borrowed ListValueClass;
    
    /* type: list of generic list values */
    type GenList = shared ListClass(GenListValue);
    type BGenlist = borrowed ListClass(GenListValue);
    
    /* type: generic values for eval */
    type GenValue = unmanaged GenValueClass;
    type BGenValue = unmanaged GenValueClass;
    type Value = unmanaged ValueClass;
    type BValue = unmanaged ValueClass;

    /*
      List Class wraps the standard List which is a record
      forwarding the interface to the class definition
      this gives me a more familiar feel to lists in python
    */
    class ListClass {
      type etype;
      forwarding var l: list(etype);
    }
    
    /* generic list value class def */
    class GenListValueClass
    {
        var lvt: LVT;
        
        /* initialize the list value type so we can test it at runtime */
        proc init(type lvtype) {
            if (lvtype == GenList)            {lvt = LVT.Lst;}
            if (lvtype == Symbol)             {lvt = LVT.Sym;}
            if (lvtype == int)                {lvt = LVT.I;}
            if (lvtype == real)               {lvt = LVT.R;}
        }
        
        /* cast to the GenListValue to borrowed ListValue(vtype) halt on failure */
        inline proc toListValue(type lvtype) {
            return try! this :BListValue(lvtype);
        }

        /* returns a copy of this... an owned GenListValue */
        proc copy(): GenListValue throws {
          select (this.lvt) {
            when (LVT.Lst) {
              return new ListValue(this.toListValue(GenList).lv);
            }
            when (LVT.Sym) {
              return new ListValue(this.toListValue(Symbol).lv);
            }
            when (LVT.I) {
              return new ListValue(this.toListValue(int).lv);
            }
            when (LVT.R) {
              return new ListValue(this.toListValue(real).lv);
            }
            otherwise {throw new owned Error("not implemented");}
          }
        }
    }
    
    /* concrete list value class def */
    class ListValueClass : GenListValueClass
    {
        type lvtype;
        var lv: lvtype;
        
        /* initialize the value and the vtype */
        proc init(val: ?vtype) {
            super.init(vtype);
            this.lvtype = vtype;
            this.lv = val;
            this.complete();
        }
        
    }

    
    /* generic value class */
    class GenValueClass
    {
        /* value type testable at runtime */
        var vt: VT;
    
        /* initialize the value type so we can test it at runtime */
        proc init(type vtype) {
            if (vtype == int)  {vt = VT.I;}
            if (vtype == real) {vt = VT.R;}
        }
        
        /* cast to the GenValue to borrowed Value(vtype) halt on failure */
        inline proc toValue(type vtype) {
            return try! this :BValue(vtype);
        }

        /* returns a copy of this... an owned GenValue */
        proc copy(): GenValue throws {
            select (this.vt) {
                when (VT.I) {return new Value(this.toValue(int).v);}
                when (VT.R) {return new Value(this.toValue(real).v);}
                otherwise { throw new owned Error("not implemented"); }
            }
        }
    }
    
    /* concrete value class */
    class ValueClass : GenValueClass
    {
        type vtype; // value type
        var v: vtype; // value
        
        /* initialize the value and the vtype */
        proc init(val: ?vtype) {
            super.init(vtype);
            this.vtype = vtype;
            this.v = val;
        }
    }

    //////////////////////////////////////////
    // operators over GenValue
    //////////////////////////////////////////
    
    inline operator +(l: BGenValue, r: BGenValue): GenValue throws {
        select (l.vt, r.vt) {
            when (VT.I, VT.I) {return new Value(l.toValue(int).v + r.toValue(int).v);}
            when (VT.I, VT.R) {return new Value(l.toValue(int).v + r.toValue(real).v);}
            when (VT.R, VT.I) {return new Value(l.toValue(real).v + r.toValue(int).v);}
            when (VT.R, VT.R) {return new Value(l.toValue(real).v + r.toValue(real).v);}
            otherwise {throw new owned Error("not implemented");}
        }
    }

    inline proc poolAdd(l: BGenValue, r: BGenValue, ref p: pool): GenValue throws {
        select (l.vt, r.vt) {
            when (VT.I, VT.I) {return new Value(l.toValue(int).v + r.toValue(int).v);}
            when (VT.I, VT.R) {return p.getReal(l.toValue(int).v + r.toValue(real).v);}
            when (VT.R, VT.I) {return p.getReal(l.toValue(real).v + r.toValue(int).v);}
            when (VT.R, VT.R) {return p.getReal(l.toValue(real).v + r.toValue(real).v);}
            otherwise {throw new owned Error("POOL not implemented");}
        }
    }

    inline proc poolMul(l: BGenValue, r: BGenValue, ref p: pool): GenValue throws {
        select (l.vt, r.vt) {
            when (VT.I, VT.I) {return new Value(l.toValue(int).v * r.toValue(int).v);}
            when (VT.I, VT.R) {return p.getReal(l.toValue(int).v * r.toValue(real).v);}
            when (VT.R, VT.I) {return p.getReal(l.toValue(real).v * r.toValue(int).v);}
            when (VT.R, VT.R) {return p.getReal(l.toValue(real).v * r.toValue(real).v);}
            otherwise {throw new owned Error("POOL not implemented");}
        }
    }

    inline operator -(l: BGenValue, r: BGenValue): GenValue throws {
        select (l.vt, r.vt) {
            when (VT.I, VT.I) {return new Value(l.toValue(int).v - r.toValue(int).v);}
            when (VT.I, VT.R) {return new Value(l.toValue(int).v - r.toValue(real).v);}
            when (VT.R, VT.I) {return new Value(l.toValue(real).v - r.toValue(int).v);}
            when (VT.R, VT.R) {return new Value(l.toValue(real).v - r.toValue(real).v);}
            otherwise {throw new owned Error("not implemented");}
        }
    }

    inline operator *(l: BGenValue, r: BGenValue): GenValue throws {
        select (l.vt, r.vt) {
            when (VT.I, VT.I) {return new Value(l.toValue(int).v * r.toValue(int).v);}
            when (VT.I, VT.R) {return new Value(l.toValue(int).v * r.toValue(real).v);}
            when (VT.R, VT.I) {return new Value(l.toValue(real).v * r.toValue(int).v);}
            when (VT.R, VT.R) {return new Value(l.toValue(real).v * r.toValue(real).v);}
            otherwise {throw new owned Error("not implemented");}
        }
    }

    inline operator <(l: BGenValue, r: BGenValue): GenValue throws {
        select (l.vt, r.vt) {
            when (VT.I, VT.I) {return new Value((l.toValue(int).v < r.toValue(int).v):int);}
            when (VT.I, VT.R) {return new Value((l.toValue(int).v < r.toValue(real).v):int);}
            when (VT.R, VT.I) {return new Value((l.toValue(real).v < r.toValue(int).v):int);}
            when (VT.R, VT.R) {return new Value((l.toValue(real).v < r.toValue(real).v):int);}
            otherwise {throw new owned Error("not implemented");}
        }
    }

    inline operator >(l: BGenValue, r: BGenValue): GenValue throws {
        select (l.vt, r.vt) {
            when (VT.I, VT.I) {return new Value((l.toValue(int).v > r.toValue(int).v):int);}
            when (VT.I, VT.R) {return new Value((l.toValue(int).v > r.toValue(real).v):int);}
            when (VT.R, VT.I) {return new Value((l.toValue(real).v > r.toValue(int).v):int);}
            when (VT.R, VT.R) {return new Value((l.toValue(real).v > r.toValue(real).v):int);}
            otherwise {throw new owned Error("not implemented");}
        }
    }

    inline operator <=(l: BGenValue, r: BGenValue): GenValue throws {
        select (l.vt, r.vt) {
            when (VT.I, VT.I) {return new Value((l.toValue(int).v <= r.toValue(int).v):int);}
            when (VT.I, VT.R) {return new Value((l.toValue(int).v <= r.toValue(real).v):int);}
            when (VT.R, VT.I) {return new Value((l.toValue(real).v <= r.toValue(int).v):int);}
            when (VT.R, VT.R) {return new Value((l.toValue(real).v <= r.toValue(real).v):int);}
            otherwise {throw new owned Error("not implemented");}
        }
    }

    inline operator >=(l: BGenValue, r: BGenValue): GenValue throws {
        select (l.vt, r.vt) {
            when (VT.I, VT.I) {return new Value((l.toValue(int).v >= r.toValue(int).v):int);}
            when (VT.I, VT.R) {return new Value((l.toValue(int).v >= r.toValue(real).v):int);}
            when (VT.R, VT.I) {return new Value((l.toValue(real).v >= r.toValue(int).v):int);}
            when (VT.R, VT.R) {return new Value((l.toValue(real).v >= r.toValue(real).v):int);}
            otherwise {throw new owned Error("not implemented");}
        }
    }

    inline operator ==(l: BGenValue, r: BGenValue): GenValue throws {
        select (l.vt, r.vt) {
            when (VT.I, VT.I) {return new Value((l.toValue(int).v == r.toValue(int).v):int);}
            when (VT.I, VT.R) {return new Value((l.toValue(int).v == r.toValue(real).v):int);}
            when (VT.R, VT.I) {return new Value((l.toValue(real).v == r.toValue(int).v):int);}
            when (VT.R, VT.R) {return new Value((l.toValue(real).v == r.toValue(real).v):int);}
            otherwise {throw new owned Error("not implemented");}
        }
    }

    inline operator !=(l: BGenValue, r: BGenValue): GenValue throws {
        select (l.vt, r.vt) {
            when (VT.I, VT.I) {return new Value((l.toValue(int).v != r.toValue(int).v):int);}
            when (VT.I, VT.R) {return new Value((l.toValue(int).v != r.toValue(real).v):int);}
            when (VT.R, VT.I) {return new Value((l.toValue(real).v != r.toValue(int).v):int);}
            when (VT.R, VT.R) {return new Value((l.toValue(real).v != r.toValue(real).v):int);}
            otherwise {throw new owned Error("not implemented");}
        }
    }

    inline proc and(l: BGenValue, r: BGenValue): GenValue throws {
        return new Value((l && r):int);
    }

    inline proc or(l: BGenValue, r: BGenValue): GenValue throws {
        return new Value((l || r):int);
    }

    inline proc not(l: BGenValue): GenValue throws {
        return new Value((! isTrue(l)):int);
    }

    inline proc isTrue(gv: BGenValue): bool throws {
        select (gv.vt) {
            when (VT.I) {return (gv.toValue(int).v != 0);}
            when (VT.R) {return (gv.toValue(real).v != 0.0);}
            otherwise {throw new owned Error("not implemented");}
        }
    }
    
    /* environment is a dictionary of {string:GenValue} */
    class Env
    {
      var realTab: map(Symbol, Value(real));
      var intTab: map(Symbol, Value(int));

        // stores a single value per arr that is updated at
        // each index, rather than reallocating
      var realArrValTab: map(Symbol, Value(real));
      var intArrValTab: map(Symbol, Value(int));

        // Stores all sym entries
      var genSymRealTab: map(Symbol, borrowed SymEntry(real));
      var genSymIntTab: map(Symbol, borrowed SymEntry(int));

        proc init() {
          realTab = new map(Symbol, Value(real));
          intTab = new map(Symbol, Value(int));

          // stores a single value per arr that is updated at
          // each index, rather than reallocating
          realArrValTab = new map(Symbol, Value(real));
          intArrValTab = new map(Symbol, Value(int));

          // Stores all sym entries
          genSymRealTab = new map(Symbol, borrowed SymEntry(real));
          genSymIntTab = new map(Symbol, borrowed SymEntry(int));
        }
      
        proc init(e: Env) {
          realTab = new map(Symbol, Value(real));
          intTab = new map(Symbol, Value(int));

          // stores a single value per arr that is updated at
          // each index, rather than reallocating
          realArrValTab = new map(Symbol, Value(real));
          intArrValTab = new map(Symbol, Value(int));

          // Stores all sym entries
          genSymRealTab = new map(Symbol, borrowed SymEntry(real));
          genSymIntTab = new map(Symbol, borrowed SymEntry(int));
          
          for (name, val) in e.realTab.items() {
            realTab.addOrSet(name, new Value(val.v));
          }
          for name in e.realArrValTab.keys() {
            realArrValTab.addOrSet(name, new Value(-1.0));
          }

          for (name, val) in e.intTab.items() {
            intTab.addOrSet(name, new Value(val.v));
          }
          for name in e.intArrValTab.keys() {
            intArrValTab.addOrSet(name, new Value(-1));
          }
          // These can just be refs?
          genSymRealTab = e.genSymRealTab;
          genSymIntTab = e.genSymIntTab;
        }

        proc addReal(name: string, val) throws {
          realTab.addOrSet(name, val);
        }

        proc addInt(name: string, val) throws {
          intTab.addOrSet(name, val);
        }
      
        proc addRealArr(name: string, id: string,st) throws {
          var entry = st.lookup(id);
          genSymRealTab.addOrSet(name, toSymEntry(toGenSymEntry(entry), real));
          // allocate a placeholder value to update later
          realArrValTab.addOrSet(name, new Value(-1.0));
        }

        proc addIntArr(name: string, id: string,st) throws {
          var entry = st.lookup(id);
          genSymIntTab.addOrSet(name, toSymEntry(toGenSymEntry(entry), int));
          // allocate a placeholder value to update later
          intArrValTab.addOrSet(name, new Value(-1));
        }
      
        proc getVal(name: string, i: int) throws {
          if realTab.contains(name) then
            return realTab.getReference(name): GenValue;
          else if realArrValTab.contains(name) {
            // this is a real value from an array
            ref ea = genSymRealTab.getReference(name).a;
            ref val = realArrValTab.getReference(name);
            val.v = ea[i];
            return val: GenValue;
          } else if intTab.contains(name) then
              return intTab.getReference(name): GenValue;
          else if intArrValTab.contains(name) {
            // this is an int value from an array
            ref ea = genSymIntTab.getReference(name).a;
            ref val = intArrValTab.getReference(name);
            val.v = ea[i];
            return val: GenValue;
          }
          throw new owned Error(name + " not in environment");
        }

      proc deinit() {
        for name in realTab.keys() do
          delete realTab.getReference(name);
        for name in realArrValTab.keys() do
          delete realArrValTab.getReference(name);
        for name in intTab.keys() do
          delete intTab.getReference(name);
        for name in intArrValTab.keys() do
          delete intArrValTab.getReference(name);
      }
    }
    
    record pool {
      var freeRealList = new list(Value(real));
      var numElems = 0;
      var realCounter = 0;

      proc deinit() {
        forall val in freeRealList {
          delete val;
        }
      }

      proc freeAll() {
        realCounter = 0;
      }

      proc getReal(val: real) throws {
        if numElems - realCounter <= 0 {
          numElems+=1;
          realCounter+=1;
          return freeRealList[freeRealList.append(new Value(val))];
        }
        ref curr = freeRealList[realCounter];
        curr.v = val;
        realCounter+=1;
        return curr;
      }
    }
}
