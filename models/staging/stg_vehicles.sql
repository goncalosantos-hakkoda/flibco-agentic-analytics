with source as (
    select * from {{ ref('raw_vehicles') }}
)

select
    vehicle_id,
    vehicle_type,
    capacity,
    registration_plate,
    year_manufactured,
    status
from source
