WITH
days AS (
  SELECT
    GENERATE_DATE_ARRAY(CAST(MIN(joined_at) AS DATE), CURRENT_DATE(), INTERVAL 1 DAY) as days
  FROM meetup_raw.members
)
,
members_dedup AS (
  SELECT
    * EXCEPT(row_number)
  FROM (
    SELECT
      *,
      ROW_NUMBER() OVER (PARTITION BY id, updated_at ORDER BY requested_at) row_number
    FROM `meetup_raw.members`
  )
  WHERE row_number=1
),
members_last_seen AS
(
  SELECT
    id,
    max(requested_at) last_seen_at
  FROM `meetup_raw.members`
  GROUP BY id

),
members_numbered AS (
  SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY id ORDER BY updated_at DESC) row_number
  FROM members_dedup
),
members_latest AS (
  SELECT
    members_numbered.*,
    members_last_seen.last_seen_at deprecated_at
  FROM members_numbered
  LEFT JOIN members_last_seen
  ON members_numbered.id = members_last_seen.id
  WHERE row_number=1
),
members_start_end AS (
  SELECT
    start_.*,
    end_.updated_at deprecated_at
  FROM
    members_numbered start_,
    members_numbered end_
  WHERE
    start_.row_number - 1 = end_.row_number
    AND start_.id = end_.id
),
members_joined AS (
  SELECT * FROM members_latest
  UNION ALL
  SELECT * FROM members_start_end
),
members_cleaned AS (
  SELECT
    members_joined.* EXCEPT(row_number),
    ROW_NUMBER() OVER (PARTITION BY id ORDER BY updated_at) = 1 first_record
  FROM
    members_joined
)
SELECT
  day,
  members.*,
FROM
  days,
  UNNEST(days.days) day,
  members_cleaned members
WHERE
  (members.first_record AND day >= CAST(members.joined_at AS DATE) AND day <= CAST(members.deprecated_at AS DATE))
  OR (NOT members.first_record AND day >= CAST(members.updated_at AS DATE) AND day <= CAST(members.deprecated_at AS DATE))
