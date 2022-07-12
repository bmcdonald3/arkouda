use BlockDist;
use Time;

config param size = 100;

var domCreateT: Timer;
var arrCreateT: Timer;
var sliceT: Timer;

domCreateT.start();
var D = {0..#size} dmapped Block(boundingBox={0..#size});
domCreateT.stop();

arrCreateT.start();
var diffs: [D] int = 1;
var left: [D] int = 2;
var right: [D] int = 3;
arrCreateT.stop();

sliceT.start();
diffs[D.interior(D.size-1)] = left[D.interior(D.size-1)] - (right[D.interior(-(D.size-1))] - 1);
sliceT.stop();

writeln("Domain creation        : ", domCreateT.elapsed());
writeln("Array creation         : ", arrCreateT.elapsed());
writeln("Slice operation        : ", sliceT.elapsed());
