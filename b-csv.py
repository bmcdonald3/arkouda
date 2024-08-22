import arkouda as ak
import pandas as pd
import time
ak.connect()
a = ak.randint(0,10,100_000_00)

a.to_csv('asd.csv')

start = time.time()
ak.read('asd_LOCALE0000.csv')
stop = time.time()
print("Arkouda took: ", stop-start)

start = time.time()
pd.read_csv('asd_LOCALE0000.csv')
stop = time.time()
print("Pandas took: ", stop-start)
