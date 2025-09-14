#!/bin/bash
#
# Simple Python wrapper for 32-bit ARM compatibility
# Python 3.11 should handle timestamp issues better
#

set -e

# Set safe timestamp environment variables
export SOURCE_DATE_EPOCH=1577836800  # Jan 1, 2020 00:00:00 UTC 
export PYTHONHASHSEED=0
export SETUPTOOLS_USE_DISTUTILS=stdlib

# Additional Python environment fixes
export PYTHONUNBUFFERED=1
export PYTHONDONTWRITEBYTECODE=1
export PYTHONIOENCODING=utf-8

# Run Python directly - modern Python should handle ARM timestamps
exec python3 "$@"