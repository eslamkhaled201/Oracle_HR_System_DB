--------------------------------------------------------------------------------
-- HR & Payroll System — Sample Data
-- Run after 03_packages.sql
--------------------------------------------------------------------------------

-- Departments
INSERT INTO departments (department_name, location) VALUES ('Engineering', 'Cairo');
INSERT INTO departments (department_name, location) VALUES ('Finance',     'Giza');
INSERT INTO departments (department_name, location) VALUES ('Human Resources', 'Cairo');

-- Jobs (with salary bands used by trg_enforce_salary_range)
INSERT INTO jobs (job_title, min_salary, max_salary ,department_id ) 
    VALUES ('Software Engineer', 3000, 8000 , (select department_id from DEPARTMENTS where DEPARTMENTS.DEPARTMENT_NAME = 'Engineering'));
INSERT INTO jobs (job_title, min_salary, max_salary ,department_id ) 
VALUES ('Engineering Manager', 7000, 15000 ,(select department_id from DEPARTMENTS where DEPARTMENTS.DEPARTMENT_NAME = 'Engineering'));
INSERT INTO jobs (job_title, min_salary, max_salary , department_id ) 
VALUES ('Accountant', 2500, 6000, (select department_id from DEPARTMENTS where DEPARTMENTS.DEPARTMENT_NAME = 'Finance'));
INSERT INTO jobs (job_title, min_salary, max_salary ,department_id) 
VALUES ('HR Specialist', 2500, 6000 ,(select department_id from DEPARTMENTS where DEPARTMENTS.DEPARTMENT_NAME = 'Human Resources'));

COMMIT;

-- Employees (manager_id left NULL for the top of the hierarchy, set after insert)
INSERT INTO employees (first_name, last_name, email, hire_date, job_id, department_id, salary)
VALUES ('Sara', 'Youssef', 'sara.youssef@example.com', DATE '2022-01-10',
        (SELECT job_id FROM jobs WHERE job_title = 'Engineering Manager'),
        (SELECT department_id FROM departments WHERE department_name = 'Engineering'),
        9500);

INSERT INTO employees (first_name, last_name, email, hire_date, job_id, department_id, manager_id, salary)
VALUES ('Omar', 'Hassan', 'omar.hassan@example.com', DATE '2023-03-05',
        (SELECT job_id FROM jobs WHERE job_title = 'Software Engineer'),
        (SELECT department_id FROM departments WHERE department_name = 'Engineering'),
        (SELECT employee_id FROM employees WHERE email = 'sara.youssef@example.com'),
        4500);

INSERT INTO employees (first_name, last_name, email, hire_date, job_id, department_id, manager_id, salary)
VALUES ('Mona', 'Adel', 'mona.adel@example.com', DATE '2023-06-15',
        (SELECT job_id FROM jobs WHERE job_title = 'Software Engineer'),
        (SELECT department_id FROM departments WHERE department_name = 'Engineering'),
        (SELECT employee_id FROM employees WHERE email = 'sara.youssef@example.com'),
        5200);

INSERT INTO employees (first_name, last_name, email, hire_date, job_id, department_id, salary)
VALUES ('Karim', 'Fathy', 'karim.fathy@example.com', DATE '2021-11-20',
        (SELECT job_id FROM jobs WHERE job_title = 'Accountant'),
        (SELECT department_id FROM departments WHERE department_name = 'Finance'),
        4200);

INSERT INTO employees (first_name, last_name, email, hire_date, job_id, department_id, salary)
VALUES ('Nour', 'Ibrahim', 'nour.ibrahim@example.com', DATE '2024-02-01',
        (SELECT job_id FROM jobs WHERE job_title = 'HR Specialist'),
        (SELECT department_id FROM departments WHERE department_name = 'Human Resources'),
        3800);

COMMIT;

-- Salary components (lookup values)
INSERT INTO salary_components (component_name, component_type, is_percentage, default_value)
VALUES ('Housing Allowance', 'EARNING', 'N', 500);

INSERT INTO salary_components (component_name, component_type, is_percentage, default_value)
VALUES ('Transport Allowance', 'EARNING', 'N', 200);

