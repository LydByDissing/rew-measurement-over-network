#!/usr/bin/env python3
"""
REW Audio Receiver for Raspberry Pi

Lightweight audio receiver that advertises via mDNS and receives RTP audio streams
from the REW Network Audio Bridge. No compilation required - uses only standard
Python libraries and system packages.

Requirements:
- Python 3.7+ (tested with 3.7.3)
- pyalsaaudio (pip install pyalsaaudio)
- zeroconf (pip install zeroconf)
- ALSA development libraries (apt-get install libasound2-dev)

Usage:
    python3 rew_audio_receiver.py [--device DEVICE] [--port PORT] [--verbose]

"""

import argparse
import json
import logging
import socket
import struct
import sys
import threading
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn

try:
    import alsaaudio
except ImportError:
    print("Error: pyalsaaudio not installed. Run: pip3 install pyalsaaudio", file=sys.stderr)
    sys.exit(1)

try:
    from zeroconf import ServiceInfo, Zeroconf
except ImportError:
    print("Error: zeroconf not installed. Run: pip3 install zeroconf", file=sys.stderr)
    sys.exit(1)


class AudioReceiver:
    """RTP audio receiver that outputs to ALSA."""
    
    def __init__(self, device="default", port=5004):
        self.device = device
        self.port = port
        self.running = False
        self.socket = None
        self.pcm = None
        self.stats = {
            "packets_received": 0,
            "bytes_received": 0,
            "errors": 0,
            "last_sequence": -1,
            "connection_errors": 0,
            "last_packet_time": 0,
            "stream_start_time": 0
        }
        
        self.logger = logging.getLogger(self.__class__.__name__)
    
    def start(self):
        """Start the audio receiver."""
        try:
            # Set up UDP socket for RTP
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.socket.bind(('', self.port))
            self.socket.settimeout(1.0)  # 1 second timeout for clean shutdown
            
            # Set up ALSA PCM output
            self.pcm = alsaaudio.PCM(
                type=alsaaudio.PCM_PLAYBACK,
                mode=alsaaudio.PCM_NONBLOCK,
                device=self.device
            )
            
            # Configure audio format (48kHz, 16-bit, stereo)
            self.pcm.setchannels(2)
            self.pcm.setrate(48000)
            self.pcm.setformat(alsaaudio.PCM_FORMAT_S16_LE)
            self.pcm.setperiodsize(1024)
            
            self.running = True
            self.stats["stream_start_time"] = int(time.time())
            
            print("🎵 Pi Audio Receiver Started!")
            print("   Port: {}".format(self.port))
            print("   Device: '{}'".format(self.device))
            print("   Format: 48kHz, 16-bit, stereo")
            print("   Waiting for RTP audio packets...")
            
            self.logger.info("Audio receiver started on port {}, device '{}'".format(self.port, self.device))
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
            
        if self.pcm:
            self.pcm.close()
            self.pcm = None
            
        self.logger.info("Audio receiver stopped")
    
    def run(self):
        """Main receiver loop."""
        if not self.start():
            return
            
        self.logger.info("Waiting for RTP audio packets...")
        packet_count = 0
        last_status_time = time.time()
        
        try:
            while self.running:
                try:
                    data, addr = self.socket.recvfrom(1500)  # Max RTP packet size
                    current_time = time.time()
                    self.stats["last_packet_time"] = int(current_time)
                    
                    if len(data) < 12:  # Minimum RTP header size
                        continue
                    
                    # Parse basic RTP header
                    # Format: V(2) P(1) X(1) CC(4) M(1) PT(7) Sequence(16) Timestamp(32) SSRC(32)
                    header = struct.unpack('!BBHII', data[:12])
                    version = (header[0] >> 6) & 0x3
                    payload_type = header[1] & 0x7F
                    sequence = header[2]
                    timestamp = header[3]
                    
                    if version != 2:  # RTP version 2
                        continue
                    
                    # Extract audio payload (skip 12-byte RTP header)
                    audio_data = data[12:]
                    
                    if audio_data:
                        # Write to ALSA (non-blocking)
                        try:
                            self.pcm.write(audio_data)
                        except alsaaudio.ALSAAudioError:
                            # Buffer full or other ALSA error - continue
                            pass
                    
                    # Update statistics
                    self.stats["packets_received"] += 1
                    self.stats["bytes_received"] += len(data)
                    packet_count += 1
                    
                    # Check for dropped packets
                    if self.stats["last_sequence"] != -1:
                        expected = (self.stats["last_sequence"] + 1) & 0xFFFF
                        if sequence != expected:
                            dropped = (sequence - expected) & 0xFFFF
                            self.stats["errors"] += dropped
                            print("⚠️  Dropped {} packets (seq {}->{}), total errors: {}".format(
                                dropped, expected, sequence, self.stats["errors"]))
                            self.logger.warning("Dropped {} packets (seq {}->{})".format(dropped, expected, sequence))
                    
                    self.stats["last_sequence"] = sequence
                    
                    # Periodic status reporting (every 1000 packets)
                    if packet_count > 0 and packet_count % 1000 == 0:
                        duration = current_time - last_status_time
                        if duration > 0:
                            bitrate = (self.stats["bytes_received"] * 8.0) / duration
                            connection_status = self.get_connection_status()
                            print("📊 Pi Receiver: {} pkts, {:.1f} kbps, status: {}".format(
                                self.stats["packets_received"], bitrate / 1000, connection_status))
                    
                except socket.timeout:
                    # Normal timeout - check if we should continue
                    self.check_connection_health()
                    continue
                except Exception as e:
                    self.stats["connection_errors"] += 1
                    print("❌ Pi Receiver error #{}: {}".format(self.stats["connection_errors"], e))
                    self.logger.error("Error receiving audio: {}".format(e))
                    self.stats["errors"] += 1
                    
        except KeyboardInterrupt:
            self.logger.info("Received interrupt signal")
        finally:
            self.stop()
    
    def get_connection_status(self):
        """Get the current connection status."""
        if not self.running:
            return "STOPPED"
        
        current_time = int(time.time())
        last_packet_time = self.stats.get("last_packet_time", 0)
        
        if last_packet_time == 0:
            return "WAITING"
        
        time_since_last = current_time - last_packet_time
        
        if time_since_last < 2:
            return "GOOD"
        elif time_since_last < 10:
            return "SLOW"
        else:
            return "DISCONNECTED"
    
    def check_connection_health(self):
        """Check connection health and log warnings if needed."""
        if not self.running:
            return
        
        current_time = int(time.time())
        last_packet_time = self.stats.get("last_packet_time", 0)
        stream_start_time = self.stats.get("stream_start_time", current_time)
        
        # Only check if we've been running for at least 10 seconds
        if current_time - stream_start_time < 10:
            return
        
        time_since_last = current_time - last_packet_time
        
        if time_since_last > 15:  # 15 seconds without packets
            print("⚠️  Pi Receiver: No data received for {} seconds".format(time_since_last))
            self.logger.warning("No data received for {} seconds".format(time_since_last))
        
        # Check error rate
        total_packets = self.stats["packets_received"]
        total_errors = self.stats["errors"]
        
        if total_packets > 100 and total_errors > total_packets * 0.05:  # More than 5% error rate
            error_percent = (total_errors * 100.0) / total_packets
            print("⚠️  Pi Receiver: High error rate: {:.1f}% ({}/{} packets)".format(
                error_percent, total_errors, total_packets))
            self.logger.warning("High error rate: {:.1f}% ({}/{})".format(
                error_percent, total_errors, total_packets))


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
        """Send detailed status information."""
        status = {
            "service": "REW Audio Receiver",
            "version": "1.0.0",
            "status": "running",
            "audio": {
                "device": self.server.audio_receiver.device,
                "port": self.server.audio_receiver.port,
                "running": self.server.audio_receiver.running,
            },
            "stats": self.server.audio_receiver.stats.copy(),
            "connection_status": self.server.audio_receiver.get_connection_status(),
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
        """Suppress default HTTP logging."""
        pass


class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    """Multi-threaded HTTP server."""
    allow_reuse_address = True
    daemon_threads = True


class REWAudioService:
    """Main service that combines audio receiver, HTTP API, and mDNS advertisement."""
    
    def __init__(self, audio_device="default", rtp_port=5004, http_port=8080):
        self.audio_device = audio_device
        self.rtp_port = rtp_port
        self.http_port = http_port
        
        self.audio_receiver = AudioReceiver(audio_device, rtp_port)
        self.http_server = None
        self.zeroconf = None
        self.service_info = None
        
        self.logger = logging.getLogger(self.__class__.__name__)
    
    def start(self):
        """Start all service components."""
        print("🚀 Starting REW Pi Audio Service...")
        print("   Audio device: {}".format(self.audio_device))
        print("   RTP port: {}".format(self.rtp_port))
        print("   HTTP status port: {}".format(self.http_port))
        
        self.logger.info("Starting REW Audio Service...")
        
        # Start HTTP status server
        self.http_server = ThreadedHTTPServer(('', self.http_port), StatusHandler)
        self.http_server.audio_receiver = self.audio_receiver
        
        http_thread = threading.Thread(target=self.http_server.serve_forever, daemon=True)
        http_thread.start()
        self.logger.info("HTTP status server started on port {}".format(self.http_port))
        
        # Start mDNS service advertisement
        self.start_mdns()
        
        # Start audio receiver (blocking)
        self.audio_receiver.run()
    
    def start_mdns(self):
        """Start mDNS service advertisement."""
        try:
            self.zeroconf = Zeroconf()
            
            # Get local IP address
            hostname = socket.gethostname()
            local_ip = socket.gethostbyname(hostname + ".local")
            
            # Create service info
            service_name = "REW-Pi-{}._rew-audio._tcp.local.".format(hostname)
            self.service_info = ServiceInfo(
                "_rew-audio._tcp.local.",
                service_name,
                addresses=[socket.inet_aton(local_ip)],
                port=self.rtp_port,
                properties={
                    'version': '1.0.0',
                    'device': self.audio_device,
                    'http_port': str(self.http_port),
                    'audio_format': '48000/16/2'  # Sample rate/bit depth/channels
                },
                server=hostname + ".local."
            )
            
            # Register service
            self.zeroconf.register_service(self.service_info)
            print("📡 mDNS service registered: {}".format(service_name))
            self.logger.info("mDNS service registered: {}".format(service_name))
            
        except Exception as e:
            print("❌ Failed to start mDNS service: {}".format(e))
            self.logger.error("Failed to start mDNS service: {}".format(e))
    
    def stop(self):
        """Stop all service components."""
        print("🛑 Stopping REW Pi Audio Service...")
        self.logger.info("Stopping REW Audio Service...")
        
        # Stop mDNS advertisement
        if self.zeroconf and self.service_info:
            self.zeroconf.unregister_service(self.service_info)
            self.zeroconf.close()
        
        # Stop HTTP server
        if self.http_server:
            self.http_server.shutdown()
            self.http_server.server_close()
        
        # Stop audio receiver
        self.audio_receiver.stop()
        
        print("✅ REW Pi Audio Service stopped")
        self.logger.info("REW Audio Service stopped")


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description="REW Audio Receiver for Raspberry Pi")
    parser.add_argument("--device", default="default", help="ALSA audio device (default: default)")
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
    logger.info("Starting REW Pi Audio Receiver")
    logger.info("Audio device: {}".format(args.device))
    logger.info("RTP port: {}".format(args.rtp_port))
    logger.info("HTTP port: {}".format(args.http_port))
    
    # Create and start service
    service = REWAudioService(args.device, args.rtp_port, args.http_port)
    
    try:
        service.start()
    except KeyboardInterrupt:
        logger.info("Received interrupt signal")
    finally:
        service.stop()


if __name__ == "__main__":
    main()