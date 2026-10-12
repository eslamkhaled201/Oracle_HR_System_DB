# HR System Database

An Oracle SQL project for managing HR records and payroll. It includes employee and department data, job history, salary components, payroll runs, payslips, and salary auditing.

## Requirements

- Oracle Database
- Oracle SQL Developer, SQLcl, or another Oracle SQL client

## Project Files

- `Create_Tables_HR_System.sql` creates the tables, keys, indexes, and constraints.
- `HR_System_Triggers.sql` adds salary auditing, salary-range and department validation, and job-history triggers.
- `Payroll_Run_Package.sql` creates `HR_PAYROLL_PKG` for salary calculations and payroll runs.
- `HR_Sample_Data & Test.sql` inserts sample data and exercises the triggers and payroll package.
- `HR_System_ERD.md` and `HR_System_ERD.html` contain the entity-relationship diagram.

## Setup

Connect to a development Oracle schema and run the SQL scripts in this order:

1. `Create_Tables_HR_System.sql`
2. `HR_System_Triggers.sql`
3. `Payroll_Run_Package.sql`
4. `HR_Sample_Data & Test.sql`

The schema script starts with `DROP TABLE ... PURGE` statements. Running it again removes the existing project tables and their data before recreating them. Use a development schema and preserve any data you need before rerunning it.

The sample/test script inserts records, updates an employee, and runs payroll for the current month and year. Review its test statements before running it against any data you need to keep.