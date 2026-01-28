use std::env;
extern crate serde;

use crate::binary::SectionsLoader;
use crate::loader::LoaderInfo;

mod binary;
mod loader;

use memory_stats::memory_stats;

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() != 4 {
        eprintln!("Usage: {} <ELF file path> <address of _liblinuxuplat_start> <log>", args[0]);
        return;
    }
    let uk_name = &args[1];
    let entry_addr_str = &args[2];
    let log = &args[3];
    let entry_addr = u64::from_str_radix(entry_addr_str, 16).unwrap();

    
    let l = LoaderInfo::new(SectionsLoader::new(format!("{}.sec", uk_name)));
    if log == "log" {
        if let Some(usage) = memory_stats() {
            println!("Current physical memory usage 1: {}", usage.physical_mem);
            println!("Current virtual memory usage 1: {}", usage.virtual_mem);
        } else {
            println!("Couldn't get the current memory usage :(");
        }
    }
    
    let data_start_addr = l.move_sec();
    l.move_data(String::from(format!("{}_update", uk_name)), data_start_addr);

    let entry_point = entry_addr as *const ();
    unsafe {
        let func: extern "C" fn() = std::mem::transmute(entry_point);
        func();
    }
}
