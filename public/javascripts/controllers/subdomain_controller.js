import { Controller } from "https://esm.sh/@hotwired/stimulus@3.2.2";

export default class extends Controller {
  static targets = ["nameInput", "subdomainInput", "suggestions"];

  connect() {
    this.timeoutId = null;
  }

  suggest() {
    clearTimeout(this.timeoutId);

    this.timeoutId = setTimeout(() => {
      const name = this.nameInputTarget.value.trim();

      if (!name) {
        this.renderNoSuggestions();
        return;
      }

      fetch(`/companies/suggest_subdomain?name=${encodeURIComponent(name)}`, {
        headers: { Accept: "application/json" }
      })
        .then((response) => response.json())
        .then((data) => {
          this.renderSuggestions(data.suggestions || []);
        })
        .catch(() => {
          this.renderNoSuggestions();
        });
    }, 500);
  }

  select(event) {
    const button = event.currentTarget;
    this.subdomainInputTarget.value = (button.dataset.value || "").trim();
  }

  renderSuggestions(suggestions) {
    this.suggestionsTarget.innerHTML = "";

    if (!suggestions.length) {
      this.renderNoSuggestions();
      return;
    }

    suggestions.slice(0, 3).forEach((suggestion) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "btn btn-outline-primary btn-sm me-2 mb-2";
      button.dataset.value = suggestion;
      button.textContent = `https://${suggestion}.${this.mainDomain()}`;
      button.dataset.action = "click->subdomain#select";
      this.suggestionsTarget.appendChild(button);
    });
  }

  renderNoSuggestions() {
    this.suggestionsTarget.innerHTML = '<span class="text-muted small">Not available</span>';
  }

  mainDomain() {
    return this.element.dataset.mainDomain || "hr.com";
  }
}
