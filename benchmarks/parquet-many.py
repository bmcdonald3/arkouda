import time, argparse, random
import arkouda as ak
import os
from glob import glob
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
import numpy as np

TYPES = ('int64')

def create_file(filename, size):
    df = pd.DataFrame(np.random.randint(0,2**32,size=(size, 1)), columns=['int-col'])
    table = pa.Table.from_pandas(df)

    pq.write_table(table, filename+'.parquet')

def time_ak_read(N_per_locale, trials, dtype, numfiles, seed):
    print(">>> arkouda parquet {} read".format(dtype))
    cfg = ak.get_config()
    N = N_per_locale * cfg["numLocales"]
    print("numLocales = {}, N = {:,}".format(cfg["numLocales"], N))
    a = ak.randint(0, 2**32, N)

    filenames = []
    # build filenames list
    for i in range(numfiles):
        filenames.append('file'+str(i)+'.parquet')
    
    readtimes = []
    for i in range(trials):
        start = time.time()
        a = ak.read_parquet(filenames, 'int-col')
        end = time.time()
        readtimes.append(end - start)
    for f in glob('*.parquet'):
        os.remove(f)
    avgread = sum(readtimes) / trials

    print("read Average time = {:.4f} sec".format(avgread))

    nb = a.size * a.itemsize
    print("read Average rate = {:.2f} GiB/sec".format(nb/2**30/avgread))

def create_parser():
    parser = argparse.ArgumentParser(description="Measure performance of writing and reading a random array from disk.")
    parser.add_argument('hostname', help='Hostname of arkouda server')
    parser.add_argument('port', type=int, help='Port of arkouda server')
    parser.add_argument('-n', '--size', type=int, default=10**8, help='Problem size: length of array to write/read')
    parser.add_argument('-f', '--numfiles', type=int, default=100, help='Problem size: length of array to write/read')
    parser.add_argument('-t', '--trials', type=int, default=1, help='Number of times to run the benchmark')
    parser.add_argument('-d', '--dtype', default='int64', help='Dtype of array ({})'.format(', '.join(TYPES)))
    parser.add_argument('--correctness-only', default=False, action='store_true', help='Only check correctness, not performance.')
    parser.add_argument('-s', '--seed', default=None, type=int, help='Value to initialize random number generator')
    return parser

if __name__ == "__main__":
    import sys
    parser = create_parser()
    args = parser.parse_args()
    if args.dtype not in TYPES:
        raise ValueError("Dtype must be {}, not {}".format('/'.join(TYPES), args.dtype))
    ak.verbose = False
    ak.connect(args.hostname, args.port)
    
    totalsize = 0
    # create files
    for i in range(args.numfiles):
        numelems = int(random.random()*args.size)
        totalsize += numelems
        create_file('file'+str(i), numelems)

    print(f"array size = {totalsize}")
    print("number of trials = ", args.trials)

    time_ak_read(args.size, args.trials, args.dtype, args.numfiles, args.seed)

    sys.exit(0)
