// lib/public/js/renderer.js
window.DrzyrRenderer = (function(window) {
  'use strict';

  function fromHTML(html) {
    const template = document.createElement('template');
    template.innerHTML = html.trim();
    return template.content.firstChild;
  }

  function renderElementsInto(elements, parentNode, postRenderCallbacks) {
    if (!elements || !Array.isArray(elements)) return;

    elements.forEach(element => {
      const creator = widgetCreators[element.type] || (element.type.startsWith('heading') ? widgetCreators.heading : null);
      if (!creator) {
        console.warn('Unknown widget type:', element.type);
        return;
      }

      const result = creator(element);
      if (!result) return;

      const isComplex = result.nodeType === undefined;
      const widget = isComplex ? result.widget : result;

      if (isComplex && result.postRender) {
          postRenderCallbacks.push(result.postRender);
      }

      const needsContainer = !['heading1', 'heading2', 'heading3', 'heading4', 'heading5', 'heading6', 'paragraph', 'columns_container', 'divider', 'navbar_brand', 'navbar_link'].includes(element.type);

      if (needsContainer) {
          const container = document.createElement('div');
          container.className = 'form-group';
          if (element.error) {
              container.classList.add('has-error');
          }
          if (element.label && !(isComplex && result.skipLabel)) {
              const label = document.createElement('label');
              label.className = 'form-label';
              label.htmlFor = element.id;
              label.innerText = (isComplex && result.label) ? result.label : element.label;
              container.appendChild(label);
          }
          container.appendChild(widget);
          if (element.error) {
              const hint = document.createElement('p');
              hint.className = 'form-input-hint';
              hint.innerText = element.error;
              container.appendChild(hint);
          }
          parentNode.appendChild(container);
      } else {
          parentNode.appendChild(widget);
      }
    });
  }

  // --- Widget Creators (This section remains the same as the previous full version) ---
  const widgetCreators = {
    heading(el) { return fromHTML(Mustache.render(DrzyrTemplates.get('heading'), { ...el, level: el.type.substring(7) })); },
    paragraph(el) { return fromHTML(Mustache.render(DrzyrTemplates.get('paragraph'), el)); },
    link(el) { return fromHTML(Mustache.render(DrzyrTemplates.get('link'), el)); },
    alert(el) { return fromHTML(Mustache.render(DrzyrTemplates.get('alert'), el)); },
    image(el) { return fromHTML(Mustache.render(DrzyrTemplates.get('image'), el)); },
    code(el) { return fromHTML(Mustache.render(DrzyrTemplates.get('code'), el)); },
    latex(el) { return fromHTML(Mustache.render(DrzyrTemplates.get('latex'), el)); },
    divider(el) { return fromHTML(Mustache.render(DrzyrTemplates.get('divider'), el)); },
    table(el) { return fromHTML(Mustache.render(DrzyrTemplates.get('table'), el)); },
    spinner(el) { return { widget: fromHTML(Mustache.render(DrzyrTemplates.get('spinner'), el)), skipLabel: true }; },

    theme_setter(el) {
        document.body.classList.toggle('dark-mode', el.theme === 'dark');
        return null;
    },

    button(el) {
      const button = fromHTML(Mustache.render(DrzyrTemplates.get('button'), el));
      button.onclick = () => window.DrzyrWebsocket.sendMessage('button_press', { widget_id: el.id });
      return { widget: button, skipLabel: true };
    },
    text_input(el) {
      const widget = fromHTML(Mustache.render(DrzyrTemplates.get('text_input'), el));
      widget.querySelector('input').oninput = (e) => window.DrzyrWebsocket.sendMessage('update', { widget_id: el.id, value: e.target.value });
      return { widget };
    },
    number_input(el) {
        const widget = fromHTML(Mustache.render(DrzyrTemplates.get('number_input'), el));
        widget.querySelector('input').oninput = (e) => window.DrzyrWebsocket.sendMessage('update', { widget_id: el.id, value: e.target.value });
        return { widget };
    },
    password_input(el) {
        const widget = fromHTML(Mustache.render(DrzyrTemplates.get('password_input'), el));
        widget.querySelector('input').oninput = (e) => window.DrzyrWebsocket.sendMessage('update', { widget_id: el.id, value: e.target.value });
        return { widget };
    },
    textarea(el) {
        const widget = fromHTML(Mustache.render(DrzyrTemplates.get('textarea'), el));
        widget.querySelector('textarea').oninput = (e) => window.DrzyrWebsocket.sendMessage('update', { widget_id: el.id, value: e.target.value });
        return { widget };
    },
    checkbox(el) {
        const widget = fromHTML(Mustache.render(DrzyrTemplates.get('checkbox'), el));
        widget.querySelector('input').onchange = (e) => window.DrzyrWebsocket.sendMessage('update', { widget_id: el.id, value: e.target.checked });
        return { widget, skipLabel: true };
    },
    selectbox(el) {
        const widget = fromHTML(Mustache.render(DrzyrTemplates.get('selectbox'), el));
        widget.querySelector('select').onchange = (e) => window.DrzyrWebsocket.sendMessage('update', { widget_id: el.id, value: e.target.value });
        return { widget };
    },
    slider(el) {
        const widget = fromHTML(Mustache.render(DrzyrTemplates.get('slider'), el));
        widget.querySelector('input').oninput = (e) => window.DrzyrWebsocket.sendMessage('update', { widget_id: el.id, value: e.target.value });
        return { widget, label: `${el.label} (${el.value})` };
    },

    columns_container(element) {
        const container = fromHTML(Mustache.render(DrzyrTemplates.get('columns_container'), {}));
        const postRenderCallbacks = [];
        if (element.columns && Array.isArray(element.columns)) {
            element.columns.forEach(columnElements => {
                const columnDiv = document.createElement('div');
                columnDiv.className = 'column';
                renderElementsInto(columnElements, columnDiv, postRenderCallbacks);
                container.appendChild(columnDiv);
            });
        }
        const postRender = () => postRenderCallbacks.forEach(cb => cb());
        return { widget: container, skipLabel: true, postRender };
    },
    expander(element) {
        const container = fromHTML(Mustache.render(DrzyrTemplates.get('expander'), element));
        container.querySelector('.accordion-header').onclick = () => window.DrzyrWebsocket.sendMessage('button_press', { widget_id: element.id });
        renderElementsInto(element.content, container.querySelector('.accordion-body'), []);
        return { widget: container, skipLabel: true };
    },
    tabs(element) {
        const container = fromHTML(Mustache.render(DrzyrTemplates.get('tabs'), element));
        container.querySelectorAll('.tab-item a').forEach((tabLink, index) => {
            const tabItemId = `${element.id}_${element.labels[index].value}`;
            tabLink.onclick = () => window.DrzyrWebsocket.sendMessage('button_press', { widget_id: tabItemId });
        });
        renderElementsInto(element.content, container.querySelector('.tab-content'), []);
        return { widget: container, skipLabel: true };
    },

    data_table(element) {
      const container = fromHTML(Mustache.render(DrzyrTemplates.get('data_table'), element));
      const postRender = () => {
        const target = document.getElementById(element.id);
        if (target) {
          target.innerHTML = '';
          new gridjs.Grid({
            columns: element.columns,
            data: element.data,
            search: true,
            sort: true,
            pagination: true,
          }).render(target);
        }
      };
      return { widget: container, skipLabel: true, postRender };
    },
    chart(element) {
        const container = fromHTML(Mustache.render(DrzyrTemplates.get('chart'), element));
        const postRender = () => {
            const ctx = document.getElementById(element.id);
            if (ctx) {
                new Chart(ctx, {
                    type: element.options.type || 'bar',
                    data: element.data,
                    options: element.options
                });
            }
        };
        return { widget: container, skipLabel: true, postRender };
    },
    date_range_picker(element) {
        const widget = fromHTML(Mustache.render(DrzyrTemplates.get('date_range_picker'), element));
        const postRender = () => {
            const el = document.getElementById(element.id);
            if (el && !el.litepickerInstance) {
                el.litepickerInstance = new Litepicker({
                    element: el,
                    singleMode: false,
                    format: 'YYYY-MM-DD',
                    setup: (picker) => {
                        picker.on('selected', (date1, date2) => {
                            if (date1 && date2) {
                                const value = `${date1.format('YYYY-MM-DD')} - ${date2.format('YYYY-MM-DD')}`;
                                window.DrzyrWebsocket.sendMessage('update', { widget_id: element.id, value: value });
                            }
                        });
                    }
                });
            }
        };
        return { widget, postRender };
    },
  };

  // --- Public API ---
  return {
    render(data) {
        const app = document.getElementById('app');
        const sidebar = document.getElementById('sidebar');
        const layoutContainer = document.getElementById('layout-container');
        const postRenderCallbacks = [];

        const appScrollTop = app.scrollTop;
        const sidebarScrollTop = sidebar.scrollTop;

        app.innerHTML = '';
        sidebar.innerHTML = '';

        // Detect if the server sent sidebar elements and toggle the class accordingly.
        const hasSidebar = data.sidebar_elements && data.sidebar_elements.length > 0;
        layoutContainer.classList.toggle('with-sidebar', hasSidebar);

        // Render the elements into their respective containers.
        renderElementsInto(data.elements, app, postRenderCallbacks);
        renderElementsInto(data.sidebar_elements, sidebar, postRenderCallbacks);

        // After rendering, run any necessary post-render hooks.
        setTimeout(() => {
            postRenderCallbacks.forEach(cb => cb());

            if (window.MathJax) {
                window.MathJax.typesetPromise().catch(console.error);
            }

            app.scrollTop = appScrollTop;
            sidebar.scrollTop = sidebarScrollTop;
        }, 0);
    }
  };
})(window);
