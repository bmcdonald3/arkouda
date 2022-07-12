module BmrkTest {
  use Diags, BlockDist;

  config const size = 100_000_000;
  config const trials = 250;

  proc main()  {
    var D = {0..#size} dmapped Block(boundingBox={0..#size});
    var diffs: [D] int = 1;
    var diffs2: [D] int = 1;
    var diffs3: [D] int = 1;
    var left: [D] int = 2;
    var right: [D] int = 3;
    
    for 1..trials {
      diags["slice operation"].startStop();
      {
        diffs[D.interior(D.size-1)] = left[D.interior(D.size-1)] - (right[D.interior(-(D.size-1))] - 1);
      }
      diags["slice operation"].startStop();

      diags["forall interior"].startStop();
      {
        forall idx in D.interior(D.size-1) {
          diffs2[idx] = left[idx] - (right[idx-1]-1);
        }
      }
      diags["forall interior"].startStop();

      diags["forall conditional"].startStop();
      {
        forall idx in D {
          if idx!=0 {
            diffs3[idx] = left[idx] - (right[idx-1]-1);
          }
        }
      }
      diags["forall conditional"].startStop();
    }
  }
}
