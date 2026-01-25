from __future__ import annotations

from django.utils.dateparse import parse_date


def parse_dates(query_params):
    """
    start=YYYY-MM-DD
    end=YYYY-MM-DD
    """
    start = query_params.get("start")
    end = query_params.get("end")

    start_date = parse_date(start) if start else None
    end_date = parse_date(end) if end else None

    return start_date, end_date


def date_range_qs(qs, date_field: str, start_date, end_date):
    if start_date:
        qs = qs.filter(**{f"{date_field}__date__gte": start_date})
    if end_date:
        qs = qs.filter(**{f"{date_field}__date__lte": end_date})
    return qs
