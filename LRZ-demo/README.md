## Arkouda LRZ Demo

### Running and connecting to an Arkouda server
- Arkouda server can be launched by running the Arkouda server executable
  - `./arkouda_server -nl 2` - launches server on 2 nodes using machines job scheduler (e.g., slurm)
    - can see full launch command with `--verbose` flag: `./arkouda_server -nl 2 --verbose`
    - slurm systems can pass regular slurm flags as well (e.g., `--nodelist`, `--exclude`, etc.)
- Once Arkouda server is launcher, it will print out hostname and port for client to connect to
  - default port can be overridden with `--ServerPort` argument
- To connect to server, from Python client, run `ak.connect(hostname, port)`


### Connect to an Arkouda server
```python3
import arkouda as ak
ak.connect(<hostname>, <port>)
```
- With an Arkouda server running, connect to the server in your python client using the hostname and port displayed:

### Generate some random arrays
```python3
a = ak.randint(0,2**32,2**10)
b = ak.randint(0,2**32,2**10)
```
- create a "pdarray", which is Arkouda's standard array, "pd" stands for parallel-distributed
- "pdarray"s are stored on the Arkouda server side (in the Chapel code) with the Python client holding onto a reference to that server-side data
- since the data is stored on the server, it is able to use Chapel's parallel and distributed features
- in the real world, you would likely be reading in a huge dataset from a file, rather than generating random data

### Sort the array and print the first 10 elements to confirm:
```python3
ak.sort(a)
a[0:10]
```
- the Arkouda library call `ak.sort` sends a message to the server to sort the data on the server side
- the server sends a response message to indicate completion, but the data still only lives on the server side and all computation is done with the Chapel server

### Write the results to Parquet and read it back in
```python3
a.to_parquet('test-file')
c = ak.read('test-file*')
print(c[0:10])
```
- writing files in Arkouda writes one file per locale, each file containing the elements owned by that locale
- each file has the locale number appended to the end (i.e., `test-file_LOCALE0000` and `test-file_LOCALE0001` for 2 locales)
- this means when we do the `read` call, we have to use a wildcard to read all the files
- CSV and HDF5 are also supported

### Create a DataFrame
```python3
d = {}
for (i,col) in enumerate([a, b, c]):
    d[str(i)] = col
akdf = ak.DataFrame(d)
```
- column names are `"1"`, `"2"`, `"3"`

### GroupBy on DataFrame
```python3
gb = akdf.GroupBy("1")
keys, count = gb.count()
print("Unique keys: ", keys)
print("Count: ", count)
```

### sorting and other operations are supported on DataFrames
```python3
argsort_res = akdf.argsort(key="1")
print(argsort_res)
```

### Downselect a portion of the array and convert it to `ndarray`
```python3
nparr = akdf['1'][0:100].to_ndarray()
print(nparr)
```
- `to_ndarray()` transfers data back to client to do whatever you'd like with it
- large arrays should not be transferred back to client due to only have a single nodes memory

### Notes for building Arkouda
1. Install Chapel
2. Clone Arkouda
3. `python3 -m pip install -e .` - install Arkouda Python dependencies
4. `conda env create -f arkouda-env.yml && conda activate arkouda` - install Arkouda C dependencies
    - if no access to conda, can also be installed via `Makefile` commands
5. `make` from Arkouda directory - build Arkouda
6. [optional] `make test` - run unit tests; ensure that everything built correctly
