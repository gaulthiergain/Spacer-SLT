// enable asm to jump to the entry point of the program
mod load_elf;
mod parse_elf;

fn parse_file(file_path: &str) -> usize {
    // parse the ELF file to be loaded to obtain necessary load information
    let binary_info = parse_elf::parse_elf(file_path);

    // we will have to check if the ELF file uses an interpreter. If so, the entry point needs to be _start of that shared object file (usually ld.so)
    let (entry_point, _) = if let Some(_elf_interp) = &binary_info.elf_interp {
                        panic!("Interpreter not supported yet");
                    } else {
                        println!("Entry point: {:#x}", binary_info.entry_point);
                        (binary_info.entry_point, 0)
    };

    let _binary_load = load_elf::ElfLoad::load(&binary_info);
    entry_point
}

use std::{thread, time::Duration};
fn main() {

    // ensure that there is at least one argument to this program, it is the program that should be loaded
    let args: Vec<String> = std::env::args().collect();
    if args.len() == 1 {
        panic!("Usage: {} /PATH/TO/PROGRAM/TO/LOAD", args[0]);
    }
    thread::sleep(Duration::from_millis(4000));
    // get the entry point of the program to be loaded
    let entry_point = parse_file(&args[1]);
    thread::sleep(Duration::from_millis(4000));
    unsafe {
        let func: extern "C" fn() = std::mem::transmute(entry_point as *const ());
        func();
    }
}