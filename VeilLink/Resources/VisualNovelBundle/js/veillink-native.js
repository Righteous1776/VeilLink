// R5: notification-only bridge; persistent-origin witness never reads game saves.
(function () {
  'use strict';
  var allowed = Object.freeze({
    ready: true, error: true, 'init-failed': true, 'storage-unavailable': true,
    'storage-probe-created': true, 'storage-probe-retained': true
  });
  var sent = Object.create(null);
  var bridge = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.veilNovel;
  function notify(type) {
    if (!Object.prototype.hasOwnProperty.call(allowed, type) || sent[type]) return;
    sent[type] = true;
    if (bridge && typeof bridge.postMessage === 'function') {
      try { bridge.postMessage({ type: type }); } catch (_) { /* web preview has no native bridge */ }
    }
  }
  Object.defineProperty(window, 'VeilNovelHost', {
    value: Object.freeze({ protocolVersion: 3, notify: notify }),
    configurable: false, writable: false
  });
  // Separate sentinel, not a Monogatari save key. This tests same-origin
  // availability and allows the native host to compare across later launches.
  try {
    var storage = window.localStorage;
    var healthKey = '__veilnovel_storage_probe_r5';
    if (storage.getItem(healthKey) === 'veilnovel-v1') {
      notify('storage-probe-retained');
    } else {
      storage.setItem(healthKey, 'veilnovel-v1');
      if (storage.getItem(healthKey) === 'veilnovel-v1') {
        notify('storage-probe-created');
      } else {
        notify('storage-unavailable');
      }
    }
  } catch (_) { notify('storage-unavailable'); }
  window.addEventListener('error', function () { notify('error'); });
  window.addEventListener('unhandledrejection', function () { notify('error'); });
})();
