import arkouda as ak
ak.connect()
a = ak.randint(0,2**32,10_000_000);
filename = "hdf-test-file"
for i in range(100):
    #a.save_parquet(filename+str(i))
    a.save(filename+str(i))
