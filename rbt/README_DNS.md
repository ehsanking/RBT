# RBT DNS Manager - Advanced DNS Testing and Selection System

## Overview

The RBT DNS Manager is a comprehensive DNS testing, selection, and monitoring system designed for the RBT (Research-Based Tunneling) project. It provides automated DNS server selection, stability measurement, failover capabilities, and DNS tunneling support for censorship resistance, with special focus on Iranian network conditions.

## Features

### 🔍 DNS Testing and Selection
- **Comprehensive DNS Database**: Access to 62,791 DNS servers from 193 countries
- **Automated Testing**: Concurrent testing of DNS servers with latency, reliability, and DNSSEC support
- **Smart Selection**: Intelligent selection of best DNS servers based on multiple criteria
- **Geographic Optimization**: Preferential selection based on country and region
- **Failover Support**: Automatic failover to backup DNS servers

### 🛡️ Censorship Resistance
- **DNS Poisoning Detection**: Detects DNS poisoning and censorship attempts
- **DNS-over-TLS Support**: Tests and configures DNS-over-TLS for encrypted queries
- **DNS-over-HTTPS Support**: Tests and configures DNS-over-HTTPS for web-based DNS
- **DNS Tunneling**: Full DNSTT (DNS tunneling) integration for extreme censorship scenarios

### 🇮🇷 Iranian Network Focus
- **Iranian DNS Testing**: Specialized testing for Iranian network conditions
- **Censorship Detection**: Detects various censorship methods used in Iran
- **Blocked Domain Testing**: Tests access to commonly blocked domains
- **Alternative Solutions**: Provides multiple circumvention strategies

### 📊 Monitoring and Management
- **Real-time Monitoring**: Continuous monitoring of DNS performance
- **Automated Failover**: Automatic switching to backup DNS servers
- **Performance Metrics**: Detailed performance metrics and reporting
- **Configuration Management**: Centralized configuration system

## Installation

### Quick Install
```bash
# Clone the repository
git clone https://github.com/EHSANKiNG/RBT.git
cd RBT

# Run the installation script
chmod +x install-dns-manager.sh
./install-dns-manager.sh
```

### Manual Installation
```bash
# Install system dependencies
sudo apt-get update
sudo apt-get install python3-pip python3-dev build-essential

# Install Python dependencies
pip3 install dnspython asyncio aiohttp requests pysocks

# Install Go (for dnstt)
wget https://golang.org/dl/go1.21.5.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin

# Copy DNS data files
cp high_reliability_dns.json ~/rbt-dns/data/
cp dns_by_country.json ~/rbt-dns/data/
```

## Usage

### Basic Usage

```bash
# Initialize DNS system
python3 dns_automation.py --init

# Show system status
python3 dns_automation.py --status

# Test DNS performance
python3 dns_automation.py --test-dns
```

### Advanced Usage

```bash
# Setup DNS tunnel for censorship resistance
python3 dns_automation.py --setup-tunnel --domain example.com --server-ip 1.2.3.4

# Start DNS tunnel server
python3 dns_automation.py --start-server --domain example.com

# Start DNS tunnel client
python3 dns_automation.py --start-client --socks-port 9050

# Test tunnel connectivity
python3 dns_automation.py --test-tunnel --socks-port 9050
```

### Iranian Network Testing

```bash
# Run comprehensive Iranian network test
python3 iran_network_tester.py --comprehensive --save-results

# Test specific components
python3 iran_network_tester.py --dns-poisoning
python3 iran_network_tester.py --dns-over-tls
python3 iran_network_tester.py --censorship
python3 iran_network_tester.py --iranian-dns
```

### Preferred Countries Configuration

```bash
# Use preferred countries for DNS selection
python3 dns_automation.py --init --preferred-countries US,CA,GB,DE

# Emergency countries for censorship scenarios
python3 dns_automation.py --init --preferred-countries RU,CN,IR,IN
```

## Configuration

The system uses a comprehensive configuration file (`dns_config.json`) that includes:

### DNS Manager Settings
- Test domains for DNS validation
- Timeout and concurrency settings
- Reliability thresholds
- Preferred and emergency countries
- Monitoring intervals

### DNS Tunnel Settings
- Default SOCKS proxy port
- Server and client configuration
- DNS-over-TLS and DNS-over-HTTPS settings
- Key rotation intervals

### Iranian Testing Settings
- Blocked domains list
- DNS poisoning IP patterns
- Test protocols and methods
- Censorship detection rules

### Performance Metrics
- Latency thresholds (excellent, good, acceptable, degraded, critical)
- Success rate thresholds
- Stability factors and weights

## Architecture

### Core Components

