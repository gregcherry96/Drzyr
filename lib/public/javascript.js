// public/javascript.js
(function () {
  const app = document.getElementById('app');
  if (!app) return;

  const socket = new WebSocket(`ws://${window.location.host}/websocket`);

  function sendMessage(type, payload = {}) {
    if (socket.readyState !== WebSocket.OPEN) return;
    const message = { type, path: window.location.pathname, ...payload };
    socket.send(JSON.stringify(message));
  }

  function createElement(tag, attributes = {}) {
    const el = document.createElement(tag);
    Object.entries(attributes).forEach(([key, value]) => {
      if (key in el) {
        el[key] = value;
      } else if (value !== null && value !== undefined) {
        el.setAttribute(key, value);
      }
    });
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
      const select = createElement('select', {
        id: element.id,
        className: 'form-select',
        value: element.value,
        onchange: (e) => sendMessage('update', { widget_id: element.id, value: e.target.value })
      });
      element.options.forEach(opt => {
        select.appendChild(createElement('option', { value: opt, innerText: opt }));
      });
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
        // Recursively render the elements for this column into the column's div
        renderElementsInto(columnElements, columnDiv);
        container.appendChild(columnDiv);
      });
      return container;
    },
  };

  function createInputElement(tag, element, extraAttrs = {}) {
    return createElement(tag, {
      id: element.id,
      value: element.value,
      ...extraAttrs
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

/**
 * Renders a list of UI elements from the server, preserving focus.
 */
function render(elements) {
  const activeEl = document.activeElement;
  const focusedElementId = activeEl?.id;
  const selectionStart = activeEl?.selectionStart;
  const selectionEnd = activeEl?.selectionEnd;

  app.innerHTML = '';
  renderElementsInto(elements, app); // Call the new helper

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

  socket.onopen = () => sendMessage('client_ready');
  socket.onmessage = (event) => {
    const message = JSON.parse(event.data);
    if (message.type === 'render') {
      render(message.elements);
    }
  };
  socket.onclose = () => {
    app.className = 'container grid-lg text-center';
    app.innerHTML = '<h1>Connection to server lost. Please refresh.</h1>';
  };
  window.onpopstate = () => sendMessage('navigate');
})();
