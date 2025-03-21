{% macro calculate_rental_duration(return_date, rental_date) %}
    case 
        when {{ return_date }} is null then 
            datediff('day', {{ rental_date }}, current_date)
        else 
            datediff('day', {{ rental_date }}, {{ return_date }})
    end
{% endmacro %} 