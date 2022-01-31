use TestBase;
use GenSymIO;
use HDF5Msg;
use ParquetMsg;

config const size = 10**4;
config const write = true;
config const read = true;
config const hdf = true;

proc parseIdFromReadAllHdfMsgCreated(msg:string, start:int = 0):string {
  const marker = "created id_";
  var p:int = msg.find(marker, start..<msg.size):int;
  if p > -1 {
    p = p + marker.size;
    var q:int = msg.find(" ", p..<msg.size):int;
    if q > -1 {
      return "id_" + msg.this(p..q-1); // our id number should be [p..q-1]
    }
  }
  return "ERROR";
}

proc main() {
  var st = new owned SymTab();
  var A = st.addEntry("A", size*numLocales, int);
  A.a = A.aD;
  const GiB = (8*A.aD.size):real / (2**30):real;

  var d: Diags;

  if write {
    d.start();
    
    if hdf {
      var cmd = "tohdf";
      var payload = "A array 0 [\"file\"] int64";
      tohdfMsg(cmd, payload, st);
    }
    else {
      var cmd = "writeParquet";
      var payload = "A array [\"pq-file\"] int64";
      toparquetMsg(cmd, payload, st);
    }
    d.stop(printTime=false);
    if printTimes then writeln("write: %.2dr GiB/s (%.2drs)".format(GiB/d.elapsed(), d.elapsed()));
  }

  if read {
    d.start();
    var repMsg: string;
    if hdf {
      var cmd = "readAllHdf";
      var payload = "True 1 1 False False [\"array\"] | [\"file_LOCALE*\"]";
      repMsg = readAllHdfMsg(cmd, payload, st).msg;
    } else {
      var cmd = "readAllParquet";
      var payload = "True 1 1 False [\"array\"] | [\"pq-file_LOCALE*\"]";
      readAllParquetMsg(cmd, payload, st).msg;
    }
    //var id = parseIdFromReadAllHdfMsgCreated(repMsg);
    //var B = toSymEntry(toGenSymEntry(st.lookup(id)), int);
    d.stop(printTime=false);
    if printTimes then writeln("read: %.2dr GiB/s (%.2drs)".format(GiB/d.elapsed(), d.elapsed()));
    //forall (a, b) in zip (A.a, B.a) do assert(a == b);
  }
}
