module ArkoudaMapCompat {
  use Map;

  proc map.this(k:keyType, compat:bool) {
    return getBorrowed(k);
  }
}