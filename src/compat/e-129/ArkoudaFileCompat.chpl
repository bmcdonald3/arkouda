module ArkoudaFileCompat {
  use IO;
  enum ioMode {
    r = 1,
    cw = 2,
    rw = 3,
    cwr = 4,
  }

  proc openMemFile() throws {
    return openmem();
  }
}
