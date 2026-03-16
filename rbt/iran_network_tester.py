#!/usr/bin/env python3
"""
RBT Iran Network Testing Suite
Comprehensive testing for Iranian network conditions and censorship resistance
"""

import asyncio
import json
import logging
import socket
import subprocess
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import dns.resolver
import dns.exception
import requests
import concurrent.futures

# Import our modules
from dns_manager import DNSTester
from dns_tunnel import DNSTunnelManager, IranNetworkSimulator

class IranNetworkTester:
    """Comprehensive testing for Iranian network conditions"""
    
    def __init__(self):
        self.logger = self._setup_logger()
        self.dns_tester = DNSTester()
        self.iran_simulator = IranNetworkSimulator()
        self.blocked_domains = [
            'youtube.com',
            'facebook.com',
            'twitter.com', 
            'telegram.org',
            'instagram.com',
            'netflix.com',
            'spotify.com',
            'medium.com',
            'linkedin.com',
            'wordpress.com',
            'blogspot.com',
            'vimeo.com',
            'dailymotion.com',
            'bbc.com',
            'cnn.com',
            'foxnews.com',
            'nytimes.com',
            'washingtonpost.com',
            'theguardian.com',
            'reuters.com',
            'ap.org'
        ]
        self.iranian_dns_servers = [
            {'ip': '217.218.127.127', 'name': 'University of Tehran', 'country': 'IR'},
            {'ip': '217.218.127.128', 'name': 'University of Tehran Secondary', 'country': 'IR'},
            {'ip': '185.10.74.204', 'name': 'Rasaneh Systems', 'country': 'IR'},
            {'ip': '185.10.74.205', 'name': 'Rasaneh Systems Secondary', 'country': 'IR'},
            {'ip': '94.182.146.201', 'name': 'Iran Telecommunication', 'country': 'IR'},
            {'ip': '94.182.146.202', 'name': 'Iran Telecommunication Secondary', 'country': 'IR'}
        ]
        self.censorship_resistant_dns = [
            {'ip': '8.8.8.8', 'name': 'Google DNS Primary', 'country': 'US'},
            {'ip': '8.8.4.4', 'name': 'Google DNS Secondary', 'country': 'US'},
            {'ip': '1.1.1.1', 'name': 'Cloudflare Primary', 'country': 'US'},
            {'ip': '1.0.0.1', 'name': 'Cloudflare Secondary', 'country': 'US'},
            {'ip': '9.9.9.9', 'name': 'Quad9 Primary', 'country': 'US'},
            {'ip': '149.112.112.112', 'name': 'Quad9 Secondary', 'country': 'US'},
            {'ip': '208.67.222.222', 'name': 'OpenDNS Primary', 'country': 'US'},
            {'ip': '208.67.220.220', 'name': 'OpenDNS Secondary', 'country': 'US'}
        ]
        
    def _setup_logger(self) -> logging.Logger:
        """Setup logging configuration"""
        logger = logging.getLogger('iran_network_tester')
        logger.setLevel(logging.INFO)
        
        if not logger.handlers:
            handler = logging.StreamHandler()
            formatter = logging.Formatter(
                '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            )
            handler.setFormatter(formatter)
            logger.addHandler(handler)
            
        return logger
    
    async def test_dns_poisoning(self) -> Dict:
        """Test for DNS poisoning in Iranian network"""
        self.logger.info("Testing DNS poisoning...")
        
        results = {
            'test_timestamp': datetime.now().isoformat(),
            'poisoning_detected': False,
            'affected_domains': [],
            'test_results': []
        }
        
        # Test each blocked domain
        for domain in self.blocked_domains[:10]:  # Test first 10 for speed
            try:
                # Test with different DNS servers
                test_result = {
                    'domain': domain,
                    'tests': []
                }
                
                # Test with Iranian DNS
                for dns_server in self.iranian_dns_servers[:2]:
                    try:
                        resolver = dns.resolver.Resolver()
                        resolver.nameservers = [dns_server['ip']]
                        resolver.timeout = 5
                        resolver.lifetime = 5
                        
                        answers = resolver.resolve(domain, 'A')
                        ips = [str(rdata) for rdata in answers]
                        
                        # Check for poisoning indicators
                        poisoned = self._check_dns_poisoning(ips)
                        
                        test_result['tests'].append({
                            'dns_server': dns_server['ip'],
                            'dns_name': dns_server['name'],
                            'resolved_ips': ips,
                            'poisoned': poisoned,
                            'poisoning_type': self._detect_poisoning_type(ips) if poisoned else None
                        })
                        
                        if poisoned:
                            results['poisoning_detected'] = True
                            if domain not in results['affected_domains']:
                                results['affected_domains'].append(domain)
                                
                    except Exception as e:
                        test_result['tests'].append({
                            'dns_server': dns_server['ip'],
                            'dns_name': dns_server['name'],
                            'error': str(e),
                            'poisoned': False
                        })
                
                results['test_results'].append(test_result)
                
            except Exception as e:
                self.logger.error(f"Error testing {domain}: {e}")
                continue
        
        return results
    
    def _check_dns_poisoning(self, ips: List[str]) -> bool:
        """Check if DNS response indicates poisoning"""
        poisoned_ips = ['10.10.34.34', '10.10.34.35', '127.0.0.1', '0.0.0.0', '1.2.3.4']
        
        for ip in ips:
            if ip in poisoned_ips:
                return True
                
        # Check for suspicious patterns
        if len(ips) == 1 and ips[0] in poisoned_ips:
            return True
            
        return False
    
    def _detect_poisoning_type(self, ips: List[str]) -> str:
        """Detect type of DNS poisoning"""
        if '10.10.34.34' in ips or '10.10.34.35' in ips:
            return 'iran_standard_poisoning'
        elif '127.0.0.1' in ips:
            return 'localhost_poisoning'
        elif '0.0.0.0' in ips:
            return 'null_route_poisoning'
        else:
            return 'unknown_poisoning'
    
    async def test_dns_over_tls(self) -> Dict:
        """Test DNS-over-TLS connectivity"""
        self.logger.info("Testing DNS-over-TLS...")
        
        results = {
            'test_timestamp': datetime.now().isoformat(),
            'dot_servers_tested': [],
            'successful_connections': 0,
            'failed_connections': 0
        }
        
        # Common DNS-over-TLS servers
        dot_servers = [
            {'ip': '1.1.1.1', 'name': 'Cloudflare', 'port': 853},
            {'ip': '1.0.0.1', 'name': 'Cloudflare Secondary', 'port': 853},
            {'ip': '8.8.8.8', 'name': 'Google DNS', 'port': 853},
            {'ip': '8.8.4.4', 'name': 'Google DNS Secondary', 'port': 853},
            {'ip': '9.9.9.9', 'name': 'Quad9', 'port': 853},
            {'ip': '149.112.112.112', 'name': 'Quad9 Secondary', 'port': 853}
        ]
        
        for server in dot_servers:
            try:
                # Test TLS connection
                import ssl
                import socket
                
                context = ssl.create_default_context()
                context.check_hostname = False
                context.verify_mode = ssl.CERT_NONE
                
                with socket.create_connection((server['ip'], server['port']), timeout=5) as sock:
                    with context.wrap_socket(sock, server_hostname=server['ip']) as ssock:
                        # Connection successful
                        results['successful_connections'] += 1
                        results['dot_servers_tested'].append({
                            'server': server['name'],
                            'ip': server['ip'],
                            'port': server['port'],
                            'status': 'connected',
                            'tls_version': ssock.version()
                        })
                        
            except Exception as e:
                results['failed_connections'] += 1
                results['dot_servers_tested'].append({
                    'server': server['name'],
                    'ip': server['ip'],
                    'port': server['port'],
                    'status': 'failed',
                    'error': str(e)
                })
        
        return results
    
    async def test_dns_over_https(self) -> Dict:
        """Test DNS-over-HTTPS connectivity"""
        self.logger.info("Testing DNS-over-HTTPS...")
        
        results = {
            'test_timestamp': datetime.now().isoformat(),
            'doh_servers_tested': [],
            'successful_connections': 0,
            'failed_connections': 0
        }
        
        # Common DNS-over-HTTPS servers
        doh_servers = [
            {'url': 'https://cloudflare-dns.com/dns-query', 'name': 'Cloudflare'},
            {'url': 'https://dns.google/dns-query', 'name': 'Google'},
            {'url': 'https://dns.quad9.net/dns-query', 'name': 'Quad9'},
            {'url': 'https://dns.opendns.com/dns-query', 'name': 'OpenDNS'}
        ]
        
        for server in doh_servers:
            try:
                # Test DoH connection
                headers = {
                    'Accept': 'application/dns-json',
                    'Content-Type': 'application/dns-json'
                }
                
                # Test query
                test_domain = 'google.com'
                params = {
                    'name': test_domain,
                    'type': 'A'
                }
                
                response = requests.get(server['url'], headers=headers, params=params, timeout=10)
                
                if response.status_code == 200:
                    results['successful_connections'] += 1
                    results['doh_servers_tested'].append({
                        'server': server['name'],
                        'url': server['url'],
                        'status': 'connected',
                        'response_time': response.elapsed.total_seconds() * 1000
                    })
                else:
                    results['failed_connections'] += 1
                    results['doh_servers_tested'].append({
                        'server': server['name'],
                        'url': server['url'],
                        'status': 'failed',
                        'error': f'HTTP {response.status_code}'
                    })
                    
            except Exception as e:
                results['failed_connections'] += 1
                results['doh_servers_tested'].append({
                    'server': server['name'],
                    'url': server['url'],
                    'status': 'failed',
                    'error': str(e)
                })
        
        return results
    
    async def test_dnstt_setup(self) -> Dict:
        """Test DNSTT (DNS tunneling) setup"""
        self.logger.info("Testing DNSTT setup...")
        
        results = {
            'test_timestamp': datetime.now().isoformat(),
            'dnstt_available': False,
            'server_binary': False,
            'client_binary': False,
            'test_results': []
        }
        
        # Check if dnstt binaries exist
        tunnel_manager = DNSTunnelManager()
        
        # Check server binary
        server_bin = tunnel_manager.server_dir / 'dnstt-server'
        if server_bin.exists():
            results['server_binary'] = True
            results['dnstt_available'] = True
        
        # Check client binary
        client_bin = tunnel_manager.client_dir / 'dnstt-client'
        if client_bin.exists():
            results['client_binary'] = True
            results['dnstt_available'] = True
        
        # Test key generation
        try:
            privkey, pubkey = tunnel_manager.generate_server_keys()
            if pubkey:
                results['test_results'].append({
                    'test': 'key_generation',
                    'status': 'success',
                    'public_key_length': len(pubkey)
                })
            else:
                results['test_results'].append({
                    'test': 'key_generation',
                    'status': 'failed'
                })
        except Exception as e:
            results['test_results'].append({
                'test': 'key_generation',
                'status': 'error',
                'error': str(e)
            })
        
        return results
    
    async def test_censorship_resistance(self) -> Dict:
        """Test censorship resistance capabilities"""
        self.logger.info("Testing censorship resistance...")
        
        results = {
            'test_timestamp': datetime.now().isoformat(),
            'dns_poisoning_resistance': False,
            'dns_over_tls_working': False,
            'dns_over_https_working': False,
            'dnstt_available': False,
            'recommended_solutions': []
        }
        
        # Test DNS poisoning
        poisoning_test = await self.test_dns_poisoning()
        results['dns_poisoning_detected'] = poisoning_test['poisoning_detected']
        results['dns_poisoning_resistance'] = not poisoning_test['poisoning_detected']
        
        # Test DNS-over-TLS
        dot_test = await self.test_dns_over_tls()
        results['dns_over_tls_working'] = dot_test['successful_connections'] > 0
        
        # Test DNS-over-HTTPS
        doh_test = await self.test_dns_over_https()
        results['dns_over_https_working'] = doh_test['successful_connections'] > 0
        
        # Test DNSTT
        dnstt_test = await self.test_dnstt_setup()
        results['dnstt_available'] = dnstt_test['dnstt_available']
        
        # Generate recommendations
        if results['dns_poisoning_detected']:
            results['recommended_solutions'].extend([
                'Use DNS-over-TLS (DoT)',
                'Use DNS-over-HTTPS (DoH)', 
                'Use DNSTT for tunneling',
                'Use encrypted DNS resolvers'
            ])
        
        if not results['dns_over_tls_working']:
            results['recommended_solutions'].append('Configure alternative DoT servers')
        
        if not results['dns_over_https_working']:
            results['recommended_solutions'].append('Configure alternative DoH servers')
        
        return results
    
    async def test_iranian_dns_servers(self) -> Dict:
        """Test Iranian DNS servers specifically"""
        self.logger.info("Testing Iranian DNS servers...")
        
        results = {
            'test_timestamp': datetime.now().isoformat(),
            'iranian_servers_tested': [],
            'censorship_detected': False,
            'recommended_foreign_dns': []
        }
        
        # Test Iranian DNS servers
        for server in self.iranian_dns_servers:
            try:
                result = await self.dns_tester.test_dns_server(server)
                results['iranian_servers_tested'].append(result)
                
                # Check for censorship indicators
                if result['status'] == 'poor' or result['success_rate'] < 0.5:
                    results['censorship_detected'] = True
                    
            except Exception as e:
                self.logger.error(f"Error testing Iranian DNS {server['ip']}: {e}")
                results['iranian_servers_tested'].append({
                    'ip': server['ip'],
                    'name': server['name'],
                    'error': str(e),
                    'status': 'error'
                })
        
        # Select best foreign DNS servers for Iran
        best_foreign = await self._select_best_foreign_dns_for_iran()
        results['recommended_foreign_dns'] = best_foreign
        
        return results
    
    async def _select_best_foreign_dns_for_iran(self) -> List[Dict]:
        """Select best foreign DNS servers for use in Iran"""
        # Test censorship-resistant DNS servers
        test_results = []
        
        for server in self.censorship_resistant_dns:
            try:
                result = await self.dns_tester.test_dns_server(server)
                test_results.append(result)
            except Exception as e:
                self.logger.error(f"Error testing {server['ip']}: {e}")
        
        # Select best servers based on latency and reliability
        best_servers = self.dns_tester.select_best_servers(test_results, count=5)
        return best_servers
    
    async def run_comprehensive_test(self) -> Dict:
        """Run comprehensive test suite for Iranian network conditions"""
        self.logger.info("Starting comprehensive Iranian network test...")
        
        results = {
            'test_id': f"iran_test_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
            'test_timestamp': datetime.now().isoformat(),
            'summary': {},
            'detailed_results': {}
        }
        
        # Test 1: DNS Poisoning
        self.logger.info("Testing DNS poisoning...")
        results['detailed_results']['dns_poisoning'] = await self.test_dns_poisoning()
        
        # Test 2: DNS-over-TLS
        self.logger.info("Testing DNS-over-TLS...")
        results['detailed_results']['dns_over_tls'] = await self.test_dns_over_tls()
        
        # Test 3: DNS-over-HTTPS
        self.logger.info("Testing DNS-over-HTTPS...")
        results['detailed_results']['dns_over_https'] = await self.test_dns_over_https()
        
        # Test 4: DNSTT Setup
        self.logger.info("Testing DNSTT setup...")
        results['detailed_results']['dnstt_setup'] = await self.test_dnstt_setup()
        
        # Test 5: Censorship Resistance
        self.logger.info("Testing censorship resistance...")
        results['detailed_results']['censorship_resistance'] = await self.test_censorship_resistance()
        
        # Test 6: Iranian DNS Servers
        self.logger.info("Testing Iranian DNS servers...")
        results['detailed_results']['iranian_dns'] = await self.test_iranian_dns_servers()
        
        # Generate summary
        results['summary'] = self._generate_summary(results['detailed_results'])
        
        self.logger.info("Comprehensive Iranian network test completed")
        return results
    
    def _generate_summary(self, detailed_results: Dict) -> Dict:
        """Generate summary from detailed results"""
        summary = {
            'censorship_level': 'unknown',
            'dns_poisoning_detected': False,
            'recommended_solutions': [],
            'best_dns_servers': [],
            'tunnel_recommendations': []
        }
        
        # Check DNS poisoning
        if 'dns_poisoning' in detailed_results:
            poisoning = detailed_results['dns_poisoning']
            summary['dns_poisoning_detected'] = poisoning['poisoning_detected']
        
        # Determine censorship level
        if summary['dns_poisoning_detected']:
            summary['censorship_level'] = 'high'
        else:
            summary['censorship_level'] = 'moderate'
        
        # Generate recommendations
        if summary['dns_poisoning_detected']:
            summary['recommended_solutions'].extend([
                'Use DNS-over-TLS (DoT) with foreign servers',
                'Use DNS-over-HTTPS (DoH) with CDN providers',
                'Deploy DNSTT for DNS tunneling',
                'Use encrypted DNS resolvers'
            ])
        
        # Get best DNS servers
        if 'iranian_dns' in detailed_results:
            iran_dns = detailed_results['iranian_dns']
            if 'recommended_foreign_dns' in iran_dns:
                summary['best_dns_servers'] = iran_dns['recommended_foreign_dns'][:3]
        
        # Tunnel recommendations
        if 'dnstt_setup' in detailed_results:
            dnstt = detailed_results['dnstt_setup']
            if dnstt['dnstt_available']:
                summary['tunnel_recommendations'].append('DNSTT is available for DNS tunneling')
            else:
                summary['tunnel_recommendations'].append('Install and configure DNSTT for tunneling')
        
        return summary
    
    def save_test_results(self, results: Dict, filename: str = None) -> bool:
        """Save test results to file"""
        try:
            if filename is None:
                filename = f"iran_network_test_{results['test_id']}.json"
            
            with open(filename, 'w') as f:
                json.dump(results, f, indent=2)
            
            self.logger.info(f"Test results saved to {filename}")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to save test results: {e}")
            return False
    
    def print_test_summary(self, results: Dict):
        """Print test summary to console"""
        print("\n" + "="*70)
        print("IRANIAN NETWORK TESTING RESULTS")
        print("="*70)
        print(f"Test ID: {results['test_id']}")
        print(f"Timestamp: {results['test_timestamp']}")
        print()
        
        summary = results['summary']
        print("SUMMARY:")
        print(f"  Censorship Level: {summary['censorship_level'].upper()}")
        print(f"  DNS Poisoning: {'DETECTED' if summary['dns_poisoning_detected'] else 'NOT DETECTED'}")
        print()
        
        if summary['recommended_solutions']:
            print("RECOMMENDED SOLUTIONS:")
            for i, solution in enumerate(summary['recommended_solutions'], 1):
                print(f"  {i}. {solution}")
            print()
        
        if summary['best_dns_servers']:
            print("BEST DNS SERVERS FOR IRAN:")
            for i, server in enumerate(summary['best_dns_servers'], 1):
                print(f"  {i}. {server['ip']} ({server['name']}) - {server['avg_latency']:.1f}ms")
            print()
        
        if summary['tunnel_recommendations']:
            print("TUNNEL RECOMMENDATIONS:")
            for recommendation in summary['tunnel_recommendations']:
                print(f"  • {recommendation}")
            print()
        
        print("="*70)


async def main():
    """Main function for Iran network testing"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Iran Network Testing Suite')
    parser.add_argument('--comprehensive', action='store_true', help='Run comprehensive test suite')
    parser.add_argument('--dns-poisoning', action='store_true', help='Test DNS poisoning only')
    parser.add_argument('--dns-over-tls', action='store_true', help='Test DNS-over-TLS only')
    parser.add_argument('--dns-over-https', action='store_true', help='Test DNS-over-HTTPS only')
    parser.add_argument('--dnstt', action='store_true', help='Test DNSTT setup only')
    parser.add_argument('--censorship', action='store_true', help='Test censorship resistance only')
    parser.add_argument('--iranian-dns', action='store_true', help='Test Iranian DNS servers only')
    parser.add_argument('--save-results', action='store_true', help='Save results to file')
    parser.add_argument('--output', type=str, help='Output filename for results')
    
    args = parser.parse_args()
    
    # Create tester
    tester = IranNetworkTester()
    
    try:
        if args.comprehensive:
            results = await tester.run_comprehensive_test()
            tester.print_test_summary(results)
            
            if args.save_results:
                tester.save_test_results(results, args.output)
            return 0
        
        if args.dns_poisoning:
            results = await tester.test_dns_poisoning()
            print("DNS Poisoning Test Results:")
            print(f"Poisoning detected: {results['poisoning_detected']}")
            if results['affected_domains']:
                print(f"Affected domains: {len(results['affected_domains'])}")
            return 0
        
        if args.dns_over_tls:
            results = await tester.test_dns_over_tls()
            print("DNS-over-TLS Test Results:")
            print(f"Successful connections: {results['successful_connections']}")
            print(f"Failed connections: {results['failed_connections']}")
            return 0
        
        if args.dns_over_https:
            results = await tester.test_dns_over_https()
            print("DNS-over-HTTPS Test Results:")
            print(f"Successful connections: {results['successful_connections']}")
            print(f"Failed connections: {results['failed_connections']}")
            return 0
        
        if args.dnstt:
            results = await tester.test_dnstt_setup()
            print("DNSTT Test Results:")
            print(f"DNSTT available: {results['dnstt_available']}")
            print(f"Server binary: {results['server_binary']}")
            print(f"Client binary: {results['client_binary']}")
            return 0
        
        if args.censorship:
            results = await tester.test_censorship_resistance()
            print("Censorship Resistance Test Results:")
            print(f"DNS poisoning resistance: {results['dns_poisoning_resistance']}")
            print(f"DNS-over-TLS working: {results['dns_over_tls_working']}")
            print(f"DNS-over-HTTPS working: {results['dns_over_https_working']}")
            print(f"DNSTT available: {results['dnstt_available']}")
            
            if results['recommended_solutions']:
                print("Recommended solutions:")
                for solution in results['recommended_solutions']:
                    print(f"  • {solution}")
            return 0
        
        if args.iranian_dns:
            results = await tester.test_iranian_dns_servers()
            print("Iranian DNS Servers Test Results:")
            print(f"Censorship detected: {results['censorship_detected']}")
            print(f"Servers tested: {len(results['iranian_servers_tested'])}")
            
            if results['recommended_foreign_dns']:
                print("Recommended foreign DNS servers:")
                for i, server in enumerate(results['recommended_foreign_dns'][:3], 1):
                    print(f"  {i}. {server['ip']} ({server['name']}) - {server['avg_latency']:.1f}ms")
            return 0
        
        # If no arguments, run comprehensive test
        print("No specific test specified. Running comprehensive test...")
        results = await tester.run_comprehensive_test()
        tester.print_test_summary(results)
        
        if args.save_results:
            tester.save_test_results(results, args.output)
        return 0
        
    except KeyboardInterrupt:
        print("\nTest interrupted by user")
        return 0
    except Exception as e:
        print(f"Test failed: {e}")
        return 1


if __name__ == '__main__':
    import asyncio
    exit_code = asyncio.run(main())
    exit(exit_code)