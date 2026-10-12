
DROP TABLE salary_audit             PURGE;
DROP TABLE payslip_details          PURGE;
DROP TABLE payslips                 PURGE;
DROP TABLE payroll_runs             PURGE;
DROP TABLE employee_salary_components PURGE;
DROP TABLE salary_components         PURGE;
DROP TABLE job_history               PURGE;
DROP TABLE employees                 PURGE;
DROP TABLE jobs                      PURGE;
DROP TABLE departments               PURGE;


CREATE TABLE Departments(
        department_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        department_name VARCHAR2(50) NOT NULL,
        location VARCHAR(50) NOT NULL
);





CREATE TABLE Jobs(
    job_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    job_title VARCHAR2 (50) NOT NULL,
    min_salary NUMBER NOT NULL,
    max_salary NUMBER,
    department_id NUMBER,
    constraint uq_job_title UNIQUE (job_title),
    constraint fk_job_department_id foreign key (department_id) references departments(department_id),
    CONSTRAINT salary_range_check CHECK(max_salary > min_salary)
);


CREATE TABLE Job_history (
    job_history_id  NUMBER  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_id     NUMBER  NOT NULL,
    start_date      DATE    NOT NULL,
    end_date        DATE,
    job_id          NUMBER  NOT NULL,
    department_id   NUMBER,
    CONSTRAINT chk_jobhist_dates CHECK (end_date IS NULL OR end_date >= start_date),
    CONSTRAINT fk_jobhist_job    FOREIGN KEY (job_id) REFERENCES Jobs (job_id),
    CONSTRAINT fk_jobhist_dept   FOREIGN KEY (department_id) REFERENCES Departments(department_id)
);




CREATE TABLE Employees(
    employee_id     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name      VARCHAR2(30)    NOT NULL,
    last_name       VARCHAR2(30)    NOT NULL,
    email           VARCHAR2(100)   NOT NULL,
    phone_number    VARCHAR2(20),
    hire_date       DATE            DEFAULT SYSDATE NOT NULL,
    job_id          NUMBER          NOT NULL,
    department_id   NUMBER          NOT NULL,            
    manager_id      NUMBER,
    salary          NUMBER(10,2)    NOT NULL,
    status          VARCHAR2(10)    DEFAULT 'ACTIVE' NOT NULL,
    CONSTRAINT uq_employee_email     UNIQUE (email),
    CONSTRAINT chk_employee_salary   CHECK (salary > 0),
    CONSTRAINT chk_employee_status   CHECK (status IN ('ACTIVE','TERMINATED','ON_LEAVE')),
    CONSTRAINT fk_emp_job            FOREIGN KEY (job_id) REFERENCES jobs (job_id),
    CONSTRAINT fk_emp_department     FOREIGN KEY (department_id) REFERENCES departments (department_id)
);

ALTER TABLE Job_history ADD CONSTRAINT fk_jobhist_emp FOREIGN KEY (employee_id) REFERENCES Employees (employee_id);
ALTER TABLE Employees ADD CONSTRAINT fk_emp_manager FOREIGN KEY (manager_id) REFERENCES employees (employee_id);
CREATE INDEX idx_emp_dep ON Employees(department_id);
CREATE INDEX idx_emp_job ON Employees(job_id);
CREATE INDEX idx_emp_manager ON Employees(manager_id);
CREATE INDEX idx_jobhis_emp_id ON Job_history(employee_id);


CREATE TABLE Salary_Audit(
    audit_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_id NUMBER NOT NULL,
    old_salary NUMBER NOT NULL,
    new_salary NUMBER NOT NULL,
    changed_by   VARCHAR2(50) DEFAULT USER NOT NULL,
    changed_on   DATE    DEFAULT SYSDATE NOT NULL,
    CONSTRAINT emp_id_fk FOREIGN KEY (employee_id) REFERENCES Employees(employee_id)
);



CREATE INDEX idx_aud_emp_id ON  Salary_Audit(employee_id);

CREATE TABLE SALARY_COMPONENTS(
    component_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    component_name VARCHAR(50) NOT NULL,
    component_type VARCHAR(50) NOT NULL,
    is_percentage    CHAR(1)   DEFAULT 'N' NOT NULL,
    default_value    NUMBER(10,2),
    CONSTRAINT uq_component_name     UNIQUE (component_name),
    CONSTRAINT chk_component_type    CHECK (component_type IN ('EARNING','DEDUCTION')),
    CONSTRAINT chk_component_pct     CHECK (is_percentage IN ('Y','N'))
);



CREATE TABLE Employee_Salary_Components(
    emp_component_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_id NUMBER NOT NULL,
    component_id NUMBER NOT NULL,
    value NUMBER NOT NULL,
    CONSTRAINT  component_id_fk FOREIGN KEY (component_id) REFERENCES SALARY_COMPONENTS(component_id),
    CONSTRAINT  employee_id_fk FOREIGN KEY (employee_id) REFERENCES Employees(employee_id)
);


CREATE INDEX idx_salary_emp_id ON  Employee_Salary_Components(employee_id);

CREATE TABLE PAYROLL_RUNS(
    payroll_run_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    period_month NUMBER NOT NULL,
    period_year NUMBER NOT NULL,
    run_date        DATE    DEFAULT SYSDATE NOT NULL,
    status          VARCHAR2(10) DEFAULT 'DRAFT' NOT NULL,
    CONSTRAINT uq_payroll_period      UNIQUE (period_month, period_year),
    CONSTRAINT chk_payroll_month      CHECK (period_month BETWEEN 1 AND 12),
    CONSTRAINT chk_payroll_status     CHECK (status IN ('DRAFT','COMPLETED','CANCELLED'))
);


CREATE TABLE Payslips(
    payslip_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payroll_run_id NUMBER NOT NULL,
    employee_id NUMBER NOT NULL,
    gross_salary      NUMBER(10,2) NOT NULL,
    total_deductions  NUMBER(10,2) NOT NULL,
    net_salary        NUMBER(10,2) NOT NULL,
    generated_on      DATE    DEFAULT SYSDATE NOT NULL,
    CONSTRAINT uq_payslip_run_emp     UNIQUE (payroll_run_id, employee_id),
    CONSTRAINT  payroll_run_id_fk FOREIGN KEY (payroll_run_id) REFERENCES PAYROLL_RUNS(payroll_run_id),
    CONSTRAINT  empl_id_fk FOREIGN KEY (employee_id) REFERENCES Employees(employee_id)
);

CREATE INDEX idx_pays_emp_id ON Payslips(employee_id);
CREATE INDEX idx_payslip_run ON Payslips(payroll_run_id);



CREATE TABLE PAYSLIP_DETAILS(
    detail_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payslip_id NUMBER NOT NULL,
    component_id NUMBER NOT NULL,
    amount NUMBER NOT NULL,
    CONSTRAINT  payslip_id_fk FOREIGN KEY (payslip_id) REFERENCES Payslips(payslip_id),
    CONSTRAINT  comp_id_fk FOREIGN KEY (component_id) REFERENCES SALARY_COMPONENTS(component_id)
);


CREATE INDEX idx_detail_payslip ON PAYSLIP_DETAILS(payslip_id);



COMMIT;
SELECT table_name FROM user_tables ORDER BY table_name;
/*ALTER TABLE Department MODIFY dep_name NOT NULL;*/
/*ALTER TABLE Job_History ADD CONSTRAINT Jobs_His_PK PRIMARY KEY(job_history_id);*/
    