import pathlib

from pyhocon import ConfigFactory
from pyhocon.converter import HOCONConverter


_DB_CONF = pathlib.Path("db.conf")
_REPORT_CONF = pathlib.Path("report.conf")

_DB_CONFIG_DEFAULTS = ConfigFactory.parse_string(
    """
source_driver = "mysql+pymysql"

username = "database username"
password = "database password"
host = "database server host"
database = "database name"

username = ${?DB_USER}
password = ${?DB_PASSWORD}
host = ${?DB_HOST}
database = ${?DB_DATABASE}
"""
)

_REPORT_CONFIG_DEFAULTS = ConfigFactory.parse_string(
    """
orders {
  procedures = [
    "order_report_procedure"
  ]
  tables = [
    "order_report"
  ]
}
customers {
  procedures = [
    "customer_report_procedure"
    "customer_order_transaction_report_procedure"
  ]
  tables = [
    "customer_report"
    "customer_order_transaction_report"
  ]
}
stores {
  procedures = [
    "invoice_balance_procedure_orders"
    "invoice_balance_procedure_subscriptions"
    "xyz_calc_daily_store_driver_stats"
    "abc_calc_daily_store_stats"
  ]
  tables = [
    "invoice_balance_orders_report"
    "invoice_balance_subscriptions_report"
    "cleaner_daily_driver_stats_1902"
    "abc_cleaner_daily_stats_1902"
  ]
  stores = [
    8
    17
    18
    19
    21
    22
    23
    24
  ]
}
"""
)


try:
    db = ConfigFactory.parse_file(_DB_CONF).with_fallback(_DB_CONFIG_DEFAULTS)
except FileNotFoundError:
    db = _DB_CONFIG_DEFAULTS

try:
    report = ConfigFactory.parse_file(_REPORT_CONF).with_fallback(
        _REPORT_CONFIG_DEFAULTS
    )
except FileNotFoundError:
    report = _REPORT_CONFIG_DEFAULTS


def generate_db() -> str:
    return HOCONConverter.to_hocon(db)


def generate_report() -> str:
    return HOCONConverter.to_hocon(report)


__all__ = ["db", "report", "generate_db", "generate_report"]

