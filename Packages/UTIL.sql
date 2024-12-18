--SET DEFINE OFF;

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
                                
                                
PROCEDURE fire_an_employee(p_employee_id IN NUMBER);

PROCEDURE change_attribute_employee(p_employee_id IN NUMBER, 
                                p_first_name IN VARCHAR2 DEFAULT NULL,
                                p_last_name IN VARCHAR2 DEFAULT NULL,
                                p_email IN VARCHAR2 DEFAULT NULL,
                                p_phone_number IN VARCHAR2 DEFAULT NULL,
                                p_job_id IN VARCHAR2 DEFAULT NULL,
                                p_salary IN NUMBER DEFAULT NULL,
                                p_commission_pct IN NUMBER DEFAULT NULL,
                                p_manager_id IN NUMBER DEFAULT NULL,
                                p_department_id IN NUMBER DEFAULT NULL);
								
PROCEDURE copy_table(p_source_scheme IN VARCHAR2 
                       , p_target_scheme IN VARCHAR2 DEFAULT USER
                       , p_list_table IN VARCHAR2
                       , p_copy_data IN BOOLEAN DEFAULT FALSE
                       , po_result OUT VARCHAR2);
                       

TYPE rec_value_list IS RECORD (value_list VARCHAR2(100));
TYPE tab_value_list IS TABLE OF rec_value_list;

TYPE rec_exchange IS RECORD (r030 NUMBER,
                            txt VARCHAR2(100),
                            rate NUMBER,
                            cur VARCHAR2(100),
                            exchangedate DATE );
TYPE tab_exchange IS TABLE OF rec_exchange;
								
FUNCTION table_from_list(p_list_val IN VARCHAR2,
                         p_separator IN VARCHAR2 DEFAULT ',') 
	RETURN tab_value_list PIPELINED;
    
    
FUNCTION get_currency(p_currency IN VARCHAR2 DEFAULT 'USD',
                      p_exchangedate IN DATE DEFAULT SYSDATE) RETURN tab_exchange PIPELINED;    
    
PROCEDURE api_nbu_sync;

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




FUNCTION table_from_list(p_list_val IN VARCHAR2,
                         p_separator IN VARCHAR2 DEFAULT ',') 
RETURN tab_value_list PIPELINED IS
    out_rec tab_value_list := tab_value_list();
    l_cur SYS_REFCURSOR;
BEGIN
    OPEN l_cur FOR
    SELECT TRIM(REGEXP_SUBSTR(p_list_val, '[^'||p_separator||']+', 1, LEVEL)) AS cur_value
    FROM dual
    CONNECT BY LEVEL <= REGEXP_COUNT(p_list_val, p_separator) + 1;
    BEGIN
        LOOP
            EXIT WHEN l_cur%NOTFOUND;
            FETCH l_cur BULK COLLECT
            INTO out_rec;
                FOR i IN 1 .. out_rec.count LOOP
                    PIPE ROW(
                    out_rec(i));
                END LOOP;
        END LOOP;
    CLOSE l_cur;
EXCEPTION
    WHEN OTHERS THEN
    IF (l_cur%ISOPEN) THEN
        CLOSE l_cur;
        RAISE;
    ELSE
        RAISE;
    END IF;
    END;
END table_from_list;


FUNCTION get_currency(p_currency IN VARCHAR2 DEFAULT 'USD',
                      p_exchangedate IN DATE DEFAULT SYSDATE) RETURN tab_exchange PIPELINED IS
    out_rec tab_exchange := tab_exchange();
    l_cur SYS_REFCURSOR;
BEGIN
    OPEN l_cur FOR
    SELECT tt.r030, tt.txt, tt.rate, tt.cur, TO_DATE(tt.exchangedate, 'dd.mm.yyyy') AS exchangedate
    FROM (SELECT get_needed_curr(p_valcode => p_currency,p_date => p_exchangedate) AS json_value
    FROM dual)
    CROSS JOIN json_table
        (
        json_value, '$[*]'
        COLUMNS
            (
            r030 NUMBER PATH '$.r030',
            txt VARCHAR2(100) PATH '$.txt',
            rate NUMBER PATH '$.rate',
            cur VARCHAR2(100) PATH '$.cc',
            exchangedate VARCHAR2(100) PATH '$.exchangedate'
            )
    ) TT;
        BEGIN
            LOOP
                EXIT WHEN l_cur%NOTFOUND;
                FETCH l_cur BULK COLLECT
                INTO out_rec;
                    FOR i IN 1 .. out_rec.count LOOP
                        PIPE ROW(out_rec(i));
                    END LOOP;
            END LOOP;
            CLOSE l_cur;
        EXCEPTION
            WHEN OTHERS THEN
                IF (l_cur%ISOPEN) THEN
                    CLOSE l_cur;
                RAISE;
                ELSE
                RAISE;
                END IF;
        END;
