class EmployeeMailer < ApplicationMailer
  def payslip(payslip_id)
    @payslip = Payslip.find(payslip_id)
    return unless @payslip.employee&.email.present?

    pdf = GeneratePayslipPdfService.new(@payslip).call
    attachments["payslip_#{@payslip.id}.pdf"] = { mime_type: 'application/pdf', content: pdf }

    mail to: @payslip.employee.email, subject: ConfigService.get(@payslip.company, nil, 'payslip_email_subject') || "Your Payslip"
  end
end
