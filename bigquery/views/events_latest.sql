SELECT
  * EXCEPT(row_number)
FROM (
  SELECT
    *,
    row_number() OVER (PARTITION BY id ORDER BY requested_at DESC) row_number
  FROM meetup_raw.events
)
WHERE row_number = 1
