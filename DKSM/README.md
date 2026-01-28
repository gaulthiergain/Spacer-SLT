# Daemonless Kernel Same-page Merging

Kernel Same-page Merging without daemon, only for anonymous and read-only memory pages.

## Usage

Use the`madvise` system call with advice `MADV_MERGEABLE` on the desired memory region, the memory region *should be read-only*. Memory pages of the calling process will be merged with identical pages previously advertised.

Pages are automatically reclaimed when all processes terminate and all shared memory is released, `MADV_UNMERGEABLE` has no effect.

### Additional information

- DKSM is disabled by default, it can be enabled using command: \
`echo 1 | sudo tee "/sys/kernel/mm/dksm/run"`

- DKSM can be disabled using command: \
`echo 0 | sudo tee "/sys/kernel/mm/dksm/run"`

When DKSM is disabled, all advertised pages are removed from the pool of mergeable pages (removed from a hash table that tracks pages), they will not be merged even if DKSM is re-enabled.
*Merged pages are not unmerged when DKSM is disabled.*

- Other read-only virtual files are available for gathering statistics:
    - Number of pages scanned by DKSM since last launch: \
    `/sys/kernel/mm/dksm/pages_scanned`

    - Number of pages merged by DKSM since last launch: \
    `/sys/kernel/mm/dksm/pages_merged`

    - Number of pages merging that failed since last launch: \
    `/sys/kernel/mm/dksm/merging_failed`
    
    - Current number of pages tracked by the hashtable: \
    `/sys/kernel/mm/dksm/hashtable_entries`

    - Size of the hashtable (statically defined), *does not impose a maximum number of pages that can be tracked*: \
    `/sys/kernel/mm/dksm/hashtable_size`

**Transparent hugepages must be disabled for DKSM to work:** \
`echo never | sudo tee "/sys/kernel/mm/transparent_hugepage/enabled"`

## Implementation

When `madvise` with advice `MADV_MERGEABLE` is invoked, the advertised pages of the calling process will be merged with the previously advertised pages that are identical, releasing the calling process memory when possible.
To determine if two pages are identical, DKSM uses a hash table to quickly find the potential pages, a bit-wise comparison is then performed to check if the pages have the same content.
A pages is merged by changing the calling process' page table entry so that it points to the physical frame of the previously advertised pages.
If an advertised page cannot be merged, it will be added to the hash table, so that it is available for future merging.
