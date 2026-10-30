'use strict';
/* global Monogatari, monogatari */
const { $_ready } = Monogatari;
$_ready(() => {
 try { Promise.resolve(monogatari.init('#monogatari')).then(() => {
  window.VeilNovelHost && window.VeilNovelHost.notify('ready');
 }).catch(() => { window.VeilNovelHost && window.VeilNovelHost.notify('init-failed'); }); }
 catch (_) { window.VeilNovelHost && window.VeilNovelHost.notify('init-failed'); }
});
