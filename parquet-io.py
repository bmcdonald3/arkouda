import time
import arkouda as ak
import os
import argparse
import shutil
import pandas as pd

str_length = 2
test_dir = ''
test_results = {}

correctness_test = False

def generate_arr(num_files, scaling):
    if scaling:
        return ak.random_strings_uniform(str_length, str_length+1, int(size/num_files))
    else:
        return ak.random_strings_uniform(str_length, str_length+1, size)

def compare_arrs(a,b):
    for i in range(len(a)):
        if a[i] != b[i]:
            print("FAIL!")
            print(a[i], '!=', b[i], " at ", i)

def read_files(num, scaling=False, info=""):
    for i in range(num):
        a = generate_arr(num, scaling)
        a.to_parquet(test_dir+"test"+str(i))
    start = time.time()
    b = ak.read(test_dir +"*", fixed_len=str_length)
    stop = time.time()
    test_results[info] = (False, ((a.nbytes*num)/2**30/(stop-start)))
    delete_folder_contents(test_dir)
    for i in range(num):
        a = generate_arr(num, scaling)
        a.to_parquet(test_dir+"test"+str(i))
    start = time.time()
    b = ak.read(test_dir +"*", fixed_len=str_length)
    stop = time.time()
    test_results[info+"-fixed"] = (True, ((a.nbytes*num)/2**30/(stop-start)))
    delete_folder_contents(test_dir)

def delete_folder_contents(folder_path):
    for root, _, files in os.walk(folder_path):
        for file in files:
            file_path = os.path.join(root, file)
            try:
                os.remove(file_path)
            except OSError as e:
                print(f"Error deleting file {file_path}: {e}")

def print_performance_table(test_results):
    data = [(test, fixed, time) for test, (fixed, time) in test_results.items()]
    df = pd.DataFrame(data, columns=["test", "fixed", "GB/s"])
    df["GB/s"] = df["GB/s"].apply(lambda x: f"{x:.3f}")
    print(df.to_markdown(index=False))
                
def create_parser():
    parser = argparse.ArgumentParser(
        description="Measure performance of writing and reading random arrays from disk."
    )
    parser.add_argument("hostname", help="Hostname of arkouda server")
    parser.add_argument("port", type=int, help="Port of arkouda server")
    parser.add_argument(
        "-n", "--size", type=int, default=10**7, help="Problem size: length of array to write/read"
    )
    parser.add_argument(
        "-p",
        "--path",
        default=os.path.join(os.getcwd(), "ak-io-test/"),
        help="Target path for measuring read/write rates",
    )
    return parser

if __name__ == "__main__":
    import sys
    parser = create_parser()
    args = parser.parse_args()
    ak.connect(args.hostname, args.port)
    if not os.path.exists(args.path):
        os.makedirs(args.path)
    test_dir = args.path
    size = args.size

    # 1 string single file read
    read_files(1, False, info="Single file string")

    # 2 string multi file read split data
    read_files(5, True, info="Five file string split size")
    read_files(10, True, info="Ten file string split size")

    # 3 string multi file read fixed sizee
    read_files(5, False, info="Five file string fixed size")
    read_files(10, False, info="Ten file string fixed size")

    print_performance_table(test_results)

import pandas as pd
        
# 5 integer single file read
# 6 integer multi file read
