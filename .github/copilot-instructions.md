# PayslipPro - Copilot Instructions

Stack: Rails 8.1, Ruby 3.4, Tabler UI, Bootstrap 5, PostgreSQL, Axlsx, Roo, Devise, ActiveStorage

Core Models: Company has_many Employees, PayPeriods, Payslips, CompanyConfigs, CompanyPayrollSetting has_one, PayrollComponents. Employee belongs_to Company, has salary, payment_method bank/mobile_money/cash, medical_grade, employment_status active/blocked.

Key Rules:
- Always use money() helper for MWK formatting, not raw number
- Tabler classes only: card shadow-sm border-0 rounded-3, table-vcenter, badge bg-blue-lt / bg-green-lt
- No hardcoded bg-white - must support light/dark
- Payroll logic: Basic + House 10% + Other Allowances = Gross, PAYE Malawi brackets 0% up to 100k, 15% 100-120k, 30% 120k-1.7M, 35% 1.7M+, Pension EE 5% + ER 10%, Tevet 1%, Funeral 1%, Life 1%, Admin 0.3% + VAT 16.5%
- Import: Use public/templates/PayslipPro_Standard_Template_v1_Malawi.xlsx with 5 sheets (Employees, Allowances Guide, Deductions Guide, PAYE Brackets MW, Instructions) 27 columns
- Always require "ostruct" when using OpenStruct in Ruby 3.4
- Routes: company_dashboard, employees, pay_periods, import_templates/download_sample, company_configs?tab=payroll_settings
- Always keep has_one :company_payroll_setting singular, not plural

Current Status: Fixed navbar duplicate, fixed import template download, working on payroll_settings tab and employee_payroll_dashboard with 5 tabs General/Allowances/Deductions/Benefits/Payslip Preview
