import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="personal-amount"
// Toggles between exact amount input and divide-by-people input.
// In "people" mode, calculates total/people and submits the hidden money field.
export default class extends Controller {
  static targets = ["typeSelect", "exactGroup", "peopleGroup", "peopleInput"]
  static values = { total: Number }

  connect() {
    this.updateType()
  }

  get amountInput() {
    return this.exactGroupTarget.querySelector("input[data-money-field-target='amount']")
  }

  get form() {
    return this.element.closest("form")
  }

  updateType() {
    const type = this.typeSelectTarget.value
    if (type === "people") {
      this.exactGroupTarget.classList.add("hidden")
      this.peopleGroupTarget.classList.remove("hidden")
      this.calculate()
    } else {
      this.exactGroupTarget.classList.remove("hidden")
      this.peopleGroupTarget.classList.add("hidden")
    }
  }

  calculate() {
    const people = parseInt(this.peopleInputTarget.value)
    const input = this.amountInput
    if (people >= 2 && this.totalValue > 0 && input) {
      const share = (this.totalValue / people).toFixed(2)
      input.value = share
      // Submit the form since the input is hidden and won't get blur events
      if (this.form) {
        this.form.requestSubmit()
      }
    }
  }
}
