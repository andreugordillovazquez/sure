import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="personal-amount"
// Toggles between exact amount and divide-by-people modes for personal_amount
export default class extends Controller {
  static targets = ["modeSelect", "exactGroup", "divideGroup", "peopleInput"]
  static values = { total: Number }

  connect() {
    this.updateMode()
  }

  get amountInput() {
    return this.element.querySelector("input[data-money-field-target='amount']")
  }

  updateMode() {
    const mode = this.modeSelectTarget.value
    if (mode === "divide") {
      this.exactGroupTarget.classList.add("hidden")
      this.divideGroupTarget.classList.remove("hidden")
      this.calculate()
    } else {
      this.exactGroupTarget.classList.remove("hidden")
      this.divideGroupTarget.classList.add("hidden")
    }
  }

  calculate() {
    const people = parseInt(this.peopleInputTarget.value)
    const input = this.amountInput
    if (people > 0 && this.totalValue > 0 && input) {
      const share = (this.totalValue / people).toFixed(2)
      input.value = share
      input.dispatchEvent(new Event("input", { bubbles: true }))
      input.dispatchEvent(new Event("blur", { bubbles: true }))
    }
  }
}
