#!/usr/bin/env python3

import argparse
import time

import numpy as np

import arkouda as ak

TYPES = ("string")
ENCODINGS = ("idna", "ascii")

def time_ak_encode(N_per_locale, trials, seed):
    print(">>> arkouda string encode")
    cfg = ak.get_config()
    N = N_per_locale * cfg["numLocales"]
    print("numLocales = {}, N = {:,}".format(cfg["numLocales"], N))
    a = ak.random_strings_uniform(1, 16, N, seed=seed)
    nbytes = a.nbytes * a.entry.itemsize

    for encoding in ENCODINGS:
        timings = []
        for i in range(trials):
            start = time.time()
            perm = a.encode('idna')
            end = time.time()
            timings.append(end - start)
        tavg = sum(timings) / trials
        print("Average {} encode time = {:.4f} sec".format(encoding, tavg))
        bytes_per_sec = nbytes / tavg
        print("Average {} encode rate = {:.4f} GiB/sec".format(encoding, bytes_per_sec / 2**30))

def check_correctness(dtype, seed):
    N = 10**2
    a = ak.random_strings_uniform(1, 16, N, seed=seed)

    perm = a.encode('idna')


def create_parser():
    parser = argparse.ArgumentParser(
        description="Measure performance of encoding an array of random values."
    )
    parser.add_argument("hostname", help="Hostname of arkouda server")
    parser.add_argument("port", type=int, help="Port of arkouda server")
    parser.add_argument(
        "-n", "--size", type=int, default=10**5, help="Problem size: length of array to argsort"
    )
    parser.add_argument(
        "-t", "--trials", type=int, default=1, help="Number of times to run the benchmark"
    )
    parser.add_argument(
        "-s", "--seed", default=None, type=int, help="Value to initialize random number generator"
    )
    return parser


if __name__ == "__main__":
    import sys

    parser = create_parser()
    args = parser.parse_args()
    ak.verbose = False
    ak.connect(args.hostname, args.port)

    print("array size = {:,}".format(args.size))
    print("number of trials = ", args.trials)
    time_ak_encode(args.size, args.trials, args.seed)
    sys.exit(0)
