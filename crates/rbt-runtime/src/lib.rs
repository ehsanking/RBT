pub mod auth;

use rbt_config::{ConfigManager, LinkConfig};
use tokio::time::{sleep, Duration};
use tokio::net::{TcpListener, TcpStream};
use tokio::io::{copy_bidirectional, AsyncReadExt, AsyncWriteExt};
use tracing::{info, warn, error};
use std::sync::Arc;
use quinn::{Endpoint, ServerConfig};
use rustls::{Certificate, PrivateKey, ServerName};
use rustls::client::{ServerCertVerifier, ServerCertVerified};
use sha2::{Sha256, Digest};
use std::time::{SystemTime, UNIX_EPOCH};
use chacha20::ChaCha20;
use chacha20::cipher::{KeyIvInit, StreamCipher};
use aead::{Aead, AeadInPlace};
use std::fs;
use std::path::Path;
use std::os::unix::io::AsRawFd;
use tokio::net::tcp::{OwnedReadHalf, OwnedWriteHalf};

#[cfg(target_os = "linux")]
struct PipeGuard(std::os::unix::io::RawFd, std::os::unix::io::RawFd);

#[cfg(target_os = "linux")]
impl Drop for PipeGuard {
    fn drop(&mut self) {
        let _ = nix::unistd::close(self.0);
        let _ = nix::unistd::close(self.1);
    }
}

#[cfg(target_os = "linux")]
async fn splice_one_way(reader: &OwnedReadHalf, writer: &OwnedWriteHalf, bandwidth_limit: Option<usize>) -> anyhow::Result<()> {
    let (pipe_rd, pipe_wr) = nix::unistd::pipe()?;
    let _guard = PipeGuard(pipe_rd, pipe_wr);
    
    // Set non-blocking for pipes
    let _ = nix::fcntl::fcntl(pipe_rd, nix::fcntl::FcntlArg::F_SETFL(nix::fcntl::OFlag::O_NONBLOCK));
    let _ = nix::fcntl::fcntl(pipe_wr, nix::fcntl::FcntlArg::F_SETFL(nix::fcntl::OFlag::O_NONBLOCK));

    let in_fd = reader.as_ref().as_raw_fd();
    let out_fd = writer.as_ref().as_raw_fd();

    let mut tokens = bandwidth_limit.map(|l| l as f64);
    let mut last_update = tokio::time::Instant::now();

    loop {
        if let Some(limit) = bandwidth_limit {
            let now = tokio::time::Instant::now();
            let elapsed = now.duration_since(last_update).as_secs_f64();
            if let Some(ref mut t) = tokens {
                *t += elapsed * (limit as f64);
                if *t > limit as f64 {
                    *t = limit as f64;
                }
                if *t < 1.0 {
                    tokio::time::sleep(tokio::time::Duration::from_millis(10)).await;
                    continue;
                }
            }
            last_update = now;
        }

        // Wait for reader to be readable
        reader.readable().await?;
        
        let chunk_size = if let Some(ref t) = tokens {
            std::cmp::min(65536, *t as usize)
        } else {
            65536
        };

        let n = unsafe {
            libc::splice(
                in_fd,
                std::ptr::null_mut(),
                pipe_wr,
                std::ptr::null_mut(),
                chunk_size,
                libc::SPLICE_F_MOVE | libc::SPLICE_F_NONBLOCK,
            )
        };

        if n < 0 {
            let err = std::io::Error::last_os_error();
            if err.kind() == std::io::ErrorKind::WouldBlock {
                continue;
            }
            return Err(err.into());
        }
        if n == 0 {
            break;
        }

        if let Some(ref mut t) = tokens {
            *t -= n as f64;
        }

        let mut left = n;
        while left > 0 {
            // Wait for writer to be writable
            writer.writable().await?;
            
            let m = unsafe {
                libc::splice(
                    pipe_rd,
                    std::ptr::null_mut(),
                    out_fd,
                    std::ptr::null_mut(),
                    left as usize,
                    libc::SPLICE_F_MOVE | libc::SPLICE_F_NONBLOCK,
                )
            };

            if m < 0 {
                let err = std::io::Error::last_os_error();
                if err.kind() == std::io::ErrorKind::WouldBlock {
                    // This shouldn't happen often for pipes if we just wrote to them,
                    // but we should handle it.
                    tokio::task::yield_now().await;
                    continue;
                }
                return Err(err.into());
            }
            left -= m;
        }
    }
    
    Ok(())
}

