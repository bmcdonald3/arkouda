module SymEntry4D {
  use MultiTypeSymEntry;
  use SymArrayDmap;

  class SymEntry4D : GenSymEntry {
    type etype;

    var m: int;
    var n: int;
    var p: int;
    var q: int;
    var aD: makeDistDom4D(m,n,p,q).type;
    var a: [aD] etype;

    proc init(m: int, n: int, p: int, q: int, type etype) {
      super.init(etype, (m*n*p*q));
      this.etype = etype;
      this.m = m;
      this.n = n;
      this.p = p;
      this.q = q;
      this.aD = makeDistDom4D(m, n, p, q);
      this.ndim = 4;
    }

    proc init(a: [?D] ?etype) {
      super.init(etype, a.size);
      this.etype = etype;
      this.m = D.high[0]+1;
      this.n = D.high[1]+1;
      this.p = D.high[2]+1;
      this.q = D.high[3]+1;
      this.aD = D;
      this.a = a;
      this.ndim = 4;
    }

    // TODO: not using threshold, how do we want to print large
    // 4D arrays?
    override proc __str__(thresh:int=6, prefix:string = "[", suffix:string = "]", baseFormat:string = "%t"): string throws {
      var s:string = "";

      for i in 0..#this.m {
        s += "[";
        for j in 0..#this.n {
          s += "[";
          for k in 0..#this.p {
            s += "[";
            for l in 0..#this.q {
              s += try! baseFormat.format(this.a[i, j, k, l]);
              if l != q-1 then
                s += ", ";
              else {
                s += "]";
                if k != p-1 then
                  s += ",\n         ";
                else if j == n-1 && i != m-1 then
                  s += "]],\n\n\n       ";
                else if j != n-1 then
                  s += "],\n\n        ";
                else
                  s += "]]"; 
              }
            }   
          }
        }
      }

      if (bool == this.etype) {
        s = s.replace("true","True");
        s = s.replace("false","False");
      }

      return prefix + s + suffix;
    }
  }

  proc toSymEntry4D(e, type etype) {
    return try! e :borrowed SymEntry4D(etype);
  }

  proc makeDistDom4D(m: int, n: int, p: int, q: int) {
    select MyDmap {
        when Dmap.defaultRectangular {
          return {0..#m, 0..#n, 0..#p, 0..#q};
        }
        when Dmap.blockDist {
          if m > 0 && n > 0 && p > 0 && q > 0 {
            return {0..#m, 0..#n, 0..#p, 0..#q} dmapped Block(boundingBox={0..#m, 0..#n, 0..#p, 0..#q});
          }
          // fix the annoyance about boundingBox being enpty
          else {return {0..#0, 0..#0, 0..#0, 0..#0} dmapped Block(boundingBox={0..0, 0..0, 0..0, 0..0});}
        }
        when Dmap.cyclicDist {
          return {0..#m, 0..#n, 0..#p, 0..#q} dmapped Cyclic(startIdx=0);
        }
        otherwise {
          halt("Unsupported distribution " + MyDmap:string);
        }
      }
  }

  proc makeDistArray4D(m: int, n: int, p: int, q: int, type etype) {
    var a: [makeDistDom4D(m, n, p, q)] etype;
    return a;
  }
}
