use serde::{de, Deserialize, Serialize};
use std::fs::File;
use std::io::Read;

fn as_u16_le(array: &[u8]) -> u16 {
    ((array[0] as u16) <<  0) +
    ((array[1] as u16) <<  8) 
}

fn as_u64_le(array: &[u8]) -> u64 {
    ((array[0] as u64) <<  0) +
    ((array[1] as u64) <<  8) +
    ((array[2] as u64) << 16) +
    ((array[3] as u64) << 24) +
    ((array[4] as u64) << 32) +
    ((array[5] as u64) << 40) +
    ((array[6] as u64) << 48) +
    ((array[7] as u64) << 56)
}
#[derive(Serialize, Deserialize, Debug)]
pub struct Sections {
    pub name: String,
    pub vma: u64,
    pub size: u64,
    pub bytes: Option<Vec<u8>>,
}

fn get_file_as_byte_vec(filename: String) -> Vec<u8> {
    let mut f = File::open(&filename).expect("no file found");
    let metadata = f.metadata().expect("unable to read metadata");
    let mut buffer = vec![0; metadata.len() as usize];
    f.read(&mut buffer).expect("buffer overflow");

    buffer
}

fn read_file(filename : String) -> Vec<Sections>{
    let buff = Some(get_file_as_byte_vec(filename));
    let nb_entry = buff.as_ref().unwrap()[0] as u32;
    let mut sections: Vec<Sections> = Vec::new();

    let mut current : usize = 1;
    for _ in 0..nb_entry {

        let mut current_next : usize = current+2;
        
        // Read size of string
        let size = as_u16_le(&buff.as_ref().unwrap()[current..current_next]);

        // Read string
        current = current_next;
        current_next = current+(size as usize);
        let name = String::from_utf8(buff.as_ref().unwrap()[current..current_next].to_vec()).expect("Found invalid UTF-8");

        // Read sh_size
        current = current_next;
        current_next = current+8;
        let size = as_u64_le(&buff.as_ref().unwrap()[current..current_next]);

        // Read vma
        current = current_next;
        current_next = current+8;
        let vma = as_u64_le(&buff.as_ref().unwrap()[current..current_next]);

        // Read data
        current = current_next;
        current_next = current+ size as usize;
        let bytes = buff.as_ref().unwrap()[current..current_next].to_vec();

        sections.push(Sections{name, vma, size, bytes: Some(bytes)});

        current = current_next;
    }

    sections
}

fn read_sections(filename: String) -> Vec<Sections> {
    // Open the file
    let mut file = File::open(filename).expect("Cannot open sections file");

    // Read the file content into a buffer
    let mut buffer = Vec::new();
    file.read_to_end(&mut buffer).expect("Cannot read sections");

    // Deserialize the buffer into a list of Sections structs
    let sections: Vec<Sections> = bincode::deserialize(&buffer).expect("Cannot deserialize sections");

    sections
}

#[derive(Serialize, Deserialize, Debug)]
pub struct Sections2 {
    /// Name of the section
    pub name: String,
    /// vma of the section
    #[serde(deserialize_with = "hex_deserialize")]
    pub vma: u64,
    /// Size of the section
    #[serde(deserialize_with = "hex_deserialize")]
    pub size: u64,
    /// Data of the section (as bytes)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub bytes: Option<Vec<u8>>,
}

fn hex_deserialize<'de, D>(deserializer: D) -> Result<u64, D::Error>
where
    D: de::Deserializer<'de>,
{
    let s: String = Deserialize::deserialize(deserializer)?;
    let without_prefix = s.trim_start_matches("0x");
    match u64::from_str_radix(without_prefix, 16) {
        Ok(res) => Ok(res),
        Err(e) => Err(de::Error::custom(format!(
            "Failed to deserialize color: {}",
            e
        ))),
    }
}
/// Used to describe a binary
#[derive(Serialize, Deserialize, Debug)]
pub struct JsonLoader {
    /// List of sections
    pub sections: Vec<Sections2>,
}

/// Contains common sections of particular app
impl JsonLoader {
    /// Read json file libs
    pub fn read_json(filename: String) -> JsonLoader {
        let mut f = File::open(filename).expect("Error during opening file");
        let mut s = String::new();
        f.read_to_string(&mut s).expect("Error during reading file");
        let json_loader: JsonLoader = serde_json::from_str(&s).expect("Error during parsing file");
        json_loader
    }
}


fn main()  {

    use std::time::Instant;
    

    let now2 = Instant::now();
    {
        JsonLoader::read_json(String::from("/home/gain/unikraft/apps/lib-sqlite/build/unikernel_kvmfc-x86_64_local_align.json")); //SLOW
    }
    let elapsed2 = now2.elapsed();
    println!("Elapsed: {:.2?}", elapsed2);

    let now = Instant::now();
    // Code block to measure.
    {
        let sections = read_sections(String::from("/home/gain/unikraft/apps/lib-sqlite/build/unikernel_kvmfc-x86_64_local_align.sec")); //FAST
    }
    let elapsed = now.elapsed();
    println!("Elapsed: {:.2?}", elapsed);
}
