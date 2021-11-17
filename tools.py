import datetime

import pytz


def today(timezone: str = "America/Chicago") -> datetime.date:
    return datetime.datetime.now(tz=pytz.timezone(timezone)).date()

