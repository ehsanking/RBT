#!/usr/bin/env python3
"""
RBT DNS Manager - Advanced DNS Testing and Selection System
Provides automated DNS server selection, stability measurement, and failover capabilities.
"""

import asyncio
import json
import logging
import subprocess
import time
import statistics
import socket
import dns.resolver
import dns.exception
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import concurrent.futures
import threading
import signal
import sys

class DNSTester:
    """Advanced DNS testing and measurement system"""
    
    def __init__(self):
        self.logger = self._setup_logger()
        self.dns_servers = []
        self.test_domains = [
            'google.com',
            'cloudflare.com', 
            'microsoft.com',
            'amazon.com',
            'github.com'
        ]
        self.timeout = 5.0  # seconds
        self.max_concurrent = 50
        self.semaphore = asyncio.Semaphore(self.max_concurrent)
        
    def _setup_logger(self) -> logging.Logger:
        """Setup logging configuration"""
        logger = logging.getLogger('dns_tester')
        logger.setLevel(logging.INFO)
        
        if not logger.handlers:
            handler = logging.StreamHandler()
            formatter = logging.Formatter(
                '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            )
            handler.setFormatter(formatter)
            logger.addHandler(handler)
            
        return logger
    
    async def load_dns_servers(self, filename: str = None) -> None:
        """Load DNS servers from JSON file"""
        if filename is None:
            filename = Path(__file__).parent / 'high_reliability_dns.json'
            
        try:
            with open(filename, 'r') as f:
                servers = json.load(f)
                self.dns_servers = servers
                self.logger.info(f"Loaded {len(servers)} high-reliability DNS servers")
        except Exception as e:
            self.logger.error(f"Failed to load DNS servers: {e}")
            # Fallback to well-known DNS servers
            self.dns_servers = self._get_fallback_servers()
    
    def _get_fallback_servers(self) -> List[Dict]:
        """Get fallback DNS servers if loading fails"""
        return [
            {'ip': '8.8.8.8', 'name': 'Google DNS Primary', 'country': 'US', 'reliability': 1.0},
            {'ip': '8.8.4.4', 'name': 'Google DNS Secondary', 'country': 'US', 'reliability': 1.0},
            {'ip': '1.1.1.1', 'name': 'Cloudflare Primary', 'country': 'US', 'reliability': 1.0},
            {'ip': '1.0.0.1', 'name': 'Cloudflare Secondary', 'country': 'US', 'reliability': 1.0},
            {'ip': '9.9.9.9', 'name': 'Quad9 Primary', 'country': 'US', 'reliability': 0.99},
            {'ip': '149.112.112.112', 'name': 'Quad9 Secondary', 'country': 'US', 'reliability': 0.99},
            {'ip': '208.67.222.222', 'name': 'OpenDNS Primary', 'country': 'US', 'reliability': 0.98},
            {'ip': '208.67.220.220', 'name': 'OpenDNS Secondary', 'country': 'US', 'reliability': 0.98}
        ]
    
    async def test_dns_server(self, server: Dict) -> Dict:
        """Test a single DNS server comprehensively"""
        async with self.semaphore:
            result = {
                'ip': server['ip'],
                'name': server['name'],
                'country': server.get('country', 'Unknown'),
                'reliability': server.get('reliability', 0),
                'tests': [],
                'avg_latency': 0,
                'max_latency': 0,
                'min_latency': 0,
                'std_deviation': 0,
                'success_rate': 0,
                'dnssec_support': False,
                'last_tested': datetime.now().isoformat(),
                'status': 'unknown'
            }
            
            try:
                # Test connectivity first
                if not await self._test_connectivity(server['ip']):
                    result['status'] = 'unreachable'
                    return result
                
                # Perform DNS queries
                latencies = []
                success_count = 0
                
                for domain in self.test_domains:
                    try:
                        start_time = time.time()
                        resolver = dns.resolver.Resolver()
                        resolver.nameservers = [server['ip']]
                        resolver.timeout = self.timeout
                        resolver.lifetime = self.timeout
                        
                        # Query A record
                        answer = resolver.resolve(domain, 'A')
                        end_time = time.time()
                        
                        latency = (end_time - start_time) * 1000  # ms
                        latencies.append(latency)
                        success_count += 1
                        
                        # Test DNSSEC if available
                        if not result['dnssec_support']:
                            try:
                                resolver.resolve(domain, 'A', want_dnssec=True)
                                result['dnssec_support'] = True
                            except:
                                pass
                        
                        result['tests'].append({
                            'domain': domain,
                            'latency': latency,
                            'success': True,
                            'answers': [str(rdata) for rdata in answer]
                        })
                        
                    except Exception as e:
                        result['tests'].append({
                            'domain': domain,
                            'latency': 0,
                            'success': False,
                            'error': str(e)
                        })
                
                # Calculate statistics
                if latencies:
                    result['avg_latency'] = statistics.mean(latencies)
                    result['min_latency'] = min(latencies)
                    result['max_latency'] = max(latencies)
                    result['std_deviation'] = statistics.stdev(latencies) if len(latencies) > 1 else 0
                    result['success_rate'] = success_count / len(self.test_domains)
                    
                    # Determine status
                    if result['success_rate'] >= 0.8 and result['avg_latency'] < 200:
                        result['status'] = 'excellent'
                    elif result['success_rate'] >= 0.6 and result['avg_latency'] < 500:
                        result['status'] = 'good'
                    else:
                        result['status'] = 'poor'
                else:
                    result['status'] = 'failed'
                    
            except Exception as e:
                self.logger.error(f"Error testing {server['ip']}: {e}")
                result['status'] = 'error'
                result['error'] = str(e)
            
            return result
    
    async def _test_connectivity(self, ip: str, port: int = 53) -> bool:
        """Test basic connectivity to the DNS server"""
        try:
            # Test both IPv4 and IPv6
            if ':' in ip:
                # IPv6
                sock = socket.socket(socket.AF_INET6, socket.SOCK_DGRAM)
            else:
                # IPv4
                sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            
            sock.settimeout(2)
            sock.connect((ip, port))
            sock.close()
            return True
        except:
            return False
    
    async def test_all_servers(self) -> List[Dict]:
        """Test all DNS servers concurrently"""
        self.logger.info(f"Starting DNS tests for {len(self.dns_servers)} servers")
        
        tasks = [self.test_dns_server(server) for server in self.dns_servers]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Filter out exceptions
        valid_results = [r for r in results if not isinstance(r, Exception)]
        
        self.logger.info(f"Completed tests for {len(valid_results)} DNS servers")
        return valid_results
    
    def select_best_servers(self, results: List[Dict], count: int = 5, 
                          preferred_countries: List[str] = None) -> List[Dict]:
        """Select the best DNS servers based on multiple criteria"""
        
        # Filter by preferred countries if specified
        if preferred_countries:
            filtered_results = [
                r for r in results 
                if r.get('country') in preferred_countries and r['status'] in ['excellent', 'good']
            ]
            if not filtered_results:  # If none in preferred countries, use all
                filtered_results = [r for r in results if r['status'] in ['excellent', 'good']]
        else:
            filtered_results = [r for r in results if r['status'] in ['excellent', 'good']]
        
        # Sort by multiple criteria
        def sort_key(result):
            # Score based on multiple factors
            score = 0
            
            # Success rate (40%)
            score += result['success_rate'] * 40
            
            # Low latency bonus (30%)
            if result['avg_latency'] < 50:
                score += 30
            elif result['avg_latency'] < 100:
                score += 20
            elif result['avg_latency'] < 200:
                score += 10
            
            # DNSSEC support (15%)
            if result['dnssec_support']:
                score += 15
            
            # Low standard deviation (15%)
            if result['std_deviation'] < 20:
                score += 15
            elif result['std_deviation'] < 50:
                score += 10
            else:
                score += 5
            
            # Original reliability factor (10%)
            score += result['reliability'] * 10
            
            return score
        
        # Sort by score (descending)
        filtered_results.sort(key=sort_key, reverse=True)
        
        # Return top N servers
        return filtered_results[:count]
    
    async def save_test_results(self, results: List[Dict], filename: str = None) -> None:
        """Save test results to JSON file"""
        if filename is None:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            filename = f"dns_test_results_{timestamp}.json"
        
        try:
            with open(filename, 'w') as f:
                json.dump(results, f, indent=2)
            self.logger.info(f"Saved test results to {filename}")
        except Exception as e:
            self.logger.error(f"Failed to save results: {e}")


class DNSManager:
    """Main DNS management system with automated selection and failover"""
    
    def __init__(self):
        self.logger = self._setup_logger()
        self.tester = DNSTester()
        self.current_dns = None
        self.backup_dns = []
        self.config_file = Path(__file__).parent / 'dns_config.json'
        self.monitoring = False
        self.monitor_thread = None
        
    def _setup_logger(self) -> logging.Logger:
        """Setup logging configuration"""
        logger = logging.getLogger('dns_manager')
        logger.setLevel(logging.INFO)
        
        if not logger.handlers:
            handler = logging.StreamHandler()
            formatter = logging.Formatter(
                '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            )
            handler.setFormatter(formatter)
            logger.addHandler(handler)
            
        return logger
    
    async def initialize(self) -> None:
        """Initialize the DNS manager"""
        self.logger.info("Initializing DNS Manager")
        
        # Load DNS servers
        await self.tester.load_dns_servers()
        
        # Load existing configuration
        self.load_configuration()
        
        # Test and select best DNS servers
        results = await self.tester.test_all_servers()
        best_servers = self.tester.select_best_servers(results)
        
        if best_servers:
            self.current_dns = best_servers[0]
            self.backup_dns = best_servers[1:]
            
            self.logger.info(f"Selected primary DNS: {self.current_dns['ip']} "
                          f"({self.current_dns['name']}) - "
                          f"Latency: {self.current_dns['avg_latency']:.1f}ms")
            
            # Apply DNS configuration
            self.apply_dns_configuration()
            
            # Save configuration
            self.save_configuration()
        else:
            self.logger.error("No suitable DNS servers found!")
            raise Exception("DNS selection failed")
    
    def apply_dns_configuration(self) -> None:
        """Apply the selected DNS configuration to the system"""
        if not self.current_dns:
            self.logger.error("No DNS server selected")
            return
        
        try:
            # Create DNS configuration for systemd-resolved
            dns_servers = [self.current_dns['ip']]
            dns_servers.extend([dns['ip'] for dns in self.backup_dns[:2]])  # Add 2 backup servers
            
            # Apply to system (Linux-specific)
            self._apply_to_system(dns_servers)
            
            self.logger.info(f"Applied DNS configuration: {dns_servers}")
            
        except Exception as e:
            self.logger.error(f"Failed to apply DNS configuration: {e}")
    
    def _apply_to_system(self, dns_servers: List[str]) -> None:
        """Apply DNS configuration to the system"""
        try:
            # Method 1: systemd-resolved
            if self._is_systemd_resolved_active():
                self._configure_systemd_resolved(dns_servers)
            # Method 2: resolv.conf
            else:
                self._configure_resolv_conf(dns_servers)
                
        except Exception as e:
            self.logger.error(f"System DNS configuration failed: {e}")
            # Fallback to resolv.conf
            self._configure_resolv_conf(dns_servers)
    
    def _is_systemd_resolved_active(self) -> bool:
        """Check if systemd-resolved is active"""
        try:
            result = subprocess.run(['systemctl', 'is-active', 'systemd-resolved'], 
                                  capture_output=True, text=True)
            return result.returncode == 0 and 'active' in result.stdout
        except:
            return False
    
    def _configure_systemd_resolved(self, dns_servers: List[str]) -> None:
        """Configure systemd-resolved"""
        try:
            # Set DNS servers
            dns_string = ' '.join(dns_servers)
            subprocess.run(['resolvectl', 'dns', 'eth0', dns_string], check=True)
            
            # Set fallback DNS
            if len(dns_servers) > 1:
                fallback_string = ' '.join(dns_servers[1:])
                subprocess.run(['resolvectl', 'fallback-dns', 'eth0', fallback_string], check=True)
                
            self.logger.info("Configured systemd-resolved DNS")
            
        except Exception as e:
            self.logger.error(f"systemd-resolved configuration failed: {e}")
            raise
    
    def _configure_resolv_conf(self, dns_servers: List[str]) -> None:
        """Configure /etc/resolv.conf"""
        try:
            resolv_conf = "# Generated by RBT DNS Manager\n"
            resolv_conf += "# Updated at {}\n\n".format(datetime.now().isoformat())
            
            for dns in dns_servers:
                resolv_conf += f"nameserver {dns}\n"
            
            # Backup original
            subprocess.run(['cp', '/etc/resolv.conf', '/etc/resolv.conf.backup'], check=False)
            
            # Write new configuration
            with open('/etc/resolv.conf', 'w') as f:
                f.write(resolv_conf)
                
            self.logger.info("Configured /etc/resolv.conf")
            
        except Exception as e:
            self.logger.error(f"resolv.conf configuration failed: {e}")
            raise
    
    def save_configuration(self) -> None:
        """Save current DNS configuration"""
        config = {
            'current_dns': self.current_dns,
            'backup_dns': self.backup_dns,
            'last_updated': datetime.now().isoformat(),
            'version': '1.0'
        }
        
        try:
            with open(self.config_file, 'w') as f:
                json.dump(config, f, indent=2)
            self.logger.info("Saved DNS configuration")
        except Exception as e:
            self.logger.error(f"Failed to save configuration: {e}")
    
    def load_configuration(self) -> None:
        """Load DNS configuration from file"""
        try:
            if self.config_file.exists():
                with open(self.config_file, 'r') as f:
                    config = json.load(f)
                    self.current_dns = config.get('current_dns')
                    self.backup_dns = config.get('backup_dns', [])
                self.logger.info("Loaded existing DNS configuration")
        except Exception as e:
            self.logger.error(f"Failed to load configuration: {e}")
    
    def start_monitoring(self) -> None:
        """Start DNS monitoring and failover"""
        if self.monitoring:
            return
            
        self.monitoring = True
        self.monitor_thread = threading.Thread(target=self._monitor_loop)
        self.monitor_thread.daemon = True
        self.monitor_thread.start()
        self.logger.info("Started DNS monitoring")
    
    def stop_monitoring(self) -> None:
        """Stop DNS monitoring"""
        self.monitoring = False
        if self.monitor_thread:
            self.monitor_thread.join(timeout=5)
        self.logger.info("Stopped DNS monitoring")
    
    def _monitor_loop(self) -> None:
        """Main monitoring loop"""
        check_interval = 300  # 5 minutes
        
        while self.monitoring:
            try:
                # Test current DNS
                if self.current_dns:
                    result = asyncio.run(self._test_current_dns())
                    
                    if result['status'] != 'excellent':
                        self.logger.warning(f"Current DNS degraded: {result['status']}")
                        self._handle_dns_failure()
                        
            except Exception as e:
                self.logger.error(f"DNS monitoring error: {e}")
                
            time.sleep(check_interval)
    
    async def _test_current_dns(self) -> Dict:
        """Test the current DNS server"""
        if not self.current_dns:
            return {'status': 'failed'}
            
        return await self.tester.test_dns_server(self.current_dns)
    
    def _handle_dns_failure(self) -> None:
        """Handle DNS server failure"""
        self.logger.warning("DNS failure detected, initiating failover")
        
        # Try backup servers
        for i, backup in enumerate(self.backup_dns):
            try:
                result = asyncio.run(self.tester.test_dns_server(backup))
                
                if result['status'] in ['excellent', 'good']:
                    # Promote backup to primary
                    old_primary = self.current_dns
                    self.current_dns = backup
                    
                    # Remove from backup list and add old primary
                    self.backup_dns.pop(i)
                    if old_primary:
                        self.backup_dns.insert(0, old_primary)
                    
                    # Apply new configuration
                    self.apply_dns_configuration()
                    self.save_configuration()
                    
                    self.logger.info(f"Failover successful: {backup['ip']} is now primary")
                    return
                    
            except Exception as e:
                self.logger.error(f"Backup DNS {backup['ip']} failed: {e}")
                continue
        
        # If all backups fail, need to retest all servers
        self.logger.error("All backup DNS servers failed, need comprehensive retest")
        asyncio.run(self._emergency_retest())
    
    async def _emergency_retest(self) -> None:
        """Emergency retest of all DNS servers"""
        try:
            results = await self.tester.test_all_servers()
            best_servers = self.tester.select_best_servers(results)
            
            if best_servers:
                self.current_dns = best_servers[0]
                self.backup_dns = best_servers[1:]
                
                self.apply_dns_configuration()
                self.save_configuration()
                
                self.logger.info("Emergency retest completed, new DNS configuration applied")
            else:
                self.logger.error("No working DNS servers found after emergency retest")
                
        except Exception as e:
            self.logger.error(f"Emergency retest failed: {e}")


async def main():
    """Main function"""
    manager = DNSManager()
    
    try:
        # Initialize and test DNS servers
        await manager.initialize()
        
        # Start monitoring
        manager.start_monitoring()
        
        print(f"DNS Manager initialized successfully")
        print(f"Primary DNS: {manager.current_dns['ip']} ({manager.current_dns['name']})")
        print(f"Backup DNS servers: {len(manager.backup_dns)}")
        
        # Keep running
        try:
            while True:
                await asyncio.sleep(60)
        except KeyboardInterrupt:
            print("\nShutting down DNS Manager...")
            manager.stop_monitoring()
            
    except Exception as e:
        print(f"DNS Manager failed: {e}")
        return 1
    
    return 0


if __name__ == '__main__':
    # Handle graceful shutdown
    def signal_handler(sig, frame):
        print('\nReceived shutdown signal, exiting...')
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Run main function
    exit_code = asyncio.run(main())
    sys.exit(exit_code)