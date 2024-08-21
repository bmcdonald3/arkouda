import time
import arkouda as ak
import os
import shutil
ak.connect()

size = 10**7
str_length = 2
test_dir = '/Users/ben.mcdonald/test-data/'

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
    print(f"{info}")
    start = time.time()
    b = ak.read(test_dir +"*", fixed_len=str_length)
    stop = time.time()
    print(f"Read {num} files took: ", stop-start)
    delete_folder_contents(test_dir)
    print("Fixed length:")
    for i in range(num):
        a = generate_arr(num, scaling)
        a.to_parquet(test_dir+"test"+str(i))
    start = time.time()
    b = ak.read(test_dir +"*", fixed_len=str_length)
    stop = time.time()
    print(f"Read {num} files took: ", stop-start)
    delete_folder_contents(test_dir)

def delete_folder_contents(folder_path):
    for root, _, files in os.walk(folder_path):
        for file in files:
            file_path = os.path.join(root, file)
            try:
                os.remove(file_path)
            except OSError as e:
                print(f"Error deleting file {file_path}: {e}")

# 1 string single file read
read_files(1, False, info="Single file string")

# 2 string multi file read split data
read_files(5, True, info="Five file string split size")
read_files(10, True, info="Ten file string split size")

# 3 string multi file read fixed sizee
read_files(5, False, info="Five file string fixed size")
read_files(10, False, info="Ten file string fixed size")

# 5 integer single file read
# 6 integer multi file read
