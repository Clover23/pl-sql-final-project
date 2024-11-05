/*У таблицю додаємо дані про співробітника, його посаду і дати найму і звільнення.
employee_id - це первинний ключ, для заповнення цього поля використовуємо сіквенс emp_history_seq.
В ідеальному випадку варто було б зв'язати цю таблицю з таблицею jobs через foreign key job_id, але тут використовуємо job_title для лаконічності
(або взагалі тримати в employees_history всі поля з employees на випадок помилкового видалення)
*/

CREATE TABLE employees_history(
    employee_id NUMBER,
    first_name varchar(255),
    last_name varchar(255),
    email varchar(255),
    phone_number varchar(255),
    job_title VARCHAR2(225),
    hire_date DATE,
    fire_date DATE,
    CONSTRAINT empid_pk PRIMARY KEY(employee_id)
);