END get_currency;

--PS-81

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
v_proc_name VARCHAR2(100) := 'add_employee';

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
        log_util.log_error(p_proc_name => v_proc_name, p_sqlerrm => v_sqlerm);
        RAISE_APPLICATION_ERROR(-20001, v_sqlerm);
    END IF;
    
    --check if department exist
    SELECT COUNT(1) INTO v_department_exist FROM departments WHERE department_id = p_department_id;
    IF v_department_exist = 0 THEN
        v_sqlerm := 'Введено неіснуючий ідентифікатор відділу';
        log_util.log_error(p_proc_name => v_proc_name, p_sqlerrm => v_sqlerm);
        RAISE_APPLICATION_ERROR(-20001, v_sqlerm);
    END IF;
    
    --check salary
    SELECT min_salary, max_salary INTO v_min_salary, v_max_salary FROM jobs WHERE job_id = p_job_id;
    IF p_salary < v_min_salary OR p_salary > v_max_salary THEN
        v_sqlerm := 'Введено неприпустиму заробітну плату для даного коду посади';
        log_util.log_error(p_proc_name => v_proc_name, p_sqlerrm => v_sqlerm);
        RAISE_APPLICATION_ERROR(-20001, v_sqlerm);
        
    END IF;
    
    --check work time
    v_is_work_time := check_work_time();
    IF NOT v_is_work_time THEN
        v_sqlerm := 'Ви можете додавати нового співробітника лише в робочий час';
        log_util.log_error(p_proc_name => v_proc_name, p_sqlerrm => v_sqlerm);
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
        log_util.log_error(p_proc_name => v_proc_name, p_sqlerrm => v_sqlerm);
        RAISE_APPLICATION_ERROR(-20001, v_sqlerm);
    END;
    
    log_util.log_finish(p_proc_name => v_proc_name);
    
END add_employee;



--PS-82

PROCEDURE fire_an_employee(p_employee_id IN NUMBER)IS
v_first_name VARCHAR2(100);
v_last_name VARCHAR2(100);
v_email VARCHAR2(100);
v_phone_number VARCHAR2(100);
v_job_id VARCHAR2(100);
v_hire_date DATE;
v_fire_date DATE;

v_is_work_time BOOLEAN;
v_employee_exist NUMBER;
v_proc_name VARCHAR2(100) := 'fire_an_employee';
v_sqlerm VARCHAR2(500);
BEGIN
log_util.log_start(p_proc_name => v_proc_name);

--Перевіряємо employee id
BEGIN
  SELECT first_name, last_name, email, phone_number, hire_date, job_id 
  INTO v_first_name, v_last_name, v_email, v_phone_number, v_hire_date, v_job_id 
  FROM employees 
  WHERE employee_id = p_employee_id;
EXCEPTION
  WHEN no_data_found THEN
    v_sqlerm := 'Переданий співробітник не існує';
    log_util.log_error(p_proc_name => v_proc_name, p_sqlerrm => v_sqlerm);
    raise_application_error(-20001, v_sqlerm);
END;


--Перевіряємо робочий час
v_is_work_time := check_work_time;
    IF NOT v_is_work_time THEN
        v_sqlerm := 'Ви можете додавати нового співробітника лише в робочий час';
        log_util.log_error(p_proc_name => v_proc_name, p_sqlerrm => v_sqlerm);
        RAISE_APPLICATION_ERROR(-20001, v_sqlerm);
    END IF;
  
    BEGIN
    --Видаляємо співробітника з таблиці employees
        DELETE FROM employees WHERE employee_id = p_employee_id;
        v_sqlerm := 'Співробітника '||v_first_name||' '||v_last_name||', '||v_job_id||' '||'звільнено';
        
    --Додаємо співробітника в employees_history
        v_fire_date := TRUNC(SYSDATE);        
        INSERT INTO employees_history(employee_id, first_name, last_name, email, phone_number, job_id, hire_date, fire_date)
        VALUES(emp_history_seq.NEXTVAL, v_first_name, v_last_name, v_email, v_phone_number, v_job_id, v_hire_date, v_fire_date);
        
    EXCEPTION
        WHEN OTHERS THEN
        v_sqlerm := 'Звільнення співробітника не відбулося. '|| SQLERRM;      
        log_util.log_error(p_proc_name => v_proc_name, p_sqlerrm => v_sqlerm);
        RAISE_APPLICATION_ERROR(-20001, v_sqlerm);    
    END;

    dbms_output.put_line(v_sqlerm);
    log_util.log_finish(p_proc_name => v_proc_name);

