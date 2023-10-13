import { Controller } from "stimulus";

// Manages "modified" state for a form with multiple records
export default class BulkFormController extends Controller {
  static targets = ["actions", "modifiedSummary"];
  static values = {
    disableSelector: String,
    error: Boolean,
  };
  recordElements = {};

  connect() {
    this.form = this.element;

    // Start listening for any changes within the form
    // this.element.addEventListener('change', this.toggleModified.bind(this)); // dunno why this doesn't work
    for (const element of this.form.elements) {
      element.addEventListener("keyup", this.toggleModified.bind(this)); // instant response
      element.addEventListener("change", this.toggleModified.bind(this)); // just in case (eg right-click paste)

      // Set up a tree of fields according to their associated record
      const recordContainer = element.closest("[data-record-id]"); // The JS could be more efficient if this data was added to each element. But I didn't want to pollute the HTML too much.
      const recordId = recordContainer && recordContainer.dataset.recordId;
      if (recordId) {
        this.recordElements[recordId] ||= [];
        this.recordElements[recordId].push(element);
      }
    }

    this.toggleFormModified();
  }

  disconnect() {
    // Make sure to clean up anything that happened outside
    this.#disableOtherElements(false);
    window.removeEventListener("beforeunload", this.preventLeavingBulkForm);
  }

  toggleModified(e) {
    const element = e.target;
    element.classList.toggle("modified", this.#isModified(element));

    this.toggleFormModified();
  }

  toggleFormModified() {
    // For each record, check if any fields are modified
    const modifiedRecordCount = Object.values(this.recordElements).filter((elements) =>
      elements.some(this.#isModified)
    ).length;
    const formModified = modifiedRecordCount > 0 || this.errorValue;

    // Show actions
    this.actionsTarget.classList.toggle("hidden", !formModified);
    this.#disableOtherElements(formModified); // like filters and sorting

    // Display number of records modified
    const key = this.hasModifiedSummaryTarget && this.modifiedSummaryTarget.dataset.translationKey;
    if (key) {
      // TODO: save processing and only run if modifiedRecordCount has changed.
      this.modifiedSummaryTarget.textContent = I18n.t(key, { count: modifiedRecordCount });
    }

    // Prevent accidental data loss
    if (formModified) {
      window.addEventListener("beforeunload", this.preventLeavingBulkForm);
    } else {
      window.removeEventListener("beforeunload", this.preventLeavingBulkForm);
    }
  }

  preventLeavingBulkForm(e) {
    // Cancel the event
    e.preventDefault();
    // Chrome requires returnValue to be set. Other browsers may display this if provided, but let's
    // not create a new translation key, and keep the behaviour consistent.
    e.returnValue = "";
  }

  // private

  #disableOtherElements(disable) {
    if (!this.hasDisableSelectorValue) return;

    this.disableElements ||= document.querySelectorAll(this.disableSelectorValue);

    if (!this.disableElements) return;

    this.disableElements.forEach((element) => {
      element.classList.toggle("disabled-section", disable);
    });
  }

  #isModified(element) {
    return element.value != element.defaultValue;
  }
}
