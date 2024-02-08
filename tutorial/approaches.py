import arkouda as ak
import time
ak.connect()

def naiveAddOne(a):
    for i in range(a.size):
        a[i] += 1

a = ak.randint(0,2**32,10**3)

start1 = time.time()
naiveAddOne(a)
stop1 = time.time()

start2 = time.time()
b = a + 1
stop2 = time.time()

start3 = time.time()
b = ak.addOne(a)
stop3 = time.time()

print("Naive add one took    : ", stop1-start1)
print("Python add one took   : ", stop2-start2)
print("Server add one took   : ", stop3-start3)
