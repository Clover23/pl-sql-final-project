CREATE OR REPLACE PACKAGE util AS

PROCEDURE add_employee(p_first_name IN VARCHAR2,
                                p_last_name IN VARCHAR2,
                                p_email IN VARCHAR2,
                                p_phone_number IN VARCHAR2,
                                p_hire_date IN DATE DEFAULT trunc(sysdate, 'dd'),
                                p_job_id IN VARCHAR2,
                                p_salary IN NUMBER,
                                p_commission_pct IN NUMBER DEFAULT NULL,
                                p_manager_id IN NUMBER DEFAULT 100,
                                p_department_id IN NUMBER
                                );

END util;




-- package body


CREATE OR REPLACE PACKAGE BODY util AS

FUNCTION check_work_time RETURN BOOLEAN AS
v_check_time NUMBER;
v_is_work_time BOOLEAN;

BEGIN       
    select
      case when to_char(sysdate, 'HH24:MI') >= '07:59' 
            and to_char(sysdate, 'HH24:MI') <  '18:01' then 1 else 0
      end as in_time_range
      INTO v_check_time
    from dual;
    
    IF TO_CHAR(SYSDATE, 'DY', 'NLS_DATE_LANGUAGE = AMERICAN') IN ('SAT', 'SUN')
    OR v_check_time = 0
    THEN
        v_is_work_time := FALSE;
    ELSE
        v_is_work_time := TRUE;
        END IF;
        
    RETURN v_is_work_time;             
END check_work_time;

PROCEDURE add_employee(p_first_name IN VARCHAR2,
                                p_last_name IN VARCHAR2,
                                p_email IN VARCHAR2,
                                p_phone_number IN VARCHAR2,
                                p_hire_date IN DATE DEFAULT trunc(sysdate, 'dd'),
                                p_job_id IN VARCHAR2,
                                p_salary IN NUMBER,
                                p_commission_pct IN NUMBER DEFAULT NULL,
                                p_manager_id IN NUMBER DEFAULT 100,
                                p_department_id IN NUMBER
                                ) IS

v_job_exist NUMBER;
v_department_exist NUMBER;
v_max_salary NUMBER;
v_min_salary NUMBER;
v_salary_valid NUMBER;
v_employee_id NUMBER;
v_is_work_time BOOLEAN;
v_sqlerm VARCHAR2(500);

FUNCTION get_employee_id RETURN NUMBER IS
    v_employee_id NUMBER;
    BEGIN
        SELECT NVL(MAX(employee_id),0)+1
        INTO  v_employee_id
        FROM employees;
    RETURN  v_employee_id;
    END get_employee_id;

BEGIN
    log_util.log_start(p_proc_name => 'add_employee');
    
    --check if job_id exist
    SELECT COUNT(1) INTO v_job_exist FROM jobs WHERE job_id = p_job_id;
    IF v_job_exist = 0 THEN
        v_sqlerm := 'Введено неіснуючий код посади';
        log_util.log_error(p_proc_name => 'add_employee', p_sqlerrm => v_sqlerm);
        RAISE_APPLICATION_ERROR(-20001, v_sqlerm);
    END IF;
    
    --check if department exist
    SELECT COUNT(1) INTO v_department_exist FROM departments WHERE department_id = p_department_id;
    IF v_department_exist = 0 THEN
        v_sqlerm := 'Введено неіснуючий ідентифікатор відділу';
        log_util.log_error(p_proc_name => 'add_employee', p_sqlerrm => v_sqlerm);
        RAISE_APPLICATION_ERROR(-20001, v_sqlerm);
    END IF;
    
    --check salary
    SELECT min_salary INTO v_min_salary FROM jobs WHERE job_id = p_job_id;
    SELECT max_salary INTO v_max_salary FROM jobs WHERE job_id = p_job_id;
    IF p_salary < v_min_salary OR p_salary > v_max_salary THEN
        v_sqlerm := 'Введено неприпустиму заробітну плату для даного коду посади';
        log_util.log_error(p_proc_name => 'add_employee', p_sqlerrm => v_sqlerm);
        RAISE_APPLICATION_ERROR(-20001, v_sqlerm);
        
    END IF;
    
    --check work time
    v_is_work_time := check_work_time();
    IF NOT v_is_work_time THEN
        v_sqlerm := 'Ви можете додавати нового співробітника лише в робочий час';
        log_util.log_error(p_proc_name => 'add_employee', p_sqlerrm => v_sqlerm);
        RAISE_APPLICATION_ERROR(-20001, v_sqlerm);
    END IF;
    
    --get employee id
    v_employee_id := get_employee_id;
    
    --insert new employee into the table
    BEGIN
        INSERT INTO employees (employee_id, first_name, last_name, email, phone_number, hire_date, job_id, salary, commission_pct, manager_id, department_id)
        VALUES (v_employee_id, p_first_name, p_last_name, p_email, p_phone_number, p_hire_date, p_job_id, p_salary, p_commission_pct, p_manager_id, p_department_id);
        
        dbms_output.put_line('Співробітник '||p_first_name||' '||p_last_name||' '||p_job_id||' '||p_department_id||' успішно додано до системи');
    EXCEPTION
        WHEN OTHERS THEN
        v_sqlerm := SQLERRM;
        log_util.log_error(p_proc_name => 'add_employee', p_sqlerrm => v_sqlerm);
    END;
    
    log_util.log_finish(p_proc_name => 'add_employee');
    
END add_employee;
    

END util;