END fire_an_employee;



--PS-83

PROCEDURE change_attribute_employee(p_employee_id IN NUMBER, 
                                p_first_name IN VARCHAR2 DEFAULT NULL,
                                p_last_name IN VARCHAR2 DEFAULT NULL,
                                p_email IN VARCHAR2 DEFAULT NULL,
                                p_phone_number IN VARCHAR2 DEFAULT NULL,
                                p_job_id IN VARCHAR2 DEFAULT NULL,
                                p_salary IN NUMBER DEFAULT NULL,
                                p_commission_pct IN NUMBER DEFAULT NULL,
                                p_manager_id IN NUMBER DEFAULT NULL,
                                p_department_id IN NUMBER DEFAULT NULL) IS
								

/*
Щоб мати можливість використати цикл замість численних IF...THEN створюємо власний тип,
у якому приписуємо вхідний параметр до відповідного йому стовпця таблиці. 
Я розумію що тут роблю не зовсім правильно, бо покладаюсь на автоматичне конвертування VARCHAR2 в NUMBER
і в ідеалі напевно варто створити різні каталоги для різних типів вхідних параметрів і відповідно їм будувати 
sql команду для оновлення таблиці, але цей код майже ідентчний буде (тільки наявність - відсутність лапок), 
тому тут я уникаю повторів  
*/
TYPE catalog IS TABLE OF VARCHAR2(100) INDEX BY VARCHAR2(100);
list catalog;

sql_str VARCHAR2(500) := 'UPDATE employees SET';
idx  VARCHAR2(100);
smth_update BOOLEAN := FALSE;
v_proc_name VARCHAR2(100) := 'change_attribute_employee';
v_sqlerm VARCHAR2(500);
v_message VARCHAR2(200) := 'У співробітника '||p_employee_id||' успішно оновлені атрибути';

BEGIN

--заповняємо каталог
list('first_name') := p_first_name;
list('last_name') := p_last_name;
list('email') := p_email;
list('phone_number') := p_phone_number;
list('job_id') := p_job_id;
list('salary') := p_salary;
list('commission_pct') := p_commission_pct;
list('manager_id') := p_manager_id;
list('department_id') := p_department_id;

idx       := list.first;

--будуємо sql команду для кожного не нулового параметра (і перевіряємо чи є такі параметри взагалі)

WHILE idx IS NOT NULL LOOP
    IF list(idx) IS NOT NULL THEN
        IF NOT smth_update THEN
            sql_str := sql_str||' '||idx||' = '||''''||list(idx)||'''';
            smth_update := TRUE;
        ELSE 
            sql_str := sql_str||', '||idx||' = '||''''||list(idx)||''''||' ';
        END IF;
    END IF;
  idx := list.next(idx);    
  END LOOP;
 
--Якщо нема параметрів для оновлення 
  IF NOT smth_update THEN
    v_sqlerm := 'Нема чого оновлювати';
    log_util.log_finish(p_proc_name => v_proc_name);
    v_sqlerm := 'Нема чого оновлювати';
    RAISE_APPLICATION_ERROR(-20001, v_sqlerm);
    
  END IF;

--Виконуємо оновлення
BEGIN
    sql_str := sql_str||' WHERE employee_id = '||p_employee_id;
    EXECUTE IMMEDIATE sql_str;
    dbms_output.put_line(v_message);
    
    EXCEPTION
        WHEN OTHERS THEN
        v_sqlerm := 'Сталася помилка '|| SQLERRM;      
        log_util.log_error(p_proc_name => v_proc_name, p_sqlerrm => v_sqlerm);
        RAISE_APPLICATION_ERROR(-20001, v_sqlerm);

END;
log_util.log_finish(p_proc_name => v_proc_name);

END change_attribute_employee;


--PS-84

PROCEDURE copy_table(p_source_scheme IN VARCHAR2 
                       , p_target_scheme IN VARCHAR2 DEFAULT USER
                       , p_list_table IN VARCHAR2
                       , p_copy_data IN BOOLEAN DEFAULT FALSE
                       , po_result OUT VARCHAR2) IS
v_result VARCHAR2(500); --для вихідного параметра                      
v_table_exist NUMBER; --для перевірки чи існує таблиця в p_target_scheme
v_insert_sql VARCHAR(500); --команда для вставки даних в таблицю

--змінні для логування
v_proc_name VARCHAR2(100) := 'copy_table';
v_sqlerm VARCHAR2(500);
BEGIN
log_util.log_start(p_proc_name => v_proc_name);

