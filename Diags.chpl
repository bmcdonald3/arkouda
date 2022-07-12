module Diags {
  use List, Time, IO, CommDiagnostics;

  config const printDiags = false;
  config const printTime = true;

  record orderedMap {
    type keyT, valueT;
    var keys: list(keyT);
    var vals: list(valueT);

    proc this(k: keyT) ref {
      if !keys.contains(k) {
        keys.append(k);
        var defValue: valueT;
        vals.append(defValue);
      }
      return vals[keys.find(k)];
    }
    iter items() {
      for (k, v) in zip(keys, vals) do yield (k, v);
    }
  }

  record Diags {
    var t: Timer;
    var d: [LocaleSpace] commDiagnostics;

    proc startStop() {
      if t.running {
        t.stop();
        if printDiags {
          stopCommDiagnostics();
          d = getCommDiagnostics();
          // TODO, append not override
        }
      } else {
        t.start();
        if printDiags {
          resetCommDiagnostics();
          startCommDiagnostics();
        }
      }
    }
  }

  var diags: orderedMap(string, Diags);
  proc deinit()  {
    const maxLen = max reduce for k in diags.keys do k.size;
    for (k, v) in diags.items() {
      try! writeln("%s %s: %.2drs".format(k, " "*(maxLen-k.size), v.t.elapsed()));
      // TODO summery
      if printDiags { writeln(v.d); }
    }
  }
}
