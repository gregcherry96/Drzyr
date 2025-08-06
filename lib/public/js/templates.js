// lib/public/js/templates.js
window.DrzyrTemplates = {
  _cache: {},
  get(name) {
    if (this._cache[name]) {
      return this._cache[name];
    }
    const templateEl = document.getElementById(`template-${name}`);
    if (!templateEl) {
      console.error(`Template not found: ${name}`);
      return '';
    }
    const template = templateEl.innerHTML;
    Mustache.parse(template); // Pre-parse for performance
    this._cache[name] = template;
    return template;
  }
};
