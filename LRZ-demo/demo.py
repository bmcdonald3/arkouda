import argparse
import numpy as np
import arkouda as ak

def build_df(columns):

    return ak.DataFrame(d)

def create_parser():
    parser = argparse.ArgumentParser(
        description="Measure performance of sorting an array of random values."
    )
    parser.add_argument("hostname", help="Hostname of arkouda server")
    parser.add_argument("port", type=int, help="Port of arkouda server")
    parser.add_argument("size", type=int, help="Size of problem to run")
    return parser

if __name__ == "__main__":
    import sys

    parser = create_parser()
    args = parser.parse_args()

    # connect to Arkouda server
    ak.connect(args.hostname, args.port)

    # create random pdarrays
    # "pdarray" = parallel, distributed array
    # this is Arkouda's array type
    a = ak.randint(0,10,args.size)
    b = ak.randint(0,2**32,args.size)

    # sort array and print first 10 elements
    c = ak.sort(a)
    print(a[0:10])

    # write array to Parquet file and read it back in
    # CSV and HDF5 also supported
    # TODO: writes locale per file
    a.to_parquet('test-file')
    d = ak.read('test-file*')
    print(c[0:10])

    cols = {}
    for (i,col) in enumerate([a,b,c]):
        cols[str(i)] = col
        akdf = ak.DataFrame(cols)

    gb = akdf.GroupBy("1")
    keys, count = gb.count()
    print("Unique keys: ", keys)
    print("Count: ", count)

    argsort_res = akdf.argsort(key="1")
    print(argsort_res)

    # downselect data
    # convert a slice of 100 elements to a numpy array
    nparr = akdf['1'][0:100].to_ndarray()
    print(nparr)
