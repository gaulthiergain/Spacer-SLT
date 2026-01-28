#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/mman.h>

/* ELF header structure */
#define ALIGN_TO_PAGE(addr) (((unsigned long)(addr) + ((0x1000) - 1)) & ~((0x1000) - 1))

/* ELF header structure */
typedef struct {
    unsigned char e_ident[16]; // ELF identification
    uint16_t e_type;           // Object file type
    uint16_t e_machine;        // Machine type
    uint32_t e_version;        // Object file version
    uint64_t e_entry;          // Entry point address
    uint64_t e_phoff;          // Program header offset
    uint64_t e_shoff;          // Section header offset
    uint32_t e_flags;          // Processor-specific flags
    uint16_t e_ehsize;         // ELF header size
    uint16_t e_phentsize;      // Size of program header entry
    uint16_t e_phnum;          // Number of program header entries
    uint16_t e_shentsize;      // Size of section header entry
    uint16_t e_shnum;          // Number of section header entries
    uint16_t e_shstrndx;       // Section name string table index
} Elf64_Ehdr;

/* Program header structure */
typedef struct {
    uint32_t p_type;   // Type of segment
    uint32_t p_flags;  // Segment attributes
    uint64_t p_offset; // Offset in file
    uint64_t p_vaddr;  // Virtual address in memory
    uint64_t p_paddr;  // Physical address (unused)
    uint64_t p_filesz; // Size of segment in file
    uint64_t p_memsz;  // Size of segment in memory
    uint64_t p_align;  // Alignment
} Elf64_Phdr;


// Function to check if a value is in an array
static int in_array(uint64_t *array, uint64_t size, uint64_t value) {
    for (uint64_t i = 0; i < size; i++) {
        if (array[i] == value) {
            return 1;
        }
    }
    return 0;
}

static uint64_t read_elf(const char *file_path) {
    FILE *file = fopen(file_path, "rb");
    if (!file) {
        perror("Error opening file");
        return -1;
    }

    uint64_t entry_point = 0;
    Elf64_Ehdr *header = malloc(sizeof(Elf64_Ehdr));
    if (header == NULL) {
        perror("Error allocating memory for ELF header");
        fclose(file);
        return -1;
    }

    if (fread(header, sizeof(Elf64_Ehdr), 1, file) != 1) {
        perror("Error reading ELF header");
        fclose(file);
        return -2;
    }

    if(header->e_ident[0] != 0x7f || header->e_ident[1] != 'E' || header->e_ident[2] != 'L' || header->e_ident[3] != 'F') {
        fprintf(stderr, "Not a valid ELF file\n");
        fclose(file);
        return -3;
    }
    entry_point = header->e_entry;

    printf("Entry point: 0x%lx\n", header->e_entry);

    // Seek to the program header table
    if (fseek(file, header->e_phoff, SEEK_SET) != 0) {
        perror("Error seeking to program header");
        fclose(file);
        return -4;
    }

    for (uint16_t i = 0; i < header->e_phnum; i++) {
        Elf64_Phdr *phdr = malloc(sizeof(Elf64_Phdr));
        if (phdr == NULL) {
            perror("Error allocating memory for program header");
            fclose(file);
            free(header);
            return -5;
        }

        if (fread(phdr, sizeof(Elf64_Phdr), 1, file) != 1) {
            return -5;
        }
        long position = ftell(file);
        printf("Position: %ld\n", position);

        printf("Segment %d:\n", i);
        printf("  Type: 0x%x\n", phdr->p_type);
        printf("  Offset: 0x%lx\n", phdr->p_offset);
        printf("  Virtual Address: 0x%lx\n", phdr->p_vaddr);
        printf("  Physical Address: 0x%lx\n", phdr->p_paddr);
        printf("  File Size: 0x%lx\n", phdr->p_filesz);
        printf("  Memory Size: 0x%lx\n", phdr->p_memsz);
        printf("  Flags: 0x%x\n", phdr->p_flags);
        printf("  Alignment: 0x%lx\n", phdr->p_align);

        if (phdr->p_vaddr == 0) {
            printf("  Segment has p_vaddr = 0...\n");
            free(phdr);
            continue;
        }

        // Seek to the segment content in the file
        if (fseek(file, phdr->p_offset, SEEK_SET) != 0) {
            perror("Error seeking to segment content");
            break;
        }

        // Align segment to page boundary
        if (phdr->p_vaddr % 0x1000 != 0) {
            printf("-> Segment is not page aligned. Aligning... %lx -> %lx\n", phdr->p_vaddr, ALIGN_TO_PAGE(phdr->p_vaddr) - 0x1000);
            phdr->p_vaddr = ALIGN_TO_PAGE(phdr->p_vaddr) - 0x1000;
        }

        void *ptr = mmap((void*)phdr->p_vaddr, ALIGN_TO_PAGE(phdr->p_memsz) , PROT_READ | PROT_EXEC | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        if (ptr == MAP_FAILED) {
            perror("Error mapping memory");
            return -6;
        }
        if (phdr->p_filesz > 0) {
            if (fread(ptr, 1, phdr->p_filesz, file) != phdr->p_filesz) {
                perror("Error reading segment content");
                return -7;
            }
        }
        if (madvise(ptr, ALIGN_TO_PAGE(phdr->p_memsz), MADV_MERGEABLE) == -1) {
            perror("Error advising memory");
            return -8;
        }

        printf("  Segment content successfully copied to buffer.\n");
        // rewind to the position after reading the segment content
        fseek(file, position, SEEK_SET);
        free(phdr);
    }

    fclose(file);
    free(header);
    return entry_point;
}

static void test_tt(int (*ptr)(int, char **), int argc, char *argv[]){
    int ret;
    ret = ptr(argc, argv);
}

int main(int argc, char *argv[]) {
    int ret;
    int (*ptr)(int, char **);
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <elf-file>\n", argv[0]);
        return EXIT_FAILURE;
    }

    ptr = (void *)read_elf(argv[1]);
    //printf("Address of _liblinuxuplat_start: %p\n", entry);
    printf("Address of entry: %p\n", ptr);
    
    test_tt(ptr, argc, argv);

    return EXIT_SUCCESS;
}