async fn copy_with_limit<R, W>(mut reader: R, mut writer: W, bandwidth_limit: Option<usize>) -> anyhow::Result<()>
where
    R: tokio::io::AsyncRead + Unpin,
    W: tokio::io::AsyncWrite + Unpin,
{
    if let Some(limit) = bandwidth_limit {
        let mut buf = [0u8; 8192];
        let mut tokens = limit as f64;
        let mut last_update = tokio::time::Instant::now();
        
        loop {
            let now = tokio::time::Instant::now();
            let elapsed = now.duration_since(last_update).as_secs_f64();
            tokens += elapsed * (limit as f64);
            if tokens > limit as f64 { tokens = limit as f64; }
            last_update = now;

            if tokens < 1.0 {
                tokio::time::sleep(tokio::time::Duration::from_millis(10)).await;
                continue;
            }

            let chunk = std::cmp::min(buf.len(), tokens as usize);
            let n = match tokio::io::AsyncReadExt::read(&mut reader, &mut buf[..chunk]).await {
                Ok(0) => break,
                Ok(n) => n,
                Err(e) => return Err(e.into()),
            };
            
            tokens -= n as f64;
            tokio::io::AsyncWriteExt::write_all(&mut writer, &buf[..n]).await?;
        }
    } else {
        tokio::io::copy(&mut reader, &mut writer).await?;
    }
    Ok(())
}

#[cfg(not(target_os = "linux"))]
async fn splice_one_way(mut reader: OwnedReadHalf, mut writer: OwnedWriteHalf, bandwidth_limit: Option<usize>) -> anyhow::Result<()> {
    copy_with_limit(reader, writer, bandwidth_limit).await
}

async fn copy_bidirectional_zero_copy(inbound: TcpStream, outbound: TcpStream, bandwidth_limit: Option<usize>) -> anyhow::Result<()> {
    let (in_rd, in_wr) = inbound.into_split();
    let (out_rd, out_wr) = outbound.into_split();
    
    let task1 = splice_one_way(&in_rd, &out_wr, bandwidth_limit);
    let task2 = splice_one_way(&out_rd, &in_wr, bandwidth_limit);
    
    tokio::select! {
        res1 = task1 => res1?,
        res2 = task2 => res2?,
    }
    Ok(())
}

struct SkipServerVerification;

impl SkipServerVerification {
    fn new() -> Self {
        Self
    }
}

impl ServerCertVerifier for SkipServerVerification {
    fn verify_server_cert(
        &self,
        _end_entity: &Certificate,
        _intermediates: &[Certificate],
        _server_name: &ServerName,
        _scts: &mut dyn Iterator<Item = &[u8]>,
        _ocsp_response: &[u8],
        _now: SystemTime,
    ) -> Result<rustls::client::ServerCertVerified, rustls::Error> {
        Ok(rustls::client::ServerCertVerified::assertion())
    }
}

struct PinnedCertVerifier {
    expected_hash: String,
}

impl PinnedCertVerifier {
    fn new(hash: String) -> Self {
        Self { expected_hash: hash }
    }
}

impl ServerCertVerifier for PinnedCertVerifier {
    fn verify_server_cert(
        &self,
        end_entity: &Certificate,
        _intermediates: &[Certificate],
        _server_name: &ServerName,
        _scts: &mut dyn Iterator<Item = &[u8]>,
        _ocsp_response: &[u8],
        _now: SystemTime,
    ) -> Result<rustls::client::ServerCertVerified, rustls::Error> {
        let mut hasher = Sha256::new();
        hasher.update(&end_entity.0);
        let actual_hash = hex::encode(hasher.finalize());
        
        if actual_hash == self.expected_hash {
            info!("Certificate pinning successful: hash matches");
            Ok(rustls::client::ServerCertVerified::assertion())
        } else {
            error!(actual = %actual_hash, expected = %self.expected_hash, "Certificate pinning FAILED: hash mismatch");
            Err(rustls::Error::InvalidCertificate("Pinned hash mismatch".to_string()))
        }
    }
}

pub struct Supervisor;

impl Supervisor {
    pub async fn reload(config: ConfigManager) -> anyhow::Result<()> {
        info!("Reloading supervisor with {} links", config.links.len());
        for link in config.links {
            let link_clone = link.clone();
            
            tokio::spawn(async move {
                if let Some(ref port_range) = link_clone.port_hopping {
                    Self::supervise_port_hopping(link_clone).await;
                } else {
                    Self::supervise_single_link(link_clone).await;
                }
            });
        }
        Ok(())
    }

