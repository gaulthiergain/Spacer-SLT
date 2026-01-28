use bincode::deserialize;
use serde::Deserialize;
use std::collections::HashMap;

#[derive(Debug, Deserialize)]
struct Header {
    pub ident_magic:        [u8; 16],
    pub etype:      u16,
    pub machine:    u16,
    pub version:    u32, 
    pub entry:      u64, //program counter starts here
    pub phoff:      u64, //offset of program header table
    pub shoff:      u64, //offset of section header table
    pub flags:      u32,
    pub ehsize:     u16, //size of this header (who cares?)
    pub phentsize:  u16, //the size of a program header table entry
    pub phnum:      u16, //the number of entries in the program header table
    pub shentsize:  u16, //the size of a section header table entry
    pub shnum:      u16, //the number of entries in the section header table
    pub shstrndx:   u16, //where to find section names
}

#[derive(Debug, Clone, Deserialize)]
struct SectionHeader {
    pub name:       u32,
    pub shtype:     u32,
    pub flags:      u64,
    pub addr:       u64,
    pub offset:     u64,
    pub size:       u64,
    pub link:       u32,
    pub info:       u32,
    pub addralign:  u64,
    pub entsize:    u64,
    #[serde(skip_deserializing)]
    hash: String,
}

pub struct MinimalSect{
    pub addr:     u64,
    pub offset:   u64,
    pub size:     u64,
}

const TEXT: &str = ".text";

fn read_section_header_table64(slices: &[u8], h: Header) ->  HashMap<String, MinimalSect>
{
    let mut map_libs = HashMap::new();
    let mut sections: Vec<SectionHeader> = Vec::new();

    // Get position of section header table
    let mut current = h.shoff as usize;
    
    // Parse section header (without section name)
    for _ in 0..h.shnum  {
        let s_array = &slices[current..(current+h.shentsize as usize)];
        let sect: SectionHeader = deserialize(&s_array).unwrap();
        
        sections.push(sect);
        current = current + h.shentsize as usize;
    }

    // Get position of shstrtab
    current = sections[h.shstrndx as usize].offset as usize;
    let shstrtab = &slices[current..current+(sections[h.shstrndx as usize].size as usize)];

    // Parse section name
    for mut s in sections{
        let buf = shstrtab[s.name as usize..]
                .split(|e| *e == 0)
                .next()
                .unwrap_or(&[0; 0]).to_vec();
        
        s.hash = match std::str::from_utf8(&buf) {
            Ok(v) => v.to_string(),
            Err(e) => panic!("Invalid UTF-8 sequence: {}", e),
        };
        map_libs.insert(s.hash, MinimalSect {addr: s.addr, size: s.size, offset : s.offset});
    }

    map_libs
}

fn round_to_n(x: f64, base: f64) -> u64 {
    let y = x / base;
    (base * y.ceil()) as u64
}

pub fn init_madvise(region_addr: *mut libc::c_void, uk_str : String) {
    
    let path = std::path::PathBuf::from(uk_str);
    let file_data = std::fs::read(path).expect("Could not read file.");
    let slices = file_data.as_slice();

    // Get the header
    let h: Header = deserialize(&slices).unwrap();
    // Get Hashtable <Section Name, Section>
    let hm = read_section_header_table64(slices, h);

    // Iterate through map
    for k in hm.keys(){
        let value = hm.get(k);

        let addr = value.unwrap().addr;
        let size_sect = value.unwrap().size as usize;
        if addr > 0 {
            
            
            let size_sect_aligned = round_to_n(value.unwrap().size as f64, 0x1000 as f64);
            
            unsafe{
                let offset1 = value.unwrap().offset as usize;
                let offset2 = offset1 as usize + size_sect;
                if offset1 > slices.len() || offset2 > slices.len() {
                    //println!("offset out of bounds");
                    continue;
                }

                println!("{}: {:x} - {:x} (size:  {:x} - vaddr: {:x})", k, offset1, offset2, size_sect, (region_addr as usize +addr as usize));
                let ret_mcpy = libc::memcpy((region_addr as usize +addr as usize) as *mut libc::c_void,slices[offset1..offset2].as_ptr() as *const libc::c_void, size_sect as usize);
                if ret_mcpy.is_null() {
                    panic!("memcpy failed");
                }

                if k.contains(&TEXT) {
                    let ret =
                    libc::madvise(
                        (region_addr as u64+addr) as *mut _,
                        size_sect_aligned as usize,
                        libc::MADV_MERGEABLE,
                    );
                    if ret < 0 {
                        println!("\tmadvise failed");
                    } else {
                        println!("\tmadvise succeeded");
                    }
                }

            }
        }
    }
}
