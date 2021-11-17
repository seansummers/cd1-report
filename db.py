import contextlib
import pathlib

from typing import Any, Iterable, Iterator, Mapping, Tuple, Union

import sqlalchemy
from sqlalchemy.engine.url import URL


class DbEngine:
    def __init__(self, db_config: Mapping[str, Any]):
        cfg = dict(db_config)
        self.source_driver = cfg.pop("source_driver", "mysql+pymysql")
        self.url = URL.create(self.source_driver, **cfg)
        self.engine = sqlalchemy.create_engine(
            self.url, isolation_level="READ UNCOMMITTED"
        )
        self.meta = sqlalchemy.MetaData()

    def callproc(self, proc: str, *args: Iterable[Any]) -> None:
        with contextlib.closing(self.engine.raw_connection()) as con:
            with con.cursor() as cur:
                cur.callproc(proc, *args)
                con.commit()

    def rows(
        self, table_name: str, header: bool = True
    ) -> Iterator[Union[Tuple[str], sqlalchemy.engine.Row]]:
        table = sqlalchemy.Table(table_name, self.meta, autoload_with=self.engine)
        if header:
            yield tuple(_.name for _ in table.columns)
        with self.engine.begin() as con, contextlib.closing(
            con.execute(table.select())
        ) as rows:
            yield from rows

