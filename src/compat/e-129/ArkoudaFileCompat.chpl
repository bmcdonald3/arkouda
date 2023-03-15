module ArkoudaFileCompat {
  import IO.{openmem, iomode};
  import IO.open as fileOpen;
  enum ioMode {
    r = 1,
    cw = 2,
    rw = 3,
    cwr = 4,
  }

  proc openMemFile() throws {
    return openmem();
  }

  proc open(path: string, mode: ioMode) {
    var oldMode: iomode;
    select mode {
      when ioMode.r {
        oldMode = iomode.r;
      }
      when ioMode.cw {
        oldMode = iomode.cw;
      }
      when ioMode.rw {
        oldMode = iomode.rw;
      }
      when ioMode.cwr {
        oldMode = iomode.cwr;
      }
    }
    return fileOpen(path, oldMode);
  }
}
