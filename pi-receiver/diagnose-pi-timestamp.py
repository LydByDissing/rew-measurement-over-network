#!/usr/bin/env python3
"""
Pi Timestamp Diagnostic Script
Helps identify timestamp issues on Raspberry Pi
"""

import sys
import platform
import time
import os
from datetime import datetime

print("🔍 Pi Timestamp Diagnostic")
print("=" * 40)

# Basic system info
print(f"Python version: {sys.version}")
print(f"Platform: {platform.platform()}")
print(f"Architecture: {platform.machine()}")
print(f"Processor: {platform.processor()}")

# Check if 32-bit or 64-bit
print(f"Pointer size: {sys.getsizeof(0)} bytes")
print(f"Max int: {sys.maxsize}")

print("\n🕒 Time Module Tests")
print("-" * 20)

try:
    # Test current time
    current_time = time.time()
    print(f"✅ Current timestamp: {current_time}")
    print(f"✅ Current datetime: {datetime.fromtimestamp(current_time)}")
except Exception as e:
    print(f"❌ Current time failed: {e}")

try:
    # Test specific problematic timestamp (if any)
    test_timestamp = 1757443100  # From our working test
    dt = datetime.fromtimestamp(test_timestamp)
    print(f"✅ Test timestamp {test_timestamp}: {dt}")
except Exception as e:
    print(f"❌ Test timestamp failed: {e}")

try:
    # Test future timestamp that might cause issues on 32-bit
    future_timestamp = 2147483647  # 32-bit signed int limit
    dt = datetime.fromtimestamp(future_timestamp)
    print(f"✅ Max 32-bit timestamp {future_timestamp}: {dt}")
except Exception as e:
    print(f"❌ Max 32-bit timestamp failed: {e}")

try:
    # Test post-2038 timestamp
    post_2038 = 2147483648  # One second past 32-bit limit
    dt = datetime.fromtimestamp(post_2038)
    print(f"✅ Post-2038 timestamp {post_2038}: {dt}")
except Exception as e:
    print(f"❌ Post-2038 timestamp failed: {e}")

print("\n🐍 Python Module Import Tests")
print("-" * 30)

modules_to_test = [
    'logging', 'sys', 'os', 'time', 'io', 're', 
    'traceback', 'warnings', 'weakref', 'collections.abc'
]

for module_name in modules_to_test:
    try:
        __import__(module_name)
        print(f"✅ {module_name}")
    except Exception as e:
        print(f"❌ {module_name}: {e}")

print("\n🔧 System Environment")
print("-" * 20)
print(f"OS: {os.name}")
print(f"PATH: {os.environ.get('PATH', 'Not set')}")
print(f"PYTHONPATH: {os.environ.get('PYTHONPATH', 'Not set')}")
print(f"HOME: {os.environ.get('HOME', 'Not set')}")

# Check for specific Pi environment issues
if os.path.exists('/proc/version'):
    with open('/proc/version', 'r') as f:
        print(f"Kernel: {f.read().strip()}")

print("\n💡 Recommendations")
print("-" * 15)
print("If you see timestamp errors after 2038-01-19:")
print("• Your Pi might be running 32-bit OS with time_t issues")
print("• Consider upgrading to 64-bit Pi OS")
print("• Or use a time workaround in the application")

print(f"\n📋 Diagnostic complete!")