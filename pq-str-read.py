import arkouda as ak
import time
ak.connect()

SIZE = 10000

a = ak.random_strings_uniform(2,3,SIZE)
a.to_parquet('test-file')

start = time.time()
ak.read('test-file*')
stop = time.time()
print('read took             : ', stop-start)

start = time.time()
ak.read('test-file*', fixed_len=2)
stop = time.time()
print('fixed length read took : ', stop-start)
