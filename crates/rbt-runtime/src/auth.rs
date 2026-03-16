use tokio::io::{AsyncReadExt, AsyncWriteExt, AsyncRead, AsyncWrite};
use sha2::{Sha256, Digest};
use rand::Rng;
use rand::rngs::OsRng;

pub async fn client_handshake<S: AsyncWrite + Unpin>(stream: &mut S, secret: &str) -> anyhow::Result<()> {
    let mut hasher = Sha256::new();
    hasher.update(secret.as_bytes());
    let token = hasher.finalize();
    
    // Write 32-byte token
    stream.write_all(&token).await?;
    
    // Write random padding (0-255 bytes)
    let mut rng = OsRng;
    let pad_len: u8 = rng.gen();
    stream.write_u8(pad_len).await?;
    
    let padding: Vec<u8> = (0..pad_len).map(|_| rng.gen()).collect();
    stream.write_all(&padding).await?;
    
    Ok(())
}

pub async fn server_handshake<S: AsyncRead + Unpin>(stream: &mut S, secret: &str) -> anyhow::Result<()> {
    let mut hasher = Sha256::new();
    hasher.update(secret.as_bytes());
    let expected_token = hasher.finalize();
    
    let mut token = [0u8; 32];
    stream.read_exact(&mut token).await?;
    
    if token != expected_token.as_slice() {
        return Err(anyhow::anyhow!("Authentication failed: invalid token"));
    }
    
    let pad_len = stream.read_u8().await?;
    let mut padding = vec![0u8; pad_len as usize];
    stream.read_exact(&mut padding).await?;
    
    Ok(())
}
