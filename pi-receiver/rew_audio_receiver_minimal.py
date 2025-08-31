#!/usr/bin/env python3
"""
REW Audio Receiver for Raspberry Pi - Minimal Version

Ultra-lightweight audio receiver that uses only Python standard library.
No external dependencies - just pipes audio to aplay command.

Requirements:
- Python 3.7+ (standard library only)
- aplay command (pre-installed on Raspberry Pi OS)

Usage:
    python3 rew_audio_receiver_minimal.py [--port PORT] [--verbose]

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


class MinimalAudioReceiver:
    """Minimal RTP audio receiver that pipes to aplay."""
    
    def __init__(self, port=5004):
        self.port = port
        self.running = False
        self.socket = None
        self.aplay_process = None
        self.stats = {
            "packets_received": 0,
            "bytes_received": 0,
            "errors": 0,
            "last_sequence": -1
        }
        
        self.logger = logging.getLogger(self.__class__.__name__)
    
    def start(self):
        """Start the audio receiver."""
        try:
            # Set up UDP socket for RTP
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.socket.bind(('', self.port))
            self.socket.settimeout(1.0)
            
            # Start aplay process for audio output
            # Format: 48kHz, 16-bit, stereo, little-endian
            aplay_cmd = [
                'aplay', 
                '-f', 'S16_LE',  # 16-bit signed little endian
                '-c', '2',       # 2 channels (stereo)
                '-r', '48000',   # 48kHz sample rate
                '-'              # Read from stdin
            ]
            
            self.aplay_process = subprocess.Popen(
                aplay_cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            
            self.running = True
            self.logger.info("Audio receiver started on port {}, using aplay".format(self.port))
            return True
            
        except Exception as e:
            self.logger.error("Failed to start audio receiver: {}".format(e))
            return False
    
    def stop(self):
        """Stop the audio receiver."""
        self.running = False
        
        if self.socket:
            self.socket.close()
            self.socket = None
            
        if self.aplay_process:
            self.aplay_process.terminate()
            try:
                self.aplay_process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.aplay_process.kill()
            self.aplay_process = None
            
        self.logger.info("Audio receiver stopped")
    
    def run(self):
        """Main receiver loop."""
        if not self.start():
            return
            
        self.logger.info("Waiting for RTP audio packets...")
        
        try:
            while self.running:
                try:
                    data, addr = self.socket.recvfrom(1500)
                    
                    if len(data) < 12:
                        continue
                    
                    # Parse basic RTP header
                    header = struct.unpack('!BBHII', data[:12])
                    version = (header[0] >> 6) & 0x3
                    sequence = header[2]
                    
                    if version != 2:
                        continue
                    
                    # Extract audio payload
                    audio_data = data[12:]
                    
                    if audio_data and self.aplay_process:
                        try:
                            self.aplay_process.stdin.write(audio_data)
                            self.aplay_process.stdin.flush()
                        except (BrokenPipeError, OSError):
                            # aplay process died - restart it
                            self.logger.warning("aplay process died, restarting...")
                            self.restart_aplay()
                    
                    # Update statistics
                    self.stats["packets_received"] += 1
                    self.stats["bytes_received"] += len(data)
                    
                    # Check for dropped packets
                    if self.stats["last_sequence"] != -1:
                        expected = (self.stats["last_sequence"] + 1) & 0xFFFF
                        if sequence != expected:
                            dropped = (sequence - expected) & 0xFFFF
                            self.stats["errors"] += dropped
                            self.logger.warning("Dropped {} packets".format(dropped))
                    
                    self.stats["last_sequence"] = sequence
                    
                except socket.timeout:
                    continue
                except Exception as e:
                    self.logger.error("Error receiving audio: {}".format(e))
                    self.stats["errors"] += 1
                    
        except KeyboardInterrupt:
            self.logger.info("Received interrupt signal")
        finally:
            self.stop()
    
    def restart_aplay(self):
        """Restart the aplay process."""
        if self.aplay_process:
            self.aplay_process.terminate()
            try:
                self.aplay_process.wait(timeout=1)
            except subprocess.TimeoutExpired:
                self.aplay_process.kill()
        
        try:
            aplay_cmd = ['aplay', '-f', 'S16_LE', '-c', '2', '-r', '48000', '-']
            self.aplay_process = subprocess.Popen(
                aplay_cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
        except Exception as e:
            self.logger.error("Failed to restart aplay: {}".format(e))
            self.aplay_process = None


class StatusHandler(BaseHTTPRequestHandler):
    """HTTP handler for status API."""
    
    def do_GET(self):
        """Handle GET requests."""
        if self.path == '/status':
            self.send_status()
        elif self.path == '/health':
            self.send_health()
        else:
            self.send_error(404, "Not found")
    
    def send_status(self):
        """Send status information."""
        status = {
            "service": "REW Audio Receiver (Minimal)",
            "version": "1.0.0-minimal",
            "status": "running",
            "audio": {
                "method": "aplay",
                "port": self.server.audio_receiver.port,
                "running": self.server.audio_receiver.running,
            },
            "stats": self.server.audio_receiver.stats.copy(),
            "timestamp": int(time.time())
        }
        
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(status, indent=2).encode())
    
    def send_health(self):
        """Send simple health check."""
        health = {"status": "healthy", "timestamp": int(time.time())}
        
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(health).encode())
    
    def log_message(self, format, *args):
        """Suppress HTTP logging unless verbose."""
        if hasattr(self.server, 'verbose') and self.server.verbose:
            super().log_message(format, *args)


class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    """Multi-threaded HTTP server."""
    allow_reuse_address = True
    # daemon_threads available in Python 3.7+


class MinimalREWService:
    """Minimal service with audio receiver and HTTP API only."""
    
    def __init__(self, rtp_port=5004, http_port=8080, verbose=False):
        self.rtp_port = rtp_port
        self.http_port = http_port
        self.verbose = verbose
        
        self.audio_receiver = MinimalAudioReceiver(rtp_port)
        self.http_server = None
        
        self.logger = logging.getLogger(self.__class__.__name__)
    
    def start(self):
        """Start service components."""
        self.logger.info("Starting Minimal REW Audio Service...")
        
        # Start HTTP status server
        self.http_server = ThreadedHTTPServer(('', self.http_port), StatusHandler)
        self.http_server.audio_receiver = self.audio_receiver
        self.http_server.verbose = self.verbose
        
        http_thread = threading.Thread(target=self.http_server.serve_forever)
        http_thread.daemon = True
        http_thread.start()
        self.logger.info("HTTP status server started on port {}".format(self.http_port))
        
        # Print service info (since no mDNS)
        hostname = socket.gethostname()
        self.logger.info("REW Audio Receiver ready!")
        self.logger.info("Hostname: {}".format(hostname))
        self.logger.info("RTP Port: {}".format(self.rtp_port))
        self.logger.info("Status URL: http://{}:{}".format(hostname, self.http_port))
        self.logger.info("Note: No mDNS - configure Java client manually")
        
        # Start audio receiver (blocking)
        self.audio_receiver.run()
    
    def stop(self):
        """Stop service components."""
        self.logger.info("Stopping Minimal REW Audio Service...")
        
        if self.http_server:
            self.http_server.shutdown()
            self.http_server.server_close()
        
        self.audio_receiver.stop()
        self.logger.info("Minimal REW Audio Service stopped")


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description="REW Audio Receiver - Minimal Version")
    parser.add_argument("--rtp-port", type=int, default=5004, help="RTP audio port (default: 5004)")
    parser.add_argument("--http-port", type=int, default=8080, help="HTTP status port (default: 8080)")
    parser.add_argument("--verbose", "-v", action="store_true", help="Enable verbose logging")
    
    args = parser.parse_args()
    
    # Set up logging
    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[logging.StreamHandler()]
    )
    
    logger = logging.getLogger("main")
    logger.info("Starting REW Pi Audio Receiver (Minimal)")
    logger.info("RTP port: {}".format(args.rtp_port))
    logger.info("HTTP port: {}".format(args.http_port))
    logger.info("Using aplay for audio output (no external dependencies)")
    
    # Create and start service
    service = MinimalREWService(args.rtp_port, args.http_port, args.verbose)
    
    try:
        service.start()
    except KeyboardInterrupt:
        logger.info("Received interrupt signal")
    finally:
        service.stop()


if __name__ == "__main__":
    main()