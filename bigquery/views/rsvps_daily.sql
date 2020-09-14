WITH
days AS (
  SELECT
    GENERATE_DATE_ARRAY(CAST(MIN(created_at) AS DATE), CURRENT_DATE(), INTERVAL 1 DAY) as days
  FROM meetup.events
)
,
events_latest AS (
  SELECT
    * EXCEPT(row_number)
  FROM (
    SELECT
      *,
      ROW_NUMBER() OVER (PARTITION BY ID ORDER BY requested_at DESC) row_number
    FROM meetup.events
  )
  WHERE row_number=1
)
,
members_latest AS (
  SELECT
    * EXCEPT(row_number)
  FROM (
    SELECT
      *,
      ROW_NUMBER() OVER (PARTITION BY ID ORDER BY requested_at DESC) row_number
    FROM meetup.members
  )
  WHERE row_number=1
)
,
requested_at_numbered AS (
  SELECT
    *,
    row_number() OVER (PARTITION BY member_id, event_id, group_id ORDER BY requested_at) row_number
  FROM meetup.rsvps
)
,
requested_at_start_end AS (
  SELECT
    start_.member_id,
    start_.event_id,
    start_.group_id,
    start_.response,
    start_.guests + 1 attendees,
    start_.updated_at,
    start_.requested_at,
    end_.requested_at deprecated_at,
    start_.row_number = 1 is_first_requested_at,
  FROM
    requested_at_numbered start_,
    requested_at_numbered end_
  WHERE
    start_.member_id = end_.member_id
    AND start_.event_id = end_.event_id
    AND start_.group_id = end_.group_id
    AND start_.row_number + 1 = end_.row_number
)
SELECT
  day,
  requested_at.*,
  events event,
  members member,
FROM
  days,
  UNNEST(days.days) day,
  requested_at_start_end requested_at
LEFT JOIN events_latest events
ON requested_at.event_id = events.id
LEFT JOIN members_latest members
ON requested_at.member_id = members.id
WHERE
  day >= CAST(events.created_at AS DATE)
  AND ((requested_at.is_first_requested_at AND day >= CAST(requested_at.updated_at AS DATE)) OR (NOT requested_at.is_first_requested_at AND day >= CAST(requested_at.requested_at AS DATE)))
  AND CAST(requested_at.deprecated_at AS DATE) >= day
  AND day <= CAST(events.started_at AS DATE)
