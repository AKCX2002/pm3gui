/// PM3 CLI command string definitions.
///
/// These mirror the TypeScript definitions in src/config/protocols.ts
/// but are available on the Rust side for server-side command generation.

pub mod hf {
    pub mod mf {
        pub fn info() -> &'static str {
            "hf mf info"
        }
        pub fn autopwn(sz: &str) -> String {
            format!("hf mf autopwn --{sz}")
        }
        pub fn darkside() -> &'static str {
            "hf mf darkside"
        }
        pub fn dump(sz: &str, file: Option<&str>) -> String {
            let mut s = format!("hf mf dump --{sz}");
            if let Some(f) = file {
                s.push_str(&format!(" -f {f}"));
            }
            s
        }
        pub fn rdbl(blk: u8, kt: &str, key: &str) -> String {
            format!("hf mf rdbl --blk {blk} -{kt} -k {key}")
        }
        pub fn wrbl(blk: u8, kt: &str, key: &str, data: &str) -> String {
            let force = if blk == 0 { " --force" } else { "" };
            format!("hf mf wrbl --blk {blk} -{kt} -k {key} -d {data}{force}")
        }
    }

    pub mod mfu {
        pub fn info() -> &'static str {
            "hf mfu info"
        }
        pub fn dump() -> &'static str {
            "hf mfu dump"
        }
    }

    pub mod mfdes {
        pub fn info() -> &'static str {
            "hf mfdes info"
        }
        pub fn enumerate() -> &'static str {
            "hf mfdes enum"
        }
    }
}

pub mod lf {
    pub fn search() -> &'static str {
        "lf search"
    }

    pub mod em {
        pub fn reader() -> &'static str {
            "lf em 410x reader"
        }
    }

    pub mod t55xx {
        pub fn info() -> &'static str {
            "lf t55xx info"
        }
        pub fn wipe() -> &'static str {
            "lf t55xx wipe"
        }
    }

    pub mod hid {
        pub fn reader() -> &'static str {
            "lf hid reader"
        }
        pub fn sim(card_id: &str) -> String {
            format!("lf hid sim -r {card_id}")
        }
    }
}

pub mod hw {
    pub fn tune() -> &'static str {
        "hw tune"
    }
}

pub mod common {
    pub fn hf_search() -> &'static str {
        "hf 14a reader"
    }
    pub fn hf_sniff() -> &'static str {
        "hf sniff"
    }
}
