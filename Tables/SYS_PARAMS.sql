CREATE TABLE sys_params (param_name    VARCHAR2(150),
                         value_date    DATE,
                         value_text    VARCHAR2(2000),
                         value_number  NUMBER,
                         param_descr   VARCHAR2(200) );
                         
INSERT INTO sys_params(param_name, value_date, value_text, value_number, param_descr)
            VALUES('list_currencies', TRUNC(SYSDATE), 'USD,EUR,KZT,AMD,GBP,ILS', 
            6, 'Список валют для синхронізації в процедурі util.api_nbu_sync');
            
SELECT * FROM sys_params;