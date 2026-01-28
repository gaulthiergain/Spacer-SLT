#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <libelf.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <dlfcn.h>
#include <elf.h>

#if !defined(MAP_ANONYMOUS)
#define MAP_ANONYMOUS        0x20
#endif

#define NUM_PATHS 25
#define NB_CHAR 128
#define PAGE_SIZE 0x1000

#define RELOC RTLD_NOW
//#define RELOC RTLD_LAZY

typedef struct {
    char **libs;
    void **handles;
    size_t count;
    size_t capacity;
} LibraryList;

typedef struct  {
    Elf64_Ehdr *hdr;
    Elf64_Phdr *phdr;
    Elf64_Shdr *shdr;
    Elf64_Sym  *syms;
    char       *strings;
    char       *start;
    char       *taddr;
    void       *entry;
    char       *exec;

    LibraryList list;
    char        lib_path[NB_CHAR];
    short       has_interpreter;
    unsigned long total_size_segments;
    unsigned long lower_addr;
    unsigned long upper_addr;
} Elf_struct;

static unsigned long entry_addres = 0x0;

// Initialize LibraryList
static void init_library_list(LibraryList *list) {
    list->count = 0;
    list->capacity = 5; // Initial capacity
    list->libs = malloc(list->capacity * sizeof(char *));
    list->handles = malloc(list->capacity * sizeof(void *));
    if (!list->libs||!list->handles) {
        perror("malloc");
        exit(EXIT_FAILURE);
    }
}


static int check_library_in_paths(Elf_struct* elf, const char *libname) {
    const char *paths[NUM_PATHS] = { "/lib/x86_64-linux-gnu", "/usr/lib/x86_64-linux-gnu/tls/x86_64/x86_64", "/usr/lib/x86_64-linux-gnu/tls/x86_64", "/usr/lib/x86_64-linux-gnu/tls/x86_64", "/usr/lib/x86_64-linux-gnu/tls", "/usr/lib/x86_64-linux-gnu/x86_64/x86_64", "/usr/lib/x86_64-linux-gnu/x86_64", "/usr/lib/x86_64-linux-gnu/x86_64", "/usr/lib/x86_64-linux-gnu", "/lib/tls/x86_64/x86_64", "/lib/tls/x86_64", "/lib/tls/x86_64", "/lib/tls", "/lib/x86_64/x86_64", "/lib/x86_64", "/lib/x86_64", "/lib", "/usr/lib/tls/x86_64/x86_64", "/usr/lib/tls/x86_64", "/usr/lib/tls/x86_64", "/usr/lib/tls", "/usr/lib/x86_64/x86_64", "/usr/lib/x86_64", "/usr/lib/x86_64", "/usr/lib"};
    for (int i = 0; i < NUM_PATHS; ++i) {
        snprintf(elf->lib_path, strlen(paths[i]) + strlen(libname) + 2, "%s/%s", paths[i], libname);

        // Check if the file exists and is accessible
        if (access(elf->lib_path, F_OK) == 0) {
            return 1;
        }
    }

    return -1;
}

static void add_library_str(LibraryList *list, const char *libname) {
    if (list->count >= list->capacity) {
        // Grow the array if necessary
        list->capacity *= 2;
        list->libs = realloc(list->libs, list->capacity * sizeof(char *));
        list->handles = realloc(list->handles, list->capacity * sizeof(void *));
        if (!list->libs||!list->handles) {
            perror("realloc");
            exit(EXIT_FAILURE);
        }
    }
    list->libs[list->count] = calloc(strlen(libname)+1, sizeof(char));
    strncpy(list->libs[list->count], libname, strlen(libname));
    if (!list->libs[list->count]) {
        perror("strdup");
        exit(EXIT_FAILURE);
    }
    list->handles[list->count] = NULL;
    list->count++;
}

