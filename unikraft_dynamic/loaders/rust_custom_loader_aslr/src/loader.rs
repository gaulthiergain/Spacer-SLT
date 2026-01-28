use crate::binary::BinaryLoader;
use crate::binary::SectionsLoader;

pub struct LoaderInfo {
    /// Binary uk
    pub bin: BinaryLoader,
    /// Sections loader
    pub sections_loader: SectionsLoader,
}

impl LoaderInfo {

    /// Move all sections to vma
    pub fn move_data(&self) {
        for s in self.bin.sections.iter() {
            //println!("Copy section {} at address 0x{:x} with size 0x{:x}", s.name, s.vma, s.size);
            let addr = s.vma as usize;
            unsafe {
                libc::memcpy(
                    addr as *mut libc::c_void,
                    s.bytes.as_ref().unwrap().to_vec().as_ptr() as *const libc::c_void,
                    s.size as usize,
                );
            }
        }
    }

    /// Move particular area to mmap
    pub unsafe fn shm_mmap(&self, region_addr: *mut libc::c_void, prot: i32, name: String, size: usize){
        //println!("Opening shared memory with name: {} at address 0x{:x} and size 0x{:x}", name, region_addr as usize, size);
        let fd_shm = libc::shm_open(name.as_ptr() as *const libc::c_char, libc::O_RDONLY, 0); //O_RDONLY
        if fd_shm < 0 {
            panic!("Failed during shm_open in reader");
        }

        // mmap64 instructions to vma
        let shared_addr = libc::mmap(
            region_addr,
            size as libc::size_t,
            prot,
            libc::MAP_PRIVATE| libc::MAP_FIXED,
            fd_shm,
            0,
        );
        if shared_addr == libc::MAP_FAILED {
            panic!("Failed during mmap lib");
        }
    }

    // Multiple to n
    pub fn multiple_to_n(&self, x: usize, n: usize) -> usize {
        return ((x + n - 1) / n) * n;
    }

    /// Move sec to mmap
    pub fn move_sec(&self) {
        let mut _data_start_addr : usize = 0;
        let first_addr = self.sections_loader.sections[0].vma;
        let addr_size = self.bin.sections[self.bin.sections.len()-1].vma + self.bin.sections[self.bin.sections.len()-1].size;
        let last_addr = self.multiple_to_n(addr_size as usize, 0x1000);
        let size = last_addr - first_addr as usize;
        //let size = 0x8000000; // 16MiB

        //println!("MMAP first_addr 0x{:x} last_addr 0x{:x} size 0x{:x}", first_addr, last_addr, size);

        unsafe { _data_start_addr =  libc::mmap(
            first_addr as *mut libc::c_void,
            size as libc::size_t,
            libc::PROT_READ|libc::PROT_WRITE|libc::PROT_EXEC,
            libc::MAP_PRIVATE | libc::MAP_ANONYMOUS|libc::MAP_FIXED,
            -1,
            0,
        ) as usize;}
        //println!("MMAP data_start_addr 0x{:x}", data_start_addr as usize);
        
        for s in self.sections_loader.sections.iter() {
            if s.vma % 0x1000 != 0 {
                println!("section is not 4K aligned. SKIP");
                continue;
            }
            let name = format!("aslr{}\0", s.name);
            //println!("MMAP {} at adress 0x{:x} with size 0x{:x}",name, s.vma, s.size);
            unsafe {
                
                if s.name == ".tdata" || s.name == ".uk_ctortab" || s.name == ".posix_socket_driver_list"|| s.name == ".got" {
                    self.shm_mmap(s.vma as *mut libc::c_void, libc::PROT_READ|libc::PROT_WRITE|libc::PROT_EXEC, name, s.size as usize)
                }else{
                    self.shm_mmap(s.vma as *mut libc::c_void, libc::PROT_READ|libc::PROT_EXEC, name, s.size  as usize)
                }
            };
        }
    }

    /// Build a new LoaderInfo struct
    pub fn new(bin: BinaryLoader, sections_loader: SectionsLoader) -> LoaderInfo {
        LoaderInfo {
            bin: bin,
            sections_loader: sections_loader
        }
    }
}
