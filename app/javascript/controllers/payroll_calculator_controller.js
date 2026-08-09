import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["preview", "basic", "house", "gross", "paye", "pension", "net"]

  connect() {
    // no-op
  }

  update(event) {
    const salaryInput = this.element.querySelector('input[name="employee[salary]"]') || this.element.querySelector('input[name="basic_salary"]')
    const salary = salaryInput ? salaryInput.value : 0

    const token = document.querySelector('meta[name="csrf-token"]').content

    fetch('/employees/calculate_preview', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': token,
        'Accept': 'application/json'
      },
      body: JSON.stringify({ basic_salary: salary })
    }).then(r => r.json()).then(data => {
      this.basicTarget.textContent = this.formatMoney(salary)
      this.houseTarget.textContent = this.formatMoney(data.allowances && data.allowances.house_allowance || 0)
      this.grossTarget.textContent = this.formatMoney(data.gross)
      this.payeTarget.textContent = this.formatMoney(data.paye)
      this.pensionTarget.textContent = this.formatMoney(data.pension)
      this.netTarget.textContent = this.formatMoney(data.net)
    }).catch(e => {
      // ignore
    })
  }

}

  formatMoney(value) {
    if (value === null || value === undefined) return '-'
    const n = Number(value)
    if (Number.isNaN(n)) return '-'
    return n.toLocaleString('en-US')
  }
}
