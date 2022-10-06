#!/usr/bin/env python3

import argparse
import time

import numpy as np

import arkouda as ak

OPS = ("sum")
AXES = (0, 1)
TYPES = ("int64", "float64")


def time_ak_partial_reduce(N_per_locale, trials, dtype, random):
    print(">>> arkouda {} reduce".format(dtype))
    cfg = ak.get_config()
    N = N_per_locale * cfg["numLocales"]
    print("numLocales = {}, N = {:,}".format(cfg["numLocales"], N))
    if dtype == "int64":
        a = ak.randint2D(1, N, N, N)
    elif dtype == "float64":
        a = ak.randint2D(1, N, N, N, dtype=ak.float64)

    timings = {axis: [] for axis in AXES}
    results = {}
    for i in range(trials):
        for axis in timings.keys():
            start = time.time()
            ak.sum(a,axis)
            end = time.time()
            timings[axis].append(end - start)
    tavg = {axis: sum(t) / trials for axis, t in timings.items()}

    for axis, t in tavg.items():
        print("  {} Average time = {:.4f} sec".format(axis, t))
        bytes_per_sec = (a.size * a.itemsize) / t
        print("  {} Average rate = {:.2f} GiB/sec".format(axis, bytes_per_sec / 2**30))
        

def create_parser():
    parser = argparse.ArgumentParser(description="Measure performance of reductions over arrays.")
    parser.add_argument("hostname", help="Hostname of arkouda server")
    parser.add_argument("port", type=int, help="Port of arkouda server")
    parser.add_argument(
        "-n", "--size", type=int, default=10**4, help="Problem size: length of array to reduce"
    )
    parser.add_argument(
        "-t", "--trials", type=int, default=6, help="Number of times to run the benchmark"
    )
    parser.add_argument(
        "-d", "--dtype", default="int64", help="Dtype of array ({})".format(", ".join(TYPES))
    )
    parser.add_argument(
        "-r",
        "--randomize",
        default=True,
        action="store_true",
        help="Fill array with random values instead of range",
    )
    parser.add_argument(
        "--numpy",
        default=False,
        action="store_true",
        help="Run the same operation in NumPy to compare performance.",
    )
    parser.add_argument(
        "--correctness-only",
        default=False,
        action="store_true",
        help="Only check correctness, not performance.",
    )
    parser.add_argument(
        "-s", "--seed", default=None, type=int, help="Value to initialize random number generator"
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

    if args.correctness_only:
        for dtype in TYPES:
            check_correctness(dtype, args.randomize, args.seed)
        sys.exit(0)

    print("array size = {:,}".format(args.size))
    print("number of trials = ", args.trials)
    time_ak_partial_reduce(args.size, args.trials, args.dtype, args.randomize)
    sys.exit(0)
