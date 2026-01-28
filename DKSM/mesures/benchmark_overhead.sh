output_file="output_overhead.csv"

rm $output_file

ksm="ksm"
if [[ -d /sys/kernel/mm/dksm ]] ; then
    ksm=dksm
fi

for nmb_pages in $(seq 100 100 10000) ; do
    echo 0 | sudo tee /sys/kernel/mm/$ksm/run
    echo 1 | sudo tee /sys/kernel/mm/$ksm/run
    echo -e -n "$nmb_pages\t" >> $output_file
    \time -f "%e" -a -o $output_file sudo ./madvise_test 64 $nmb_pages
done
