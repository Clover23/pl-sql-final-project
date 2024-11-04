
CREATE TABLE logs (id NUMBER,
                    appl_proc VARCHAR2(50),
                    message VARCHAR2(2000),
                    log_date DATE DEFAULT SYSDATE,
                    CONSTRAINT id_pk PRIMARY KEY(id));