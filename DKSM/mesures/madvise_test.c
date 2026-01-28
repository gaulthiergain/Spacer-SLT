#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/wait.h>
#include <stdint.h>


#define SAME_WRITE 0

#define RANDOMIZE_LAYOUT 0
#define MAX_OFFSET 100

#define SKIP_PRINT 1
#define SKIP_INIT 1
#define SKIP_CLEANUP 1


static void print_page(int child, int page_nmb, uint64_t address, uint64_t data, uint64_t page_value)
{
	printf("Process %d\tpage %d\taddress 0x%lx\tpfn %lx\tvalue 0x%lx\n",
		child,
		page_nmb,
		address,
		data & 0x7fffffffffffff,
		page_value
	);
}

static void init()
{
	if (SKIP_INIT) {
		return;
	}

	int f = open("/sys/kernel/mm/transparent_hugepage/enabled", O_WRONLY);
	if (f != -1) {
		write(f, "never", 5);
		close(f);
	}
	
	f = open("/sys/kernel/mm/dksm/run", O_WRONLY);
	if (f != -1) {
		write(f, "1", 1);
		close(f);
	}
}

static void cleanup()
{
	if (SKIP_CLEANUP) {
		return;
	}

	int f = open("/sys/kernel/mm/dksm/run", O_WRONLY);
	if (f != -1) {
		write(f, "0", 1);
		close(f);
	}
}

int main(int argc, char **argv)
{
	init();

	if (argc != 3) {
		fprintf(stderr, "Usage: %s <nmb_processes> <nmb_pages>\n", argv[0]);
		return 1;
	}

	int nmb_processes = atoi(argv[1]);
	int nmb_pages = atoi(argv[2]);

	size_t page_size = sysconf(_SC_PAGE_SIZE); // 4096 - 0x1000 bytes
	size_t region_size =  nmb_pages * page_size;

	int i;
	for (i = 0; i < nmb_processes; ++i) {
		if (fork() == 0) {
			int child_nmb = i;
			int pid = getpid();
			
			void *default_address = NULL;
			if (RANDOMIZE_LAYOUT) {
				srand(time(NULL) + i);
				size_t random_offset  = rand() % MAX_OFFSET;
				default_address = (void*)(0x700000000000 + 0x1000 * random_offset);
			} else {
				default_address = (void*)(0x700000000000 + 0x1000 * i);
			}

			size_t *region = mmap(default_address, region_size, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
			if (region == MAP_FAILED) {
				fprintf(stderr, "Process %d, mmap failed\n", child_nmb);
				return 1;
			}

			uint64_t start_address = (uint64_t)region;
			uint64_t end_address = start_address + region_size; 

			for (uint64_t i = start_address; i < end_address; i += page_size) {
				if (SAME_WRITE) {
					// set all pages to the same value, and same accross processes
					*(size_t*)(i) = 0xdeadbeef;
				}
				else {
					// set all pages to the different values, but same accross processes
					*(size_t*)(i) = (i - start_address) / page_size;
				}
			}

			if (madvise(region, region_size, MADV_MERGEABLE)) {
				fprintf(stderr, "Process %d, madvise failed\n", child_nmb);
				return 1;
			}
			
			if (SKIP_PRINT) {
				munmap(region, region_size);
				exit(0);
			}

			char filename[BUFSIZ];
			snprintf(filename, sizeof filename, "/proc/%d/pagemap", pid);

			int fd = open(filename, O_RDONLY);
			if(fd < 0) {
				fprintf(stderr, "Process %d, open failed: %s\n", child_nmb, filename);
				return 1;
			}

			for(uint64_t i = start_address; i < end_address; i += page_size) {
				uint64_t data;
				uint64_t index = (i / page_size) * sizeof(data);
				if(pread(fd, &data, sizeof(data), index) != sizeof(data)) {
					break;
				}

				uint64_t page_value = *(size_t*)(i);
				print_page(child_nmb, (i - start_address) / page_size, i, data, page_value);
			}

			close(fd);
			munmap(region, region_size);

			exit(0);
		}
	}
	
	// wait all child processes
	int status;
	for (i = 0; i < nmb_processes; ++i)
		wait(&status);

	cleanup();

	return 0;
}
