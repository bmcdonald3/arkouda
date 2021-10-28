module ArrowInclude {
  use SysCTypes, CPtr, Time;
  require "ArrowFunctions.h";
  require "ArrowFunctions.o";

  const ROWGROUPS = 512*1024*128; // 512 mb of int64
  
  extern proc c_getSize(chpl_str): int;
  extern proc c_readColumnByName(filename, chpl_arr, colNum, numElems);
  extern proc c_getType(filename, colname): c_string;
  extern proc c_writeColumnToParquet(filename, chpl_arr, colnum,
                                     dsetname, numelems, rowGroupSize);
  extern proc c_getVersionInfo(): c_string;

  proc getVersionInfo() {
    extern proc strlen(str): c_int;
    var cVersionString = c_getVersionInfo();
    var ret;
    try! ret = createStringWithNewBuffer(cVersionString,
                                         strlen(cVersionString));
    return ret;
  }
  
  proc getSubdomains(lengths: [?FD] int) {
    var subdoms: [FD] domain(1);
    var offset = 0;
    for i in FD {
      subdoms[i] = {offset..#lengths[i]};
      offset += lengths[i];
    }
    return (subdoms, (+ reduce lengths));
  }

  proc domain_intersection(d1: domain(1), d2: domain(1)) {
    var low = max(d1.low, d2.low);
    var high = min(d1.high, d2.high);
    if (d1.stride !=1) && (d2.stride != 1) {
      //TODO: change this to throw
      halt("At least one domain must have stride 1");
    }
    var stride = max(d1.stride, d2.stride);
    return {low..high by stride};
  }
  
  proc readFilesByName(A, filenames: [] string, sizes: [] int, dsetname: string) {
    var (subdoms, length) = getSubdomains(sizes);

    coforall loc in A.targetLocales() do on loc {
      var locFiles = filenames;
      var locFiledoms = subdoms;
      forall (filedom, filename) in zip(locFiledoms, locFiles) {
        for locdom in A.localSubdomains() {
          const intersection = domain_intersection(locdom, filedom);
          if intersection.size > 0 {
            var col: [filedom] int;
            c_readColumnByName(filename.c_str(), c_ptrTo(col), dsetname.c_str(), filedom.size);
            A[filedom] = col;
          }
        }
      }
    }
  }

  proc getArrSize(filename: string) {
    var size = c_getSize(filename.c_str());
    return size;
  }

  proc getArrType(filename: string, colname: string) {
    extern proc strlen(str): c_int;
    var arrType = c_getType(filename.c_str(), colname.c_str());
    var ret;
    try! ret = createStringWithNewBuffer(arrType,
                                         strlen(arrType));
    var asd;
    try! asd = createStringWithNewBuffer(arrType, 5);
    writeln(asd);
    
    return ret;
  }
  
  proc getArrSizeAndType(filenames: [?D] string) {
    extern proc strlen(str): c_int;
    var sizes: [D] int;
    var ty: string = "int64";
    for i in D {
      sizes[i] = c_getSize(filenames[i].c_str());
    }
    return (sizes, ty);
  }

  proc writeDistArrayToParquet(A, filename, dsetname, rowGroupSize) {
    var filenames: [0..#A.targetLocales().size] string;
    for i in 0..#A.targetLocales().size {
      var suffix = i: string;
      filenames[i] = filename + "_LOCALE" + suffix + ".parquet";
    }

    coforall (loc, idx) in zip(A.targetLocales(), filenames.domain) do on loc {
        const myFilename = filenames[idx];

        var locDom = A.localSubdomain();
        var locArr = A[locDom];
        c_writeColumnToParquet(myFilename.c_str(), c_ptrTo(locArr), 0, dsetname.c_str(), locDom.size, rowGroupSize);
      }
  }

  proc write1DDistArrayParquet(filename: string, dsetname, A) throws {
    var prefix = filename;
    var extension = ".parquet";
    writeDistArrayToParquet(A, filename, dsetname, ROWGROUPS);
    return false;
  }
}
