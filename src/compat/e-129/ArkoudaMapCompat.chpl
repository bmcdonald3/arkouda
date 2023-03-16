module ArkoudaMapCompat {
  import Map.map as chapelMap;
  import IO.fileWriter;

  record map {
    type keyType;
    type valType;
    forwarding var m: chapelMap(keyType, valType);

    proc init(type keyType, type valType) {
      this.keyType = keyType;
      this.valType = valType;
      m = new chapelMap(keyType, valType);
    }

    proc this(k) where isClass(valType) {
      return m.getBorrowed(k);
    }

    proc const writeThis(ch: fileWriter) throws {
      m.writeThis(ch);
    }
  }
}
