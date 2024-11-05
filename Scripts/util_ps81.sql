
--Правильні дані
BEGIN
util.add_employee(p_first_name => 'John',
                                p_last_name => 'Smith',
                                p_email => 'JOHNSMITH',
                                p_phone_number => '5678945321',
                                p_job_id => 'AD_PRES',
                                p_salary => 21000,
                                p_department_id => 10
                                );
END;

--Неіснуючий job_id
BEGIN                                                                
util.add_employee(p_first_name => 'John',
                                p_last_name => 'Smith',
                                p_email => 'JOHNSMITH',
                                p_phone_number => '5678945321',
                                p_job_id => 'AD_PRESS',
                                p_salary => 21000,
                                p_department_id => 10
                                );
END;

--Не коректна зарплата
BEGIN
util.add_employee(p_first_name => 'John',
                                p_last_name => 'Smith',
                                p_email => 'JOHNSMITH',
                                p_phone_number => '5678945321',
                                p_job_id => 'AD_PRES',
                                p_salary => 1000,
                                p_department_id => 10
                                );
END;

--Не коректний department_id
BEGIN                               
util.add_employee(p_first_name => 'John',
                                p_last_name => 'Smith',
                                p_email => 'JOHNSMITH',
                                p_phone_number => '567.894.5321',
                                p_job_id => 'AD_PRES',
                                p_salary => 21000,
                                p_department_id => 1000
                                );
END;

--Помилка при інсерті
BEGIN
util.add_employee(p_first_name => 'John',
                                p_last_name => 'Smith',
                                p_email => 'johnsmith@gmail.com',
                                p_phone_number => '5678945321ggggggggggggggggggggggggggggggggggggggggggggggggggg',
                                p_job_id => 'AD_PRES',
                                p_salary => 21000,
                                p_department_id => 10
                                );
END;


SELECT * FROM logs ORDER BY log_date DESC;

SELECT * FROM employees ORDER BY hire_date DESC;