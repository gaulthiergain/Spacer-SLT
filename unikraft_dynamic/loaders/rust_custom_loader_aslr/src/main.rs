use std::env;
extern crate serde;
use crate::binary::BinaryLoader;
use crate::binary::SectionsLoader;
use crate::loader::LoaderInfo;

mod binary;
mod loader;

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 4 {
        eprintln!("Usage: {} <ELF file path> <address of _liblinuxuplat_start> <log>", args[0]);
        return;
    }
    let uk_name = &args[1];
    let entry_addr_str = &args[2];
    let entry_addr = u64::from_str_radix(entry_addr_str, 16).unwrap();

    let mut bin = BinaryLoader::new();
    // check is aslr in in uk_name
    if uk_name.contains("_aslr"){
        bin.read_uk_file(format!("{}_update", uk_name));
    }else{
        panic!("ASLR is not in uk_name");
    }

    
    let l = LoaderInfo::new(bin, SectionsLoader::new(format!("{}.sec", uk_name)));
    
    l.move_sec();
    l.move_data();

    let entry_point = entry_addr as *const ();
    unsafe {
        let func: extern "C" fn() = std::mem::transmute(entry_point);
        func();
    }
}
