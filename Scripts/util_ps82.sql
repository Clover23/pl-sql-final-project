BEGIN
    util.fire_an_employee(p_employee_id => 209);
END;


BEGIN
    util.fire_an_employee(p_employee_id => 300);
END;


SELECT * FROM logs ORDER BY log_date DESC;
SELECT * FROM employees ORDER BY hire_date DESC;
SELECT * FROM employees_history; 