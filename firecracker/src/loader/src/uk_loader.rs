use crate::binary::BinaryLoader;
use crate::binary::SectionsLoader;
use std::os::unix::io::AsRawFd;
use std::fs::File;

/// Loader info for unikraft unikernels
pub struct LoaderInfo {
    /// Binary uk
    pub bin: BinaryLoader,
    /// Sections loader
    pub sections_loader: SectionsLoader,
    /// aslr
    pub aslr: bool
}

impl LoaderInfo {

    /// Move all sections to vma
    pub fn move_all(&self, region_addr: *mut libc::c_void, filename: String, data_start_addr: usize) {
        if self.aslr{
            for s in self.bin.sections.iter() {
                let addr = region_addr as usize + s.vma as usize;
                unsafe {
                    println!("memcopy: {}", s.name);
                    libc::memcpy(
                        addr as *mut libc::c_void,
                        s.bytes.as_ref().unwrap().to_vec().as_ptr() as *const libc::c_void,
                        s.size as usize,
                    );
                }
            }
        }else{
            let file = File::open(filename).expect("Failed to open file");
            unsafe{
                let shared_addr = libc::mmap(
                    (region_addr as usize + data_start_addr) as *mut libc::c_void,
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
    }

    /// Move particular area to mmap
    pub unsafe fn shm_mmap(&self, region_addr: *mut libc::c_void, prot: i32, name: String, size: usize){
        let fd_shm = libc::shm_open(name.as_ptr() as *const libc::c_char, libc::O_RDONLY, 0); //O_RDONLY
        if fd_shm < 0 {
            panic!("Failed during shm_open in reader");
        }

        // mmap64 instructions to vma
        let shared_addr = libc::mmap(
            region_addr,
            size as libc::size_t,
            prot,
            libc::MAP_PRIVATE | libc::MAP_FIXED,
            fd_shm,
            0,
        );
        if shared_addr == libc::MAP_FAILED {
            panic!("Failed during mmap lib");
        }
    }

    /// Move sec to mmap
    pub fn move_sec_aslr(&self, region_addr: *mut libc::c_void, prot: i32) -> usize {
        let mut data_start_addr : usize = 0;
        for s in self.sections_loader.sections.iter() {
            if s.vma % 0x1000 != 0 {
                println!("section is not 4K aligned. SKIP");
                continue;
            }
            if s.name == ".data"{
                data_start_addr = s.vma as usize;
                continue;
            }
            let mut name = String::from("");
            if self.aslr{
                name = String::from("aslr_")
            }
            name = concat_string!(name, "lib");
            name = concat_string!(name, s.name, "\0");

            unsafe {
                println!("mmap: {}", s.name);
                if s.name == ".text" || s.name == ".uk_thread_inittab" || s.name == "uk_lib_arg__lib_param" {
                    self.shm_mmap((region_addr as usize + s.vma as usize) as *mut libc::c_void, prot, name, s.size as usize)
                }else{
                    self.shm_mmap((region_addr as usize + s.vma as usize) as *mut libc::c_void, prot/*libc::PROT_READ*/, name, s.size  as usize)
                }
            };
        }
        return data_start_addr;
    }

    /// Build a new LoaderInfo struct
    pub fn new(bin: BinaryLoader, sections_loader: SectionsLoader, aslr: bool) -> LoaderInfo {
        LoaderInfo {
            bin: bin,
            sections_loader: sections_loader,
            aslr: aslr,
        }
    }
}
