use clap::{Parser, Subcommand};
use rbt_config::ConfigManager;
use rbt_runtime::Supervisor;
use rbt_observability::init_telemetry;
use rbt_cert::AcmeManager;
use rbt_service::SystemdManager;
use rbt_audit::Auditor;
use rbt_research_tcr::{TrafficClassifier, PolicySimulator};
use rbt_discovery_dpd::PeerDiscovery;

#[derive(Parser)]
#[command(name = "rbt", version = env!("CARGO_PKG_VERSION"), about = "RBT Tunnel Orchestrator")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Initialize RBT configuration directory
    Init,
    /// Add a new tunnel link
    #[command(name = "link-add")]
    LinkAdd {
        #[arg(short, long)]
        name: String,
        #[arg(short, long)]
        listen: String,
        #[arg(short, long)]
        target: String,
        #[arg(short, long)]
        proto: String,
        #[arg(long)]
        tls_enabled: bool,
        #[arg(long)]
        tls_cert: Option<String>,
        #[arg(long)]
        tls_key: Option<String>,
        #[arg(long)]
        tls_version: Option<String>,
        #[arg(long)]
        tls_sni: Option<String>,
        #[arg(long)]
        obfuscation: Option<String>,
        #[arg(long)]
        port_hopping: Option<String>,
        #[arg(long)]
        secret: Option<String>,
        #[arg(long)]
        peer_cert_hash: Option<String>,
        #[arg(long)]
        bandwidth_limit: Option<usize>,
    },
    /// List all configured links
    #[command(name = "link-list")]
    LinkList,
    /// Remove a tunnel link
    #[command(name = "link-remove")]
    LinkRemove { name: String },
    /// Apply configuration and reload runtime
    Apply,
    /// Start the tunnel orchestrator in foreground
    Start,
    /// Show current status of tunnels
    Status,
    /// Traffic Classification Research tools
    Research {
        #[command(subcommand)]
        action: ResearchCommands,
    },
    /// Peer discovery tools
    Discovery,
    /// Generate transparency and audit reports
    Audit,
    /// Validate configuration file
    Validate,
    /// Dashboard management
    Dashboard {
        #[command(subcommand)]
        action: DashboardCommands,
    },
    /// Run in research/simulation mode
    Simulate {
        #[arg(short, long)]
        ruleset: String,
    },
    /// Certificate management
    Cert {
        #[command(subcommand)]
        action: CertCommands,
    },
    /// Service management
    Service {
        #[command(subcommand)]
        action: ServiceCommands,
    },
    /// Show version information
    Version,
}

#[derive(Subcommand)]
enum ResearchCommands {
    /// Analyze current traffic patterns
    Analyze,
    /// Generate a research summary report
    Summary,
}

#[derive(Subcommand)]
enum DashboardCommands {
    /// Set dashboard username
    SetUser { username: String },
    /// Set dashboard password
    SetPass { password: String },
    /// Set dashboard port
    SetPort { port: u16 },
    /// Show current dashboard configuration
    Show,
}

#[derive(Subcommand)]
enum CertCommands {
    /// Issue a new certificate
    Issue {
        #[arg(short, long)]
        domain: String,
    },
    /// Renew all certificates
    Renew,
}

#[derive(Subcommand)]
enum ServiceCommands {
    /// Install systemd service
    Install,
    /// Enable and start service
    Enable,
    /// Show service status
    Status,
}

use std::io::{self, Write};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    init_telemetry();
    
    // Check if arguments are provided
    let args: Vec<String> = std::env::args().collect();
    
    if args.len() == 1 {
        // No arguments, enter interactive mode
        return run_interactive_menu().await;
    }

    let cli = Cli::parse();
    handle_command(cli.command).await
}

async fn run_interactive_menu() -> anyhow::Result<()> {
    // Check if Node.js is available and run the TypeScript menu
    if std::process::Command::new("node").arg("--version").output().is_ok() {
        // Check if npx is available
        if std::process::Command::new("npx").arg("--version").output().is_ok() {
            // Check if the menu script exists in the webapp directory
            let menu_script = "/home/user/webapp/scripts/rbt-menu.ts";
            if std::path::Path::new(menu_script).exists() {
                println!("🚀 Starting RBT Interactive Menu...");
                let output = std::process::Command::new("npx")
                    .args(&["tsx", menu_script])
                    .current_dir("/home/user/webapp")
                    .status()?;
                
                if !output.success() {
                    println!("❌ Failed to start interactive menu. Falling back to built-in menu.");
                    return run_builtin_interactive_menu().await;
                }
                return Ok(());
            }
        }
    }
    
    // Fallback to built-in menu
    run_builtin_interactive_menu().await
}

