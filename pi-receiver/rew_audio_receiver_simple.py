#!/usr/bin/env python3
"""
REW Audio Receiver - Simplified Container Version

Basic audio receiver that receives RTP audio streams from the REW Network Audio Bridge.
Simplified for container deployment without mDNS or complex audio device detection.

Requirements:
- Python 3.7+
- aplay command available (alsa-utils package)

Usage:
    python3 rew_audio_receiver_simple.py [--device DEVICE] [--rtp-port PORT] [--http-port PORT] [--verbose]
"""

import argparse
import json
import logging
import socket
import struct
import subprocess
import sys
import threading
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn

# Global statistics
stats = {
    'packets_received': 0,
    'bytes_received': 0,
    'errors': 0,
    'last_sequence': -1,
    'start_time': time.time(),
    'connected': False,
    'connection_time': 0,
    'last_sender': None
}


class SimpleHTTPHandler(BaseHTTPRequestHandler):
    """Simple HTTP handler for status API."""
    
    def do_GET(self):
        if self.path in ['/status', '/health']:
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            
            response = {
                'service': 'REW Audio Receiver',
                'version': '1.0.0-simple',
                'status': 'healthy',
                'audio': {
                    'method': 'aplay',
                    'port': args.rtp_port,
                    'sample_rate': '48000',
                    'format': '48000Hz/16bit',
                    'running': True
                },
                'stats': stats.copy(),
                'timestamp': int(time.time())
            }
            
            self.wfile.write(json.dumps(response, indent=2).encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        # Suppress HTTP server logs unless verbose
        if args and hasattr(args[0], 'verbose') and args[0].verbose:
            super().log_message(format, *args)


class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    """Multi-threaded HTTP server."""
    allow_reuse_address = True


class SimpleAudioReceiver:
    """Simple RTP audio receiver using aplay subprocess."""
    
    def __init__(self, device="default", port=5004, verbose=False):
        self.device = device
        self.port = port
        self.verbose = verbose
        self.running = False
        self.socket = None
        self.aplay_process = None
        self.last_packet_time = 0
        
        # Setup logging
        logging.basicConfig(
            level=logging.DEBUG if verbose else logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)
    
    def start_aplay(self):
        """Start aplay subprocess for audio output."""
        try:
            # aplay command for 48kHz stereo 16-bit audio
            cmd = [
                'aplay', 
                '--device', self.device,
                '--format', 'S16_LE',
                '--rate', '48000',
                '--channels', '2',
                '--buffer-time', '50000'  # 50ms buffer
            ]
            
            self.logger.info(f"Starting aplay: {' '.join(cmd)}")
            
            self.aplay_process = subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE if self.verbose else subprocess.DEVNULL
            )
            
            self.logger.info("Audio output started successfully")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to start aplay: {e}")
            return False
    
    def stop_aplay(self):
        """Stop aplay subprocess."""
        if self.aplay_process:
            try:
                self.aplay_process.terminate()
                self.aplay_process.wait(timeout=5)
            except:
                self.aplay_process.kill()
            self.aplay_process = None
    
    def start(self):
        """Start the RTP receiver."""
        try:
            # Create UDP socket
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.socket.settimeout(1.0)  # 1 second timeout for disconnection detection
            self.socket.bind(('0.0.0.0', self.port))
            
            self.logger.info(f"RTP receiver listening on port {self.port}")
            
            # Start audio output
            if not self.start_aplay():
                return False
            
            self.running = True
            
            # Receive loop
            while self.running:
                try:
                    data, addr = self.socket.recvfrom(1500)  # Max UDP packet size
                    
                    if len(data) < 12:  # Minimum RTP header size
                        continue
                    
                    # Parse RTP header (simplified)
                    header = struct.unpack('!BBHII', data[:12])
                    version = (header[0] >> 6) & 0x3
                    payload_type = header[1] & 0x7F
                    sequence = header[2]
                    
                    if version != 2:  # RTP version 2
                        continue
                    
                    # Extract audio payload (skip RTP header)
                    audio_data = data[12:]
                    
                    # Write to aplay stdin
                    if self.aplay_process and audio_data:
                        try:
                            self.aplay_process.stdin.write(audio_data)
                            self.aplay_process.stdin.flush()
                        except BrokenPipeError:
                            self.logger.warning("Audio output pipe broken, restarting...")
                            self.stop_aplay()
                            if not self.start_aplay():
                                break
                        except Exception as e:
                            self.logger.error(f"Audio output error: {e}")
                    
                    # Detect new connection
                    if not stats['connected']:
                        stats['connected'] = True
                        stats['connection_time'] = int(time.time())
                        stats['last_sender'] = addr[0]
                        print(f"🔗 Connected to REW Audio Bridge from {addr[0]}:{addr[1]}")
                        self.logger.info(f"REW Audio Bridge connected from {addr[0]}:{addr[1]}")
                    elif stats['last_sender'] != addr[0]:
                        # New sender detected
                        stats['last_sender'] = addr[0]
                        print(f"🔄 REW Audio Bridge switched to {addr[0]}:{addr[1]}")
                        self.logger.info(f"REW Audio Bridge switched to {addr[0]}:{addr[1]}")
                    
                    # Update statistics
                    stats['packets_received'] += 1
                    stats['bytes_received'] += len(data)
                    stats['last_sequence'] = sequence
                    self.last_packet_time = time.time()
                    
                    if self.verbose and stats['packets_received'] % 100 == 0:
                        self.logger.info(f"Received {stats['packets_received']} packets")
                
                except socket.timeout:
                    # Check for disconnection (no packets for 5 seconds)
                    if stats['connected'] and self.last_packet_time > 0:
                        if time.time() - self.last_packet_time > 5.0:
                            print(f"❌ REW Audio Bridge disconnected from {stats['last_sender']}")
                            self.logger.info(f"REW Audio Bridge disconnected from {stats['last_sender']}")
                            stats['connected'] = False
                            stats['last_sender'] = None
                    continue
                except Exception as e:
                    self.logger.error(f"Receive error: {e}")
                    stats['errors'] += 1
                    time.sleep(0.1)
            
        except Exception as e:
            self.logger.error(f"Failed to start receiver: {e}")
            return False
        
        return True
    
    def stop(self):
        """Stop the receiver."""
        self.running = False
        self.stop_aplay()
        
        if self.socket:
            self.socket.close()
            self.socket = None
        
        self.logger.info("Receiver stopped")


