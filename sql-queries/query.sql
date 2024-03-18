/* 
DAU
*/

SELECT log_date,
    COUNT(DISTINCT user_id) as dau,
    COUNT(*)
FROM events_log
GROUP BY log_date
ORDER BY log_date

----------------------------------------------------------------------------------------------------------

/* 
Активные пользователи по источникам привлечения
*/

SELECT utm_source,
    COUNT(DISTINCT user_id) as users
FROM events_log
GROUP BY utm_source
ORDER BY users DESC

----------------------------------------------------------------------------------------------------------

/* 
Воронка просмотров
*/

WITH page_open AS
  (SELECT dt,
          log_date,
          user_id,
          app_id,
          utm_source,
          name
   FROM events_log
   WHERE name = 'pageOpen'),
     search_type_table AS
  (SELECT dt,
          log_date,
          user_id,
          app_id,
          utm_source,
          name,
          object_details
   FROM events_log
   WHERE name IN ('searchMovieByTag', 'searchMovieByString')),
     start_movie AS
  (SELECT dt,
          log_date,
          user_id,
          app_id,
          utm_source,
          object_id,
          object_details,
          name
   FROM events_log
   WHERE name = 'startMovie'),
     rating AS
  (SELECT dt,
          user_id,
          app_id,
          object_id
   FROM events_log
   WHERE name = 'rateMovie'),
     comment AS
  (SELECT dt,
          user_id,
          app_id,
          object_id
   FROM events_log
   WHERE name = 'commentMovie')
SELECT page_open.app_id AS app_id,
       page_open.utm_source AS utm_source,
       page_open.log_date AS log_date,
       COUNT(DISTINCT page_open.user_id) AS users_open_page,
       COUNT(DISTINCT search_type_table.user_id) AS users_search_type,
       COUNT(DISTINCT start_movie.user_id) AS users_start_movie,
       COUNT(DISTINCT end_movie.user_id) AS users_end_movie,
       COUNT(DISTINCT rating.user_id) AS users_rating,
       COUNT(DISTINCT comment.user_id) AS users_comment
FROM page_open
LEFT JOIN search_type_table ON page_open.log_date = search_type_table.log_date
AND page_open.app_id = search_type_table.app_id
AND page_open.user_id = search_type_table.user_id
LEFT JOIN start_movie ON start_movie.log_date = COALESCE(search_type_table.log_date, page_open.log_date)
AND start_movie.user_id = COALESCE(search_type_table.user_id, page_open.user_id)
AND start_movie.object_details = COALESCE(search_type_table.object_details, 'searchMovieByString')
AND start_movie.app_id = COALESCE(search_type_table.app_id, page_open.app_id)
LEFT JOIN end_movie ON end_movie.app_id = COALESCE(start_movie.app_id, page_open.app_id)
AND end_movie.user_id = COALESCE(start_movie.user_id, page_open.user_id)
LEFT JOIN rating ON rating.user_id = COALESCE(end_movie.user_id, start_movie.user_id, page_open.user_id)
LEFT JOIN comment ON comment.user_id = COALESCE(rating.user_id, end_movie.user_id, start_movie.user_id, page_open.user_id)
WHERE (search_type_table.dt IS NULL
       OR page_open.dt <= search_type_table.dt
       AND (start_movie.dt IS NULL
            OR COALESCE(search_type_table.dt, page_open.dt) <= start_movie.dt
            AND (end_movie.dt IS NULL
                 OR COALESCE(start_movie.dt, COALESCE(search_type_table.dt, page_open.dt)) <= end_movie.dt)
            AND (rating.dt IS NULL
                 OR COALESCE(end_movie.dt, COALESCE(start_movie.dt, COALESCE(search_type_table.dt, page_open.dt))) <= rating.dt)
            AND (comment.dt IS NULL
                 OR COALESCE(rating.dt, COALESCE(end_movie.dt, COALESCE(start_movie.dt, COALESCE(search_type_table.dt, page_open.dt)))) <= comment.dt)))
GROUP BY page_open.log_date,
         page_open.app_id,
         page_open.utm_source
ORDER BY page_open.log_date;

----------------------------------------------------------------------------------------------------------

/*
Топ фильмов
*/

WITH top_ AS (
    SELECT
         object_id,
         COUNT(DISTINCT user_id) as users
    FROM events_log
    WHERE name = 'startMovie'
    GROUP BY object_id
),
movie_rates AS (
    SELECT
         object_id,
         AVG(CAST (object_value AS FLOAT)) AS avg_rate
    FROM events_log
    WHERE name = 'rateMovie'
    GROUP BY object_id      
)

SELECT 
    t.object_id,
    t.users,
    COALESCE(m.avg_rate, 0) AS avg_rate
FROM top_ t
LEFT JOIN 
    movie_rates m ON m.object_id = t.object_id
ORDER BY 
    t.users DESC, t.object_id;


----------------------------------------------------------------------------------------------------------

/*
Воронка покупки
*/

SELECT 
    log_date AS dt,
    app_id,
    utm_source,
    COUNT(DISTINCT user_id) AS all_users,
    COUNT(DISTINCT CASE WHEN name = 'offerClicked' THEN user_id END) AS users_click_offer,
    COUNT(DISTINCT CASE WHEN name = 'purchase' THEN user_id END) AS users_purch,
    SUM(CASE WHEN name = 'purchase' THEN CAST(object_value AS FLOAT) END) AS revenue
FROM 
    events_log
WHERE 
    name IN ('offerShow', 'offerClicked', 'purchase') 
    AND object_id NOT LIKE '%off%' 
GROUP BY 
    dt, app_id, utm_source, name, object_id;

-----------------------------------------------------------------------------------------------

/*
Длительность просмотра фильмов на пользователя
*/

SELECT 
    log_date,
    app_id,
    utm_source,
    SUM(CAST(object_value AS FLOAT)) AS sum_duration,
    COUNT(DISTINCT user_id) AS users
FROM 
    events_log
WHERE 
    name IN ('endMovie')
GROUP BY 
    log_date, app_id, utm_source;