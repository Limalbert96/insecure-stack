#!/usr/bin/env python3
"""
Load Testing Tool with Cloud Armor Demonstration
=================================================

This script tests the Tasky application and demonstrates Cloud Armor
security policy enforcement by triggering rate limits.

Scenarios:
- baseline: Normal user behavior (20 req/min)
- rate-limit: Trigger Cloud Armor blocking (150 req/min, exceeds 100/min threshold)
- burst: Sudden traffic spike (200 req in 10 seconds)
- sustained: Long-running stability test

Cloud Armor Config (13-cloud-armor.tf):
- Rate limit: 100 requests/minute per IP
- Ban duration: 60 seconds
- Action: Block with 429 status code
"""

import requests
import time
import argparse
import json
import csv
import sys
import subprocess
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
from collections import defaultdict

class CloudArmorLoadTester:
    def __init__(self, target_url, scenario='baseline', duration=60):
        self.target_url = target_url
        self.scenario = scenario
        self.duration = duration
        self.session = requests.Session()
        self.session.headers.update({'User-Agent': 'CloudArmorTester/1.0'})

        # Results tracking
        self.results = []
        self.status_counts = defaultdict(int)
        self.response_times = []
        self.blocked_count = 0
        self.success_count = 0
        self.start_time = None
        self.first_block_time = None

    def detect_load_balancer(self):
        """Auto-detect load balancer IP from kubectl or gcloud"""
        print("Auto-detecting load balancer endpoint...")

        try:
            # Try kubectl first
            result = subprocess.run(
                ['kubectl', 'get', 'ingress', 'tasky-ingress', '-o',
                 'jsonpath={.status.loadBalancer.ingress[0].ip}'],
                capture_output=True,
                text=True,
                timeout=10
            )

            if result.returncode == 0 and result.stdout.strip():
                lb_ip = result.stdout.strip()
                print(f"Found load balancer IP via kubectl: {lb_ip}")
                return f"http://{lb_ip}"
        except (subprocess.TimeoutExpired, FileNotFoundError):
            print("kubectl not available or timed out")

        try:
            # Try gcloud as fallback
            result = subprocess.run(
                ['gcloud', 'compute', 'addresses', 'list',
                 '--filter=name:tasky', '--format=value(address)'],
                capture_output=True,
                text=True,
                timeout=10
            )

            if result.returncode == 0 and result.stdout.strip():
                lb_ip = result.stdout.strip()
                print(f"Found load balancer IP via gcloud: {lb_ip}")
                return f"http://{lb_ip}"
        except (subprocess.TimeoutExpired, FileNotFoundError):
            print("gcloud not available or timed out")

        print("Could not auto-detect load balancer. Use --target flag.")
        return None

    def make_request(self):
        """Make a single HTTP request and record results"""
        try:
            start = time.time()
            response = self.session.get(self.target_url, timeout=5)
            elapsed = time.time() - start

            # Record result
            result = {
                'timestamp': time.time(),
                'status_code': response.status_code,
                'response_time': elapsed,
                'blocked': response.status_code in [429, 403]
            }

            self.results.append(result)
            self.status_counts[response.status_code] += 1
            self.response_times.append(elapsed)

            if result['blocked']:
                self.blocked_count += 1
                if self.first_block_time is None:
                    self.first_block_time = time.time()
            elif 200 <= response.status_code < 300:
                self.success_count += 1

            return result

        except requests.exceptions.Timeout:
            result = {'timestamp': time.time(), 'status_code': 'TIMEOUT',
                     'response_time': 0, 'blocked': False}
            self.results.append(result)
            self.status_counts['TIMEOUT'] += 1
            return result

        except Exception as e:
            result = {'timestamp': time.time(), 'status_code': f'ERROR: {str(e)}',
                     'response_time': 0, 'blocked': False}
            self.results.append(result)
            self.status_counts['ERROR'] += 1
            return result

    def run_baseline_scenario(self):
        """Normal user behavior: 20 requests/minute"""
        print("Running BASELINE scenario (20 req/min)")
        print("   This should NOT trigger Cloud Armor (threshold: 100 req/min)\n")

        requests_per_minute = 20
        interval = 60.0 / requests_per_minute  # 3 seconds between requests

        end_time = self.start_time + self.duration

        while time.time() < end_time:
            self.make_request()
            elapsed = time.time() - self.start_time
            progress = (elapsed / self.duration) * 100
            print(f"\rProgress: {progress:.1f}% | Requests: {len(self.results)} | "
                  f"Success: {self.success_count} | Blocked: {self.blocked_count}", end='')
            time.sleep(interval)

        print()  # Newline after progress

    def run_rate_limit_scenario(self):
        """Aggressive load: 150 requests/minute to trigger Cloud Armor"""
        print("Running RATE-LIMIT scenario (150 req/min)")
        print("   This WILL trigger Cloud Armor blocking (threshold: 100 req/min)")
        print("   Expected: Blocks after ~40 seconds, 60-second ban\n")

        requests_per_minute = 150
        interval = 60.0 / requests_per_minute  # 0.4 seconds between requests

        end_time = self.start_time + self.duration

        while time.time() < end_time:
            self.make_request()
            elapsed = time.time() - self.start_time
            progress = (elapsed / self.duration) * 100

            # Show when blocking starts
            block_indicator = " BLOCKING!" if self.blocked_count > 0 else ""
            print(f"\rProgress: {progress:.1f}% | Requests: {len(self.results)} | "
                  f"Success: {self.success_count} | Blocked: {self.blocked_count}{block_indicator}", end='')

            time.sleep(interval)

        print()  # Newline after progress

    def run_burst_scenario(self):
        """Sudden burst: 200 requests in 10 seconds"""
        print("Running BURST scenario (200 req in 10 seconds)")
        print("   This will immediately trigger Cloud Armor\n")

        total_requests = 200
        burst_duration = 10

        print("Sending burst traffic...")

        with ThreadPoolExecutor(max_workers=20) as executor:
            futures = [executor.submit(self.make_request) for _ in range(total_requests)]

            for i, future in enumerate(as_completed(futures), 1):
                future.result()
                if i % 20 == 0:
                    print(f"  Sent: {i}/{total_requests} | Blocked: {self.blocked_count}")

        print(f"\nBurst complete. Waiting remaining duration ({self.duration - burst_duration}s)...")
        time.sleep(max(0, self.duration - burst_duration))

    def run_sustained_scenario(self):
        """Long-running test at moderate rate: 60 requests/minute"""
        print("Running SUSTAINED scenario (60 req/min)")
        print("   Just below Cloud Armor threshold for stability testing\n")

        requests_per_minute = 60
        interval = 60.0 / requests_per_minute  # 1 second between requests

        end_time = self.start_time + self.duration

        while time.time() < end_time:
            self.make_request()
            elapsed = time.time() - self.start_time
            progress = (elapsed / self.duration) * 100
            print(f"\rProgress: {progress:.1f}% | Requests: {len(self.results)} | "
                  f"Success: {self.success_count} | Blocked: {self.blocked_count}", end='')
            time.sleep(interval)

        print()  # Newline after progress

    def run_test(self):
        """Execute the selected test scenario"""
        self.start_time = time.time()

        scenarios = {
            'baseline': self.run_baseline_scenario,
            'rate-limit': self.run_rate_limit_scenario,
            'burst': self.run_burst_scenario,
            'sustained': self.run_sustained_scenario
        }

        if self.scenario not in scenarios:
            print(f"❌ Unknown scenario: {self.scenario}")
            print(f"Available: {', '.join(scenarios.keys())}")
            sys.exit(1)

        print(f"\n{'='*70}")
        print(f"Cloud Armor Load Test")
        print(f"{'='*70}")
        print(f"Target: {self.target_url}")
        print(f"Scenario: {self.scenario}")
        print(f"Duration: {self.duration}s")
        print(f"Start Time: {datetime.fromtimestamp(self.start_time).strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"{'='*70}\n")

        # Run the scenario
        scenarios[self.scenario]()

        total_time = time.time() - self.start_time

        # Generate report
        self.print_report(total_time)
        self.export_results()

    def calculate_percentiles(self, data, percentiles=[50, 95, 99]):
        """Calculate percentile values"""
        if not data:
            return {p: 0 for p in percentiles}

        sorted_data = sorted(data)
        result = {}

        for p in percentiles:
            index = int(len(sorted_data) * (p / 100.0))
            result[p] = sorted_data[min(index, len(sorted_data) - 1)]

        return result

    def print_report(self, total_time):
        """Print comprehensive test report"""
        print(f"\n{'='*70}")
        print("TEST RESULTS")
        print(f"{'='*70}\n")

        total_requests = len(self.results)

        print(f"Duration: {total_time:.2f}s")
        print(f"Total Requests: {total_requests}")
        print(f"Requests/sec: {total_requests/total_time:.2f}")
        print()

        print("Status Code Distribution:")
        for status, count in sorted(self.status_counts.items()):
            percentage = (count / total_requests) * 100
            print(f"  {status}: {count} ({percentage:.1f}%)")
        print()

        print(f"Successful: {self.success_count} ({(self.success_count/total_requests)*100:.1f}%)")
        print(f"Blocked: {self.blocked_count} ({(self.blocked_count/total_requests)*100:.1f}%)")
        print()

        if self.response_times:
            percentiles = self.calculate_percentiles(self.response_times)
            avg_time = sum(self.response_times) / len(self.response_times)

            print("Response Time Statistics:")
            print(f"  Average: {avg_time*1000:.2f}ms")
            print(f"  P50 (Median): {percentiles[50]*1000:.2f}ms")
            print(f"  P95: {percentiles[95]*1000:.2f}ms")
            print(f"  P99: {percentiles[99]*1000:.2f}ms")
            print(f"  Min: {min(self.response_times)*1000:.2f}ms")
            print(f"  Max: {max(self.response_times)*1000:.2f}ms")
            print()

        # Cloud Armor Analysis
        if self.blocked_count > 0:
            print("Cloud Armor Analysis:")
            print(f"  First block occurred at: {self.first_block_time - self.start_time:.1f}s")
            print(f"  Block rate: {(self.blocked_count/total_requests)*100:.1f}%")
            print(f"  Cloud Armor is actively protecting the application!")

            # Estimate when rate limit was exceeded
            requests_before_block = sum(1 for r in self.results
                                       if r['timestamp'] < self.first_block_time)
            print(f"  Requests before first block: {requests_before_block}")
        else:
            print("No blocking detected - rate stayed below Cloud Armor threshold")

        print(f"\n{'='*70}\n")

    def export_results(self):
        """Export results to JSON and CSV"""
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')

        # JSON export (detailed)
        json_file = f"load_test_results_{self.scenario}_{timestamp}.json"
        with open(json_file, 'w') as f:
            json.dump({
                'scenario': self.scenario,
                'target': self.target_url,
                'duration': self.duration,
                'total_requests': len(self.results),
                'success_count': self.success_count,
                'blocked_count': self.blocked_count,
                'status_counts': dict(self.status_counts),
                'results': self.results
            }, f, indent=2)

        print(f"Detailed results exported to: {json_file}")

        # CSV export (summary)
        csv_file = f"load_test_summary_{self.scenario}_{timestamp}.csv"
        with open(csv_file, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(['Timestamp', 'Status Code', 'Response Time (ms)', 'Blocked'])
            for r in self.results:
                writer.writerow([
                    datetime.fromtimestamp(r['timestamp']).strftime('%Y-%m-%d %H:%M:%S.%f'),
                    r['status_code'],
                    f"{r['response_time']*1000:.2f}",
                    'Yes' if r['blocked'] else 'No'
                ])

        print(f"Summary exported to: {csv_file}")

def main():
    parser = argparse.ArgumentParser(
        description='Load testing tool with Cloud Armor demonstration',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Auto-detect endpoint and run rate-limit test
  python load_test.py --scenario rate-limit --duration 120

  # Specify endpoint manually
  python load_test.py --target http://34.120.45.67 --scenario burst

  # Baseline test (should not trigger blocking)
  python load_test.py --scenario baseline --duration 300

Scenarios:
  baseline    - Normal traffic (20 req/min), should NOT trigger Cloud Armor
  rate-limit  - Aggressive traffic (150 req/min), WILL trigger blocking
  burst       - Sudden spike (200 req in 10s), immediate blocking
  sustained   - Moderate traffic (60 req/min), stability test
        """
    )

    parser.add_argument(
        '--target',
        help='Target URL (auto-detected if not provided)',
        default=None
    )

    parser.add_argument(
        '--scenario',
        choices=['baseline', 'rate-limit', 'burst', 'sustained'],
        default='rate-limit',
        help='Test scenario to run (default: rate-limit)'
    )

    parser.add_argument(
        '--duration',
        type=int,
        default=120,
        help='Test duration in seconds (default: 120)'
    )

    args = parser.parse_args()

    # Detect or validate target
    target = args.target
    if not target:
        tester = CloudArmorLoadTester('', args.scenario, args.duration)
        target = tester.detect_load_balancer()
        if not target:
            print("\nNo target URL provided and auto-detection failed.")
            print("   Use: python load_test.py --target http://<LOAD_BALANCER_IP>")
            sys.exit(1)

    # Run the test
    tester = CloudArmorLoadTester(target, args.scenario, args.duration)
    tester.run_test()

if __name__ == "__main__":
    main()
