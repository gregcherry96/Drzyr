// lib/public/js/websocket.js
window.DrzyrWebsocket = {
  socket: null,
  reconnectAttempts: 0,
  maxReconnectAttempts: 10,

  connect(onMessageCallback) {
    this.socket = new WebSocket(`ws://${window.location.host}/websocket`);
    this.socket.onopen = () => {
      console.log('WebSocket connected.');
      this.reconnectAttempts = 0;
      this.sendMessage('client_ready');
    };
    this.socket.onmessage = (event) => {
      const message = JSON.parse(event.data);
      if (message.type === 'render' && onMessageCallback) {
        onMessageCallback(message);
      }
    };
    this.socket.onclose = () => {
      console.log('WebSocket disconnected. Attempting to reconnect...');
      this.reconnectAttempts++;
      if (this.reconnectAttempts > this.maxReconnectAttempts) {
        document.getElementById('app').innerHTML = '<h1>Connection lost. Please refresh.</h1>';
        return;
      }
      const delay = Math.min(30000, 1000 * Math.pow(2, this.reconnectAttempts));
      setTimeout(() => this.connect(onMessageCallback), delay);
    };
    this.socket.onerror = (err) => {
      console.error('WebSocket error:', err);
      this.socket.close();
    };
  },

  sendMessage(type, payload = {}) {
    if (!this.socket || this.socket.readyState !== WebSocket.OPEN) {
      console.warn('Socket not open.', { type, payload });
      return;
    }
    const message = { type, path: window.location.pathname, ...payload };
    this.socket.send(JSON.stringify(message));
  }
};
