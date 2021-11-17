import pathlib

from pyhocon import ConfigFactory


_DB_CONF = pathlib.Path("db.conf")
_REPORT_CONF = pathlib.Path("report.conf")

_DB_CONFIG_DEFAULTS = ConfigFactory.parse_string(
    """
username = ${?DB_USER}
password = ${?DB_PASSWORD}
host = ${?DB_HOST}
database = ${?DB_DATABASE}
source_driver = "mysql+pymysql"
"""
)

try:
    db = ConfigFactory.parse_file(_DB_CONF).with_fallback(_DB_CONFIG_DEFAULTS)
except FileNotFoundError:
    db = _DB_CONFIG_DEFAULTS

report = ConfigFactory.parse_file(_REPORT_CONF)

__all__ = ["db", "report"]

