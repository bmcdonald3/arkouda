import sys
import arkouda as ak

ak.connect(server=sys.argv[1], port=sys.argv[2])

a = ak.randint(0, 2**32, 2**27)
for i in range(128):
    a.save_parquet("/lus/scratch/flash/mcdonald/parquet/test-file"+str(i))
    a.save(        "/lus/scratch/flash/mcdonald/hdf5/test-file"+str(i))