def main():
    global args
    
    parser = argparse.ArgumentParser(description='REW Audio Receiver - Simple Version')
    parser.add_argument('--device', default='default', 
                       help='Audio output device (default: default)')
    parser.add_argument('--rtp-port', type=int, default=5004,
                       help='RTP listening port (default: 5004)')
    parser.add_argument('--http-port', type=int, default=8080,
                       help='HTTP status server port (default: 8080)')
    parser.add_argument('--verbose', action='store_true',
                       help='Enable verbose logging')
    
    args = parser.parse_args()
    
    print("🎵 REW Audio Receiver - Simple Container Version")
    print("=" * 50)
    print(f"RTP Port: {args.rtp_port}")
    print(f"HTTP Port: {args.http_port}")
    print(f"Audio Device: {args.device}")
    print(f"Verbose: {args.verbose}")
    print()
    
    # Test audio system
    print("Testing audio system...")
    try:
        result = subprocess.run(['aplay', '--version'], 
                              capture_output=True, text=True)
        print(f"✓ aplay available: {result.stdout.strip().split()[0]}")
    except FileNotFoundError:
        print("✗ aplay not found - install alsa-utils package")
        return 1
    
    # List available audio devices
    try:
        result = subprocess.run(['aplay', '-l'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            print("Available audio devices:")
            for line in result.stdout.split('\n'):
                if 'card' in line.lower():
                    print(f"  {line.strip()}")
        else:
            print("No audio devices found - using null device")
            args.device = 'null'
    except:
        print("Could not list audio devices")
    
    print()
    
    # Start HTTP status server
    try:
        http_server = ThreadedHTTPServer(('0.0.0.0', args.http_port), SimpleHTTPHandler)
        http_thread = threading.Thread(target=http_server.serve_forever, daemon=True)
        http_thread.start()
        print(f"✓ HTTP status server running on port {args.http_port}")
    except Exception as e:
        print(f"✗ Failed to start HTTP server: {e}")
        return 1
    
    # Start audio receiver
    receiver = SimpleAudioReceiver(args.device, args.rtp_port, args.verbose)
    
    try:
        print(f"✓ Starting RTP audio receiver on port {args.rtp_port}...")
        print("Ready to receive audio streams!")
        print(f"Status API: http://localhost:{args.http_port}/status")
        print("Press Ctrl+C to stop")
        print()
        
        if not receiver.start():
            print("Failed to start receiver")
            return 1
            
    except KeyboardInterrupt:
        print("\nShutdown requested...")
        receiver.stop()
        http_server.shutdown()
        print("Stopped")
        return 0
    except Exception as e:
        print(f"Error: {e}")
        receiver.stop()
        return 1


if __name__ == '__main__':
    sys.exit(main())