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
        const skipLabel = isComplexObject && result.skipLabel;
        const customLabelText = isComplexObject ? result.label : null;

        if (element.label && !skipLabel) {
          const labelText = customLabelText || element.label;
          container.appendChild(createElement('label', { className: 'form-label', htmlFor: element.id, innerText: labelText }));
        }
        container.appendChild(widget);
        parentNode.appendChild(container);
      } else {
        parentNode.appendChild(widget);
      }
    });
  }

  function render(elements) {
    const activeEl = document.activeElement;
    const focusedElementId = activeEl?.id;
    const selectionStart = activeEl?.selectionStart;
    const selectionEnd = activeEl?.selectionEnd;

    app.innerHTML = '';
    renderElementsInto(elements, app);

    if (focusedElementId) {
      const newElementToFocus = document.getElementById(focusedElementId);
      if (newElementToFocus) {
        newElementToFocus.focus();
        if (typeof newElementToFocus.setSelectionRange === 'function') {
          newElementToFocus.setSelectionRange(selectionStart, selectionEnd);
        }
      }
    }
  }

  connect();
  window.onpopstate = () => sendMessage('navigate');
})();
