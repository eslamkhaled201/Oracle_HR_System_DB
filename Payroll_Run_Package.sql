--- Package

CREATE OR REPLACE PACKAGE hr_payroll_pkg AS

    FUNCTION f_calc_gross(p_employee_id NUMBER) RETURN NUMBER;
    
    FUNCTION f_calc_tax(p_gross_salary payslips.gross_salary%type) RETURN NUMBER;
    
    FUNCTION f_calc_deductions(p_employee_id NUMBER, p_tax NUMBER) RETURN NUMBER;
    
    PROCEDURE p_set_employee_component(p_employee_id NUMBER, p_salary_component_name salary_components.component_name%type, p_value NUMBER);
    
    PROCEDURE p_set_payslip_details(p_payslip_id NUMBER,p_employee_Id NUMBER, p_base_salary NUMBER);
    
    PROCEDURE p_run_payroll(p_month NUMBER, p_year NUMBER);
END hr_payroll_pkg;
/

CREATE OR REPLACE PACKAGE BODY hr_payroll_pkg AS

    FUNCTION f_calc_gross(p_employee_id NUMBER) RETURN NUMBER 
    IS      
        v_base_salary employees.salary%type;
       v_total_earnings NUMBER;
    BEGIN
        SELECT salary INTO v_base_salary FROM employees WHERE EMPLOYEE_ID= p_employee_id;
        
        SELECT NVL(
                    SUM( CASE 
                        WHEN sc.IS_PERCENTAGE ='Y' THEN v_base_salary  * (esc.VALUE /100)
                        ELSE esc.VALUE 
                        END
                        ),0) 
        INTO v_total_earnings FROM EMPLOYEE_SALARY_COMPONENTS esc
        LEFT JOIN salary_components sc ON  esc.component_id=sc.component_id
        WHERE sc.component_type='EARNING';
            
        
        RETURN v_base_salary + v_total_earnings;
    END f_calc_gross;

    FUNCTION f_calc_tax(p_gross_salary payslips.gross_salary%type) RETURN NUMBER
    IS
        v_tax NUMBER;
    BEGIN
        IF p_gross_salary <= 3000 THEN
            v_tax := 0;
        ELSIF p_gross_salary <= 7000 THEN
            v_tax := (p_gross_salary - 3000) * 0.10;
        ELSE
            v_tax := (4000 * 0.10) + ( p_gross_salary - 7000) * 0.20;
        END IF;
 
        RETURN ROUND(v_tax, 2);
    END f_calc_tax;
    
    FUNCTION f_calc_deductions(p_employee_id NUMBER, p_tax NUMBER) RETURN NUMBER
    IS
        v_base_salary employees.salary%type;
       v_deductions NUMBER; 
    BEGIN
        SELECT salary INTO v_base_salary FROM employees WHERE EMPLOYEE_ID= p_employee_id;
        SELECT NVL(
        SUM( CASE 
            WHEN sc.IS_PERCENTAGE ='Y' THEN v_base_salary * (esc.value /100 )
            ELSE esc.value
            END
            ),0) 
        INTO v_deductions
        FROM employee_salary_components esc
        LEFT JOIN salary_components  sc ON  esc.component_id=sc.component_id
        WHERE sc.component_type='DEDUCTION';
        
        RETURN v_deductions + p_tax;
    END f_calc_deductions;
    
    PROCEDURE p_set_employee_component(p_employee_id NUMBER, p_salary_component_name salary_components.component_name%type, p_value NUMBER)
    IS
        v_salary_comp_id NUMBER;
    BEGIN
        select component_id into v_salary_comp_id 
        from  salary_components
        WHERE  component_name= p_salary_component_name;
        
         UPDATE employee_salary_components SET value= p_value WHERE employee_id= p_employee_id AND component_id= v_salary_comp_id;
        if (sql%found) then
            dbms_output.put_line('updated value');
            COMMIT;
        else
            INSERT INTO employee_salary_components (employee_id, component_id , value) 
            VALUES (p_employee_id , v_salary_comp_id ,  p_value);
            commit;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003,'Salary Component Name Not Found');
        WHEN OTHERS THEN
            dbms_output.put_line(SQLERRM);
    END p_set_employee_component; 
    
    PROCEDURE p_set_payslip_details(p_payslip_id NUMBER,p_employee_Id NUMBER, p_base_salary NUMBER)
    IS
     -- calac employee salary component amount and insert for employee payslip detailes  
        v_amount NUMBER;
    Begin 
        FOR comp_row IN (
            select sc.is_percentage as is_percnt , NVL(esc.value,0) as value ,esc.component_id as comp_id 
            from employee_salary_components esc
            LEFT JOIN salary_components sc ON esc.component_id = sc.component_id
            WHERE esc.employee_id= p_employee_Id
            
        )LOOP 
        
            IF (comp_row.is_percnt = 'Y')
            THEN 
                v_amount := p_base_salary * (comp_row.value /100);
            ELSE 
                v_amount := comp_row.value;
            END IF;
            INSERT INTO payslip_details (payslip_id,component_id,amount)
            VALUES (p_payslip_id , comp_row.comp_id , v_amount);
            
        END LOOP;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            dbms_output.put_line('NO Employee Salary Components Found');
        WHEN OTHERS THEN
            dbms_output.put_line(SQLERRM);
    END p_set_payslip_details;
    
    PROCEDURE p_run_payroll(p_month NUMBER, p_year NUMBER)
    IS
        CURSOR cur_payroll_run IS
            SELECT  payroll_run_id,status from payroll_runs where period_month=p_month AND period_year=p_year;
        v_employee_id NUMBER;
        v_gross_salary NUMBER;
        v_taxes NUMBER;
        v_deduciotns NUMBER;
        v_net_salary NUMBER;
        v_payroll_run_id NUMBER;
        v_payroll_run_status payroll_runs.status%type DEFAULT NULL;
        v_payslip_id NUMBER;
    BEGIN
        OPEN cur_payroll_run;
        FETCH cur_payroll_run INTO v_payroll_run_id , v_payroll_run_status;
        CLOSE cur_payroll_run;
        
        if (v_payroll_run_status = 'COMPLETED') THEN
            dbms_output.put_line('Payroll Run for this period is already completed');
            RETURN;        
        ELSIF (v_payroll_run_status IS NULL) THEN
             
            INSERT INTO payroll_runs (period_month,period_year,status,run_date) 
            VALUES (p_month,p_year,'DRAFT', SYSDATE )
            RETURNING payroll_run_id INTO v_payroll_run_id;
        END IF;
        
        
        FOR employee_row IN (
            select employee_id,first_name,salary from employees where status='ACTIVE'
        ) LOOP
            
              DELETE FROM payslips WHERE payroll_run_id=v_payroll_run_id AND employee_id = employee_row.employee_id;
              v_gross_salary := hr_payroll_pkg.f_calc_gross(employee_row.employee_id);
              v_taxes := hr_payroll_pkg.f_calc_tax(v_gross_salary);
              v_deduciotns := hr_payroll_pkg.f_calc_deductions(employee_row.employee_id , v_taxes);
              v_net_salary := v_gross_salary - v_deduciotns;

   
             INSERT INTO payslips (payroll_run_id,employee_id,net_salary,gross_salary,total_deductions,generated_on)
             
             VALUES (v_payroll_run_id ,employee_row.employee_id ,v_net_salary ,v_gross_salary ,v_deduciotns , SYSDATE)
             RETURNING payslip_id INTO v_payslip_id;
             
            hr_payroll_pkg.p_set_payslip_details(v_payslip_id,employee_row.employee_id,employee_row.salary);
        END Loop;
        
        -- validate payroll run
        UPDATE payroll_runs SET payroll_runs.status='COMPLETED' where period_month=p_month AND period_year=p_year;
        COMMIT;
   EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line(SQLERRM);
            
    END p_run_payroll;
    
END hr_payroll_pkg;
    
