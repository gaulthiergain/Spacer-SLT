use crate::binary::SectionsLoader;
use std::os::unix::io::AsRawFd;
use std::fs::File;

pub struct LoaderInfo {
    pub sections_loader: SectionsLoader,
}

impl LoaderInfo {

    /// Move all sections to vma
    pub fn move_data(&self, filename: String, data_start_addr: usize) {
        let file = File::open(filename).expect("Failed to open file");
        
        unsafe{
            //let size = file.metadata().expect("Failed to read metadata").len();
            //println!("Moving data to address 0x{:x} with size of 0x{:x}", data_start_addr, size);
            let shared_addr = libc::mmap(
                data_start_addr as *mut libc::c_void,
                file.metadata().expect("Failed to read metadata").len() as libc::size_t,
                libc::PROT_READ | libc::PROT_WRITE,
                libc::MAP_PRIVATE | libc::MAP_FIXED,
                file.as_raw_fd(),
                0,
            );
            if shared_addr == libc::MAP_FAILED {
                panic!("Failed during mmap data");
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

    /// Move sec to mmap
    pub fn move_sec(&self) -> usize {
        let mut data_start_addr : usize = 0;
        for s in self.sections_loader.sections.iter() {
            if s.vma % 0x1000 != 0 {
                //println!("section is not 4K aligned. SKIP");
                continue;
            }
            if s.name == ".data.common"|| s.name == ".data.bss.common"|| s.name == ".data.bss" {
                data_start_addr = s.vma as usize;
                continue;
            }else if s.name == ".bss.common" {
                //println!("Allocate {} at adress 0x{:x} with size 0x{:x}",s.name, s.vma, s.size);
                unsafe {libc::mmap(
                    s.vma as *mut libc::c_void,
                    s.size as libc::size_t,
                    libc::PROT_READ|libc::PROT_WRITE,
                    libc::MAP_PRIVATE | libc::MAP_ANONYMOUS,
                    -1,
                    0,
                );}
                continue;
            }
            let name = format!("lib{}\0", s.name);
            unsafe {
                if s.name == ".tdata" || s.name == ".posix_socket_driver_list"|| s.name == ".got" {
                    self.shm_mmap(s.vma as *mut libc::c_void, libc::PROT_READ|libc::PROT_WRITE, name, s.size as usize)
                }else{
                    self.shm_mmap(s.vma as *mut libc::c_void, libc::PROT_READ|libc::PROT_EXEC, name, s.size  as usize)
                }
            };
        }
        return data_start_addr;
    }

    /// Build a new LoaderInfo struct
    pub fn new(sections_loader: SectionsLoader) -> LoaderInfo {
        LoaderInfo {
            sections_loader: sections_loader,
        }
    }
}
