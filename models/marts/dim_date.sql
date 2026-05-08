{{ config(materialized='table') }}

with date_spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2024-01-01' as date)",
        end_date="cast('2026-01-01' as date)"
    ) }}
)

select
    cast(date_day as date) as date_key,
    date_day as full_date,
    extract(year from date_day) as year,
    extract(month from date_day) as month,
    extract(day from date_day) as day_of_month,
    extract(dayofweek from date_day) as day_of_week,
    to_char(date_day, 'YYYY-Q') as year_quarter,
    extract(quarter from date_day) as quarter,
    to_char(date_day, 'Mon') as month_name,
    to_char(date_day, 'Dy') as day_name,
    case
        when extract(month from date_day) in (12, 1, 2) then 'Winter'
        when extract(month from date_day) in (3, 4, 5) then 'Spring'
        when extract(month from date_day) in (6, 7, 8) then 'Summer'
        when extract(month from date_day) in (9, 10, 11) then 'Autumn'
    end as season,
    case
        when extract(dayofweek from date_day) in (0, 6) then false
        else true
    end as is_weekday
from date_spine
