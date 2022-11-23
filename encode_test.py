import argparse
import arkouda as ak

ENCODINGS = ('idna', 'ascii')

def test_idna():
    idna_strings = ak.array(['Bücher.example','ドメイン.テスト', 'домен.испытание', 'Königsgäßchen'])
    expected_encoded = ak.array(['xn--bcher-kva.example','xn--eckwd4c7c.xn--zckzah', 'xn--d1acufc.xn--80akhbyknj4f', 'xn--knigsgchen-b4a3dun'])
    assert((idna_strings.encode('idna') == expected_encoded).all())

def test_encodings(size):
    for encoding in ENCODINGS:
        test_vals = ak.random_strings_uniform(1, 10, size, characters="printable").to_lower()
        nparr_pre = test_vals.to_ndarray()
        nparr_post = test_vals.encode(encoding).decode(encoding).to_ndarray()
        misses = 0
        for (pre, post) in zip(nparr_pre, nparr_post):
            if pre != post:
                if post == '':
                    print('invalid input: ', pre, " != ", post)
                else:
                    print('miss: ', pre, " != ", post)
                    misses += 1
        assert(misses == 0)

def create_parser():
    parser = argparse.ArgumentParser(
        description="Measure performance of encoding an array of random values."
    )
    parser.add_argument("hostname", help="Hostname of arkouda server")
    parser.add_argument("port", type=int, help="Port of arkouda server")
    parser.add_argument(
        "-n", "--size", type=int, default=1000, help="Problem size: length of array to argsort"
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
    
    test_idna()
    test_encodings(args.size)
    sys.exit(0)
