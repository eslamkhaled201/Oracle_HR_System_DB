-- Triggers
--------------------------------------------------------------------------------
-- HR & Payroll System — Triggers
-- Run after 01_create_schema.sql
--------------------------------------------------------------------------------
 
--------------------------------------------------------------------------------
-- TRIGGER 1: trg_salary_audit
-- Fires whenever an employee's salary changes. Logs old and new values.
-- This is the audit-trail trigger recruiters expect to see in a payroll project.
CREATE OR REPLACE TRIGGER trg_salary_audit
    AFTER UPDATE OF salary ON employees
    FOR EACH ROW
    WHEN (NVL(OLD.salary,-1) != NVL(NEW.salary,-1))
DECLARE 
    v_emp_id NUMBER;
    v_old_salary employees.salary%type;
    v_new_salary employees.salary%type;
BEGIN
    v_emp_id := :NEW.EMPLOYEE_ID;
    v_old_salary := :OLD.salary;
    v_new_salary := :NEW.salary;
    INSERT INTO salary_audit (EMPLOYEE_ID,old_salary,new_salary)
    VALUES(v_emp_id , v_old_salary , v_new_salary);

END;
/

-- TRIGGER 2: trg_enforce_salary_range
-- Business rule: an employee's salary must fall within their job's
-- min_salary/max_salary band. Fires on INSERT and on salary/job changes

CREATE OR REPLACE TRIGGER trg_enfore_salary_range
    BEFORE INSERT OR UPDATE OF salary , job_id ON Employees
    FOR EACH ROW
    DECLARE
            v_min_salary jobs.min_salary%TYPE;
            v_max_salary  jobs.max_salary%type;
            v_job_title jobs.job_title%type;
            e_out_of_Range_salary EXCEPTION;
    BEGIN
        SELECT min_salary ,max_salary , job_title INTO v_min_salary,v_max_salary,v_job_title FROM jobs WHERE job_id= :NEW.job_id;
        IF :NEW.salary < v_min_salary OR :NEW.salary > v_max_salary THEN
               RAISE_APPLICATION_ERROR(
                -20004,'Salary : ' || :NEW.salary || ' is not in allowed range(' || v_min_salary || '-' || v_max_salary || ') 
                        for Job tittle : ' || v_job_title);
                ROLLBACK;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(
                -20002,'Invaild Job ID' || :NEW.job_id);
        ROLLBACK;
END;
/



CREATE OR REPLACE TRIGGER trg_validate_job_department
    BEFORE INSERT OR UPDATE OF job_id, department_id ON employees
    FOR EACH ROW
DECLARE
    v_job_department jobs.department_id%TYPE;
BEGIN
    IF :NEW.department_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20005,
            'Department is required: job ' || :NEW.job_id ||
            ' belongs to a specific department.');
    END IF;

    SELECT department_id
    INTO   v_job_department
    FROM   jobs
    WHERE  job_id = :NEW.job_id;

    IF v_job_department IS NULL OR v_job_department != :NEW.department_id THEN
        RAISE_APPLICATION_ERROR(-20003,
            'Job ' || :NEW.job_id || ' does not belong to department ' ||
            :NEW.department_id || ' (expected department ' ||
            NVL(TO_CHAR(v_job_department), 'none') || ').');
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20002, 'Invalid job_id: ' || :NEW.job_id);
END;
/

-- 2) Archiving: only records history, no validation, no swallowed errors
CREATE OR REPLACE TRIGGER trg_job_change_log
    AFTER UPDATE OF job_id, department_id ON employees
    FOR EACH ROW
    WHEN (OLD.job_id != NEW.job_id
          OR NVL(OLD.department_id, -1) != NVL(NEW.department_id, -1))
DECLARE
    v_start_date DATE;
BEGIN
    SELECT NVL(MAX(end_date), :OLD.hire_date)
    INTO   v_start_date
    FROM   job_history
    WHERE  employee_id = :OLD.employee_id;

    INSERT INTO job_history (employee_id, start_date, end_date, job_id, department_id)
    VALUES (:OLD.employee_id, v_start_date, SYSDATE, :OLD.job_id, :OLD.department_id);
END;