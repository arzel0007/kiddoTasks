/* KiddoTasks Web Push service worker */
self.addEventListener("install", (event) => {
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener("push", (event) => {
  let payload = {
    title: "KiddoTasks",
    body: "You have a new family update.",
    data: {},
    tag: "kiddotasks",
  };
  try {
    if (event.data) {
      const parsed = event.data.json();
      payload = { ...payload, ...parsed };
    }
  } catch {
    if (event.data) payload.body = event.data.text();
  }

  const options = {
    body: payload.body,
    tag: payload.tag || "kiddotasks",
    renotify: true,
    icon: "/icon.png",
    badge: "/favicon.png",
    data: payload.data || {},
  };

  event.waitUntil(self.registration.showNotification(payload.title || "KiddoTasks", options));
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const url = "/";
  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((clients) => {
      for (const client of clients) {
        if ("focus" in client) return client.focus();
      }
      return self.clients.openWindow(url);
    })
  );
});
