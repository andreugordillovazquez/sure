import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="personal-amount"
// When user types a number of people, auto-calculates total/people and fills the amount input
export default class extends Controller {
  static targets = ["peopleInput"]
  static values = { total: Number }

  get amountInput() {
    return this.element.querySelector("input[data-money-field-target='amount']")
  }

  calculate() {
    const people = parseInt(this.peopleInputTarget.value)
    const input = this.amountInput
    if (people >= 2 && this.totalValue > 0 && input) {
      const share = (this.totalValue / people).toFixed(2)
      input.value = share
      // Trigger auto-submit
      input.dispatchEvent(new Event("input", { bubbles: true }))
      input.dispatchEvent(new Event("blur", { bubbles: true }))
    }
  }
}