// Add a library to LibraryList
static void add_library(Elf_struct* elf, LibraryList *list, const char *libname) {

    if (list->count >= list->capacity) {
        // Grow the array if necessary
        list->capacity *= 2;
        list->libs = realloc(list->libs, list->capacity * sizeof(char *));
        list->handles = realloc(list->handles, list->capacity * sizeof(void *));
        if (!list->libs||!list->handles) {
            perror("realloc");
            exit(EXIT_FAILURE);
        }
    }
    if (check_library_in_paths(elf, libname) < 0){
        fprintf(stderr, "failed to get library path\n");
        exit(EXIT_FAILURE);
    }
    list->libs[list->count] = calloc(strlen(elf->lib_path)+1, sizeof(char));
    if (!list->libs[list->count]) {
        perror("strdup");
        exit(EXIT_FAILURE);
    }
    list->handles[list->count] = NULL;
    strncpy(list->libs[list->count], elf->lib_path, strlen(elf->lib_path));
    list->count++;
}

// Free memory used by LibraryList
static void free_library_list(LibraryList *list) {
    for (size_t i = 0; i < list->count; i++) {
        if (list->handles[i] != NULL){
            dlclose(list->handles[i]);
        }
        free(list->libs[i]);
    }
    free(list->libs);
    free(list->handles);
}

static int roundUp(int numToRound, int multiple)
{
    if (multiple == 0)
        return numToRound;

    int remainder = numToRound % multiple;
    if (remainder == 0)
        return numToRound;

    return numToRound + multiple - remainder;
}

static short lib_in_list(LibraryList *list, const char *libname) {
    for (size_t i = 0; i < list->count; i++) {
        if (strcmp(list->libs[i], libname) == 0) {
            return 1;
        }
    }
    return 0;
}

static void dlopen_libs(LibraryList *list) {
    const char *libraries[] = {"/lib/x86_64-linux-gnu/liblinuxuplat.so", "/lib/x86_64-linux-gnu/libubsan.so","/lib/x86_64-linux-gnu/libukconstructors.so", "/lib/x86_64-linux-gnu/libukalloc.so", "/lib/x86_64-linux-gnu/libukallocbbuddy.so", "/lib/x86_64-linux-gnu/libposix_event.so","/lib/x86_64-linux-gnu/libposix_time.so","/lib/x86_64-linux-gnu/libposix_libdl.so","/lib/x86_64-linux-gnu/libposix_socket.so","/lib/x86_64-linux-gnu/libposix_process.so", "/lib/x86_64-linux-gnu/libposix_time.so", "/lib/x86_64-linux-gnu/libposix_user.so","/lib/x86_64-linux-gnu/libposix_environ.so", "/lib/x86_64-linux-gnu/libposix_sysinfo.so", "/lib/x86_64-linux-gnu/libuktimeconv.so","/lib/x86_64-linux-gnu/libposix_futex.so","/lib/x86_64-linux-gnu/libuksched.so","/lib/x86_64-linux-gnu/libukschedcoop.so","/lib/x86_64-linux-gnu/libramfs.so","/lib/x86_64-linux-gnu/libvfscore.so","/lib/x86_64-linux-gnu/libuksignal.so", "/lib/x86_64-linux-gnu/libcontext.so", "/lib/x86_64-linux-gnu/libukargparse.so", "/lib/x86_64-linux-gnu/libuklock.so", "/lib/x86_64-linux-gnu/libukboot_main.so","/lib/x86_64-linux-gnu/libuksglist.so","/lib/x86_64-linux-gnu/libuknetdev.so","/lib/x86_64-linux-gnu/libukmpi.so", "/lib/x86_64-linux-gnu/libukstreambuf.so", "/lib/x86_64-linux-gnu/libukswrand.so", "/lib/x86_64-linux-gnu/libukboot.so", "/lib/x86_64-linux-gnu/libukmmap.so", "/lib/x86_64-linux-gnu/libsyscall_shim.so" , "/lib/x86_64-linux-gnu/libuksched.so" , "/lib/x86_64-linux-gnu/libukdebug.so","/lib/x86_64-linux-gnu/libukmusl.so","/lib/x86_64-linux-gnu/libmuslglue.so","/lib/x86_64-linux-gnu/libdevfs.so","/lib/x86_64-linux-gnu/libukzlib.so","/lib/x86_64-linux-gnu/liblwip.so","/lib/x86_64-linux-gnu/libukcrypto.so","/lib/x86_64-linux-gnu/libukssl.so","/lib/x86_64-linux-gnu/libnginx.so","/lib/x86_64-linux-gnu/libsqlite.so","/lib/x86_64-linux-gnu/libtesthelloworld.so","/lib/x86_64-linux-gnu/libtestsqlite.so","/lib/x86_64-linux-gnu/libtestnginx.so"};
    const size_t libs_size = sizeof(libraries) / sizeof(libraries[0]);
    printf("libs_size: %ld\n", libs_size);
    for(size_t i = 0; i < libs_size; i++){
        if (lib_in_list(list, libraries[i]) == 1){
            printf("Library %s is loaded\n", libraries[i]);
            list->handles[i] = dlopen(libraries[i], RTLD_LAZY|RTLD_GLOBAL);
            if (list->handles[i] == NULL){
                fprintf(stderr, "Error opening library %s: %s\n", libraries[i], dlerror());
                continue;
            }
        }
    }
}

