#!/usr/bin/env python3

import argparse
import os
import time
from glob import glob

import arkouda as ak

TYPES = (
    "int64",
)

def time_ak_write(N_per_locale, numcols, trials, dtype, path, seed, old=False):
    print(f">>> arkouda DF write with {numcols} columns using old code: {old}")
    cfg = ak.get_config()
    N = N_per_locale * cfg["numLocales"]
    print("numLocales = {}, N = {:,}, numcols = {}".format(cfg["numLocales"], N, numcols))

    cols = []

    for i in range(numcols):
        cols.append(ak.randint(0, 2**32, N, seed=seed))

    data = {}
    name = 1
    for col in cols:
        data[str(name)] = col
        name += 1
    df = ak.DataFrame(data)

    writetimes = []
    for i in range(trials):
        start = time.time()
        df.to_parquet(path, old=old)
        end = time.time()
        writetimes.append(end - start)
    avgwrite = sum(writetimes) / trials

    print("write Average time = {:.4f} sec".format(avgwrite))

    nb = df.size * 8
    print("write Average rate = {:.2f} GiB/sec".format(nb / 2**30 / avgwrite))

def remove_files(path):
    for f in glob(path + "*"):
        os.remove(f)

def create_parser():
    parser = argparse.ArgumentParser(
        description="Measure performance of writing and reading a random array from disk."
    )
    parser.add_argument("hostname", help="Hostname of arkouda server")
    parser.add_argument("port", type=int, help="Port of arkouda server")
    parser.add_argument(
        "-n", "--size", type=int, default=10**6, help="Problem size: length of array to write/read"
    )
    parser.add_argument(
        "-t", "--trials", type=int, default=1, help="Number of times to run the benchmark"
    )
    parser.add_argument(
        "-c", "--numcols", type=int, default=5, help="Number of columns to write to file"
    )
    parser.add_argument(
        "-d", "--dtype", default="int64", help="Dtype of array ({})".format(", ".join(TYPES))
    )
    parser.add_argument(
        "-p",
        "--path",
        default=os.getcwd() + "ak-io-test",
        help="Target path for measuring read/write rates",
    )
    parser.add_argument(
        "--correctness-only",
        default=False,
        action="store_true",
        help="Only check correctness, not performance.",
    )
    parser.add_argument(
        "--oldcode",
        default=False,
        action="store_true",
        help="Run with old append code or new multi column write",
    )
    parser.add_argument(
        "-s", "--seed", default=None, type=int, help="Value to initialize random number generator"
    )
    parser.add_argument(
        "-w",
        "--only-write",
        default=False,
        action="store_true",
        help="Only write the files; files will not be removed",
    )
    parser.add_argument(
        "-f",
        "--only-delete",
        default=False,
        action="store_true",
        help="Only delete files created from writing with this benchmark",
    )
    return parser


if __name__ == "__main__":
    import sys

    parser = create_parser()
    args = parser.parse_args()
    if args.dtype not in TYPES:
        raise ValueError("Dtype must be {}, not {}".format("/".join(TYPES), args.dtype))
    ak.verbose = False
    ak.connect(args.hostname, args.port)

    print("array size = {:,}".format(args.size))
    print("number of trials = ", args.trials)

    time_ak_write(
        args.size,
        args.numcols,
        args.trials,
        args.dtype,
        args.path,
        args.seed,
        args.oldcode,
    )
    remove_files(args.path)

    sys.exit(0)
