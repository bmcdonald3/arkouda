#!/bin/bash

CHPL_FLAGS="-sverify=false -sperfOnlyCompile -sperfValRange='uint(32)'" make test-bin/UnitTestSort


printf "Using assignment operator\n"

for i in 1 2 3 4 5 6 7 8 9 10
do
    ./test-bin/UnitTestSort -nl 8 --elemsPerLocale=$((2**32)) --doSwap=false
done

printf "\nUsing swap opertor\n\n"

for i in 1 2 3 4 5 6 7 8 9 10
do
    ./test-bin/UnitTestSort -nl 8 --elemsPerLocale=$((2**32)) --doSwap=true
done
