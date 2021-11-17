import pathlib

from . import config
from .cli import parse_args
from .db import DbEngine
from .fs import export


def main():
    args = parse_args(config.report)
    if args.generate_db:
        print(config.generate_db())
        raise SystemExit(0)
    if args.generate_report:
        print(config.generate_report())
        raise SystemExit(0)

    db = DbEngine(config.db)

    for table_name in args.dump or []:
        export_path = pathlib.Path(f"{args.date}-{table_name}.csv")
        export(db.rows(table_name), export_path)

    for report in getattr(args, "reports", []):
        cfg = config.report[report]
        stores = cfg.get("stores", [])
        for procedure in cfg.procedures:
            if not stores:
                db.callproc(procedure)
            else:
                for store in stores:
                    db.callproc(procedure, (args.date, store))
        if args.export:
            for table_name in cfg.tables:
                export_path = pathlib.Path(f"{args.date}-{table_name}.csv")
                export(db.rows(table_name), export_path)

