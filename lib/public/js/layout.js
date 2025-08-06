(function() {
  'use strict';

  // This function runs as soon as the DOM is ready.
  document.addEventListener('DOMContentLoaded', function() {
    const sidebar = document.getElementById('sidebar');
    const layoutContainer = document.getElementById('layout-container');

    if (sidebar && layoutContainer) {
      // Check if the sidebar div has any actual content inside it.
      // The `innerHTML.trim()` check ensures that whitespace doesn't count as content.
      const hasSidebarContent = sidebar.innerHTML.trim().length > 0;

      // Toggle the 'with-sidebar' class based on whether content exists.
      layoutContainer.classList.toggle('with-sidebar', hasSidebarContent);
    }
  });
})();