1. **DNS Tester** (`dns_manager.py`)
   - DNS server testing and measurement
   - Latency and reliability analysis
   - Geographic optimization
   - Automated selection algorithms

2. **DNS Tunnel Manager** (`dns_tunnel.py`)
   - DNSTT integration and management
   - Server and client configuration
   - Tunnel setup and monitoring
   - Censorship resistance

3. **Iran Network Tester** (`iran_network_tester.py`)
   - Iranian network condition simulation
   - DNS poisoning detection
   - Censorship resistance testing
   - Alternative solution recommendations

4. **DNS Automation** (`dns_automation.py`)
   - Main automation orchestrator
   - Configuration management
   - System monitoring and control
   - Integration interface

### Data Files

- `high_reliability_dns.json`: High-reliability DNS servers (49,117 servers)
- `dns_by_country.json`: DNS servers organized by country
- `dns_config.json`: Main configuration file
- `dns_test_results_*.json`: Test result files with timestamps

## Testing Methodology

### DNS Performance Testing
1. **Connectivity Test**: Basic UDP/TCP connectivity to DNS server
2. **DNS Query Test**: Standard DNS queries for common domains
3. **Latency Measurement**: Response time measurement
4. **DNSSEC Support**: DNSSEC validation testing
5. **Reliability Assessment**: Success rate over multiple queries

### Censorship Detection
1. **DNS Poisoning Detection**: Comparison against known poisoned responses
2. **Response Analysis**: Pattern matching for censorship indicators
3. **Geographic Testing**: Testing from different geographic perspectives
4. **Protocol Testing**: DNS-over-TLS, DNS-over-HTTPS, DNSTT

### Iranian Network Simulation
1. **Blocked Domain Testing**: Access to commonly blocked domains
2. **DNS Response Analysis**: Detection of Iranian-specific blocking patterns
3. **Alternative Route Testing**: Testing of circumvention methods
4. **Performance Impact**: Measurement of censorship impact on performance

## Results and Metrics

### Performance Metrics
- **Latency**: <20ms (excellent), 20-50ms (good), 50-100ms (acceptable), >100ms (degraded)
- **Success Rate**: >95% (excellent), 80-95% (good), 60-80% (acceptable), <60% (poor)
- **DNSSEC Support**: Preferred for security
- **Geographic Proximity**: Preferential selection based on location

### Censorship Metrics
- **DNS Poisoning**: Detection of manipulated DNS responses
- **Connection Blocking**: Detection of connection resets and blocks
- **Protocol Filtering**: Detection of protocol-specific blocking
- **Content Filtering**: Detection of content-based blocking

## Troubleshooting

### Common Issues

1. **DNS Server Unreachable**
   - Check network connectivity
   - Verify firewall settings
   - Try alternative DNS servers

2. **DNS Tunnel Not Working**
   - Verify domain configuration
   - Check DNS records setup
   - Ensure proper key generation

3. **Iranian Network Tests Failing**
   - Check if running from Iranian IP
   - Verify DNS poisoning detection
   - Try alternative testing methods

4. **Performance Issues**
   - Check server load and resources
   - Verify network bandwidth
   - Optimize DNS selection

### Debug Mode
```bash
# Enable debug logging
export LOG_LEVEL=DEBUG
python3 dns_automation.py --status

# Test specific components
python3 dns_manager.py --debug
python3 dns_tunnel.py --verbose
```

## Security Considerations

### DNS Security
- Prefer DNSSEC-enabled servers
- Use encrypted DNS protocols (DoT, DoH)
- Implement DNS validation
- Monitor for DNS hijacking

### Tunnel Security
- Use strong encryption keys
- Implement key rotation
- Monitor tunnel integrity
- Use secure protocols

### Network Security
- Implement proper firewall rules
- Monitor network traffic
- Use secure connections
- Regular security audits

## Contributing

### Development Setup
```bash
# Clone repository
git clone https://github.com/EHSANKiNG/RBT.git
cd RBT

# Install development dependencies
pip3 install -r requirements-dev.txt

# Run tests
python3 -m pytest tests/

# Run linting
python3 -m flake8 rbt/
```

### Code Standards
- Follow PEP 8 style guidelines
- Add comprehensive docstrings
- Include type hints
- Write unit tests
- Document configuration changes

## License

This project is licensed under the MIT License. See the LICENSE file for details.

## Support

For support and questions:
- Create an issue on GitHub
- Check the documentation
- Review troubleshooting guide
- Contact the development team

## Donations

If you find this project useful, consider supporting its development:

**Tether (USDT):** `TKPswLQqd2e73UTGJ5prxVXBVo7MTsWedU`

**Tron (TRX):** `TKPswLQqd2e73UTGJ5prxVXBVo7MTsWedU`

---

**Built with ❤️ for the Cybersecurity and Networking Community**