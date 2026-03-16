use serde::{Deserialize, Serialize};
use anyhow::Result;
use std::fs;
use std::path::Path;

#[derive(Debug, Serialize, Deserialize, Default)]
pub struct ConfigManager {
    pub version: String,
    #[serde(default)]
    pub dashboard: DashboardConfig,
    pub links: Vec<LinkConfig>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct DashboardConfig {
    pub username: String,
    pub password: String,
    pub port: u16,
}

impl Default for DashboardConfig {
    fn default() -> Self {
        Self {
            username: "admin".to_string(),
            password: "admin".to_string(),
            port: 8080,
        }
    }
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct TlsConfig {
    pub enabled: bool,
    pub cert_path: Option<String>,
    pub key_path: Option<String>,
    pub min_version: Option<String>, // e.g., "1.2", "1.3"
    pub sni: Option<String>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct LinkConfig {
    pub name: String,
    pub listen_host: String,
    pub target_host: String,
    pub protocol: String,
    pub tls: Option<TlsConfig>,
    pub obfuscation: Option<String>, // e.g., "tls", "aead"
    pub port_hopping: Option<String>, // e.g., "10000-20000"
    pub secret: Option<String>,
    pub peer_cert_hash: Option<String>,
    pub bandwidth_limit: Option<usize>, // Bytes per second
}

impl ConfigManager {
    pub fn load() -> Result<Self> {
        let paths = [
            Path::new("/etc/rbt/config.toml"),
            Path::new("./rbt-config.toml"),
        ];

        for path in &paths {
            if path.exists() {
                let content = fs::read_to_string(path)?;
                let config: Self = toml::from_str(&content)?;
                return Ok(config);
            }
        }

        Ok(Self {
            version: "1".to_string(),
            dashboard: DashboardConfig::default(),
            links: vec![],
        })
    }

    pub fn save(&self) -> Result<()> {
        let content = toml::to_string_pretty(self)?;
        let path = Path::new("/etc/rbt/config.toml");
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).unwrap_or_else(|e| eprintln!("Warning: Could not create config dir: {}", e));
        }
        match fs::write(path, &content) {
            Ok(_) => println!("✅ Configuration saved to {}", path.display()),
            Err(e) => {
                eprintln!("⚠️ Could not write to /etc/rbt/config.toml (Permission denied?). Saving to ./rbt-config.toml instead.");
                fs::write("./rbt-config.toml", content)?;
            }
        }
        Ok(())
    }

    pub fn add_link(
        &mut self,
        name: String,
        listen: String,
        target: String,
        proto: String,
        tls: Option<TlsConfig>,
        obfuscation: Option<String>,
        port_hopping: Option<String>,
        secret: Option<String>,
        peer_cert_hash: Option<String>,
        bandwidth_limit: Option<usize>,
    ) -> Result<()> {
        self.links.push(LinkConfig {
            name,
            listen_host: listen,
            target_host: target,
            protocol: proto,
            tls,
            obfuscation,
            port_hopping,
            secret,
            peer_cert_hash,
            bandwidth_limit,
        });
        Ok(())
    }

    pub fn remove_link(&mut self, name: &str) -> Result<()> {
        let original_len = self.links.len();
        self.links.retain(|l| l.name != name);
        if self.links.len() < original_len {
            Ok(())
        } else {
            anyhow::bail!("Link '{}' not found", name)
        }
    }
}
