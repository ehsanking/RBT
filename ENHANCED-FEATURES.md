# RBT Enhanced Features Documentation

## Overview

RBT Enhanced provides a comprehensive tunnel orchestration platform with advanced features including security auditing, real-time monitoring, automatic backup/recovery, and an interactive management system.

## 🚀 Quick Start

### One-Line Installation

```bash
# Enhanced installer with all features
bash <(curl -sSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-complete-enhanced.sh)

# Interactive menu only
bash <(curl -sSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-complete-enhanced.sh) --menu-only

# Non-interactive with custom settings
bash <(curl -sSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-complete-enhanced.sh) \
    --non-interactive --admin-user admin --admin-pass mypassword --port 8080
```

## 📋 Enhanced Features

### 1. Advanced Configuration Management

The enhanced configuration manager provides:

- **Validation**: Comprehensive validation of all configuration parameters
- **Backup/Restore**: Automatic configuration backup with restore capabilities
- **System Optimization**: Automatic system tuning for optimal performance
- **Security Hardening**: Built-in security best practices

```bash
# Validate configuration
tsx scripts/config-manager.ts validate

# Create backup
tsx scripts/config-manager.ts backup

# List backups
tsx scripts/config-manager.ts list-backups

# Apply system optimizations
tsx scripts/config-manager.ts optimize
```

### 2. Comprehensive Monitoring System

Real-time monitoring with advanced metrics:

- **System Metrics**: CPU, memory, disk, network, processes
- **Tunnel Metrics**: Connections, throughput, latency, errors
- **Performance Metrics**: Bandwidth utilization, packet loss, jitter
- **Alerting**: Configurable thresholds with multiple severity levels

```bash
# Start monitoring
tsx scripts/monitor.ts start

# View current metrics
tsx scripts/monitor.ts metrics

# View alerts
tsx scripts/monitor.ts alerts

# Set alert threshold
tsx scripts/monitor.ts threshold cpu 80
```

### 3. Advanced Security Management

Enterprise-grade security features:

- **Certificate Management**: Automatic SSL/TLS certificate generation and renewal
- **Security Auditing**: Comprehensive security assessments with scoring
- **Access Control**: Role-based access with audit logging
- **Threat Detection**: Real-time security monitoring and alerting

```bash
# Initialize security
tsx scripts/security-manager.ts init

# Generate certificate
tsx scripts/security-manager.ts generate-cert example.com

# Run security audit
tsx scripts/security-manager.ts audit

# List certificates
tsx scripts/security-manager.ts list-certs
```

### 4. Interactive Menu System

User-friendly numbered menu interface:

- **Quick Start**: Guided setup for first-time users
- **Configuration Management**: Easy configuration updates
- **Tunnel Management**: Visual tunnel creation and management
- **Monitoring Dashboard**: Real-time system and tunnel statistics
- **Security Center**: Certificate and security management
- **System Tools**: Backup, restore, and system utilities

```bash
# Start interactive menu
npm run rbt-menu

# Or directly
npx tsx scripts/rbt-menu.ts
```

### 5. Comprehensive Testing Framework

Automated testing with multiple test suites:

- **Unit Tests**: Individual component testing
- **Integration Tests**: Component interaction testing
- **End-to-End Tests**: Complete workflow testing
- **Performance Tests**: Load and performance testing
- **Security Tests**: Security vulnerability testing

```bash
# Run all tests
npm test

# Run specific test suite
tsx scripts/test-suite.ts config
tsx scripts/test-suite.ts security
tsx scripts/test-suite.ts monitor

# Generate test report
tsx scripts/test-suite.ts run
```

### 6. CI/CD Pipeline

Automated continuous integration and deployment:

- **Multi-Platform Testing**: Ubuntu, Debian, CentOS
- **Security Scanning**: Vulnerability and dependency scanning
- **Performance Benchmarking**: Automated performance testing
- **Documentation Generation**: Automatic API documentation
- **Release Management**: Automated package creation and distribution

## 🔧 Configuration Reference

### Environment Variables

```bash
# Core Settings
JWT_SECRET=your-secure-jwt-secret
DASHBOARD_PORT=3000
DASHBOARD_HOST=0.0.0.0

# Security
FORCE_HTTPS=true
SESSION_TIMEOUT=24h
MAX_LOGIN_ATTEMPTS=5
LOCKOUT_DURATION=15m
ENABLE_SECURITY_AUDITING=true

# hCaptcha (Optional)
VITE_HCAPTCHA_SITE_KEY=your-site-key
HCAPTCHA_SECRET_KEY=your-secret-key

# SMTP (Optional)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
NOTIFICATION_EMAIL=notifications@yourdomain.com

# Monitoring
ENABLE_MONITORING=true
MONITORING_PORT=9090
ENABLE_METRICS=true
METRICS_PORT=9091

# Performance
ENABLE_ZERO_COPY=true
ENABLE_BBR=true
TCP_BUFFER_SIZE=16MB
MAX_FILE_DESCRIPTORS=65536
```

