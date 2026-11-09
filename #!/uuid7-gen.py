#!/usr/bin/env python3
"""Print an RFC 9562 UUIDv7 using the OS clock or a supplied date/time."""

"""
v0::01a1aa5e-2857-7fde-bbc8-daa452d60e40

usage:
python uuid7.py --date 2026-11-04
python uuid7.py --date 2026-11-04T15:30:00
python uuid7.py --date 2026-11-04T15:30:00-09:00
"""

import argparse
from datetime import datetime, timezone
import secrets
import time
import uuid


def timestamp_milliseconds(date_string):
    """Parse ISO 8601 date/time; timezone-free input means local OS time."""
    try:
        dt = datetime.fromisoformat(date_string.replace("Z", "+00:00"))
    except ValueError as exc:
        raise argparse.ArgumentTypeError(
            "expected YYYY-MM-DD or ISO 8601 date/time, "
            "e.g. 2026-11-04T15:30:00-09:00"
        ) from exc

    if dt.tzinfo is None:
        # Interpret date-only input as local midnight; naive times as local time.
        seconds = int(time.mktime(dt.timetuple()))
        milliseconds = seconds * 1000 + dt.microsecond // 1000
    else:
        # Integer arithmetic avoids float rounding at millisecond boundaries.
        delta = dt.astimezone(timezone.utc) - datetime(1970, 1, 1, tzinfo=timezone.utc)
        milliseconds = (
            delta.days * 86_400_000
            + delta.seconds * 1000
            + delta.microseconds // 1000
        )

    if not 0 <= milliseconds < (1 << 48):
        raise argparse.ArgumentTypeError("date is outside the UUIDv7 timestamp range")
    return milliseconds


def uuid7(milliseconds=None):
    if milliseconds is None:
        milliseconds = time.time_ns() // 1_000_000
    value = (
        (milliseconds << 80)
        | (0x7 << 76)                  # Version 7
        | (secrets.randbits(12) << 64)
        | (0b10 << 62)                 # RFC 9562 variant
        | secrets.randbits(62)
    )
    return uuid.UUID(int=value)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--date",
        type=timestamp_milliseconds,
        metavar="ISO8601",
        help="date (YYYY-MM-DD, at local midnight) or ISO 8601 date/time "
        "(without timezone = local OS time); default: now",
    )
    args = parser.parse_args()
    print(uuid7(args.date))


if __name__ == "__main__":
    main()
