use anyhow::{Context, Result};
use tracing::{info, warn, error};
use std::path::PathBuf;
use instant_acme::{Account, ChallengeType, Identifier, LetsEncrypt, NewAccount, NewOrder, OrderStatus};
use rcgen::{CertificateParams, KeyPair};
use std::fs;

pub struct AcmeManager {
    pub cert_dir: PathBuf,
}

impl AcmeManager {
    pub fn new(cert_dir: impl Into<PathBuf>) -> Self {
        Self {
            cert_dir: cert_dir.into(),
        }
    }

    pub async fn issue_certificate(&self, domain: &str) -> Result<()> {
        info!("Initiating Let's Encrypt ACME challenge for domain: {}", domain);
        
        fs::create_dir_all(&self.cert_dir).unwrap_or(());
        
        // 1. Create account
        let (account, _creds) = Account::create(
            &NewAccount {
                contact: &[],
                terms_of_service_agreed: true,
                only_return_existing: false,
            },
            LetsEncrypt::Production.url(),
            None,
        ).await.context("Failed to create ACME account")?;

        // 2. Create order
        let mut order = account.new_order(&NewOrder {
            identifiers: &[Identifier::Dns(domain.to_string())],
        }).await.context("Failed to create ACME order")?;

        // 3. Get authorizations
        let authorizations = order.authorizations().await.context("Failed to get authorizations")?;
        
        for authz in authorizations {
            let challenge = authz.challenges.iter().find(|c| c.r#type == ChallengeType::Http01)
                .context("No HTTP-01 challenge found")?;
                
            let key_auth = order.key_authorization(challenge);
            
            info!("ACME HTTP-01 Challenge required.");
            info!("Please serve the following content at:");
            info!("http://{}/.well-known/acme-challenge/{}", domain, challenge.token);
            info!("Content: {}", key_auth.as_str());
            
            // In a fully automated setup, we would start a temporary HTTP server here on port 80.
            // For now, we simulate the wait for the user to set it up, or we can try to bind port 80.
            
            // Attempt to bind port 80 automatically
            let token = challenge.token.clone();
            let content = key_auth.as_str().to_string();
            
            let server_task = tokio::spawn(async move {
                use tokio::net::TcpListener;
                use tokio::io::{AsyncReadExt, AsyncWriteExt};
                
                let listener = match TcpListener::bind("[::]:80").await {
                    Ok(l) => Ok(l),
                    Err(_) => TcpListener::bind("0.0.0.0:80").await,
                };

                if let Ok(listener) = listener {
                    info!("Started temporary HTTP server on port 80 for ACME challenge");
                    if let Ok((mut stream, _)) = listener.accept().await {
                        let mut buf = [0; 1024];
                        if stream.read(&mut buf).await.is_ok() {
                            let response = format!(
                                "HTTP/1.1 200 OK\r\nContent-Length: {}\r\n\r\n{}",
                                content.len(),
                                content
                            );
                            let _ = stream.write_all(response.as_bytes()).await;
                        }
                    }
                } else {
                    warn!("Could not bind to port 80. Please serve the challenge manually.");
                    tokio::time::sleep(tokio::time::Duration::from_secs(15)).await;
                }
            });

            info!("Setting challenge to ready...");
            order.set_challenge_ready(&challenge.url).await?;
            
            let _ = server_task.await;
        }

        // 4. Wait for order to become ready
        loop {
            let state = order.refresh().await?;
            match state.status {
                OrderStatus::Ready => break,
                OrderStatus::Invalid => anyhow::bail!("Order is invalid"),
                OrderStatus::Pending | OrderStatus::Processing => {
                    tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;
                }
                OrderStatus::Valid => break,
            }
        }

        // 5. Generate CSR and finalize
        let mut params = CertificateParams::new(vec![domain.to_string()]);
        let key_pair = KeyPair::generate(&rcgen::PKCS_ECDSA_P256_SHA256).context("Failed to generate key pair")?;
        let csr = params.serialize_csr(&key_pair).context("Failed to generate CSR")?;

        order.finalize(csr.der()).await.context("Failed to finalize order")?;

        // 6. Wait for certificate
        loop {
            let state = order.refresh().await?;
            if state.status == OrderStatus::Valid {
                break;
            }
            tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;
        }

        let cert_chain_pem = order.certificate().await.context("Failed to download certificate")?;
        
        let cert_path = self.cert_dir.join(format!("{}.crt", domain));
        let key_path = self.cert_dir.join(format!("{}.key", domain));
        
        fs::write(&cert_path, cert_chain_pem.as_ref().expect("Certificate chain missing").as_bytes()).context("Failed to write certificate")?;
        fs::write(&key_path, key_pair.serialize_pem().as_bytes()).context("Failed to write private key")?;
        
        info!("✅ Certificate successfully issued and stored at: {:?}", cert_path);
        info!("✅ Private key stored securely at: {:?}", key_path);
        
        Ok(())
    }

    pub async fn renew_certificates(&self) -> Result<()> {
        info!("Checking for certificates nearing expiration...");
        
        let mut to_renew = Vec::new();

        if let Ok(entries) = fs::read_dir(&self.cert_dir) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.extension().and_then(|s| s.to_str()) == Some("crt") {
                    if let Some(domain) = path.file_stem().and_then(|s| s.to_str()) {
                        if let Ok(content) = fs::read(&path) {
                            if let Ok((_, pem)) = x509_parser::pem::parse_x509_pem(&content) {
                                if let Ok((_, cert)) = x509_parser::parse_x509_certificate(&pem.contents) {
                                    let not_after = cert.validity().not_after.timestamp();
                                    let now = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs() as i64;
                                    
                                    // Check if expiring within 30 days (30 * 24 * 60 * 60 = 2592000 seconds)
                                    if not_after - now < 2592000 {
                                        info!("Certificate for {} is expiring soon. Scheduling renewal.", domain);
                                        to_renew.push(domain.to_string());
                                    } else {
                                        info!("Certificate for {} is valid until timestamp {}.", domain, not_after);
                                    }
                                } else {
                                    warn!("Failed to parse certificate for {}", domain);
                                }
                            } else {
                                warn!("Failed to parse PEM for {}", domain);
                            }
                        }
                    }
                }
            }
        }

        for domain in to_renew {
            if let Err(e) = self.issue_certificate(&domain).await {
                error!("Failed to renew certificate for {}: {}", domain, e);
            } else {
                info!("Successfully renewed certificate for {}", domain);
            }
        }

        Ok(())
    }
}