static void *resolve(LibraryList *list, const char* sym)
{
    
#if 0
    for(size_t i = 0; i < list->count; i++){
        if (list->handles[i] == NULL){
            list->handles[i] = dlopen(list->libs[i], RTLD_LAZY|RTLD_GLOBAL);
            if (!list->handles[i]){
                fprintf(stderr, "Error opening library %s: %s\n", list->libs[i], dlerror());
                continue;
                free_library_list(list);
                exit(EXIT_FAILURE);
            }
        }
#endif
    for(size_t i = 0; i < list->count; i++){
        if (list->handles[i] == NULL){
            list->handles[i] = dlopen(list->libs[i], RTLD_LAZY|RTLD_GLOBAL);
            if (list->handles[i] == NULL){
                fprintf(stderr, "Error opening library %s: %s\n", list->libs[i], dlerror());
                continue;
            }
        }
        void* sym_resolved = dlsym(list->handles[i], sym);
        if (sym_resolved != NULL){
            if (strcmp(sym, "_liblinuxuplat_start") == 0){
                entry_addres = (unsigned long)sym_resolved;
            }
            printf("Symbol %s resolved %p\n", sym, sym_resolved);
            return sym_resolved;
        }
    }
    return NULL;
}

void relocate(Elf_struct* elf, Elf64_Shdr* shdr)
{
    Elf64_Rela* rela = (Elf64_Rela*)( elf->start + shdr->sh_offset);
    for(int j = 0; j < shdr->sh_size / sizeof(Elf64_Rela); j++) {
        const char* sym = elf->strings + elf->syms[ELF64_R_SYM(rela[j].r_info)].st_name;
        switch(ELF64_R_TYPE(rela[j].r_info)) {
            case R_X86_64_JUMP_SLOT:
            case R_X86_64_GLOB_DAT:
                printf("Relocating %s\n", sym);
                *(Elf64_Addr*)(elf->exec + rela[j].r_offset) = (Elf64_Addr)resolve(&elf->list, sym);
                break;
            default:
                fprintf(stderr, "Unknown relocation: %ld\n", rela[j].r_info);
        }
    }
}

void* find_sym(const char* name, Elf64_Shdr* shdr, const char* strings, const char* src, char* dst)
{
    Elf64_Sym* syms = (Elf64_Sym*)(src + shdr->sh_offset);
    for(int i = 0; i < shdr->sh_size / sizeof(Elf64_Sym); i++) {
        if (strcmp(name, strings + syms[i].st_name) == 0) {
            return dst + syms[i].st_value;
        }
    }
    return NULL;
}

void *image_load(Elf_struct* elf)
{
    if (!elf || elf->start == NULL) {
        fprintf(stderr, "elf is NULL\n");
        return 0;
    }

    elf->hdr = (Elf64_Ehdr *) elf->start;
    elf->exec = mmap((void *)NULL, elf->total_size_segments, PROT_READ | PROT_WRITE | PROT_EXEC,
                      MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if(!elf->exec) {
        fprintf(stderr, "image_load:: error allocating memory\n");
        return 0;
    }
    memset(elf->exec, 0x0, elf->total_size_segments);
    //printf("exec: %p - size:%ld\n", elf->exec, elf->total_size_segments);
    
    elf->phdr = (Elf64_Phdr *)(elf->start + elf->hdr->e_phoff);
    for(int i = 0; i < elf->hdr->e_phnum; ++i) {
        if(elf->phdr[i].p_type != PT_LOAD) {
            continue;
        }
        if(elf->phdr[i].p_filesz > elf->phdr[i].p_memsz) {
            fprintf(stderr, "image_load:: p_filesz > p_memsz\n");
            munmap(elf->exec, elf->total_size_segments);
            return 0;
        }
        if(!elf->phdr[i].p_filesz) {
            continue;
        }
        //printf("taddr: %x - start: %x - filesz: %d\n", taddr, start, phdr[i].p_filesz);
        //printf("exec: %p - size:%d\n", exec, size);
        elf->taddr = elf->phdr[i].p_vaddr + elf->exec;
        memmove(elf->taddr, elf->start + elf->phdr[i].p_offset, elf->phdr[i].p_filesz);
        if(!(elf->phdr[i].p_flags & PF_W)) {
            // Read-only.
            mprotect((unsigned char *) elf->taddr, elf->phdr[i].p_memsz, PROT_READ);
        }
        if(elf->phdr[i].p_flags & PF_X) {
            // Executable.
            mprotect((unsigned char *) elf->taddr, elf->phdr[i].p_memsz, PROT_EXEC);
        }
    }

    elf->shdr = (Elf64_Shdr *)(elf->start + elf->hdr->e_shoff);
    if (elf->has_interpreter == 1){
        for(int i=0; i < elf->hdr->e_shnum; ++i) {
            if (elf->shdr[i].sh_type == SHT_DYNSYM) {
                // Get the .dynamic section
                elf->syms = (Elf64_Sym*)(elf->start + elf->shdr[i].sh_offset);
                elf->strings = elf->start + elf->shdr[elf->shdr[i].sh_link].sh_offset;
                break;
            }
        }

        dlopen_libs(&elf->list);

        for(int i=0; i < elf->hdr->e_shnum; ++i) {
            if (elf->shdr[i].sh_type == SHT_RELA) {
                relocate(elf, elf->shdr + i);
            }
        }
    }

    /*for(int i=0; i < elf->hdr->e_shnum; ++i) {
        if (elf->shdr[i].sh_type == SHT_SYMTAB) {
            elf->syms = (Elf64_Sym*)(elf->start + elf->shdr[i].sh_offset);
            elf->strings = elf->start + elf->shdr[elf->shdr[i].sh_link].sh_offset;
            elf->entry = find_sym("_liblinuxuplat_start", elf->shdr + i, elf->strings, elf->start, elf->exec);
            if (elf->entry != NULL) {
                break;
            }
        }
    }*/

    elf->entry = (void*)entry_addres;

    free(elf->start);

    return elf->entry;
}

int parse_elf_file(const char* filename, const size_t filesize, Elf_struct* elf_obj) {
    
    // Initialize the ELF library
    if (elf_version(EV_CURRENT) == EV_NONE) {
        fprintf(stderr, "Failed to initialize libelf\n");
        return 1;
    }

    // Read the elf file to have in memory
    elf_obj->start = malloc(sizeof(char) * filesize);
    if (!elf_obj->start){
        fprintf(stderr, "Failed to allocate memory\n");
        exit(EXIT_FAILURE);
    }
    memset(elf_obj->start, 0, filesize);

    // Open the ELF file
    int fd = open(filename, O_RDONLY, 0);
    if (fd < 0) {
        perror("open");
        return 1;
    }
    read(fd, elf_obj->start, filesize);

    // Begin processing ELF
    Elf *elf = elf_begin(fd, ELF_C_READ, NULL);
    if (!elf) {
        fprintf(stderr, "elf_begin() failed: %s\n", elf_errmsg(-1));
        close(fd);
        return 1;
    }

    // Get the class (32-bit or 64-bit)
    char *ident = elf_getident(elf, NULL);
    if (!ident) {
        fprintf(stderr, "elf_getident() failed: %s\n", elf_errmsg(-1));
        elf_end(elf);
        close(fd);
        return 1;
    }

    if (ident[EI_CLASS] != ELFCLASS64) {
        fprintf(stderr, "Unsupported ELF class. Only x86_64 is supported.\n");
        elf_end(elf);
        close(fd);
        return 1;
    }

    Elf64_Ehdr *ehdr = elf64_getehdr(elf);
    Elf64_Phdr *phdr = elf64_getphdr(elf);
        
    if (!ehdr || !phdr) {
        fprintf(stderr, "Failed to get 64-bit ELF headers: %s\n", elf_errmsg(-1));
        elf_end(elf);
        close(fd);
        return 1;
    }

    // Iterate over program headers
    Elf64_Off dynamic_offset = 0;
    elf_obj->lower_addr = -1;    
    for (int i = 0; i < ehdr->e_phnum; ++i) {
        if (phdr[i].p_type == PT_LOAD) {
            if (elf_obj->lower_addr == -1 || phdr[i].p_vaddr == 0x0) {
                elf_obj->lower_addr = phdr[i].p_vaddr;
            }
            if (phdr[i].p_vaddr + phdr[i].p_memsz > elf_obj->upper_addr) {
                elf_obj->upper_addr = phdr[i].p_vaddr + phdr[i].p_memsz;
            }
            //printf("LOAD segment %d: p_vaddr: 0x%lx, Memsz: 0x%lx (Offset: 0x%lx)\n", i, phdr[i].p_vaddr, phdr[i].p_memsz, phdr[i].p_offset);
            //printf("\tLower addr: 0x%lx, Upper addr: 0x%lx\n", elf_obj->lower_addr, elf_obj->upper_addr);
        }else if (phdr[i].p_type == PT_INTERP) {
            elf_obj->has_interpreter = 1;
        }else if (phdr[i].p_type == PT_DYNAMIC) {
            dynamic_offset = phdr[i].p_offset;
            break;
        }
    }
    elf_obj->total_size_segments = roundUp(elf_obj->upper_addr, 0x1000);

    Elf64_Dyn *dyn = (Elf64_Dyn *)((char *)elf_obj->start + dynamic_offset);
    const char *strtab = NULL;

    // Scan the dynamic section for DT_NEEDED and DT_STRTAB
    for (; dyn->d_tag != DT_NULL; dyn++) {
        if (dyn->d_tag == DT_STRTAB) {
            strtab = (const char *)((char *)elf_obj->start  + dyn->d_un.d_ptr);
        }
    }

    add_library_str(&elf_obj->list, "/lib/x86_64-linux-gnu/libukconstructors.so");

    // Re-scan the dynamic section to find and print DT_NEEDED entries
    dyn = (Elf64_Dyn *)((char *)elf_obj->start  + dynamic_offset);
    for (; dyn->d_tag != DT_NULL; dyn++) {
        if (dyn->d_tag == DT_NEEDED) {
            add_library(elf_obj, &elf_obj->list, strtab + dyn->d_un.d_val);
        }
    }

    // Clean up
    elf_end(elf);
    close(fd);

    return 0;
}

int main(int argc, char** argv, char** envp)
{
    int ret = 0;
    char* filename = NULL;
    int (*ptr)(int, char **, char**);    

    if (argc < 2){
        fprintf(stderr, "Must be loader <elf_file>");
        exit(EXIT_FAILURE);
    }
    filename = argv[1];

    struct stat file_stats;
    if (stat(filename, &file_stats) != 0) {
        perror("stat");
        exit(EXIT_FAILURE);
    }

    Elf_struct elf_obj = {0};
    memset(&elf_obj, 0, sizeof(Elf_struct));

    init_library_list(&elf_obj.list);
    
    parse_elf_file(filename, file_stats.st_size, &elf_obj);

    ptr = image_load(&elf_obj);
    printf("Address of _liblinuxuplat_start: %p\n", ptr);
    //while(1);
    ret = ptr(argc, argv, envp);
    if (elf_obj.exec) {
        munmap(elf_obj.exec, elf_obj.total_size_segments);
    }
    free_library_list(&elf_obj.list);
    return ret;
}