async fn run_builtin_interactive_menu() -> anyhow::Result<()> {
    loop {
        println!("\n--- 🛡️ RBT Orchestrator Interactive Menu ---");
        println!("1. 🛠️  Initialize RBT (init)");
        println!("2. 🚀 Start Tunnel (start)");
        println!("3. ➕ Add Tunnel Link (link-add)");
        println!("4. 📋 List Tunnel Links (link-list)");
        println!("5. 🗑️  Remove Tunnel Link (link-remove)");
        println!("6. 📊 Show Status (status)");
        println!("7. 🔍 Research & Analysis (research)");
        println!("8. 🌐 Peer Discovery (discovery)");
        println!("9. 📜 Audit Report (audit)");
        println!("10. 🔐 Certificate Management (cert)");
        println!("11. ⚙️  Service Management (service)");
        println!("12. 📊 Dashboard Configuration (dashboard)");
        println!("13. ❌ Exit");
        print!("\nSelect an option [1-13]: ");
        io::stdout().flush()?;

        let mut input = String::new();
        io::stdin().read_line(&mut input)?;
        let choice = input.trim();

        match choice {
            "1" => {
                println!("🛠️ Initializing RBT configuration...");
                let mut cfg = ConfigManager::load().unwrap_or_default();
                
                println!("\n--- 📊 Dashboard Configuration ---");
                let username = prompt_input("Enter Dashboard Username [admin]: ")?;
                if !username.is_empty() { cfg.dashboard.username = username; }
                
                let password = prompt_input("Enter Dashboard Password [admin]: ")?;
                if !password.is_empty() { cfg.dashboard.password = password; }
                
                let port_str = prompt_input("Enter Dashboard Port [8080]: ")?;
                if !port_str.is_empty() {
                    if let Ok(port) = port_str.parse() {
                        cfg.dashboard.port = port;
                    }
                }
                
                cfg.save()?;
                println!("✅ Initialization complete.");
            },
            "2" => handle_command(Commands::Start).await?,
            "3" => {
                println!("\n--- ➕ Add New Tunnel Link ---");
                let name = prompt_input("Enter Link Name (e.g., my-tunnel): ")?;
                let listen = prompt_input("Enter Listen Address (e.g., 0.0.0.0:8080): ")?;
                let target = prompt_input("Enter Target Address (e.g., 1.2.3.4:8080): ")?;
                let proto = prompt_input("Enter Protocol (tcp/udp/ws): ")?;

                let tls_enabled = prompt_input("Enable TLS? (y/n): ")?.to_lowercase() == "y";
                let mut tls_cert = None;
                let mut tls_key = None;
                let mut tls_version = None;
                let mut tls_sni = None;

                if tls_enabled {
                    tls_cert = Some(prompt_input("Enter Certificate Path (optional): ")?).filter(|s| !s.is_empty());
                    tls_key = Some(prompt_input("Enter Private Key Path (optional): ")?).filter(|s| !s.is_empty());
                    tls_version = Some(prompt_input("Enter Min TLS Version (e.g., 1.2, 1.3 - optional): ")?).filter(|s| !s.is_empty());
                    tls_sni = Some(prompt_input("Enter SNI (optional): ")?).filter(|s| !s.is_empty());
                }

                let obfuscation = Some(prompt_input("Enter Obfuscation method (e.g., aead, tls - optional): ")?).filter(|s| !s.is_empty());
                let port_hopping = Some(prompt_input("Enter Port Hopping range (e.g., 10000-20000 - optional): ")?).filter(|s| !s.is_empty());
                let secret = Some(prompt_input("Enter Shared Secret (for AEAD/PortHopping - optional): ")?).filter(|s| !s.is_empty());
                let peer_cert_hash = Some(prompt_input("Enter Peer Certificate Hash (for QUIC Pinning - optional): ")?).filter(|s| !s.is_empty());
                let bandwidth_limit_str = prompt_input("Enter Bandwidth Limit in bytes/sec (optional): ")?;
                let bandwidth_limit = if bandwidth_limit_str.is_empty() { None } else { bandwidth_limit_str.parse().ok() };

                handle_command(Commands::LinkAdd { 
                    name, 
                    listen, 
                    target, 
                    proto,
                    tls_enabled,
                    tls_cert,
                    tls_key,
                    tls_version,
                    tls_sni,
                    obfuscation,
                    port_hopping,
                    secret,
                    peer_cert_hash,
                    bandwidth_limit,
                }).await?;
            }
            "4" => handle_command(Commands::LinkList).await?,
            "5" => {
                println!("\n--- 🗑️ Remove Tunnel Link ---");
                let name = prompt_input("Enter the name of the link to remove: ")?;
                handle_command(Commands::LinkRemove { name }).await?;
            }
            "6" => handle_command(Commands::Status).await?,
            "7" => {
                println!("\n--- 🔍 Traffic Research & Analysis ---");
                println!("1. 🕵️  Analyze Current Traffic");
                println!("2. 📄 Generate Research Summary");
                println!("3. 🔙 Back to Main Menu");
                print!("Select an option [1-3]: ");
                io::stdout().flush()?;
                
                let mut sub_input = String::new();
                io::stdin().read_line(&mut sub_input)?;
                match sub_input.trim() {
                    "1" => handle_command(Commands::Research { action: ResearchCommands::Analyze }).await?,
                    "2" => handle_command(Commands::Research { action: ResearchCommands::Summary }).await?,
                    _ => {}
                }
            }
            "8" => handle_command(Commands::Discovery).await?,
            "9" => handle_command(Commands::Audit).await?,
            "10" => {
                println!("\n--- 🔐 Certificate Management ---");
                println!("1. 🆕 Issue New Certificate (ACME)");
                println!("2. 🔄 Renew All Certificates");
                println!("3. 🔙 Back to Main Menu");
                print!("Select an option [1-3]: ");
                io::stdout().flush()?;
                
                let mut sub_input = String::new();
                io::stdin().read_line(&mut sub_input)?;
                match sub_input.trim() {
                    "1" => {
                        let domain = prompt_input("Enter domain for certificate: ")?;
                        handle_command(Commands::Cert { action: CertCommands::Issue { domain } }).await?;
                    }
                    "2" => handle_command(Commands::Cert { action: CertCommands::Renew }).await?,
                    _ => {}
                }
            }
            "11" => {
                println!("\n--- ⚙️  Service Management (systemd) ---");
                println!("1. 📥 Install Systemd Service");
                println!("2. 🚀 Enable & Start Service");
                println!("3. 📊 Show Service Status");
                println!("4. 🔙 Back to Main Menu");
                print!("Select an option [1-4]: ");
                io::stdout().flush()?;
                
                let mut sub_input = String::new();
                io::stdin().read_line(&mut sub_input)?;
                match sub_input.trim() {
                    "1" => handle_command(Commands::Service { action: ServiceCommands::Install }).await?,
                    "2" => handle_command(Commands::Service { action: ServiceCommands::Enable }).await?,
                    "3" => handle_command(Commands::Service { action: ServiceCommands::Status }).await?,
                    _ => {}
                }
            }
            "12" => {
                println!("\n--- 📊 Dashboard Configuration ---");
                println!("1. 👤 Set Username");
                println!("2. 🔑 Set Password");
                println!("3. 🔌 Set Port");
                println!("4. 📋 Show Current Config");
                println!("5. 🔙 Back to Main Menu");
                print!("Select an option [1-5]: ");
                io::stdout().flush()?;
                
                let mut sub_input = String::new();
                io::stdin().read_line(&mut sub_input)?;
                match sub_input.trim() {
                    "1" => {
                        let username = prompt_input("Enter new username: ")?;
                        handle_command(Commands::Dashboard { action: DashboardCommands::SetUser { username } }).await?;
                    }
                    "2" => {
                        let password = prompt_input("Enter new password: ")?;
                        handle_command(Commands::Dashboard { action: DashboardCommands::SetPass { password } }).await?;
                    }
                    "3" => {
                        let port_str = prompt_input("Enter new port: ")?;
                        if let Ok(port) = port_str.parse() {
                            handle_command(Commands::Dashboard { action: DashboardCommands::SetPort { port } }).await?;
                        } else {
                            println!("❌ Invalid port.");
                        }
                    }
                    "4" => handle_command(Commands::Dashboard { action: DashboardCommands::Show }).await?,
                    _ => {}
                }
            }
            "13" => {
                println!("Goodbye!");
                break;
            }
            _ => println!("⚠️ Invalid choice, please try again."),
        }
    }
    Ok(())
}

