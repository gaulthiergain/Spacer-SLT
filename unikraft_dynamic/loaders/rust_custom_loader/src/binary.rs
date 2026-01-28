use serde::{Deserialize};
use std::fs::File;
use std::io::Read;

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
