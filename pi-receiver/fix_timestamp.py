#!/usr/bin/env python3
"""
Timestamp fix for 32-bit ARM systems
Must be imported before any other modules that use time
"""

import os
import sys
import time as _time_module

# Set safe environment variables first
os.environ.setdefault('SOURCE_DATE_EPOCH', '1577836800')  # 2020-01-01
os.environ.setdefault('PYTHONHASHSEED', '0')

# Save original time function
_original_time = _time_module.time

def _safe_time():
    """Safe time function that handles 32-bit overflow"""
    try:
        current_time = _original_time()
        # Check if timestamp exceeds 32-bit signed int limit
        if current_time > 2147483647:  # Jan 19, 2038 03:14:07 UTC
            print(f"Warning: System time {current_time} exceeds 32-bit limit, using fallback", file=sys.stderr)
            return 1577836800.0  # 2020-01-01 00:00:00 UTC
        return current_time
    except (OSError, OverflowError) as e:
        print(f"Warning: Time error {e}, using fallback timestamp", file=sys.stderr)
        return 1577836800.0

# Monkey patch the time module BEFORE any imports
_time_module.time = _safe_time

print("✅ Timestamp fix applied for 32-bit ARM compatibility", file=sys.stderr)