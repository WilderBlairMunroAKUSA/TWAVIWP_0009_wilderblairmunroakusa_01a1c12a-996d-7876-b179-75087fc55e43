#!/usr/bin/env python3

"""
v0::

Usage:
chmod +x midnight_uuid7.py

# Today, based on OS local date
./midnight_uuid7.py

# Explicit date (optional)
./midnight_uuid7.py 2026-11-04
"""

import argparse
import secrets
import uuid
from datetime import date, datetime, time

def uuid7_midnight(day: date) -> uuid.UUID:
    # OS-local midnight, converted to Unix milliseconds
    ms = int(datetime.combine(day, time.min).timestamp() * 1000)

    value = (
        (ms << 80)
        | (0x7 << 76)                 # UUIDv7 version
        | (secrets.randbits(12) << 64)
        | (0b10 << 62)               # UUID variant
        | secrets.randbits(62)
    )
    return uuid.UUID(int=value)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "day", nargs="?", type=date.fromisoformat,
        default=date.today()
    )
    args = parser.parse_args()
    print(uuid7_midnight(args.day))

