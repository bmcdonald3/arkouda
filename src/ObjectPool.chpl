module ObjectPool {
  use LisExprData;
  use Time;
  
  record pool {
    var freeRealList: [0..6] unmanaged ValueClass(real) = new unmanaged ValueClass(0.0);
    var realCounter = 0;
    var t: Timer;
    
    proc deinit() {
      forall val in freeRealList {
        delete val;
      }
    }

    proc freeAll() {
      realCounter = 0;
    }

    // TODO: figure out how to efficiently set the value
    // when popping
    proc getReal(val: real) throws {
      t.start();
      ref curr = freeRealList[realCounter];
      curr.v = val;
      realCounter+=1;
      t.stop();
      return curr;
    }
  }
}
