use chrono::{Utc, DateTime};
use serde::Serialize;
use std::path::Path;
use rbt_config::ConfigManager;

#[derive(Debug, Serialize)]
pub struct AuditReport {
    pub timestamp: DateTime<Utc>,
    pub version: String,
    pub system_checks: SystemChecks,
    pub security_posture: SecurityPosture,
    pub recent_events: Vec<AuditEvent>,
}

#[derive(Debug, Serialize)]
pub struct SystemChecks {
    pub config_exists: bool,
    pub certs_dir_accessible: bool,
    pub log_dir_accessible: bool,
    pub supervisor_active: bool,
}

#[derive(Debug, Serialize)]
pub struct SecurityPosture {
    pub no_covert_flags: bool,
    pub least_privilege_enabled: bool,
    pub encryption_active: bool,
}

#[derive(Debug, Serialize)]
pub struct AuditEvent {
    pub time: DateTime<Utc>,
    pub level: String,
    pub message: String,
}

pub struct Auditor {
    config_path: String,
    cert_path: String,
    log_path: String,
}

impl Auditor {
    pub fn new() -> Self {
        Self {
            config_path: "/etc/rbt/config.toml".to_string(),
            cert_path: "/etc/rbt/certs".to_string(),
            log_path: "/var/log/rbt".to_string(),
        }
    }

    pub fn run_audit(&self) -> AuditReport {
        AuditReport {
            timestamp: Utc::now(),
            version: env!("CARGO_PKG_VERSION").to_string(),
            system_checks: self.check_system(),
            security_posture: self.check_security(),
            recent_events: self.fetch_recent_events(),
        }
    }

    fn check_system(&self) -> SystemChecks {
        let supervisor_active = std::process::Command::new("systemctl")
            .args(["is-active", "--quiet", "rbt"])
            .status()
            .map(|s| s.success())
            .unwrap_or(false);

        SystemChecks {
            config_exists: Path::new(&self.config_path).exists() || Path::new("./rbt-config.toml").exists(),
            certs_dir_accessible: Path::new(&self.cert_path).is_dir(),
            log_dir_accessible: Path::new(&self.log_path).is_dir(),
            supervisor_active,
        }
    }

    fn check_security(&self) -> SecurityPosture {
        let mut encryption_active = false;
        let no_covert_flags = true;

        if let Ok(config) = ConfigManager::load() {
            if !config.links.is_empty() {
                encryption_active = config.links.iter().all(|link| {
                    link.tls.is_some() || link.obfuscation.is_some() || link.protocol == "quic"
                });
                
                // Example check for covert flags (e.g., if we had a stealth mode flag)
                // no_covert_flags = !config.global.stealth_mode;
            }
        }

        // Check if running as root
        let is_root = unsafe { libc::geteuid() == 0 };

        SecurityPosture {
            no_covert_flags,
            least_privilege_enabled: !is_root,
            encryption_active,
        }
    }

    fn fetch_recent_events(&self) -> Vec<AuditEvent> {
        let mut events = Vec::new();
        
        // Try to read systemd journal logs
        if let Ok(output) = std::process::Command::new("journalctl")
            .args(["-u", "rbt", "-n", "10", "--no-pager"])
            .output()
        {
            let logs = String::from_utf8_lossy(&output.stdout);
            for line in logs.lines() {
                if line.is_empty() { continue; }
                events.push(AuditEvent {
                    time: Utc::now(), // We could parse the timestamp from journalctl
                    level: "LOG".to_string(),
                    message: line.to_string(),
                });
            }
        }
        
        if events.is_empty() {
            events.push(AuditEvent {
                time: Utc::now(),
                level: "INFO".to_string(),
                message: "No recent logs found or journalctl unavailable.".to_string(),
            });
        }
        
        events
    }
}
