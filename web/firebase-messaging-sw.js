importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: '***REMOVED-FIREBASE-WEB-API-KEY***',
  appId: '1:702895874700:web:12f74d60e1621c936d91a9',
  messagingSenderId: '702895874700',
  projectId: 'autodoc-6ef5a',
  authDomain: 'autodoc-6ef5a.firebaseapp.com',
  storageBucket: 'autodoc-6ef5a.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notificationTitle = payload.notification?.title ?? 'AutoDoc';
  const notificationOptions = {
    body: payload.notification?.body,
    icon: '/icons/Icon-192.png',
  };
  self.registration.showNotification(notificationTitle, notificationOptions);
});
