importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: '$FIREBASE_WEB_API_KEY',
  appId: '$FIREBASE_APP_ID_WEB',
  messagingSenderId: '$FIREBASE_MESSAGING_SENDER_ID',
  projectId: '$FIREBASE_PROJECT_ID',
  authDomain: '$FIREBASE_AUTH_DOMAIN',
  storageBucket: '$FIREBASE_STORAGE_BUCKET',
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
