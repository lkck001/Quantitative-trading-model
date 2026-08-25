"""Convert Forex Tester 2 Bars.dat records to the MT5 replay CSV format.

Forex Tester stores M1 bars as:

    uint32 valid_record_count
    repeated <time_oa, open, close, high, low, volume> (six float64 values)

The generated CSV has no header and uses these nine columns:

    Date,Time,Open,High,Low,Close,TickVolume,RealVolume,Spread
"""

from __future__ import annotations

import argparse
import math
import os
import struct
import tempfile
from datetime import date, datetime, time, timedelta
from pathlib import Path


HEADER = struct.Struct("<I")
RECORD = struct.Struct("<6d")
OA_EPOCH = datetime(1899, 12, 30)


def parse_date(value: str) -> date:
    try:
        return date.fromisoformat(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(
            f"Invalid date {value!r}; expected YYYY-MM-DD"
        ) from exc


def oa_datetime(value: float) -> datetime:
    return OA_EPOCH + timedelta(days=value)


def convert(
    source: Path,
    output: Path,
    start_date: date,
    end_date: date,
    spread: int,
    overwrite: bool,
) -> dict[str, object]:
    if end_date < start_date:
        raise ValueError("End date must not be earlier than start date")
    if output.exists() and not overwrite:
        raise FileExistsError(f"Output already exists: {output}")

    start = datetime.combine(start_date, time.min)
    end_exclusive = datetime.combine(end_date + timedelta(days=1), time.min)
    output.parent.mkdir(parents=True, exist_ok=True)

    temp_path: Path | None = None
    written = 0
    scanned = 0
    first_time: datetime | None = None
    last_time: datetime | None = None

    try:
        with source.open("rb") as source_file:
            raw_header = source_file.read(HEADER.size)
            if len(raw_header) != HEADER.size:
                raise ValueError("Source is too short to contain a Forex Tester header")

            declared_count = HEADER.unpack(raw_header)[0]
            available_count = (source.stat().st_size - HEADER.size) // RECORD.size
            readable_count = min(declared_count, available_count)

            with tempfile.NamedTemporaryFile(
                "w",
                encoding="ascii",
                newline="",
                dir=output.parent,
                prefix=f".{output.name}.",
                suffix=".tmp",
                delete=False,
            ) as output_file:
                temp_path = Path(output_file.name)

                for index in range(readable_count):
                    raw_record = source_file.read(RECORD.size)
                    if len(raw_record) != RECORD.size:
                        raise ValueError(f"Truncated record at index {index}")
                    scanned += 1

                    oa_value, open_, close, high, low, volume = RECORD.unpack(raw_record)
                    if not all(
                        math.isfinite(value)
                        for value in (oa_value, open_, close, high, low, volume)
                    ):
                        raise ValueError(f"Non-finite value at record {index}")

                    timestamp = oa_datetime(oa_value)
                    if timestamp < start:
                        continue
                    if timestamp >= end_exclusive:
                        break

                    tolerance = 1e-10
                    if high + tolerance < max(open_, close, low):
                        raise ValueError(
                            f"Invalid high at record {index}: "
                            f"open={open_}, high={high}, low={low}, close={close}"
                        )
                    if low - tolerance > min(open_, close, high):
                        raise ValueError(
                            f"Invalid low at record {index}: "
                            f"open={open_}, high={high}, low={low}, close={close}"
                        )
                    if volume < 0:
                        raise ValueError(f"Negative volume at record {index}: {volume}")
                    if last_time is not None and timestamp <= last_time:
                        raise ValueError(
                            f"Timestamps are not strictly increasing at record {index}: "
                            f"{timestamp.isoformat(sep=' ')}"
                        )

                    integer_volume = int(round(volume))
                    output_file.write(
                        f"{timestamp:%Y.%m.%d},{timestamp:%H:%M},"
                        f"{open_:.5f},{high:.5f},{low:.5f},{close:.5f},"
                        f"{integer_volume},{integer_volume},{spread}\n"
                    )

                    first_time = first_time or timestamp
                    last_time = timestamp
                    written += 1

        if written == 0:
            raise ValueError(
                f"No records found from {start_date.isoformat()} through "
                f"{end_date.isoformat()}"
            )

        if output.exists() and not overwrite:
            raise FileExistsError(f"Output was created during conversion: {output}")
        os.replace(temp_path, output)
        temp_path = None

        return {
            "declared_count": declared_count,
            "available_count": available_count,
            "scanned": scanned,
            "written": written,
            "first_time": first_time,
            "last_time": last_time,
        }
    finally:
        if temp_path is not None:
            temp_path.unlink(missing_ok=True)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Forex Tester Bars.dat path")
    parser.add_argument("output", type=Path, help="Destination CSV path")
    parser.add_argument("--start", type=parse_date, required=True, help="YYYY-MM-DD")
    parser.add_argument("--end", type=parse_date, required=True, help="YYYY-MM-DD")
    parser.add_argument("--spread", type=int, default=30, help="CSV spread value")
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Replace the output file if it already exists",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()
    result = convert(
        source=args.source,
        output=args.output,
        start_date=args.start,
        end_date=args.end,
        spread=args.spread,
        overwrite=args.overwrite,
    )

    print(f"Wrote: {args.output}")
    print(f"Rows: {result['written']}")
    print(f"First: {result['first_time']}")
    print(f"Last: {result['last_time']}")
    print(
        "Source records: "
        f"declared={result['declared_count']}, "
        f"available={result['available_count']}, scanned={result['scanned']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
