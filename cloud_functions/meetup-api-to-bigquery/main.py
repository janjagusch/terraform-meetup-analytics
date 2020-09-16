"""
Requests data from Meetup API and inserts it into Google BigQuery.
"""

import datetime
import os
import warnings

import pandas as pd
from meetup.client import Client
from meetup.token_manager import TokenCacheGCS, TokenManager
from tqdm import tqdm

from cloud_functions_utils import decode, error_reporting, to_table

warnings.filterwarnings(
    "ignore", "Your application has authenticated using end user credentials"
)

TOKEN_MANAGER = TokenManager(
    os.environ["CLIENT_ID"],
    os.environ["CLIENT_SECRET"],
    TokenCacheGCS(os.environ["BUCKET_NAME"], os.environ["BLOB_NAME"]),
)

CLIENT = Client(access_token=lambda: TOKEN_MANAGER.token().access_token)

DATASET_ID = "meetup_raw"


def _merge_location_info(
    df,
    country_col="country",
    city_col="city",
    lon_col="lon",
    lat_col="lat",
    new_col="location",
):
    df[new_col] = df.apply(
        lambda row: {
            "country": row[country_col],
            "city": row[city_col],
            "geo": {"lon": row[lon_col], "lat": row[lat_col]},
        },
        axis=1,
    )
    return df


def _access_nested_value(df, keys, new_col):
    def nested_get(dct, keys):
        for key in keys:
            try:
                dct = dct[key]
            except KeyError:
                return None
        return dct

    df[new_col] = df.apply(lambda row: nested_get(row, keys), axis=1)
    return df


def _add_column(df, val, new_col):
    df[new_col] = val(df) if callable(val) else val
    return df


def _cast_to_datetime(df, col, new_col=None):
    if not new_col:
        new_col = col
    df[new_col] = pd.to_datetime(df[col] * 10 ** 6)
    return df


def _replace_nan(df):
    return df.replace({pd.NA: None})


def _transform_members(members, requested_at, inplace=False):
    if not inplace:
        members = members.copy()
    return (
        members.pipe(
            _access_nested_value, keys=["group_profile", "created"], new_col="joined_at"
        )
        .pipe(
            _access_nested_value,
            keys=["group_profile", "visited"],
            new_col="visited_at",
        )
        .pipe(
            _access_nested_value,
            keys=["group_profile", "updated"],
            new_col="updated_at",
        )
        .pipe(_access_nested_value, keys=["group_profile", "role"], new_col="role")
        .pipe(_cast_to_datetime, col="joined_at")
        .pipe(_cast_to_datetime, col="visited_at")
        .pipe(_cast_to_datetime, col="updated_at")
        .pipe(_cast_to_datetime, col="joined", new_col="created_at")
        .pipe(_merge_location_info)
        .pipe(_add_column, val=requested_at, new_col="requested_at")
        .pipe(_add_column, val=datetime.datetime.now(), new_col="inserted_at")
        .pipe(_replace_nan)[
            [
                "id",
                "created_at",
                "joined_at",
                "updated_at",
                "visited_at",
                "role",
                "location",
                "requested_at",
                "inserted_at",
            ]
        ]
    )


def _transform_rsvps(rsvps, requested_at, inplace=False):
    if not inplace:
        rsvps = rsvps.copy()
    return (
        rsvps.pipe(_access_nested_value, keys=["member", "id"], new_col="member_id")
        .pipe(_access_nested_value, keys=["event", "id"], new_col="event_id")
        .pipe(_access_nested_value, keys=["group", "id"], new_col="group_id")
        .pipe(_cast_to_datetime, col="updated", new_col="updated_at")
        .pipe(_cast_to_datetime, col="created", new_col="created_at")
        .pipe(_add_column, val=requested_at, new_col="requested_at")
        .pipe(_add_column, val=datetime.datetime.now(), new_col="inserted_at")
        .pipe(_replace_nan)[
            [
                "member_id",
                "event_id",
                "group_id",
                "response",
                "guests",
                "created_at",
                "updated_at",
                "requested_at",
                "inserted_at",
            ]
        ]
    )