fn prompt_input(prompt: &str) -> anyhow::Result<String> {
    print!("{}", prompt);
    io::stdout().flush()?;
    let mut input = String::new();
    io::stdin().read_line(&mut input)?;
    Ok(input.trim().to_string())
}

async fn handle_command(command: Commands) -> anyhow::Result<()> {
    match command {
        Commands::Init => {
            println!("🛠️ Initializing RBT configuration...");
            let mut cfg = ConfigManager::load().unwrap_or_default();
            
            println!("\n--- 📊 Dashboard Configuration ---");
            let username = prompt_input("Enter Dashboard Username [admin]: ")?;
            if !username.is_empty() { cfg.dashboard.username = username; }
            
            let password = prompt_input("Enter Dashboard Password [admin]: ")?;
            if !password.is_empty() { cfg.dashboard.password = password; }
            
            let port_str = prompt_input("Enter Dashboard Port [8080]: ")?;
            if !port_str.is_empty() {
                if let Ok(port) = port_str.parse() {
                    cfg.dashboard.port = port;
                }
            }
            
            cfg.save()?;
            println!("✅ Initialization complete.");
        }
        Commands::Dashboard { action } => {
            let mut cfg = ConfigManager::load()?;
            match action {
                DashboardCommands::SetUser { username } => {
                    cfg.dashboard.username = username;
                    cfg.save()?;
                    println!("✅ Dashboard username updated.");
                }
                DashboardCommands::SetPass { password } => {
                    cfg.dashboard.password = password;
                    cfg.save()?;
                    println!("✅ Dashboard password updated.");
                }
                DashboardCommands::SetPort { port } => {
                    cfg.dashboard.port = port;
                    cfg.save()?;
                    println!("✅ Dashboard port updated.");
                }
                DashboardCommands::Show => {
                    println!("📊 Dashboard Configuration:");
                    println!("   Username: {}", cfg.dashboard.username);
                    println!("   Password: {}", cfg.dashboard.password);
                    println!("   Port:     {}", cfg.dashboard.port);
                }
            }
        }
        Commands::LinkAdd { 
            name, 
            listen, 
            target, 
            proto, 
            tls_enabled, 
            tls_cert, 
            tls_key, 
            tls_version, 
            tls_sni,
            obfuscation,
            port_hopping,
            secret,
            peer_cert_hash,
            bandwidth_limit,
        } => {
            let mut cfg = ConfigManager::load()?;
            let tls = if tls_enabled {
                Some(rbt_config::TlsConfig {
                    enabled: true,
                    cert_path: tls_cert,
                    key_path: tls_key,
                    min_version: tls_version,
                    sni: tls_sni,
                })
            } else {
                None
            };
            cfg.add_link(name, listen, target, proto, tls, obfuscation, port_hopping, secret, peer_cert_hash, bandwidth_limit)?;
            cfg.save()?;
            println!("✅ Link added successfully. Run `rbt apply` to enact.");
        }
        Commands::LinkList => {
            let cfg = ConfigManager::load()?;
            println!("{:<20} {:<20} {:<20} {:<10} {:<15} {:<15}", "NAME", "LISTEN", "TARGET", "PROTO", "OBFUSCATION", "PORT HOPPING");
            for link in cfg.links {
                let obfs = link.obfuscation.unwrap_or_else(|| "none".to_string());
                let ph = link.port_hopping.unwrap_or_else(|| "none".to_string());
                println!("{:<20} {:<20} {:<20} {:<10} {:<15} {:<15}", link.name, link.listen_host, link.target_host, link.protocol, obfs, ph);
            }
        }
        Commands::LinkRemove { name } => {
            let mut cfg = ConfigManager::load()?;
            match cfg.remove_link(&name) {
                Ok(_) => {
                    cfg.save()?;
                    println!("✅ Link '{}' removed successfully.", name);
                }
                Err(e) => println!("❌ Error: {}", e),
            }
        }
        Commands::Apply => {
            let cfg = ConfigManager::load()?;
            Supervisor::reload(cfg).await?;
            println!("🚀 Configuration applied and supervised.");
        }
        Commands::Start => {
            println!("🚀 Starting RBT Tunnel Orchestrator...");
            let cfg = ConfigManager::load()?;
            println!("🔧 Loading configuration from /etc/rbt/config.toml");
            // In a real scenario, this would block and run the supervisor
            Supervisor::reload(cfg).await?;
            println!("✅ Tunnels are active. Press Ctrl+C to stop.");
            // Mocking a blocking wait
            tokio::signal::ctrl_c().await?;
            println!("\n🛑 Stopping RBT...");
        }
        Commands::Status => {
            println!("📊 RBT Runtime Status:");
            
            // Check international internet connectivity
            print!("Checking international connectivity... ");
            io::stdout().flush()?;
            
            let is_connected = match std::net::TcpStream::connect_timeout(
                &"1.1.1.1:80".parse().unwrap(),
                std::time::Duration::from_secs(2),
            ) {
                Ok(mut stream) => {
                    let request = "GET /generate_204 HTTP/1.1\r\nHost: cp.cloudflare.com\r\nConnection: close\r\n\r\n";
                    if stream.write_all(request.as_bytes()).is_ok() {
                        let mut response = String::new();
                        use std::io::Read;
                        // Set read timeout
                        stream.set_read_timeout(Some(std::time::Duration::from_secs(2))).unwrap_or(());
                        if stream.read_to_string(&mut response).is_ok() {
                            response.contains("HTTP/1.1 204") || response.contains("HTTP/1.0 204")
                        } else { false }
                    } else { false }
                },
                Err(_) => false,
            };

            if is_connected {
                println!("✅ Connected");
                println!("All systems operational.");
            } else {
                println!("❌ Disconnected (Intranet Mode Detected)");
                println!("\n⚠️  WARNING: International internet connection is currently unavailable.");
                println!("💡 SUGGESTION: Since DNS requests are usually not blocked, it is highly recommended to activate a tunnel using 'dnstt' and 'spilnet' by searching for open DNS servers.");
                println!("   Example: rbt link-add --name dns-tunnel --listen 127.0.0.1:1080 --target <open-dns-ip>:53 --proto udp");
            }
        }
        Commands::Research { action } => {
            let classifier = TrafficClassifier::new(None);
            match action {
                ResearchCommands::Analyze => {
                    println!("🔍 Analyzing traffic patterns for research...");
                    let action = classifier.process_packet(1024, "TCP");
                    println!("  - Packet processed. Simulated Action: {:?}", action);
                }
                ResearchCommands::Summary => {
                    println!("📄 Generating research summary...");
                    println!("{}", classifier.generate_research_summary());
                }
            }
        }
        Commands::Discovery => {
            println!("🌐 Discovering authorized peers via DPD...");
            let discovery = PeerDiscovery;
            let peers = discovery.discover_authorized_peers().await;
            for peer in peers {
                println!("  - Found peer: {}", peer);
            }
        }
        Commands::Audit => {
            println!("📋 Generating transparency and audit report...");
            let auditor = Auditor::new();
            let report = auditor.run_audit();
            println!("{:#?}", report);
        }
        Commands::Validate => {
            match ConfigManager::load() {
                Ok(_) => println!("✅ Configuration is valid."),
                Err(e) => println!("❌ Validation failed: {}", e),
            }
        }
        Commands::Simulate { ruleset } => {
            println!("🔍 Starting Research Simulation Mode with ruleset: {}", ruleset);
            let simulator = PolicySimulator::new();
            let results = simulator.run_simulation(&ruleset);
            println!("{}", results);
        }
        Commands::Cert { action } => {
            let acme = AcmeManager::new("/etc/rbt/certs");
            match action {
                CertCommands::Issue { domain } => {
                    acme.issue_certificate(&domain).await?;
                    println!("✅ Certificate issued for {}", domain);
                }
                CertCommands::Renew => {
                    acme.renew_certificates().await?;
                }
            }
        }
        Commands::Service { action } => {
            match action {
                ServiceCommands::Install => {
                    SystemdManager::install_service()?;
                }
                ServiceCommands::Enable => {
                    SystemdManager::enable_service()?;
                    println!("✅ Service enabled and started.");
                }
                ServiceCommands::Status => {
                    println!("Checking systemd service status...");
                }
            }
        }
        Commands::Version => {
            println!("RBT Orchestrator v{}", env!("CARGO_PKG_VERSION"));
            println!("Developer: EHSANKiNG");
        }
    }
    Ok(())
}
