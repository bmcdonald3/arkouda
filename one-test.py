import time
import arkouda as ak
ak.connect()

size = 10
str_length = 2
test_dir = '/Users/ben.mcdonald/test-data/'

correctness_test = False

def generate_arr():
    return ak.random_strings_uniform(str_length, str_length+1, size)

def compare_arrs(a,b):
    for i in range(len(a)):
        if a[i] != b[i]:
            print("FAIL!")
            print(a[i], '!=', b[i], " at ", i)

def read_files(num, fixed=False):
    for i in range(num):
        a = generate_arr()
        a.to_parquet(test_dir+"test"+str(i))
    start = time.time()
    if fixed:
        b = ak.read(test_dir +"*", fixed_len=str_length)
    else:
        b = ak.read(test_dir +"*")
    stop = time.time()
    print(f"Read {num} files took: ", stop-start)
    delete_folder_contents(test_dir)

import os
import shutil

def delete_folder_contents(folder_path):
    for root, _, files in os.walk(folder_path):
        for file in files:
            file_path = os.path.join(root, file)
            try:
                os.remove(file_path)
            except OSError as e:
                print(f"Error deleting file {file_path}: {e}")
    
read_files(1, False)
read_files(5, False)
read_files(10, False)

print("\nFixed")
read_files(1, True)
read_files(5, True)
read_files(10, )
