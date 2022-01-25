import arkouda as ak
import time
ak.connect()

start = time.time()
#ak.read_parquet("test-file*")
ak.read_all("hdf-test-file*")
stop = time.time()
print("took {:.4f}".format(stop-start))
