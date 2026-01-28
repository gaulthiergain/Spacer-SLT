#!/bin/sh
git clone https://github.com/Krechals/unikraft/
cd unikraft
git checkout RELEASE-0.13.0
git apply all_diff.diff