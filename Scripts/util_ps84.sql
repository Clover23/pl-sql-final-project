DECLARE
result VARCHAR2(100);
BEGIN
    util.copy_table(p_source_scheme => 'HR' 
                       --, p_target_scheme => 'KATERINA_JA5'
                       , p_list_table => 'COUNTRIES,PRODUCTS_OLD,CANDIES'
                       , p_copy_data => FALSE
                       , po_result => result);
    dbms_output.put_line(result);
END;

SELECT * FROM COUNTRIES;
SELECT * FROM products_old;

DROP TABLE countries;
DROP TABLE products_old;

SELECT * FROM LOGS ORDER BY LOG_DATE DESC;
