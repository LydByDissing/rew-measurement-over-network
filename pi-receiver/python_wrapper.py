#!/usr/bin/env python3
"""
Python wrapper script to fix 32-bit ARM timestamp issues.
This must run before any other Python imports to set safe environment values.
"""

import os
import sys

# Set timestamp fix BEFORE any other imports
os.environ['SOURCE_DATE_EPOCH'] = '1577836800'  # Jan 1, 2020 00:00:00 UTC
os.environ['PYTHONHASHSEED'] = '0'
os.environ['SETUPTOOLS_USE_DISTUTILS'] = 'stdlib'

# Force Python to use safe time values
import time
# Monkey patch time functions to use safe values for 32-bit systems
original_time = time.time

def safe_time():
    """Return a safe timestamp for 32-bit systems"""
    try:
        current_time = original_time()
        # If timestamp is too large for 32-bit, use a safe fallback
        if current_time > 2**31 - 1:
            return 1577836800  # Jan 1, 2020 00:00:00 UTC
        return current_time
    except (OSError, OverflowError):
        return 1577836800

# Replace time.time with our safe version
time.time = safe_time

# Now safely import and run the main receiver
if __name__ == '__main__':
    # Import the main receiver module
    import rew_audio_receiver
    
    # Pass all arguments to the main receiver
    rew_audio_receiver.main(sys.argv[1:])