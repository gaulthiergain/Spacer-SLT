#!/bin/bash
#docker build -t cpploader:0.1 . #build

docker run --rm -ti -v "$PWD":/test cpploader:0.1 bash -c "cd /test/ && gcc -g -Wall -ldl -o loader loader64.c -ldl && gcc -pie -fPIE --static -o test test.c && valgrind ./loader test"