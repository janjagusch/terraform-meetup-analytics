WITH
days AS (
  SELECT
    GENERATE_DATE_ARRAY(CAST(MIN(joined_at) AS DATE), CURRENT_DATE(), INTERVAL 1 DAY) as days
  FROM meetup.members
)
,
members_distinct AS (
  SELECT DISTINCT
    id
  FROM meetup.members
)
,
requested_at_numbered AS (
  SELECT
    *,
    row_number() OVER (ORDER BY requested_at) row_number
  FROM (
    SELECT DISTINCT
      requested_at
    FROM meetup.members
  )
)
,
requested_at_start_end AS (
  SELECT
    start_.requested_at requested_at,
    end_.requested_at deprecated_at,
    start_.row_number = 1 is_first_requested_at,
  FROM
    requested_at_numbered start_,
    requested_at_numbered end_
  WHERE
    start_.row_number + 1 = end_.row_number
)
SELECT
  day,
  members.*,
FROM
  days,
  UNNEST(days.days) day,
  requested_at_start_end requested_at
LEFT JOIN meetup.members members
ON requested_at.requested_at = members.requested_at
WHERE
  (CAST(requested_at.requested_at AS DATE) <= day OR requested_at.is_first_requested_at)
  AND CAST(members.joined_at AS DATE) <= day
  AND CAST(requested_at.deprecated_at AS DATE) > day
ORDER BY day, id
