use BlockDist;
use CTypes;

require "ArrowFunctions.h";
require "ArrowFunctions.o";

proc getSubdomains(lengths: [?FD] int) {
  var subdoms: [FD] domain(1);
  var offset = 0;
  for i in FD {
    subdoms[i] = {offset..#lengths[i]};
    offset += lengths[i];
  }
  return (subdoms, (+ reduce lengths));
}

record parquetErrorMsg {
  var errMsg: c_ptr(uint(8));
  proc init() {
    errMsg = nil;
  }
    
  proc deinit() {
    extern proc c_free_string(ptr);
    c_free_string(errMsg);
  }
}

proc getStrColSize(filename: string, dsetname: string, ref offsets: [] int) throws {
  extern proc c_getStringColumnNumBytes(filename, colname, offsets, numElems, startIdx, batchSize, errMsg): int;
  var pqErr = new parquetErrorMsg();

  var byteSize = c_getStringColumnNumBytes(filename.localize().c_str(),
                                           dsetname.localize().c_str(),
                                           c_ptrTo(offsets),
                                           offsets.size, 0, 256,
                                           c_ptrTo(pqErr.errMsg));
  return byteSize;
}

proc calcStrSizesAndOffset(offsets: [] ?t, filenames: [] string, sizes: [] int, dsetname: string) throws {
  var (subdoms, length) = getSubdomains(sizes);

  var byteSizes: [filenames.domain] int;

  coforall loc in offsets.targetLocales() with (ref byteSizes) do on loc {
      var locFiles = filenames;
      var locFiledoms = subdoms;
      
      forall (i, filedom, filename) in zip(sizes.domain, locFiledoms, locFiles) {
        for locdom in offsets.localSubdomains() {
          const intersection = domain_intersection(locdom, filedom);
          if intersection.size > 0 {
            var col: [filedom] t;
            byteSizes[i] = getStrColSize(filename, dsetname, col);
            offsets[filedom] = col;
          }
        }
      }
    }
  return byteSizes;
}

proc domain_intersection(d1: domain(1), d2: domain(1)) {
  var low = max(d1.low, d2.low);
  var high = min(d1.high, d2.high);
  if (d1.stride !=1) && (d2.stride != 1) {
    //TODO: change this to throw
    halt("At least one domain must have stride 1");
  }
  if d1.strides==strideKind.one && d2.strides==strideKind.one {
    return {low..high};
  } else {
    var stride = max(d1.stride, d2.stride);
    return {low..high by stride};
  }
}

proc readStrFilesByName(A: [] ?t, filenames: [] string, sizes: [] int, dsetname: string) throws {
  extern proc c_readColumnByName(filename, arr_chpl, colNum, numElems, startIdx, batchSize, byteLength, errMsg): int;
  var (subdoms, length) = getSubdomains(sizes);
    
  coforall loc in A.targetLocales() do on loc {
      var locFiles = filenames;
      var locFiledoms = subdoms;

      forall (filedom, filename) in zip(locFiledoms, locFiles) {
        for locdom in A.localSubdomains() {
          const intersection = domain_intersection(locdom, filedom);

          if intersection.size > 0 {
            var pqErr = new parquetErrorMsg();
            var col: [filedom] t;

            c_readColumnByName(filename.localize().c_str(), c_ptrTo(col),
                               dsetname.localize().c_str(), intersection.size, 0,
                               8192, -1, c_ptrTo(pqErr.errMsg));
            A[filedom] = col;
          }
        }
      }
    }
}

proc main() {
  var filenames: [0..#1] string = "test_file_LOCALE0000";
  var segs = blockDist.createArray(0..10, int);
  var sizes: [filenames.domain] int = 10;
  var dsetname = "strings_array";
  var byteSizes = calcStrSizesAndOffset(segs, filenames, sizes, dsetname);
  writeln(byteSizes);

  segs = (+ scan segs) - segs;

  var vals = blockDist.createArray(0..#(+ reduce byteSizes), uint(8));
  readStrFilesByName(vals, filenames, byteSizes, dsetname);
  writeln(vals);
}
