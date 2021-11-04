require '../src/ArrowInclude.chpl';
use ArrowInclude, SysCTypes, CPtr, FileSystem;

proc testReadWrite(filename: c_string, dsetname: c_string, size: int) {
  var a: [0..#size] int;
  for i in 0..#size do a[i] = i;
  c_writeColumnToParquet(filename, c_ptrTo(a), 0, dsetname, size, 10000);

  var b: [0..#size] int;
  
  c_readColumnByName(filename, c_ptrTo(b), dsetname, size);
  if a.equals(b) {
    writeln("Finished writing");
    writeln("Finished reading");
    return 0;
  } else {
    writeln("FAILED: read/write");
    return 1;
  }
}

proc testGetNumRows(filename: c_string, expectedSize: int) {
  var size = c_getNumRows(filename);
  if size == expectedSize {
    writeln("Finished getting number of rows");
    return 0;
  } else {
    writeln("FAILED: c_getNumRows");
    return 1;
  }
}

proc testGetType(filename: c_string, dsetname: c_string) {
  var arrowType = c_getType(filename, dsetname);

  // a positive value corresponds to an arrow type
  // -1 corresponds to unsupported type
  if arrowType >= 0 {
    writeln("Finished getting type");
    return 0;
  } else {
    writeln("FAILED: c_getType with ", arrowType);
    return 1;
  }
}

proc testVersionInfo() {
  extern proc strlen(str): c_int;
  var cVersionString = c_getVersionInfo();
  var ret;
  try! ret = createStringWithNewBuffer(cVersionString,
                                       strlen(cVersionString));
  if ret[0]: int >= 5 {
    writeln("Finished getting version info");
    return 0;
  } else {
    writeln("FAILED: c_getVersionInfo");
    return 1;
  }
}
proc main() {
  var errors = 0;

  const size = 1000;
  const filename = "myFile.parquet".c_str();
  const dsetname = "my-dset-name-test".c_str();
  
  errors += testReadWrite(filename, dsetname, size);
  errors += testGetNumRows(filename, size);
  errors += testGetType(filename, dsetname);
  errors += testVersionInfo();

  if errors == 0 then
    writeln("All C/C++ Parquet tests passed");
  else 
    writeln(errors, " Parquet tests failed");

  remove("myFile.parquet");
}
