#!/usr/bin/env python3
"""
This is a driver script to automatically run the Arkouda benchmarks in this
directory and optionally graph the results. Graphing requires that $CHPL_HOME
points to a valid Chapel directory. This will start and stop the Arkouda server
automatically.
"""

import argparse
import logging
import os
import subprocess
import sys

benchmark_dir = os.path.dirname(__file__)
util_dir = os.path.join(benchmark_dir, '..', 'util', 'test')
sys.path.insert(0, os.path.abspath(util_dir))
from util import *

logging.basicConfig(level=logging.INFO)

BENCHMARKS = [
    'regularIO'
]

def create_parser():
    parser = argparse.ArgumentParser(description=__doc__)

    # TODO support alias for a larger default N
    #parser.add_argument('--large', default=False, action='store_true', help='Run a larger problem size')

    parser.add_argument('-nl', '--num-locales', '--numLocales', default=get_arkouda_numlocales(), help='Number of locales to use for the server')
    parser.add_argument('-sp', '--server-port', default='5555', help='Port number to use for the server')
    parser.add_argument('--server-args', action='append' , help='Additional server arguments')
    parser.add_argument('--numtrials', default=1, type=int, help='Number of trials to run')
    parser.add_argument('--platform-name', default='', help='Test platform name')
    parser.add_argument('--description', default='', help='Description of this configuration')
    parser.add_argument('--annotations', default='', help='File containing annotations')
    parser.add_argument('--configs', help='comma seperate list of configurations')
    parser.add_argument('--start-date', help='graph start date')
    return parser

def main():
    parser = create_parser()
    args, client_args = parser.parse_known_args()

    start_arkouda_server(args.num_locales, port=args.server_port, server_args=args.server_args)

    for benchmark in BENCHMARKS:
        for trial in range(args.numtrials):
            benchmark_py = os.path.join(benchmark_dir, '{}.py'.format(benchmark))
            out = run_client(benchmark_py, client_args+['-w'])
            print(out)

    stop_arkouda_server()

    start_arkouda_server(args.num_locales, port=args.server_port, server_args=args.server_args)
    
    for benchmark in BENCHMARKS:
        for trial in range(args.numtrials):
            benchmark_py = os.path.join(benchmark_dir, '{}.py'.format(benchmark))
            out = run_client(benchmark_py, client_args+['-r'])
            run_client(benchmark_py, client_args+['-f'])
            print(out)

    stop_arkouda_server()

if __name__ == '__main__':
    main()
