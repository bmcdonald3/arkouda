import numpy as np
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
from context import arkouda as ak
from base_test import ArkoudaTest
import unittest

SIZE = 1000
NUMFILES = 5
verbose = True

def write_random_file(filename, size):
    df = pd.DataFrame(np.random.randint(0,2**32,size=(size, 4)), columns=list('ABCD'))
    table = pa.Table.from_pandas(df)

    pq.write_table(table, filename)

def compare_values(ak_col, py_col):
    for i in range(SIZE):
        if ak_col[i] != py_col[i]:
            print(ak_col[i], 'does not match', py_col[i])
            return 1
    return 0
    
def run_test(verbose=True):
    '''
    The run_test method enables execution of ak.GroupBy and ak.GroupBy.Reductions 
    for mean, min, max, and sum
    on a randomized set of arrays including nan values. 

    :return: 
    '''
    tests = 1
    failures = 0

    write_random_file("correctness-test.parquet", SIZE)
    
    for colname in list('ABCD'):
        py_col1 = pq.read_pandas("correctness-test.parquet", columns=[colname]).to_pandas()[colname]
        ak_col1 = ak.read_parquet("correctness-test", colname).to_ndarray()
        failures += compare_values(ak_col1, py_col1)

    return failures

class ParquetTest(ArkoudaTest):
    def test_correctness(self):
        '''
        Executes run_test and asserts whether there are any errors
        
        :return: None
        :raise: AssertionError if there are any errors encountered in run_test with nan values
        '''
        self.assertEqual(0, run_test())

    def test_multiple_file_read(self):
        filenames = []
        chpl_filenames = []
        totalSize = 0
        
        for i in range(NUMFILES):
            filenames.append('file'+str(i)+'.parquet')
            chpl_filenames.append('file'+str(i))
            write_random_file(filenames[i], SIZE*(i+1))
            totalSize += SIZE*(i+1)
        ak_col = ak.read_parquet(filenames, 'A')
        self.assertEqual(len(ak_col), totalSize)