INSERT INTO salary_components (component_name, component_type, is_percentage, default_value)
VALUES ('Performance Bonus', 'EARNING', 'Y', 5);

INSERT INTO salary_components (component_name, component_type, is_percentage, default_value)
VALUES ('Social Insurance', 'DEDUCTION', 'Y', 7);

INSERT INTO salary_components (component_name, component_type, is_percentage, default_value)
VALUES ('Health Insurance', 'DEDUCTION', 'N', 150);

COMMIT;

-- Attach components to employees via the package procedure (also tests the package)
DECLARE
    v_employee_id employees.employee_id%TYPE;
BEGIN
    SELECT employee_id INTO v_employee_id
    FROM employees
    WHERE email = 'sara.youssef@example.com';

    hr_payroll_pkg.p_set_employee_component(
        v_employee_id, 'Housing Allowance', 500);
    hr_payroll_pkg.p_set_employee_component(
        v_employee_id, 'Social Insurance', 7);

    SELECT employee_id INTO v_employee_id
    FROM employees
    WHERE email = 'omar.hassan@example.com';

    hr_payroll_pkg.p_set_employee_component(
        v_employee_id, 'Transport Allowance', 200);
    hr_payroll_pkg.p_set_employee_component(
        v_employee_id, 'Social Insurance', 7);

    SELECT employee_id INTO v_employee_id
    FROM employees
    WHERE email = 'mona.adel@example.com';

    hr_payroll_pkg.p_set_employee_component(
        v_employee_id, 'Performance Bonus', 5);
    hr_payroll_pkg.p_set_employee_component(
        v_employee_id, 'Health Insurance', 150);

    SELECT employee_id INTO v_employee_id
    FROM employees
    WHERE email = 'karim.fathy@example.com';

    hr_payroll_pkg.p_set_employee_component(
        v_employee_id, 'Social Insurance', 7);

    SELECT employee_id INTO v_employee_id
    FROM employees
    WHERE email = 'nour.ibrahim@example.com';

    hr_payroll_pkg.p_set_employee_component(
        v_employee_id, 'Housing Allowance', 300);
END;
/

-- Test the salary-audit trigger (this UPDATE should generate a SALARY_AUDIT row)
SET SERVEROUTPUT ON;
UPDATE employees SET salary = 20000 WHERE email = 'omar.hassan@example.com';
COMMIT;

-- Test the salary-range trigger — this should FAIL and roll back automatically,
-- because 20000 is above the 'Software Engineer' job's max_salary of 8000.
-- Uncomment to see the trigger reject it:
-- UPDATE employees SET salary = 20000 WHERE email = 'omar.hassan@example.com';

-- Test the job-history trigger by moving Omar to Finance as an Accountant
SET SERVEROUTPUT ON;
UPDATE employees
SET department_id = (SELECT department_id FROM departments WHERE department_name = 'Finance'),
    job_id = (SELECT job_id FROM jobs WHERE job_title = 'Accountant')
WHERE email = 'omar.hassan@example.com';
COMMIT;


SELECT e.EMAIL, j.JOB_TITLE, d.DEPARTMENT_NAME, e.hire_date,e.salary
FROM employees e
LEFT JOIN jobs j ON e.job_id = j.job_id
LEFT JOIN departments d ON e.department_id = d.department_id
where e.email = 'omar.hassan@example.com';

-- Move Omar back to Engineering so the payroll run reflects the original headcount
UPDATE employees
SET department_id = (SELECT department_id FROM departments WHERE department_name = 'Engineering'),
    job_id = (SELECT job_id FROM jobs WHERE job_title = 'Engineering Manager'),
    salary = 10000
WHERE email = 'omar.hassan@example.com';
COMMIT;


select * from job_history;

-- Run payroll for the current month/year (exercises the full package)
SET SERVEROUTPUT ON;
BEGIN
    hr_payroll_pkg.p_run_payroll(EXTRACT(MONTH FROM SYSDATE), EXTRACT(YEAR FROM SYSDATE));
END;

select * from PAYROLL_RUNS; 
/

COMMIT;