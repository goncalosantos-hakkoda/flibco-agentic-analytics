with vehicles as (
    select * from {{ ref('stg_vehicles') }}
)

select
    vehicle_id,
    vehicle_type,
    capacity,
    registration_plate,
    year_manufactured,
    status
from vehicles
