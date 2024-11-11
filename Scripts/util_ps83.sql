--Нема чого оновлювати
BEGIN
    util.change_attribute_employee(p_employee_id => 166);
END;

--Оновити кілька параметрів
BEGIN
    util.change_attribute_employee(p_employee_id => 166, p_first_name => 'Ben', p_salary => 6000, p_manager_id => 105);
END;

--Помилка при оновленні
BEGIN
    util.change_attribute_employee(p_employee_id => 166, p_first_name => 'Patrik', p_salary => '120009877654432', p_manager_id => 105);
END;

SELECT * FROM logs ORDER BY log_date DESC;
SELECT * FROM employees WHERE employee_id = 166;