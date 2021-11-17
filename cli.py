import argparse
import datetime
import itertools

from typing import Any, Mapping

from .range import extract, expand
from .tools import today


def parse_args(report_cfg: Mapping[str, Any]) -> argparse.Namespace:
    now = today()
    report_list = tuple(report_cfg.keys())
    store_list = extract(report_cfg["stores"]["stores"])
    table_list = tuple(
        itertools.chain.from_iterable(report.tables for report in report_cfg.values())
    )
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-d",
        "--date",
        help=f"The date for the report and export (defaults to TODAY [{now}]).",
        default=now,
        type=datetime.date.fromisoformat,
    )
    parser.add_argument(
        "-i",
        "--store-ids",
        help=f"The specific Store ID(s) to report (defaults to '{store_list}').",
        type=expand,
        default=store_list,
    )
    parser.add_argument(
        "-r",
        "--reports",
        help=f"Run the specified report(s): {','.join(report_list)}.",
        metavar="report_name",
        choices=report_list,
        nargs="*",
    )
    parser.add_argument(
        "--export",
        help="Export report tables. (default)",
        action="store_true",
        default=True,
    )
    parser.add_argument(
        "--no-export",
        help="Don't export report tables.",
        action="store_false",
        dest="export",
    )
    parser.add_argument(
        "--dump",
        help=f"Export tables, overriding all other options.",
        nargs="*",
        choices=table_list,
    )
    args = parser.parse_args()
    if args.dump is not None:
        args = argparse.Namespace(date=args.date, dump=args.dump or table_list)
    elif args.reports is None:
        parser.print_help()
        raise SystemExit()
    return args

