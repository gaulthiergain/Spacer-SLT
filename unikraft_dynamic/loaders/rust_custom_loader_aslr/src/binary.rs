use serde::{Deserialize};
use std::fs::File;
use std::io::Read;

/// Read a file and return bytes vector
pub fn get_file_as_byte_vec(filename: String) -> Vec<u8> {
    //println!("{}", filename);
    let mut f = File::open(&filename).expect("no file found");
    let metadata = f.metadata().expect("unable to read metadata");
    let mut buffer = vec![0; metadata.len() as usize];
    f.read(&mut buffer).expect("buffer overflow");

    buffer
}

fn as_u16_le(array: &[u8]) -> u16 {
    ((array[0] as u16) << 0) + ((array[1] as u16) << 8)
}

fn as_u64_le(array: &[u8]) -> u64 {
    ((array[0] as u64) << 0)
        + ((array[1] as u64) << 8)
        + ((array[2] as u64) << 16)
        + ((array[3] as u64) << 24)
        + ((array[4] as u64) << 32)
        + ((array[5] as u64) << 40)
        + ((array[6] as u64) << 48)
        + ((array[7] as u64) << 56)
}

/// Used to describe a section
#[derive(Deserialize)]
pub struct Sections {
    /// Name of the section
    pub name: String,
    /// vma of the section
    pub vma: u64,
    /// Size of the section
    pub size: u64,
    /// Data of the section (as bytes)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub bytes: Option<Vec<u8>>,
}

/// Used to describe a binary
#[derive(Deserialize)]
pub struct SectionsLoader {
    /// List of sections
    pub sections: Vec<Sections>,
}

/// Contains common sections of particular app
impl SectionsLoader {
    /// New instance of SectionsLoader
    pub fn new(filename: String) -> SectionsLoader {
        let mut file = File::open(filename).expect("Cannot open sections file");

        // Read the file content into a buffer
        let mut buffer = Vec::new();
        file.read_to_end(&mut buffer).expect("Cannot read sections");

        SectionsLoader {
            sections: bincode::deserialize(&buffer).expect("Cannot deserialize sections"),
        }
    }
}
/// Contains specific sections of particular app
pub struct BinaryLoader {
    /// List of sections
    pub sections: Vec<Sections>,
    /// Buffer read from uk
    pub buff: Vec<u8>,
}

impl BinaryLoader {
    /// New instance of BinaryLoader
    pub fn new() -> BinaryLoader {
        BinaryLoader {
            sections: Vec::new(),
            buff: Vec::new(),
        }
    }

    /// Read the uk binary file
    pub fn read_uk_file(&mut self, filename: String) {
        self.buff = get_file_as_byte_vec(filename);
        let nb_entry = self.buff[0] as u32;

        let mut current: usize = 1;
        for _ in 0..nb_entry {
            let mut current_next: usize = current + 2;

            // Read size of string
            let size = as_u16_le(&self.buff[current..current_next]);

            // Read string
            current = current_next;
            current_next = current + (size as usize);
            let name = String::from_utf8(self.buff[current..current_next].to_vec())
                .expect("Found invalid UTF-8");

            // Read size
            current = current_next;
            current_next = current + 8;
            let size = as_u64_le(&self.buff[current..current_next]);

            // Read vma
            current = current_next;
            current_next = current + 8;
            let vma = as_u64_le(&self.buff[current..current_next]);

            // Read data
            current = current_next;
            current_next = current + size as usize;
            let bytes = self.buff[current..current_next].to_vec();

            self.sections.push(Sections {
                name,
                vma,
                size,
                bytes: Some(bytes),
            });

            current = current_next;
        }
    }
}
