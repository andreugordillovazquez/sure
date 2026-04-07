import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="personal-amount"
// Toggles between exact amount input and divide-by-people input.
// Persists mode + people count in localStorage per entry.
export default class extends Controller {
  static targets = ["typeSelect", "exactGroup", "peopleGroup", "peopleInput"]
  static values = { total: Number, entryId: String }

  connect() {
    this.restoreState()
    this.applyMode()
  }

  get amountInput() {
    return this.exactGroupTarget.querySelector("input[data-money-field-target='amount']")
  }

  get form() {
    return this.element.closest("form")
  }

  get storageKey() {
    return `personal_amount_${this.entryIdValue}`
  }

  restoreState() {
    try {
      const saved = JSON.parse(localStorage.getItem(this.storageKey))
      if (saved?.mode === "people") {
        this.typeSelectTarget.value = "people"
        if (saved.count) this.peopleInputTarget.value = saved.count
      }
    } catch { /* ignore */ }
  }

  saveState() {
    const mode = this.typeSelectTarget.value
    if (mode === "people") {
      const count = parseInt(this.peopleInputTarget.value)
      localStorage.setItem(this.storageKey, JSON.stringify({ mode, count }))
    } else {
      localStorage.removeItem(this.storageKey)
    }
  }

  updateType() {
    this.applyMode()
    this.saveState()
    if (this.typeSelectTarget.value === "people") {
      this.peopleInputTarget.focus()
    }
  }

  applyMode() {
    const type = this.typeSelectTarget.value
    if (type === "people") {
      this.exactGroupTarget.classList.add("hidden")
      this.peopleGroupTarget.classList.remove("hidden")
    } else {
      this.exactGroupTarget.classList.remove("hidden")
      this.peopleGroupTarget.classList.add("hidden")
    }
  }

  calculate() {
    const people = parseInt(this.peopleInputTarget.value)
    const input = this.amountInput
    if (!input) return

    if (people >= 2 && this.totalValue > 0) {
      const share = (this.totalValue / people).toFixed(2)
      input.value = share
    } else {
      // Clear personal_amount when people is empty, 0, or 1
      input.value = ""
      localStorage.removeItem(this.storageKey)
    }

    this.saveState()
    if (this.form) {
      this.form.requestSubmit()
    }
  }
}