def _transform_events(events, requested_at, inplace=False):
    if not inplace:
        events = events.copy()
    return (
        events.copy()
        .pipe(_cast_to_datetime, col="created", new_col="created_at")
        .pipe(_add_column, val=lambda df: df["duration"] / 1000, new_col="duration")
        .pipe(_cast_to_datetime, col="time", new_col="started_at")
        .pipe(_cast_to_datetime, col="updated", new_col="updated_at")
        .pipe(_access_nested_value, keys=["group", "id"], new_col="group_id")
        .pipe(_access_nested_value, keys=["venue", "country"], new_col="country")
        .pipe(_access_nested_value, keys=["venue", "city"], new_col="city")
        .pipe(_access_nested_value, keys=["venue", "lon"], new_col="lon")
        .pipe(_access_nested_value, keys=["venue", "lat"], new_col="lat")
        .pipe(_access_nested_value, keys=["venue", "name"], new_col="venue_name")
        .pipe(_merge_location_info)
        .pipe(
            _add_column,
            val=lambda df: df.apply(
                lambda row: {"name": row["venue_name"], "location": row["location"]},
                axis=1,
            ),
            new_col="venue",
        )
        .pipe(_add_column, val=requested_at, new_col="requested_at")
        .pipe(_add_column, val=datetime.datetime.now(), new_col="inserted_at")
        .pipe(_replace_nan)[
            [
                "id",
                "name",
                "group_id",
                "started_at",
                "duration",
                "rsvp_limit",
                "status",
                "yes_rsvp_count",
                "waitlist_count",
                "venue",
                "is_online_event",
                "visibility",
                "pro_is_email_shared",
                "member_pay_fee",
                "created_at",
                "updated_at",
                "requested_at",
                "inserted_at",
            ]
        ]
    )


def _transform_attendances(df, group_id, event_id, requested_at, inplace=False):
    if not inplace:
        df = df.copy()
    return (
        df.pipe(_access_nested_value, keys=["member", "id"], new_col="member_id")
        .pipe(_cast_to_datetime, col="updated", new_col="updated_at")
        .pipe(_add_column, val=requested_at, new_col="requested_at")
        .pipe(_add_column, val=datetime.datetime.now(), new_col="inserted_at")
        .rename({"attendance_id": "id"}, axis=1)
        .pipe(_replace_nan)[
            [
                "id",
                "member_id",
                "event_id",
                "group_id",
                "status",
                "guests",
                "updated_at",
                "requested_at",
                "inserted_at",
            ]
        ]
    )


def _request_members(client, group_id):
    return client.scan(
        url=f"{group_id}/members",
        # only="id,joined,group_profile.created,group_profile.visited,group_profile.role,group_profile.updated,city,country,lat,lon"
    )


def _request_events(client, group_id):
    return client.scan(url=f"/{group_id}/events", status="past,upcoming")


def _request_rsvps(client, group_id, event_id):
    return client.scan(
        url=f"{group_id}/events/{event_id}/rsvps",
        only="created,updated,response,guests,event.id,member.id,group.id",
    )


def _request_attendances(client, group_id, event_id):
    return client.scan(
        url=f"{group_id}/events/{event_id}/attendance",
        only="member.id,attendance_id,status,updated,guests",
    )


def _main(client, group_id, project_id, force_rsvps=False):
    """
    Requests data from Meetup API and inserts it into Google BigQuery.
    """
    requested_at = datetime.datetime.now()
    # request, transform and insert members
    print("Processing members.")
    for page in _request_members(client, group_id):
        to_table(
            _transform_members(page, requested_at).to_dict(orient="records"),
            project_id,
            DATASET_ID,
            "members",
        )
    # request, transform and insert events
    # also track event ids for rsvps
    print("Processing events.")
    event_ids = []
    for page in _request_events(client, group_id):
        events_transformed = _transform_events(page, requested_at)
        event_ids.extend(
            events_transformed[
                (
                    events_transformed.started_at
                    > datetime.datetime.now() - datetime.timedelta(hours=24)
                )
                | force_rsvps
            ].id
        )
        to_table(
            events_transformed.to_dict(orient="records"),
            project_id,
            DATASET_ID,
            "events",
        )
    # iterate through event ids
    print("Processing rsvps.")
    for event_id in tqdm(event_ids):
        # request, transform and insert rsvps per event id
        for page in _request_rsvps(client, group_id, event_id):
            to_table(
                _transform_rsvps(page, requested_at).to_dict(orient="records"),
                project_id,
                DATASET_ID,
                "rsvps",
            )
        # request, transform and insert attendances per event id
        for page in _request_attendances(client, group_id, event_id):
            to_table(
                _transform_attendances(page, group_id, event_id, requested_at).to_dict(
                    orient="records"
                ),
                project_id,
                DATASET_ID,
                "attendances",
            )


@error_reporting
# pylint: disable=unused-argument
def main(event, context):
    # pylint: enable=unused-argument
    """
    Requests data from Meetup API and inserts it into Google BigQuery.
    """
    data = decode(event["data"])
    group_id = data["group_id"]
    _main(
        CLIENT, group_id, os.environ["PROJECT_ID"], bool(os.environ.get("FORCE_RSVPS"))
    )