/* Створюємо таблицю, яка міститиме 2 стовпчики: 1)назва таблиці 2)sql команда для створення такої таблиці;
	Потім перевіряємо кожен рядок, і якщо такої таблиці нема в p_target_scheme то створюємо її там;
	Якщо потрібно скопіювати дані, то копіюємо їх
*/
FOR cc IN (
SELECT table_name, 
       'CREATE TABLE '||UPPER(p_target_scheme)||'.'||table_name||' ('||LISTAGG(column_name ||' '|| data_type||count_symbol,', ')WITHIN GROUP(ORDER BY column_id)||')' AS ddl_code
FROM (SELECT table_name,
             column_name,
             data_type,
             CASE
               WHEN data_type IN ('VARCHAR2','CHAR') THEN '('||data_length||')'
               WHEN data_type = 'DATE' THEN NULL
               WHEN data_type = 'NUMBER' THEN replace( '('||data_precision||','||data_scale||')', '(,)', NULL)
             END AS count_symbol,
             column_id
      FROM all_tab_columns
      WHERE owner = UPPER(p_source_scheme)
      AND table_name IN (SELECT * FROM table_from_list(UPPER(p_list_table)))
      ORDER BY table_name, column_id)
GROUP BY table_name
) LOOP
    BEGIN
        SELECT COUNT(1) INTO v_table_exist FROM all_tab_columns WHERE table_name = cc.table_name AND owner = UPPER(p_target_scheme);
        IF v_table_exist = 0 THEN
            EXECUTE IMMEDIATE cc.ddl_code;
            IF p_copy_data = TRUE THEN
                v_insert_sql := 'INSERT INTO '||cc.table_name||' SELECT * FROM '||UPPER(p_source_scheme)||'.'||cc.table_name;
                EXECUTE IMMEDIATE v_insert_sql;
            END IF;
        ELSE CONTINUE;
        END IF;
   --Якщо помилка - то запис в лог і продовжуємо
    EXCEPTION
        WHEN OTHERS THEN
        v_sqlerm := 'Сталася помилка '|| SQLERRM;      
        log_util.log_error(p_proc_name => v_proc_name, p_sqlerrm => v_sqlerm);
        po_result := 'Помилка при копіюванні таблиці '||cc.table_name;
        CONTINUE;
    END;

v_sqlerm := 'Таблицю '||cc.table_name||' опрацьовано';    
log_util.to_log(p_appl_proc => v_proc_name, p_message => v_sqlerm);
END LOOP;

v_result := 'Успішно скопійовано таблиці';
po_result := v_result;

END copy_table;


--PS-85

PROCEDURE api_nbu_sync IS
v_list_currencies VARCHAR2(500); --список валют
v_proc_name VARCHAR2(100) := 'api_nbu_sync';
v_sqlerm VARCHAR2(500);
-- get list currencies
BEGIN
    log_util.log_start(p_proc_name => v_proc_name);
	--зчитуємо дані про список валют з таблиці sys_params
    BEGIN
        SELECT value_text INTO v_list_currencies FROM sys_params;
        
    EXCEPTION
        WHEN no_data_found THEN
            dbms_output.put_line('No record avialable');
        WHEN too_many_rows THEN
            dbms_output.put_line('Too many rows');
        WHEN OTHERS THEN
            v_sqlerm := 'Сталася помилка '|| SQLERRM;      
            log_util.log_error(p_proc_name => v_proc_name, p_sqlerrm => v_sqlerm);
    END;
    
    /*вставляємо дані в таблицю currency_exchange. Тут використовуємо 2 функції, які попередньо були створені в курсі:   
	table_from_list (перетворює список валют в таблицю, щоб ми могли використати цикл для кожного з рядків)
	та get_currency (парсить json з API НБУ як таблицю)
	*/	
    FOR cc IN (SELECT value_list AS curr FROM TABLE(util.table_from_list(p_list_val => v_list_currencies)))
    LOOP
        dbms_output.put_line(cc.curr);
            INSERT INTO currency_exchange (r030, txt_description, rate, currency, exchangedate)
            SELECT r030, txt, rate, cur, exchangedate FROM TABLE(util.get_currency(p_currency => cc.curr));       
    END LOOP;
    
    log_util.log_finish(p_proc_name => v_proc_name);
    
    EXCEPTION
    WHEN OTHERS THEN
            v_sqlerm := 'Сталася помилка '|| SQLERRM;      
            log_util.log_error(p_proc_name => v_proc_name, p_sqlerrm => v_sqlerm);
    
END api_nbu_sync;


END util;