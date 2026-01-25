// static/js/chat.js
(function () {
  const box = document.getElementById("chatBox");
  if (!box) return;

  const messagesEl = document.getElementById("chatMessages");
  const inputEl = document.getElementById("chatInput");
  const sendBtn = document.getElementById("chatSend");
  const typingHint = document.getElementById("typingHint");

  const postUrl = box.dataset.postUrl;
  const wsPath = box.dataset.wsPath;
  const meId = Number(box.dataset.meId || 0);
  const meName = box.dataset.meName || "أنت";

  function buildWsUrl() {
    if (!wsPath) return null;
    const proto = location.protocol === "https:" ? "wss" : "ws";
    return `${proto}://${location.host}${wsPath}`;
  }

  let socket = null;
  let isOpen = false;
  let retry = 0;
  let typingTimer = null;

  // client_id -> element (pending)
  const pendingMap = new Map();

  function appendMessage(msg, opts = {}) {
    const wrap = document.createElement("div");
    wrap.className = "rounded-xl border p-2 bg-white";

    if (opts.pending) wrap.classList.add("opacity-70");
    if (opts.clientId) wrap.dataset.clientId = String(opts.clientId);

    const meta = document.createElement("div");
    meta.className = "text-xs text-slate-500 mb-1";
    const sender = msg.sender_name || "—";
    const when = msg.sent_at ? new Date(msg.sent_at).toLocaleString() : "";
    meta.textContent = `${sender} • ${when}`;

    const text = document.createElement("div");
    text.className = "whitespace-pre-wrap";
    text.textContent = msg.text || "";

    wrap.appendChild(meta);
    wrap.appendChild(text);

    messagesEl.appendChild(wrap);
    messagesEl.scrollTop = messagesEl.scrollHeight;
    return wrap;
  }

  function setTyping(show) {
    if (!typingHint) return;
    if (show) typingHint.classList.remove("hidden");
    else typingHint.classList.add("hidden");
  }

  function sendJson(payload) {
    if (!isOpen || !socket || socket.readyState !== WebSocket.OPEN) return false;
    socket.send(JSON.stringify(payload));
    return true;
  }

  function connect() {
    const wsUrl = buildWsUrl();
    if (!wsUrl) return;

    if (socket && (socket.readyState === WebSocket.OPEN || socket.readyState === WebSocket.CONNECTING)) return;

    try {
      socket = new WebSocket(wsUrl);

      socket.onopen = () => {
        isOpen = true;
        retry = 0;
        // علّم مقروء عند الاتصال
        sendJson({ type: "read" });
      };

      socket.onclose = () => {
        isOpen = false;
        reconnect();
      };

      socket.onerror = () => {
        isOpen = false;
        try {
          socket.close();
        } catch (e) {}
      };

      socket.onmessage = (ev) => {
        try {
          const data = JSON.parse(ev.data);

          if (data.type === "message") {
            // إذا هذه رسالة تأكيد لرسالة pending (ack)
            if (data.client_id && pendingMap.has(String(data.client_id))) {
              const el = pendingMap.get(String(data.client_id));
              pendingMap.delete(String(data.client_id));

              el.classList.remove("opacity-70");
              const meta = el.querySelector(".text-xs");
              const body = el.querySelector(".whitespace-pre-wrap");

              if (meta) {
                const when = data.sent_at ? new Date(data.sent_at).toLocaleString() : "";
                meta.textContent = `${data.sender_name || meName} • ${when}`;
              }
              if (body) body.textContent = data.text || "";
              return;
            }

            appendMessage(data);
            // علّم مقروء بعد استقبال رسالة
            sendJson({ type: "read" });
            return;
          }

          if (data.type === "typing") {
            if (data.user_id && Number(data.user_id) === meId) return;
            setTyping(Boolean(data.is_typing));
            return;
          }

          if (data.type === "read") {
            return;
          }
        } catch (e) {}
      };
    } catch (e) {
      reconnect();
    }
  }

  function reconnect() {
    retry += 1;
    const wait = Math.min(8000, 500 * retry);
    setTimeout(() => connect(), wait);
  }

  function getCsrfToken() {
    const m = document.cookie.match(/csrftoken=([^;]+)/);
    return m ? decodeURIComponent(m[1]) : "";
  }

  async function fallbackPost(text) {
    const csrf = getCsrfToken();
    const body = new URLSearchParams();
    body.set("text", text);

    const res = await fetch(postUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRFToken": csrf,
      },
      body: body.toString(),
      credentials: "same-origin",
    });

    const data = await res.json().catch(() => ({}));
    if (!res.ok || !data.ok) throw new Error(data.error || "تعذر الإرسال");
    return data.message;
  }

  function newClientId() {
    return `${Date.now()}_${Math.random().toString(16).slice(2)}`;
  }

  async function sendMessage() {
    const text = (inputEl.value || "").trim();
    if (!text) return;

    inputEl.value = "";
    inputEl.focus();

    // WS متصل: Pending + client_id ثم ack
    if (isOpen && socket && socket.readyState === WebSocket.OPEN) {
      const clientId = newClientId();
      const el = appendMessage(
        { text, sender_name: meName, sent_at: new Date().toISOString() },
        { pending: true, clientId }
      );
      pendingMap.set(String(clientId), el);

      sendJson({ type: "message", text, client_id: clientId });
      return;
    }

    // WS غير متصل: fallback POST (نضيف Pending)
    const pendingEl = appendMessage(
      { text, sender_name: meName, sent_at: new Date().toISOString() },
      { pending: true }
    );

    try {
      const msg = await fallbackPost(text);
      // حدث pending لتصبح نهائية
      pendingEl.classList.remove("opacity-70");
      const meta = pendingEl.querySelector(".text-xs");
      const body = pendingEl.querySelector(".whitespace-pre-wrap");
      if (meta) {
        const when = msg.sent_at ? new Date(msg.sent_at).toLocaleString() : "";
        meta.textContent = `${msg.sender_name || meName} • ${when}`;
      }
      if (body) body.textContent = msg.text || text;
    } catch (e) {
      alert(e.message || "حدث خطأ أثناء الإرسال");
    }
  }

  function sendTyping(isTyping) {
    sendJson({ type: "typing", is_typing: isTyping });
  }

  sendBtn.addEventListener("click", sendMessage);
  inputEl.addEventListener("keydown", (e) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  });

  inputEl.addEventListener("input", () => {
    sendTyping(true);
    clearTimeout(typingTimer);
    typingTimer = setTimeout(() => sendTyping(false), 700);
  });

  document.addEventListener("visibilitychange", () => {
    if (!document.hidden) sendJson({ type: "read" });
  });

  connect();
})();
