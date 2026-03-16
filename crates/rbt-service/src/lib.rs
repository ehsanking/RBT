use anyhow::Result;
use std::fs;
use std::path::Path;
use tracing::{info, warn, error};

pub struct SystemdManager;

impl SystemdManager {
    const SERVICE_TEMPLATE: &'static str = r#"
[Unit]
Description=RBT Tunnel Orchestrator
Documentation=https://github.com/EHSANKiNG/RBT
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/rbt apply
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
RestartSec=5
LimitNOFILE=1048576
LimitNPROC=51200
TasksMax=infinity

# Hardening & Least Privilege
User=rbt
Group=rbt
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/etc/rbt/certs /var/log/rbt
PrivateTmp=yes
ProtectKernelTunables=yes
ProtectControlGroups=yes
RestrictNamespaces=yes
LockPersonality=yes

[Install]
WantedBy=multi-user.target
"#;

    pub fn install_service() -> Result<()> {
        let service_path = Path::new("/etc/systemd/system/rbt.service");
        
        info!("Generating hardened systemd unit file...");
        
        if let Some(parent) = service_path.parent() {
            fs::create_dir_all(parent).unwrap_or_else(|e| warn!("Could not create systemd directory: {}", e));
        }

        match fs::write(service_path, Self::SERVICE_TEMPLATE) {
            Ok(_) => info!("✅ Service file written to {}", service_path.display()),
            Err(e) => {
                warn!("⚠️ Could not write to /etc/systemd/system/rbt.service (Permission denied?). Saving to ./rbt.service instead.");
                fs::write("./rbt.service", Self::SERVICE_TEMPLATE)?;
            }
        }
        
        info!("Service installed. Run `systemctl daemon-reload` and `systemctl enable --now rbt` as root.");
        Ok(())
    }

    pub fn enable_service() -> Result<()> {
        info!("Enabling and starting RBT service...");
        let status = std::process::Command::new("systemctl")
            .args(["enable", "--now", "rbt"])
            .status();
            
        match status {
            Ok(s) if s.success() => info!("✅ Service enabled and started."),
            Ok(s) => warn!("⚠️ systemctl exited with error: {}", s),
            Err(e) => warn!("⚠️ Could not run systemctl: {}", e),
        }
        Ok(())
    }
}
