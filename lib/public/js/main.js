// lib/public/js/main.js
(function() {
  'use strict';

  // Only connect to the WebSocket if the server has marked this page as reactive
  if (window.DRZYR_IS_REACTIVE) {
    // Connect the websocket and set the renderer as the callback
    window.DrzyrWebsocket.connect(window.DrzyrRenderer.render);

    // Handle back/forward browser navigation for reactive pages
    window.onpopstate = () => window.DrzyrWebsocket.sendMessage('navigate');
  }
})();
