// public/javascript.js
(function () {
  const app = document.getElementById('app');
  const sidebar = document.getElementById('sidebar');
  const layoutContainer = document.getElementById('layout-container');
  const navbarContainer = document.getElementById('navbar-container');
  if (!app || !sidebar || !layoutContainer || !navbarContainer) return;

  let socket;
  let reconnectAttempts = 0;
  const maxReconnectAttempts = 10;

  function connect() {
    socket = new WebSocket(`ws://${window.location.host}/websocket`);
    socket.onopen = () => { console.log('WebSocket connected.'); reconnectAttempts = 0; sendMessage('client_ready'); };
    socket.onmessage = (event) => {
      const message = JSON.parse(event.data);
      if (message.type === 'render') {
        render(message);
      }
    };
    socket.onclose = () => {
      console.log('WebSocket disconnected. Attempting to reconnect...');
      reconnectAttempts++;
      if (reconnectAttempts > maxReconnectAttempts) { app.innerHTML = '<h1>Connection lost. Please refresh.</h1>'; return; }
      const delay = Math.min(30000, 1000 * Math.pow(2, reconnectAttempts));
      setTimeout(connect, delay);
    };
    socket.onerror = (err) => { console.error('WebSocket error:', err); socket.close(); };
  }

  function sendMessage(type, payload = {}) {
    if (!socket || socket.readyState !== WebSocket.OPEN) { console.warn('Socket not open.', { type, payload }); return; }
    const message = { type, path: window.location.pathname, ...payload };
    socket.send(JSON.stringify(message));
  }

  function createElement(tag, attributes = {}, children = []) {
    const el = document.createElement(tag);
    Object.entries(attributes).forEach(([key, value]) => {
      if (key in el) {
        el[key] = value;
      } else if (value !== null && value !== undefined && value !== false) {
        el.setAttribute(key, value);
      }
    });
    children.forEach(child => el.appendChild(child));
    return el;
  }

  function renderNavbar(config) {
    navbarContainer.innerHTML = '';
    navbarContainer.classList.remove('navbar-visible');
    if (!config) {
      return;
    }

    navbarContainer.classList.add('navbar-visible');
    const brandSection = createElement('section', { className: 'navbar-section' });
    const brand = createElement('a', { href: '#', className: 'navbar-brand mr-2', innerText: config.title });
    brandSection.appendChild(brand);

    const linksSection = createElement('section', { className: 'navbar-section' });
    Object.entries(config.links).forEach(([text, path]) => {
      const link = createElement('a', {
        href: path,
        className: `btn btn-link ${window.location.pathname === path ? 'navbar-link-active' : ''}`,
        innerText: text
      });
      linksSection.appendChild(link);
    });

    navbarContainer.append(brandSection, linksSection);
  }

  const widgetCreators = {
    error_display(element) {
      const container = createElement('div', { style: 'padding: 1rem; border: 1px solid #e83e8c; background: rgba(232, 62, 140, 0.05);' });
      const title = createElement('h4', { style: 'color: #e83e8c;', innerText: `Runtime Error: ${element.message}` });
      const pre = createElement('pre', { style: 'white-space: pre-wrap; font-size: 0.8em; color: #d1d1d1; background: #2b2b2b; padding: 1rem; border-radius: 4px;' });
      const code = createElement('code', { innerText: element.backtrace });

      pre.appendChild(code);
      container.append(title, pre);
      return container;
    },
    heading(element) {
      const level = element.type.substring(7);
      return createElement(`h${level}`, { innerText: element.text, id: element.id });
    },
    link(element) {
      return createElement('a', { innerText: element.text, href: element.href });
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
    data_table(element) {
      const container = createElement('div', {
        id: element.id,
        className: 'data-table-placeholder'
      });
      const loadingSpinner = createElement('div', { className: 'loading loading-lg' });
      container.appendChild(loadingSpinner);

      setTimeout(() => {
        const target = document.getElementById(element.id);
        if (target) {
          new gridjs.Grid({
            columns: element.columns,
            data: element.data,
            search: true,
            sort: true,
            pagination: true,
          }).render(target);
        }
      }, 0);

      return { widget: container, skipLabel: true };
    },
    alert(element) {
      return createElement('div', {
        className: `toast toast-${element.style}`,
        innerText: element.text
      });
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
    latex(element) {
      return createElement('div', { innerText: `$$${element.text}$$` });
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
    theme_setter(element) {
      if (element.theme === 'dark') {
        document.body.classList.add('dark-mode');
      } else {
        document.body.classList.remove('dark-mode');
      }
      return document.createDocumentFragment();
    },
    expander(element) {
      const container = createElement('div', { className: 'accordion' });
      const checkbox = createElement('input', {
        type: 'checkbox',
        id: element.id,
        name: 'accordion-checkbox',
        hidden: true,
        checked: element.expanded
      });
      const header = createElement('label', {
        className: 'accordion-header c-hand',
        htmlFor: element.id,
        onclick: () => sendMessage('button_press', { widget_id: element.id })
      });
      const icon = createElement('i', { className: 'icon icon-arrow-right mr-1' });
      header.append(icon, element.label);
      const body = createElement('div', { className: 'accordion-body' });
      renderElementsInto(element.content, body);
      container.append(checkbox, header, body);
      return { widget: container, skipLabel: true };
    },
    form_group(element) {
      const fieldset = createElement('fieldset', { className: 'form-group' });
      const legend = createElement('legend', { className: 'form-label', innerText: element.label });
      fieldset.appendChild(legend);
      renderElementsInto(element.content, fieldset);
      return { widget: fieldset, skipLabel: true };
    },
    chart(element) {
      const container = createElement('div', { className: 'chart-container' });
      const canvas = createElement('canvas', { id: element.id });
      container.appendChild(canvas);

      setTimeout(() => {
        const ctx = document.getElementById(element.id);
        if (ctx) {
          new Chart(ctx, {
            type: element.options.type || 'bar',
            data: element.data,
            options: element.options
          });
        }
      }, 0);

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
    date_range_picker(element) {
      const input = createInputElement('input', element, {
        type: 'text',
        className: 'form-input',
      });

      setTimeout(() => {
        const el = document.getElementById(element.id);
        if (el && !el.litepickerInstance) {
          const picker = new Litepicker({
            element: el,
            singleMode: false,
            format: 'YYYY-MM-DD',
            setup: (picker) => {
              picker.on('selected', (date1, date2) => {
                if (date1 && date2) {
                  const value = `${date1.format('YYYY-MM-DD')} - ${date2.format('YYYY-MM-DD')}`;
                  sendMessage('update', { widget_id: element.id, value: value });
                }
              });
            }
          });
          el.litepickerInstance = picker;
        }
      }, 0);

      return { widget: input };
    },
    textarea(element) {
      const textarea = createInputElement('textarea', element, {
        className: 'form-input',
        rows: element.rows,
        oninput: (e) => sendMessage('update', { widget_id: element.id, value: e.target.value })
      });
      textarea.innerText = element.value;
      return { widget: textarea };
    },
    checkbox(element) {
        const isSwitch = element.id.includes('theme');
        const labelClass = isSwitch ? 'form-switch' : 'form-checkbox';
        const check = createInputElement('input', element, {
        type: 'checkbox',
        checked: element.value,
        onchange: (e) => sendMessage('update', { widget_id: element.id, value: e.target.checked })
      });
      const icon = createElement('i', { className: 'form-icon' });
      const label = createElement('label', { className: labelClass });
      label.append(check, icon, element.label);
      return { widget: label, skipLabel: true };
    },
    selectbox(element) {
      const select = createElement('select', {
        id: element.id,
        className: 'form-select',
        onchange: (e) => sendMessage('update', { widget_id: element.id, value: e.target.value })
      });
      element.options.forEach(opt => {
        select.appendChild(createElement('option', { value: opt, innerText: opt }));
      });
      select.value = element.value;
      return { widget: select };
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
          selected: element.value.includes(opt)
        });
        select.appendChild(option);
      });
      return { widget: select };
    },
    radio_group(element) {
      const container = createElement('div', { className: 'form-group' });
      const mainLabel = createElement('label', { className: 'form-label', innerText: element.label });
      container.appendChild(mainLabel);
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
    columns_container(element) {
      const container = createElement('div', { className: 'columns' });
      element.columns.forEach(columnElements => {
        const columnDiv = createElement('div', { className: 'column' });
        renderElementsInto(columnElements, columnDiv);
        container.appendChild(columnDiv);
      });
      return container;
    },
    button(element) {
      const button = createInputElement('button', element, {
        className: 'btn btn-primary',
        innerText: element.text,
        onclick: () => sendMessage('button_press', { widget_id: element.id })
      });
      return { widget: button, skipLabel: true };
    }
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
      const needsContainer = !['heading', 'paragraph', 'table', 'columns_container', 'divider'].includes(element.type);

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

  function render(data) {
    const activeEl = document.activeElement;
    const focusedElementId = activeEl?.id;
    const selectionStart = activeEl?.selectionStart;
    const selectionEnd = activeEl?.selectionEnd;
    const appScrollTop = app.scrollTop;
    const sidebarScrollTop = sidebar.scrollTop;

    if (data.error) {
      app.innerHTML = '';
      sidebar.innerHTML = '';
      app.appendChild(widgetCreators.error_display(data.error));
      return;
    }

    app.innerHTML = '';
    sidebar.innerHTML = '';

    renderNavbar(data.navbar);

    const hasSidebar = data.sidebar_elements && data.sidebar_elements.length > 0;
    if (hasSidebar) {
      layoutContainer.classList.add('with-sidebar');
      renderElementsInto(data.sidebar_elements, sidebar);
    } else {
      layoutContainer.classList.remove('with-sidebar');
    }

    if (data.elements) {
      renderElementsInto(data.elements, app);
    }

    setTimeout(() => {
        const mathjaxPromise = window.MathJax ? window.MathJax.typesetPromise() : Promise.resolve();

        mathjaxPromise.catch((err) => {
            console.error("MathJax typesetting error:", err);
        }).finally(() => {
            if (focusedElementId) {
                const newElementToFocus = document.getElementById(focusedElementId);
                if (newElementToFocus) {
                    newElementToFocus.focus();
                    if (typeof newElementToFocus.setSelectionRange === 'function') {
                        newElementToFocus.setSelectionRange(selectionStart, selectionEnd);
                    }
                }
            }
            app.scrollTop = appScrollTop;
            sidebar.scrollTop = sidebarScrollTop;
        });
    }, 0);
  }

  if (window.DRZYR_SERVER_RENDERED_NAVBAR) {
    renderNavbar(window.DRZYR_SERVER_RENDERED_NAVBAR);
  }

  connect();
  window.onpopstate = () => sendMessage('navigate');
})();