    pub async fn supervise_port_hopping(link: LinkConfig) {
        let name = link.name.clone();
        info!(tunnel = %name, "Initializing dynamic Port Hopping (Anti-Censorship)");
        
        // Parse port range (e.g., "10000-20000")
        let range_str = match link.port_hopping.as_ref() {
            Some(r) => r,
            None => {
                error!("port_hopping config is missing");
                return;
            }
        };
        let range: Vec<&str> = range_str.split('-').collect();
        if range.len() != 2 {
            error!("Invalid port_hopping format. Use 'MIN-MAX' (e.g. '10000-20000')");
            return;
        }
        let min_port: u16 = range[0].parse().unwrap_or(10000);
        let max_port: u16 = range[1].parse().unwrap_or(20000);
        let secret = link.secret.as_deref().unwrap_or("rbt_default_secret_v1");

        let mut current_task: Option<tokio::task::JoinHandle<()>> = None;
        let mut last_port = 0;

        loop {
        // Time-based port selection (changes every 5 minutes)
        let ts = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_secs() / 300)
            .unwrap_or(0);
        let mut hasher = Sha256::new();
            hasher.update(format!("{}-{}", secret, ts).as_bytes());
            let hash = hasher.finalize();
            
            // Calculate deterministic port within range
            let port_offset = u16::from_be_bytes([hash[0], hash[1]]) % (max_port - min_port);
            let active_port = min_port + port_offset;

            if active_port != last_port {
                info!(tunnel = %name, active_port, "Port Hopping: Switching to new port to evade DPI");
                
                if let Some(task) = current_task.take() {
                    task.abort(); // Stop listening on the old port
                }

                let mut new_link = link.clone();
                // Replace the port in listen_host
                let (ip, _) = new_link.listen_host.rsplit_once(':').unwrap_or(("0.0.0.0", ""));
                new_link.listen_host = format!("{}:{}", ip, active_port);

                current_task = Some(tokio::spawn(async move {
                    Self::supervise_single_link(new_link).await;
                }));

                last_port = active_port;
            }

            sleep(Duration::from_secs(10)).await; // Check every 10 seconds
        }
    }

    pub async fn supervise_single_link(link: LinkConfig) {
        let name = link.name.clone();
        let listen = link.listen_host.clone();
        let target = link.target_host.clone();
        let proto = link.protocol.clone();
        let obfuscation = link.obfuscation.clone();
        let secret = link.secret.clone();
        let peer_cert_hash = link.peer_cert_hash.clone();
        let bandwidth_limit = link.bandwidth_limit;

        if proto == "tcp" {
            let is_client = listen.starts_with("127.0.0.1") || listen.starts_with("localhost");
            Self::supervise_tcp_tunnel(name, listen, target, obfuscation, secret, is_client, bandwidth_limit).await;
        } else if proto == "quic" {
            if listen.starts_with("127.0.0.1") || listen.starts_with("localhost") {
                Self::supervise_quic_tcp_client(name, listen, target, secret, peer_cert_hash, bandwidth_limit).await;
            } else {
                Self::supervise_quic_tcp_server(name, listen, target, secret, bandwidth_limit).await;
            }
        } else if proto == "udp" {
            // Heuristic to determine client or server mode based on listen address
            if listen.starts_with("127.0.0.1") || listen.starts_with("localhost") {
                Self::supervise_quic_udp_client(name, listen, target, secret, peer_cert_hash, bandwidth_limit).await;
            } else {
                Self::supervise_quic_udp_server(name, listen, target, secret, bandwidth_limit).await;
            }
        } else {
            Self::supervise_tunnel(name, target).await;
        }
    }

    pub async fn supervise_tcp_tunnel(name: String, listen: String, target: String, obfuscation: Option<String>, secret: Option<String>, is_client: bool, bandwidth_limit: Option<usize>) {
        info!(tunnel = %name, listen = %listen, "Starting highly-optimized TCP tunnel");
        
        let listener = match TcpListener::bind(&listen).await {
            Ok(l) => l,
            Err(e) => {
                error!(tunnel = %name, error = %e, "Failed to bind listener");
                return;
            }
        };

        loop {
            match listener.accept().await {
                Ok((mut inbound, addr)) => {
                    let target = target.clone();
                    let name = name.clone();
                    let secret = secret.clone();
                    let obfuscation = obfuscation.clone();
                    let bw_limit = bandwidth_limit;
                    
                    tokio::spawn(async move {
                        // 1. TCP_NODELAY: Disable Nagle's algorithm for lower latency
                        if let Err(e) = inbound.set_nodelay(true) {
                            warn!(tunnel = %name, peer = %addr, error = %e, "Failed to set TCP_NODELAY on inbound");
                        }

                        match TcpStream::connect(&target).await {
                            Ok(mut outbound) => {
                                // 2. TCP_NODELAY on outbound
                                if let Err(e) = outbound.set_nodelay(true) {
                                    warn!(tunnel = %name, target = %target, error = %e, "Failed to set TCP_NODELAY on outbound");
                                }

                                // 2.5 Authentication & Padding
                                if let Some(ref sec) = secret {
                                    if is_client {
                                        if let Err(e) = crate::auth::client_handshake(&mut outbound, sec).await {
                                            error!(tunnel = %name, error = %e, "Client handshake failed");
                                            return;
                                        }
                                    } else {
                                        if let Err(e) = crate::auth::server_handshake(&mut inbound, sec).await {
                                            error!(tunnel = %name, error = %e, "Server handshake failed (unauthorized access attempt)");
                                            return;
                                        }
                                    }
                                }

                                // 3. Zero-Copy / Splice OR Obfuscation
                                if let Some(ref obfs) = obfuscation {
                                    if obfs == "aead" {
                                        info!(tunnel = %name, "Applying ChaCha20 Stream Obfuscation (Anti-DPI)");
                                        
                                        let secret_str = secret.as_deref().unwrap_or("rbt_default_secret_v1");
                                        let mut hasher = Sha256::new();
                                        hasher.update(secret_str.as_bytes());
                                        let key_bytes = hasher.finalize();
                                        
                                        let (mut ri, mut wi) = inbound.split();
                                        let (mut ro, mut wo) = outbound.split();
                                        
                                        let key_bytes_clone = key_bytes.clone();
                                        let c2s = tokio::spawn(async move {
                                            let mut cipher = ChaCha20::new(&key_bytes_clone.into(), &[0u8; 12].into());
                                            let mut buf = [0u8; 8192];
                                            let mut tokens = bw_limit.map(|l| l as f64);
                                            let mut last_update = tokio::time::Instant::now();

                                            while let Ok(n) = ri.read(&mut buf).await {
                                                if n == 0 { break; }

                                                if let Some(limit) = bw_limit {
                                                    let now = tokio::time::Instant::now();
                                                    let elapsed = now.duration_since(last_update).as_secs_f64();
                                                    if let Some(ref mut t) = tokens {
                                                        *t += elapsed * (limit as f64);
                                                        if *t > limit as f64 { *t = limit as f64; }
                                                        if *t < n as f64 {
                                                            tokio::time::sleep(tokio::time::Duration::from_millis(10)).await;
                                                        }
                                                        *t -= n as f64;
                                                    }
                                                    last_update = now;
                                                }

                                                cipher.apply_keystream(&mut buf[..n]);
                                                if wo.write_all(&buf[..n]).await.is_err() { break; }
                                            }
                                        });

                                        let s2c = tokio::spawn(async move {
                                            let mut cipher = ChaCha20::new(&key_bytes.into(), &[0u8; 12].into());
                                            let mut buf = [0u8; 8192];
                                            let mut tokens = bw_limit.map(|l| l as f64);
                                            let mut last_update = tokio::time::Instant::now();

                                            while let Ok(n) = ro.read(&mut buf).await {
                                                if n == 0 { break; }

                                                if let Some(limit) = bw_limit {
                                                    let now = tokio::time::Instant::now();
                                                    let elapsed = now.duration_since(last_update).as_secs_f64();
                                                    if let Some(ref mut t) = tokens {
                                                        *t += elapsed * (limit as f64);
                                                        if *t > limit as f64 { *t = limit as f64; }
                                                        if *t < n as f64 {
                                                            tokio::time::sleep(tokio::time::Duration::from_millis(10)).await;
                                                        }
                                                        *t -= n as f64;
                                                    }
                                                    last_update = now;
                                                }

                                                cipher.apply_keystream(&mut buf[..n]);
                                                if wi.write_all(&mut buf[..n]).await.is_err() { break; }
                                            }
                                        });
                                        
                                        let _ = tokio::try_join!(c2s, s2c);
                                    } else {
                                        let _ = copy_bidirectional_zero_copy(inbound, outbound, bw_limit).await;
                                    }
                                } else {
                                    // Standard Zero-Copy Splice
                                    match copy_bidirectional_zero_copy(inbound, outbound, bw_limit).await {
                                        Ok(_) => {}
                                        Err(e) => warn!(tunnel = %name, error = %e, "Connection error during copy"),
                                    }
                                }
                            }
                            Err(e) => {
                                error!(tunnel = %name, target = %target, error = %e, "Failed to connect to target");
                            }
                        }
                    });
                }
                Err(e) => {
                    error!(tunnel = %name, error = %e, "Failed to accept connection");
                    sleep(Duration::from_millis(100)).await; // Backoff on accept failure
                }
            }
        }
    }

    fn get_or_generate_certs(name: &str) -> (Vec<Certificate>, PrivateKey) {
        let cert_path = format!("/etc/rbt/certs/{}.crt", name);
        let key_path = format!("/etc/rbt/certs/{}.key", name);
        
        if Path::new(&cert_path).exists() && Path::new(&key_path).exists() {
            if let (Ok(cert_der), Ok(key_der)) = (fs::read(&cert_path), fs::read(&key_path)) {
                return (vec![Certificate(cert_der)], PrivateKey(key_der));
            }
        }

        info!("Generating new persistent certificate for tunnel: {}", name);
        let cert = match rcgen::generate_simple_self_signed(vec!["localhost".into(), name.into()]) {
            Ok(c) => c,
            Err(e) => {
                error!("Failed to generate self-signed certificate: {}", e);
                // Fallback to a very basic cert if possible, or return empty (will fail later)
                return (vec![], PrivateKey(vec![]));
            }
        };
        let cert_der = cert.serialize_der().unwrap_or_default();
        let priv_key = cert.serialize_private_key_der();
        
        fs::create_dir_all("/etc/rbt/certs").unwrap_or(());
        fs::write(&cert_path, &cert_der).unwrap_or(());
        fs::write(&key_path, &priv_key).unwrap_or(());
        
        (vec![Certificate(cert_der)], PrivateKey(priv_key))
    }

    pub async fn supervise_quic_tcp_server(name: String, listen: String, target: String, secret: Option<String>, bandwidth_limit: Option<usize>) {
        info!(tunnel = %name, listen = %listen, "Starting QUIC (TCP) tunnel SERVER");

        let (cert_chain, key) = Self::get_or_generate_certs(&name);
        
        // Log the certificate hash so the user can pin it
        let mut hasher = Sha256::new();
        hasher.update(&cert_chain[0].0);
        let hash = hex::encode(hasher.finalize());
        info!(tunnel = %name, cert_hash = %hash, "Server certificate hash (for client pinning)");

        let mut server_crypto = match rustls::ServerConfig::builder()
            .with_safe_defaults()
            .with_no_client_auth()
            .with_single_cert(cert_chain, key) {
                Ok(c) => c,
                Err(e) => {
                    error!(tunnel = %name, error = %e, "Failed to configure TLS for QUIC");
                    return;
                }
            };
        
        server_crypto.alpn_protocols = vec![b"rbt-quic-tunnel".to_vec()];
        let server_config = ServerConfig::with_crypto(Arc::new(server_crypto));

        let endpoint = match listen.parse() {
            Ok(addr) => match Endpoint::server(server_config, addr) {
                Ok(ep) => ep,
                Err(e) => {
                    error!(tunnel = %name, error = %e, "Failed to bind QUIC endpoint");
                    return;
                }
            },
            Err(e) => {
                error!(tunnel = %name, error = %e, "Invalid listen address for QUIC");
                return;
            }
        };

        while let Some(conn) = endpoint.accept().await {
            let target = target.clone();
            let name = name.clone();
            let secret = secret.clone();
            let bw_limit = bandwidth_limit;
            
            tokio::spawn(async move {
                match conn.await {
                    Ok(connection) => {
                        info!(tunnel = %name, "QUIC connection established");
                        // Accept a bidirectional stream from the client
                        while let Ok((mut quic_send, mut quic_recv)) = connection.accept_bi().await {
                            let target = target.clone();
                            let name = name.clone();
                            let secret = secret.clone();
                            let bw_limit = bw_limit;
                            
                            tokio::spawn(async move {
                                // Authentication & Padding
                                if let Some(ref sec) = secret {
                                    if let Err(e) = crate::auth::server_handshake(&mut quic_recv, sec).await {
                                        error!(tunnel = %name, error = %e, "QUIC server handshake failed (unauthorized access attempt)");
                                        return;
                                    }
                                }

                                // Connect to the actual target via TCP
                                match TcpStream::connect(&target).await {
                                    Ok(mut tcp_stream) => {
                                        if let Err(e) = tcp_stream.set_nodelay(true) {
                                            warn!("Failed to set TCP_NODELAY: {}", e);
                                        }
                                        
                                        let (mut tcp_rd, mut tcp_wr) = tcp_stream.into_split();
                                        
                                        let c2s = tokio::spawn(async move {
                                            let _ = copy_with_limit(&mut quic_recv, &mut tcp_wr, bw_limit).await;
                                        });
                                        let s2c = tokio::spawn(async move {
                                            let _ = copy_with_limit(&mut tcp_rd, &mut quic_send, bw_limit).await;
                                        });
                                        let _ = tokio::try_join!(c2s, s2c);
                                    }
                                    Err(e) => {
                                        error!(tunnel = %name, target = %target, error = %e, "Failed to connect to target");
                                    }
                                }
                            });
                        }
                    }
                    Err(e) => {
                        warn!(tunnel = %name, error = %e, "QUIC connection failed");
                    }
                }
            });
        }
    }

    pub async fn supervise_quic_tcp_client(name: String, listen: String, target: String, _secret: Option<String>, peer_cert_hash: Option<String>, bandwidth_limit: Option<usize>) {
        info!(tunnel = %name, listen = %listen, "Starting QUIC (TCP) tunnel CLIENT");

        let verifier: Arc<dyn ServerCertVerifier> = if let Some(hash) = peer_cert_hash {
            info!(tunnel = %name, hash = %hash, "Using Certificate Pinning for QUIC client");
            Arc::new(PinnedCertVerifier::new(hash))
        } else {
            warn!(tunnel = %name, "QUIC client: Certificate verification is DISABLED (MITM risk)");
            Arc::new(SkipServerVerification::new())
        };

        let mut client_crypto = rustls::ClientConfig::builder()
            .with_safe_defaults()
            .with_custom_certificate_verifier(verifier)
            .with_no_client_auth();
            
        client_crypto.alpn_protocols = vec![b"rbt-quic-tunnel".to_vec()];
        
        let mut client_config = quinn::ClientConfig::new(Arc::new(client_crypto));
        let mut transport_config = quinn::TransportConfig::default();
        transport_config.max_idle_timeout(Some(quinn::IdleTimeout::try_from(std::time::Duration::from_secs(60)).unwrap()));
        transport_config.keep_alive_interval(Some(std::time::Duration::from_secs(15)));
        client_config.transport_config(Arc::new(transport_config));

        let is_ipv6 = target.parse::<std::net::SocketAddr>().map(|a| a.is_ipv6()).unwrap_or(false);
        let bind_addr = if is_ipv6 { "[::]:0" } else { "0.0.0.0:0" };
        let mut endpoint = match Endpoint::client(bind_addr.parse().unwrap()) {
            Ok(ep) => ep,
            Err(e) => {
                error!(tunnel = %name, error = %e, "Failed to create QUIC client endpoint");
                return;
            }
        };
        endpoint.set_default_client_config(client_config);

        let server_addr = match target.parse() {
            Ok(addr) => addr,
            Err(e) => {
                error!(tunnel = %name, error = %e, "Invalid target address for QUIC client");
                return;
            }
        };
        
        let listener = match TcpListener::bind(&listen).await {
            Ok(l) => l,
            Err(e) => {
                error!(tunnel = %name, error = %e, "Failed to bind TCP listener for QUIC client");
                return;
            }
        };

        loop {
            match listener.accept().await {
                Ok((mut inbound, _)) => {
                    let endpoint = endpoint.clone();
                    let server_addr = server_addr;
                    let name = name.clone();
                    let secret = _secret.clone();
                    let bw_limit = bandwidth_limit;
                    
                    tokio::spawn(async move {
                        let connection = match endpoint.connect(server_addr, "localhost") {
                            Ok(connecting) => match connecting.await {
                                Ok(conn) => conn,
                                Err(e) => {
                                    error!(tunnel = %name, error = %e, "Failed to establish QUIC connection");
                                    return;
                                }
                            },
                            Err(e) => {
                                error!(tunnel = %name, error = %e, "Failed to initiate QUIC connection");
                                return;
                            }
                        };

                        match connection.open_bi().await {
                            Ok((mut quic_send, mut quic_recv)) => {
                                // Authentication & Padding
                                if let Some(ref sec) = secret {
                                    if let Err(e) = crate::auth::client_handshake(&mut quic_send, sec).await {
                                        error!(tunnel = %name, error = %e, "QUIC client handshake failed");
                                        return;
                                    }
                                }

                                let (mut ri, mut wi) = inbound.split();
                                let c2s = tokio::spawn(async move {
                                    let _ = copy_with_limit(&mut ri, &mut quic_send, bw_limit).await;
                                });
                                let s2c = tokio::spawn(async move {
                                    let _ = copy_with_limit(&mut quic_recv, &mut wi, bw_limit).await;
                                });
                                let _ = tokio::join!(c2s, s2c);
                            }
                            Err(e) => {
                                error!(tunnel = %name, error = %e, "Failed to open QUIC stream");
                            }
                        }
                    });
                }
                Err(e) => {
                    error!(tunnel = %name, error = %e, "Failed to accept TCP connection");
                }
            }
        }
    }

    pub async fn supervise_quic_udp_server(name: String, listen: String, target: String, _secret: Option<String>, bandwidth_limit: Option<usize>) {
        info!(tunnel = %name, listen = %listen, "Starting QUIC Datagram SERVER for UDP traffic");

        let (cert_chain, key) = Self::get_or_generate_certs(&name);
        
        // Log the certificate hash so the user can pin it
        let mut hasher = Sha256::new();
        hasher.update(&cert_chain[0].0);
        let hash = hex::encode(hasher.finalize());
        info!(tunnel = %name, cert_hash = %hash, "Server certificate hash (for client pinning)");

        let mut server_crypto = match rustls::ServerConfig::builder()
            .with_safe_defaults()
            .with_no_client_auth()
            .with_single_cert(cert_chain, key) {
                Ok(c) => c,
                Err(e) => {
                    error!(tunnel = %name, error = %e, "Failed to configure TLS for QUIC UDP");
                    return;
                }
            };
        
        server_crypto.alpn_protocols = vec![b"rbt-quic-udp".to_vec()];
        
        let mut server_config = ServerConfig::with_crypto(Arc::new(server_crypto));
        
        // Enable datagrams in transport config
        let mut transport_config = quinn::TransportConfig::default();
        transport_config.datagram_receive_buffer_size(65536);
        transport_config.datagram_send_buffer_size(65536);
        transport_config.max_idle_timeout(Some(quinn::IdleTimeout::try_from(std::time::Duration::from_secs(60)).unwrap()));
        transport_config.keep_alive_interval(Some(std::time::Duration::from_secs(15)));
        server_config.transport_config(Arc::new(transport_config));

        let endpoint = match listen.parse() {
            Ok(addr) => match Endpoint::server(server_config, addr) {
                Ok(ep) => ep,
                Err(e) => {
                    error!(tunnel = %name, error = %e, "Failed to bind QUIC UDP endpoint");
                    return;
                }
            },
            Err(e) => {
                error!(tunnel = %name, error = %e, "Invalid listen address for QUIC UDP");
                return;
            }
        };

        while let Some(conn) = endpoint.accept().await {
            let target = target.clone();
            let name = name.clone();
            let secret = _secret.clone();
            let bw_limit = bandwidth_limit;
            
            tokio::spawn(async move {
                match conn.await {
                    Ok(connection) => {
                        info!(tunnel = %name, "QUIC Datagram connection established");

                        // For UDP over QUIC, we can't easily do a handshake over datagrams reliably here without a protocol.
                        // We will use a dedicated bidirectional stream for authentication before allowing datagrams.
                        if let Some(ref sec) = secret {
                            match connection.accept_bi().await {
                                Ok((mut _send, mut recv)) => {
                                    if let Err(e) = crate::auth::server_handshake(&mut recv, sec).await {
                                        error!(tunnel = %name, error = %e, "QUIC UDP server handshake failed (unauthorized access attempt)");
                                        return;
                                    }
                                }
                                Err(e) => {
                                    error!(tunnel = %name, error = %e, "Failed to accept auth stream for QUIC UDP");
                                    return;
                                }
                            }
                        }
                        
                        // Connect to the actual UDP target
                        let is_ipv6 = target.parse::<std::net::SocketAddr>().map(|a| a.is_ipv6()).unwrap_or(false);
                        let bind_addr = if is_ipv6 { "[::]:0" } else { "0.0.0.0:0" };
                        let target_socket = match tokio::net::UdpSocket::bind(bind_addr).await {
                            Ok(s) => s,
                            Err(e) => {
                                error!("Failed to bind local UDP socket: {}", e);
                                return;
                            }
                        };
                        
                        if let Err(e) = target_socket.connect(&target).await {
                            error!("Failed to connect to UDP target {}: {}", target, e);
                            return;
                        }
                        
                        let target_socket = Arc::new(target_socket);
                        
                        // QUIC -> UDP Target
                        let conn_clone = connection.clone();
                        let ts_clone = target_socket.clone();
                        let name_clone = name.clone();
                        
                        // Use tokio::select to prevent zombie tasks (Resource Leak Fix)
                        tokio::select! {
                            _ = async {
                                let mut tokens = bw_limit.map(|l| l as f64);
                                let mut last_update = tokio::time::Instant::now();
                                while let Ok(datagram) = conn_clone.read_datagram().await {
                                    if let Some(limit) = bw_limit {
                                        let now = tokio::time::Instant::now();
                                        let elapsed = now.duration_since(last_update).as_secs_f64();
                                        if let Some(ref mut t) = tokens {
                                            *t += elapsed * (limit as f64);
                                            if *t > limit as f64 { *t = limit as f64; }
                                            if *t < datagram.len() as f64 {
                                                tokio::time::sleep(tokio::time::Duration::from_millis(10)).await;
                                            }
                                            *t -= datagram.len() as f64;
                                        }
                                        last_update = now;
                                    }
                                    if let Err(e) = ts_clone.send(&datagram).await {
                                        warn!(tunnel = %name_clone, error = %e, "Failed to send UDP datagram to target");
                                        break;
                                    }
                                }
                            } => {}
                            _ = async {
                                let mut buf = [0u8; 65536];
                                let mut tokens = bw_limit.map(|l| l as f64);
                                let mut last_update = tokio::time::Instant::now();
                                while let Ok(len) = target_socket.recv(&mut buf).await {
                                    if let Some(limit) = bw_limit {
                                        let now = tokio::time::Instant::now();
                                        let elapsed = now.duration_since(last_update).as_secs_f64();
                                        if let Some(ref mut t) = tokens {
                                            *t += elapsed * (limit as f64);
                                            if *t > limit as f64 { *t = limit as f64; }
                                            if *t < len as f64 {
                                                tokio::time::sleep(tokio::time::Duration::from_millis(10)).await;
                                            }
                                            *t -= len as f64;
                                        }
                                        last_update = now;
                                    }
                                    let data = bytes::Bytes::copy_from_slice(&buf[..len]);
                                    if let Err(e) = connection.send_datagram(data) {
                                        warn!(tunnel = %name, error = %e, "Failed to send QUIC datagram to client");
                                        break;
                                    }
                                }
                            } => {}
                        }
                    }
                    Err(e) => {
                        warn!(tunnel = %name, error = %e, "QUIC connection failed");
                    }
                }
            });
        }
    }

    pub async fn supervise_quic_udp_client(name: String, listen: String, target: String, secret: Option<String>, peer_cert_hash: Option<String>, bandwidth_limit: Option<usize>) {
        info!(tunnel = %name, listen = %listen, "Starting QUIC Datagram CLIENT for UDP traffic");

        let verifier: Arc<dyn ServerCertVerifier> = if let Some(hash) = peer_cert_hash {
            info!(tunnel = %name, hash = %hash, "Using Certificate Pinning for QUIC client");
            Arc::new(PinnedCertVerifier::new(hash))
        } else {
            warn!(tunnel = %name, "QUIC client: Certificate verification is DISABLED (MITM risk)");
            Arc::new(SkipServerVerification::new())
        };

        let mut client_crypto = rustls::ClientConfig::builder()
            .with_safe_defaults()
            .with_custom_certificate_verifier(verifier)
            .with_no_client_auth();
            
        client_crypto.alpn_protocols = vec![b"rbt-quic-udp".to_vec()];
        
        let mut client_config = quinn::ClientConfig::new(Arc::new(client_crypto));
        let mut transport_config = quinn::TransportConfig::default();
        transport_config.datagram_receive_buffer_size(65536);
        transport_config.datagram_send_buffer_size(65536);
        transport_config.max_idle_timeout(Some(quinn::IdleTimeout::try_from(std::time::Duration::from_secs(60)).unwrap()));
        transport_config.keep_alive_interval(Some(std::time::Duration::from_secs(15)));
        client_config.transport_config(Arc::new(transport_config));

        let is_ipv6 = target.parse::<std::net::SocketAddr>().map(|a| a.is_ipv6()).unwrap_or(false);
        let bind_addr = if is_ipv6 { "[::]:0" } else { "0.0.0.0:0" };
        let mut endpoint = match Endpoint::client(bind_addr.parse().unwrap()) {
            Ok(ep) => ep,
            Err(e) => {
                error!(tunnel = %name, error = %e, "Failed to create QUIC client endpoint");
                return;
            }
        };
        endpoint.set_default_client_config(client_config);

        let server_addr = match target.parse() {
            Ok(addr) => addr,
            Err(e) => {
                error!(tunnel = %name, error = %e, "Invalid target address for QUIC client");
                return;
            }
        };
        
        let connection = match endpoint.connect(server_addr, "localhost") {
            Ok(connecting) => match connecting.await {
                Ok(conn) => conn,
                Err(e) => {
                    error!(tunnel = %name, error = %e, "Failed to establish QUIC connection");
                    return;
                }
            },
            Err(e) => {
                error!(tunnel = %name, error = %e, "Failed to initiate QUIC connection");
                return;
            }
        };

        // For UDP over QUIC, we use a dedicated bidirectional stream for authentication before allowing datagrams.
        if let Some(ref sec) = secret {
            match connection.open_bi().await {
                Ok((mut send, mut _recv)) => {
                    if let Err(e) = crate::auth::client_handshake(&mut send, sec).await {
                        error!(tunnel = %name, error = %e, "QUIC UDP client handshake failed");
                        return;
                    }
                }
                Err(e) => {
                    error!(tunnel = %name, error = %e, "Failed to open auth stream for QUIC UDP");
                    return;
                }
            }
        }

        let local_socket = match tokio::net::UdpSocket::bind(&listen).await {
            Ok(s) => Arc::new(s),
            Err(e) => {
                error!("Failed to bind local UDP socket: {}", e);
                return;
            }
        };

        info!(tunnel = %name, "QUIC Datagram client connected to server");

        let conn_clone = connection.clone();
        let ls_clone = local_socket.clone();
        let name_clone = name.clone();
        let bw_limit = bandwidth_limit;
        
        let mut last_peer = None;

        // Use tokio::select to prevent zombie tasks
        tokio::select! {
            _ = async {
                let mut buf = [0u8; 65536];
                let mut tokens = bw_limit.map(|l| l as f64);
                let mut last_update = tokio::time::Instant::now();
                while let Ok((len, peer)) = local_socket.recv_from(&mut buf).await {
                    last_peer = Some(peer);
                    if let Some(limit) = bw_limit {
                        let now = tokio::time::Instant::now();
                        let elapsed = now.duration_since(last_update).as_secs_f64();
                        if let Some(ref mut t) = tokens {
                            *t += elapsed * (limit as f64);
                            if *t > limit as f64 { *t = limit as f64; }
                            if *t < len as f64 {
                                tokio::time::sleep(tokio::time::Duration::from_millis(10)).await;
                            }
                            *t -= len as f64;
                        }
                        last_update = now;
                    }
                    let data = bytes::Bytes::copy_from_slice(&buf[..len]);
                    if let Err(e) = connection.send_datagram(data) {
                        warn!(tunnel = %name, error = %e, "Failed to send QUIC datagram to server");
                        break;
                    }
                }
            } => {}
            _ = async {
                let mut tokens = bw_limit.map(|l| l as f64);
                let mut last_update = tokio::time::Instant::now();
                while let Ok(datagram) = conn_clone.read_datagram().await {
                    if let Some(peer) = last_peer {
                        if let Some(limit) = bw_limit {
                            let now = tokio::time::Instant::now();
                            let elapsed = now.duration_since(last_update).as_secs_f64();
                            if let Some(ref mut t) = tokens {
                                *t += elapsed * (limit as f64);
                                if *t > limit as f64 { *t = limit as f64; }
                                if *t < datagram.len() as f64 {
                                    tokio::time::sleep(tokio::time::Duration::from_millis(10)).await;
                                }
                                *t -= datagram.len() as f64;
                            }
                            last_update = now;
                        }
                        if let Err(e) = ls_clone.send_to(&datagram, peer).await {
                            warn!(tunnel = %name_clone, error = %e, "Failed to send UDP datagram to local client");
                            break;
                        }
                    }
                }
            } => {}
        }
    }

    pub async fn supervise_tunnel(name: String, target: String) {
        let mut backoff = Duration::from_secs(1);
        let max_backoff = Duration::from_secs(60);

        loop {
            info!(tunnel = %name, target = %target, "Starting generic tunnel process");
            
            let result = Self::run_rstun_process(&target).await;

            match result {
                Ok(_) => {
                    info!(tunnel = %name, "Tunnel exited gracefully");
                    break;
                }
                Err(e) => {
                    error!(tunnel = %name, error = %e, "Tunnel crashed");
                    warn!(tunnel = %name, "Restarting in {:?}", backoff);
                    sleep(backoff).await;
                    backoff = std::cmp::min(backoff * 2, max_backoff);
                }
            }
        }
    }

    async fn run_rstun_process(_target: &str) -> anyhow::Result<()> {
        // Mocking process execution for non-TCP protocols
        sleep(Duration::from_secs(2)).await;
        Err(anyhow::anyhow!("Simulated crash for backoff demonstration"))
    }
}
