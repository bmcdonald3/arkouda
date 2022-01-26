import time, sys
import arkouda as ak

ak.connect(server=sys.argv[1], port=sys.argv[2])

start = time.time()
if 'parquet' in sys.argv:
    filename = "/lus/scratch/flash/mcdonald/parquet/test-file*"
    ak.read_parquet(filename)
else:
    filename = "/lus/scratch/flash/mcdonald/hdf5/test-file*"
    ak.read_all(filename)
stop = time.time()
print("took {:.1f}".format(stop-start))
