import csv
import pathlib

from typing import Any, Iterable


def export(rows: Iterable[Any], output_path: pathlib.Path) -> None:
    with output_path.open("w", newline="") as csvfile:
        csv.writer(csvfile).writerows(rows)

