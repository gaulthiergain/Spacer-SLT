#!/bin/bash
binary="$1"
gcc -g -Wall -pedantic -o loader loader64.c -std=c99 -ldl -lelf||exit 1

#gcc -nostdlib --static-pie --static -o test test.c 
./loader "$binary"