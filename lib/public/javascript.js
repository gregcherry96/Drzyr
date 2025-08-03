// public/javascript.js
(function () {
  const app = document.getElementById('app');
  if (!app) return;

  let socket;
  let reconnectAttempts = 0;
  const maxReconnectAttempts = 10;

  function connect() {
    socket = new WebSocket(`ws://${window.location.host}/websocket`);

    socket.onopen = () => {
      console.log('WebSocket connected.');
      reconnectAttempts = 0;
      sendMessage('client_ready');
    };

    socket.onmessage = (event) => {
      const message = JSON.parse(event.data);
      if (message.type === 'render') {
        render(message.elements);
      }
    };

    socket.onclose = () => {
      console.log('WebSocket disconnected. Attempting to reconnect...');
      reconnectAttempts++;
      if (reconnectAttempts > maxReconnectAttempts) {
        app.className = 'container grid-lg text-center';
        app.innerHTML = '<h1>Connection to server lost. Please refresh the page.</h1>';
        return;
      }
      const delay = Math.min(30000, 1000 * Math.pow(2, reconnectAttempts));
      setTimeout(connect, delay);
    };

    socket.onerror = (err) => {
      console.error('WebSocket error:', err);
      socket.close();
    };
  }

  function sendMessage(type, payload = {}) {
    if (!socket || socket.readyState !== WebSocket.OPEN) {
      console.warn('Socket not open, message dropped.', { type, payload });
      return;
    }
    const message = { type, path: window.location.pathname, ...payload };
    socket.send(JSON.stringify(message));
  }

  function createElement(tag, attributes = {}, children = []) {
    const el = document.createElement(tag);
    Object.entries(attributes).forEach(([key, value]) => {
      if (key in el) {
        el[key] = value;
      } else if (value !== null && value !== undefined) {
        el.setAttribute(key, value);
      }
    });
    children.forEach(child => el.appendChild(child));
    return el;
  }

  const widgetCreators = {
    alert(element) {
      return createElement('div', {
        className: `toast toast-${element.style}`,
        innerText: element.text
      });
    },
    latex(element) {
      // MathJax will process this as a block-level equation
      return createElement('div', { innerText: `$$${element.text}$$` });
    },
    image(element) {
      const img = createElement('img', { className: 'img-responsive', src: element.src });
      if (!element.caption) {
        return img;
      }
      const figcaption = createElement('figcaption', { className: 'figure-caption text-center', innerText: element.caption });
      return createElement('figure', { className: 'figure' }, [img, figcaption]);
    },
    code(element) {
      const codeEl = createElement('code', { innerText: element.text });
      return createElement('pre', { className: 'code', 'data-lang': element.language }, [codeEl]);
    },
    heading(element) {
      const level = element.type.substring(7);
      return createElement(`h${level}`, { innerText: element.text });
    },
    paragraph(element) {
      return createElement('p', { innerText: element.text });
    },
    table(element) {
      const thead = createElement('thead');
      if (element.headers?.length > 0) {
        const tr = createElement('tr');
        element.headers.forEach(h => tr.appendChild(createElement('th', { innerText: h })));
        thead.appendChild(tr);
      }
      const tbody = createElement('tbody');
      if (element.data?.length > 0) {
        element.data.forEach(rowData => {
          const tr = createElement('tr');
          rowData.forEach(cellData => tr.appendChild(createElement('td', { innerText: cellData })));
          tbody.appendChild(tr);
        });
      }
      return createElement('table', { className: 'table table-striped table-hover' }, [thead, tbody]);
    },

    spinner(element) {
      const container = createElement('div', { className: 'form-group text-center' });
      const loading = createElement('div', { className: 'loading loading-lg' });
      container.appendChild(loading);
      if (element.label) {
        const label = createElement('p', { className: 'text-gray', innerText: element.label });
        container.appendChild(label);
      }
      return { widget: container, skipLabel: true };
    },

    divider(element) {
      return createElement('div', { className: 'divider' });
    },

        expander(element) {
      // ** THE FIX IS HERE **
      // This function now builds the expander using the structure
      // that Spectre.css expects, with a hidden checkbox and a label.
      const container = createElement('div', { className: 'accordion' });

      // The hidden checkbox controls the open/closed state via CSS.
      // Its state is set by the `expanded` property from the server.
      const checkbox = createElement('input', {
        type: 'checkbox',
        id: element.id,
        name: 'accordion-checkbox',
        hidden: true,
        checked: element.expanded
      });

      // The clickable label toggles the checkbox and sends a message
      // to the server to update the state for the next render.
      const header = createElement('label', {
        className: 'accordion-header c-hand',
        htmlFor: element.id,
        onclick: () => sendMessage('button_press', { widget_id: element.id })
      });

      const icon = createElement('i', { className: 'icon icon-arrow-right mr-1' });
      header.append(icon, element.label);

      // The body is now always rendered. Spectre's CSS will handle showing
      // or hiding it based on whether the checkbox is checked.
      const body = createElement('div', { className: 'accordion-body' });
      renderElementsInto(element.content, body);

      container.append(checkbox, header, body);

      return { widget: container, skipLabel: true };
    },

    tabs(element) {
    const container = createElement('div', { className: 'tab-container' });
    const tabNav = createElement('ul', { className: 'tab tab-block' });

    element.labels.forEach(label => {
      const tabItemId = `${element.id}_${label}`;
      const li = createElement('li', {
        className: `tab-item ${label === element.active_tab ? 'active' : ''}`
      });
      const a = createElement('a', {
        className: 'c-hand',
        innerText: label,
        onclick: () => sendMessage('button_press', { widget_id: tabItemId })
      });
      li.appendChild(a);
      tabNav.appendChild(li);
    });

    const contentContainer = createElement('div', { className: 'tab-content p-2' });
    renderElementsInto(element.content, contentContainer);

    container.append(tabNav, contentContainer);
    return { widget: container, skipLabel: true };
  },

  multi_select(element) {
    const select = createElement('select', {
      id: element.id,
      className: 'form-select',
      multiple: true,
      onchange: (e) => {
        const selected = Array.from(e.target.selectedOptions).map(opt => opt.value);
        sendMessage('update', { widget_id: element.id, value: selected });
      }
    });

    element.options.forEach(opt => {
      const option = createElement('option', {
        value: opt,
        innerText: opt,
        // Set the selected property for each option
        selected: element.value.includes(opt)
      });
      select.appendChild(option);
    });

    return { widget: select };
  },

  form_group(element) {
    const fieldset = createElement('fieldset', { className: 'form-group' });
    const legend = createElement('legend', { className: 'form-label', innerText: element.label });
    fieldset.appendChild(legend);
    renderElementsInto(element.content, fieldset); // Recursively render nested elements
    return { widget: fieldset, skipLabel: true };
  },

  textarea(element) {
    const textarea = createInputElement('textarea', element, {
      className: 'form-input',
      rows: element.rows,
      oninput: (e) => sendMessage('update', { widget_id: element.id, value: e.target.value })
    });
    // For textareas, the value is set via innerText, not the value attribute.
    textarea.innerText = element.value;
    return { widget: textarea };
  },

  radio_group(element) {
    const container = createElement('div', { className: 'form-group' });

    // Create a main label for the entire group
    const mainLabel = createElement('label', { className: 'form-label', innerText: element.label });
    container.appendChild(mainLabel);

    // Create a radio button for each option
    element.options.forEach(opt => {
      const radioInput = createElement('input', {
        type: 'radio',
        name: element.id,
        value: opt,
        checked: element.value === opt,
        onchange: (e) => sendMessage('update', { widget_id: element.id, value: e.target.value })
      });
      const icon = createElement('i', { className: 'form-icon' });
      const label = createElement('label', { className: 'form-radio' });

      label.append(radioInput, icon, opt);
      container.appendChild(label);
    });

    return { widget: container, skipLabel: true };
  },

    slider(element) {
      const slider = createInputElement('input', element, {
        type: 'range',
        className: 'slider',
        min: element.min,
        max: element.max,
        step: element.step,
        oninput: (e) => sendMessage('update', { widget_id: element.id, value: e.target.value })
      });
      return {
        widget: slider,
        label: `${element.label} (${element.value})`
      };
    },
    text_input: (element) => createStandardInput('text', element),
    number_input: (element) => createStandardInput('number', element),
    password_input: (element) => createStandardInput('password', element),
    date_input: (element) => createStandardInput('date', element),
    checkbox(element) {
      const check = createInputElement('input', element, {
        type: 'checkbox',
        checked: element.value,
        onchange: (e) => sendMessage('update', { widget_id: element.id, value: e.target.checked })
      });
      const icon = createElement('i', { className: 'form-icon' });
      const label = createElement('label', { className: 'form-checkbox' });
      label.append(check, icon, element.label);
      return { widget: label, skipLabel: true };
    },
    selectbox(element) {
      // Create the select element without setting its value initially
      const select = createElement('select', {
        id: element.id,
        className: 'form-select',
        onchange: (e) => sendMessage('update', { widget_id: element.id, value: e.target.value })
      });

      // Add all the child <option> elements first
      element.options.forEach(opt => {
        select.appendChild(createElement('option', { value: opt, innerText: opt }));
      });

      // NOW set the value on the parent <select> element
      select.value = element.value;

      return { widget: select };
    },
    button(element) {
      const button = createInputElement('button', element, {
        className: 'btn btn-primary',
        innerText: element.text,
        onclick: () => sendMessage('button_press', { widget_id: element.id })
      });
      return { widget: button, skipLabel: true };
    },
    columns_container(element) {
      const container = createElement('div', { className: 'columns' });
      element.columns.forEach(columnElements => {
        const columnDiv = createElement('div', { className: 'column' });
        renderElementsInto(columnElements, columnDiv);
        container.appendChild(columnDiv);
      });
      return container;
    },
  };

  function createInputElement(tag, element, extraAttrs = {}) {
    return createElement(tag, {
      id: element.id,
      ...extraAttrs,
      value: element.value
    });
  }

  function createStandardInput(type, element) {
    const input = createInputElement('input', element, {
      type: type,
      className: 'form-input',
      oninput: (e) => sendMessage('update', { widget_id: element.id, value: e.target.value })
    });
    return { widget: input };
  }

function renderElementsInto(elements, parentNode) {
    elements.forEach(element => {
      const creator = widgetCreators[element.type] || (element.type.startsWith('heading') ? widgetCreators.heading : null);
      if (!creator) return;

      const result = creator(element);
      const isComplexObject = result.nodeType === undefined;
      const widget = isComplexObject ? result.widget : result;
      const needsContainer = !['heading', 'paragraph', 'table', 'columns_container'].includes(element.type);

      if (needsContainer) {
        const container = createElement('div', { className: 'form-group' });

        if (element.error) {
          container.classList.add('has-error');
        }

        if (element.label && !(isComplexObject && result.skipLabel)) {
          const labelText = (isComplexObject && result.label) ? result.label : element.label;
          container.appendChild(createElement('label', { className: 'form-label', htmlFor: element.id, innerText: labelText }));
        }

        container.appendChild(widget);

        if (element.error) {
          const hint = createElement('p', { className: 'form-input-hint', innerText: element.error });
          container.appendChild(hint);
        }

        parentNode.appendChild(container);
      } else {
        parentNode.appendChild(widget);
      }
    });
  }

function render(elements) {
    // Save focus and cursor position
    const activeEl = document.activeElement;
    const focusedElementId = activeEl?.id;
    const selectionStart = activeEl?.selectionStart;
    const selectionEnd = activeEl?.selectionEnd;

    // Rebuild the UI from scratch
    app.innerHTML = '';
    renderElementsInto(elements, app);

    // If an element had focus before, or if MathJax is present,
    // defer the next actions to ensure the DOM is ready.
    if (focusedElementId || window.MathJax) {
      setTimeout(() => {
        // Reapply MathJax typesetting if it exists
        if (window.MathJax) {
          window.MathJax.typesetPromise();
        }

        // Restore focus to the previously active element
        if (focusedElementId) {
          const newElementToFocus = document.getElementById(focusedElementId);
          if (newElementToFocus) {
            newElementToFocus.focus();
            if (typeof newElementToFocus.setSelectionRange === 'function') {
              newElementToFocus.setSelectionRange(selectionStart, selectionEnd);
            }
          }
        }
      }, 0);
    }
  }

  connect();
  window.onpopstate = () => sendMessage('navigate');
})();
