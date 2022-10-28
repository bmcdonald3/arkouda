module EncodingMsg {
    use Subprocess;
    use Reflection;
    use Logging;
    use ServerConfig;
    use Message;
    use MultiTypeSymbolTable;
    use MultiTypeSymEntry;
    use CommAggregation;
    use ServerErrors;
    use ServerErrorStrings;
    use Codecs;

    use SegmentedString;

    private config const logLevel = ServerConfig.logLevel;
    const emLogger = new Logger(logLevel);

    proc encodeDecodeMsg(cmd: string, payload: string, argSize: int, st: borrowed SymTab): MsgTuple throws {
      var repMsg: string;
      var msgArgs = parseMessageArgs(payload, argSize);
      var encoding = msgArgs.getValueOf("encoding");

      var stringsObj = getSegString(msgArgs.getValueOf("obj"), st);

      try {
        var (offsets, vals) = encodeDecode(stringsObj, cmd, encoding);
        var encodedStrings = getSegString(offsets, vals, st);
        repMsg = "created " + st.attrib(encodedStrings.name) + "+created bytes.size %t".format(encodedStrings.nBytes);

        emLogger.debug(getModuleName(), getRoutineName(), getLineNumber(), repMsg);
        return new MsgTuple(repMsg, MsgType.NORMAL);
      } catch e: TaskErrors {
        for err in e do
          throw err;
      } catch e {
        throw e;
      }
      return new MsgTuple("error", MsgType.ERROR);
    }
    
    proc encodeDecode(stringsObj, cmd: string, encoding: string) throws {
      ref origVals = stringsObj.values.a;
      ref offs = stringsObj.offsets.a;
      // TODO: creating entire local rectangular of full size won't work for big arrays
      //       we should be able to just serialize a slice based off where we find the
      //       null index and keep everything distributed
      var encodeArr: [0..#stringsObj.size] string;

      // TODO: we only need one of these, they hold same info
      var encodeOffsets: [stringsObj.offsets.aD] int;
      var encodeLengths: [stringsObj.offsets.aD] int;

      const lengths = stringsObj.getLengths();

      var encodingUpper = encoding.toUpper();

      var encodeOrDecode = if cmd == "encode" then encodeStr else decodeStr;

      // this loop throwing a `TaskErrors` that can't be caught.
      // if explicitly wrapped, it won't error, but it will not execute
      // the code in the try/catch. if ignored, it will crash the server
      // and say uncaught task errors, even though it goes through 2
      // layers of `catch`ing in other functions (where the global try/catch
      // in `ServerDaemon.chpl` should catch all errors).
      
      //try {
      forall (i, off, len) in zip(0..#stringsObj.size, offs, lengths) {
        var str_entry: string = interpretAsString(origVals, off..#len);
        var encodedStr = encodeOrDecode(str_entry, encodingUpper);
        encodeArr[i] = encodedStr;
      }
      // catch e:TaskErrors { for err in e do throw err; }
      
      // calculate offsets and lengths
      encodeLengths = [e in encodeArr] e.numBytes;
      encodeOffsets = (+ scan encodeLengths) - encodeLengths + [i in 0..<encodeLengths.size] i;
      
      //calculate values for the segmentedstring
      var finalValues = makeDistArray((+ reduce encodeLengths)+encodeLengths.size, uint(8));
      forall (s, o) in zip(encodeArr, encodeOffsets) with (var agg = newDstAggregator(uint(8))) {
        for (j, c) in zip(0.., s.chpl_bytes()) {
          agg.copy(finalValues[j+o], c);
        }
      }
      return (encodeOffsets, finalValues);
    }

    use CommandMap;
    registerFunction("encode", encodeDecodeMsg, getModuleName());
    registerFunction("decode", encodeDecodeMsg, getModuleName());
}