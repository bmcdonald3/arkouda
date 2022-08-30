module ObjectPool {
  use LisExprData;
  
  record pool {
    var freeRealList: [0..6] unmanaged ValueClass(real) = [0..6] new unmanaged ValueClass(0.0);
    var realCounter = 0;

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
      ref curr = freeRealList[realCounter];
      curr.v = val;
      realCounter+=1;
      return curr;
    }
  }
}
