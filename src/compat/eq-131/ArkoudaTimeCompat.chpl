module ArkoudaTimeCompat {
  public use Time;

  proc createFromTimestampCompat(d) {
    return date.createFromTimestamp(d);
  }
}