### Configuration File (config.toml)

```toml
[dashboard]
username = "admin"
password = "your-password"
port = 3000
host = "0.0.0.0"
enable_rate_limiting = true
rate_limit_window = 900000
rate_limit_max = 100

[security]
jwt_secret = "your-jwt-secret"
session_timeout = "24h"
max_login_attempts = 5
lockout_duration = "15m"
force_https = true
enable_audit_logging = true
enable_auto_backup = true

[monitoring]
enable_metrics = true
metrics_port = 9091
monitoring_port = 9090
enable_health_checks = true
health_check_interval = 30000
enable_alerts = true

[logging]
level = "info"
file = "/var/log/rbt/rbt.log"
max_size = "100MB"
max_backups = 10
max_age = 30
enable_compression = true

[performance]
enable_zero_copy = true
enable_bbr = true
tcp_buffer_size = "16MB"
max_file_descriptors = 65536
worker_processes = 4

[backup]
enable_auto_backup = true
backup_interval = 24
backup_retention = 30
```

## 📊 Monitoring and Metrics

### Available Metrics

#### System Metrics
- CPU usage, load average, core count
- Memory usage, available memory
- Disk usage, available space
- Network bytes in/out, packets, errors
- Process count by state

#### Tunnel Metrics
- Active connections per tunnel
- Bytes transferred (in/out)
- Packets transferred (in/out)
- Error rates
- Uptime and status

#### Performance Metrics
- Tunnel latency (ms)
- Throughput (Mbps)
- Packet loss (%)
- Jitter (ms)
- Bandwidth utilization (%)

### Alert Thresholds

Configure alert thresholds for different metrics:

```bash
# CPU usage alert at 80%
tsx scripts/monitor.ts threshold cpu 80

# Memory usage alert at 85%
tsx scripts/monitor.ts threshold memory 85

# Disk usage alert at 90%
tsx scripts/monitor.ts threshold disk 90

# Tunnel connections alert at 1000
tsx scripts/monitor.ts threshold tunnel 1000
```

## 🔐 Security Features

### Certificate Management

Automatic SSL/TLS certificate lifecycle management:

```bash
# Generate certificate
tsx scripts/security-manager.ts generate-cert example.com

# List certificates
tsx scripts/security-manager.ts list-certs

# Revoke certificate
tsx scripts/security-manager.ts revoke-cert example.com
```

### Security Auditing

Comprehensive security assessments:

```bash
# Run full security audit
tsx scripts/security-manager.ts audit

# View audit logs
tsx scripts/security-manager.ts logs

# Check specific certificate
tsx scripts/security-manager.ts cert-info example.com
```

### Security Policies

Configurable security policies:

- **Password Policy**: Minimum length, complexity requirements, expiration
- **Session Policy**: Timeout, concurrent sessions, MFA requirements
- **Access Policy**: Login attempts, lockout duration, IP restrictions
- **Certificate Policy**: Key length, algorithms, validity period

## 🔄 Backup and Recovery

### Automatic Backup

Configure automatic configuration backups:

```bash
# Enable automatic backup
tsx scripts/config-manager.ts backup

# List available backups
tsx scripts/config-manager.ts list-backups

# Restore from backup
tsx scripts/config-manager.ts restore backup-file.json
```

### Manual Backup

Create manual backups at any time:

```bash
# Create backup
tsx scripts/backup.ts create

# List backups
tsx scripts/backup.ts list

# Restore backup
tsx scripts/restore.ts restore backup-name
```

## 🚀 Deployment Options

### Systemd Service

Automatic systemd service creation:

```bash
# Create service
sudo systemctl enable rbt
sudo systemctl start rbt
sudo systemctl status rbt
```

### Docker Deployment

Container deployment support:

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000 9090 9091
CMD ["npm", "start"]
```

### Kubernetes Deployment

Helm charts and Kubernetes manifests:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rbt
spec:
  replicas: 3
  selector:
    matchLabels:
      app: rbt
  template:
    metadata:
      labels:
        app: rbt
    spec:
      containers:
      - name: rbt
        image: rbt:latest
        ports:
        - containerPort: 3000
        - containerPort: 9090
        - containerPort: 9091
```

## 📈 Performance Optimization

### System Optimization

Automatic system tuning:

```bash
# Apply system optimizations
tsx scripts/config-manager.ts optimize

# Optimize network settings
tsx scripts/config-manager.ts optimize-network

# Optimize file descriptors
tsx scripts/config-manager.ts optimize-fd
```

### Performance Monitoring

Real-time performance tracking:

```bash
# View performance metrics
tsx scripts/monitor.ts performance

# Benchmark system
tsx scripts/benchmark.ts run

# Compare performance
tsx scripts/benchmark.ts compare
```

## 🔧 Troubleshooting

### Common Issues

