pub mod tunnel {
    use serde::{Serialize, Deserialize};

    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct TunnelState {
        pub name: String,
        pub status: Status,
        pub uptime: u64,
    }

    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub enum Status {
        Running,
        Stopped,
        Error(String),
        Restarting,
    }
}

pub mod constants {
    pub const CONFIG_PATH: &str = "/etc/rbt/config.toml";
    pub const CERT_PATH: &str = "/etc/rbt/certs";
}