1. **Port Already in Use**
   ```bash
   # Check port usage
   netstat -tuln | grep :3000
   
   # Change port in configuration
   sed -i 's/port = 3000/port = 8080/' config.toml
   ```

2. **Permission Denied**
   ```bash
   # Fix file permissions
   chmod 600 .env config.toml
   chown -R rbt:rbt /var/log/rbt
   ```

3. **Service Won't Start**
   ```bash
   # Check service logs
   journalctl -u rbt -f
   
   # Test configuration
   tsx scripts/config-manager.ts validate
   ```

4. **Certificate Issues**
   ```bash
   # Regenerate certificate
   tsx scripts/security-manager.ts generate-cert domain.com
   
   # Check certificate validity
   tsx scripts/security-manager.ts cert-info domain.com
   ```

### Debug Mode

Enable debug logging:

```bash
# Set debug environment
export DEBUG=true
export LOG_LEVEL=debug

# Run with debug output
npm run rbt-menu -- --debug
```

### Log Analysis

Analyze logs for issues:

```bash
# View recent logs
tail -f /var/log/rbt/rbt.log

# Search for errors
grep -i error /var/log/rbt/rbt.log

# Monitor in real-time
tsx scripts/monitor.ts logs
```

## 📚 API Reference

### REST API

The enhanced RBT provides a comprehensive REST API:

#### Authentication
```http
POST /api/auth/login
Content-Type: application/json

{
  "username": "admin",
  "password": "password",
  "captcha": "captcha-response"
}
```

#### Tunnels
```http
# List tunnels
GET /api/tunnels

# Create tunnel
POST /api/tunnels
Content-Type: application/json

{
  "name": "web-tunnel",
  "listen": "0.0.0.0:8080",
  "target": "localhost:3000",
  "protocol": "tcp"
}

# Delete tunnel
DELETE /api/tunnels/{id}
```

#### Metrics
```http
# Get system metrics
GET /api/metrics/system

# Get tunnel metrics
GET /api/metrics/tunnels

# Get performance metrics
GET /api/metrics/performance
```

#### Security
```http
# Get security status
GET /api/security/status

# Run security audit
POST /api/security/audit

# Get certificates
GET /api/security/certificates
```

### WebSocket API

Real-time updates via WebSocket:

```javascript
const ws = new WebSocket('ws://localhost:3000/api/ws');

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log('Real-time update:', data);
};
```

## 🛠️ Development

### Setting Up Development Environment

```bash
# Clone repository
git clone https://github.com/EHSANKiNG/RBT.git
cd RBT

# Install dependencies
npm install

# Install Rust components
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# Build project
npm run build
cargo build --release
```

### Running Tests

```bash
# Run all tests
npm test

# Run specific test suite
tsx scripts/test-suite.ts config
tsx scripts/test-suite.ts security
tsx scripts/test-suite.ts monitor

# Run with coverage
npm run test:coverage
```

### Development Scripts

```bash
# Start development server
npm run dev

# Run interactive installer in development
tsx scripts/enhanced-installer.ts --dev-mode

# Test monitoring
tsx scripts/monitor.ts start

# Test security features
tsx scripts/security-manager.ts audit
```

## 📋 Best Practices

### Security Best Practices

1. **Use Strong Passwords**: Implement complex password requirements
2. **Enable HTTPS**: Always use encrypted connections
3. **Regular Audits**: Run security audits frequently
4. **Certificate Management**: Keep certificates updated
5. **Access Logging**: Enable comprehensive audit logging
6. **Network Security**: Use firewalls and network segmentation

### Performance Best Practices

1. **System Optimization**: Enable BBR and TCP optimizations
2. **Resource Monitoring**: Monitor CPU, memory, and disk usage
3. **Connection Limits**: Set appropriate connection limits
4. **Log Rotation**: Configure proper log rotation
5. **Backup Strategy**: Implement regular backup procedures

### Operational Best Practices

1. **Monitoring**: Enable comprehensive monitoring
2. **Alerting**: Configure meaningful alert thresholds
3. **Documentation**: Keep configuration documented
4. **Testing**: Regular testing of backup/restore procedures
5. **Updates**: Keep software updated

## 🆘 Support

### Getting Help

1. **Documentation**: Check this documentation first
2. **Logs**: Review system and application logs
3. **Community**: Join the community forums
4. **Issues**: Report issues on GitHub
5. **Support**: Contact support for enterprise assistance

### Reporting Issues

When reporting issues, include:

- System information (OS, version, architecture)
- RBT version and configuration
- Error messages and logs
- Steps to reproduce the issue
- Expected vs actual behavior

### Contributing

We welcome contributions:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Rust community for the excellent tooling
- Node.js community for the runtime environment
- All contributors who have helped improve RBT

---

For more information, visit the [RBT GitHub repository](https://github.com/EHSANKiNG/RBT) or check the [interactive guide](INTERACTIVE-GUIDE.md).