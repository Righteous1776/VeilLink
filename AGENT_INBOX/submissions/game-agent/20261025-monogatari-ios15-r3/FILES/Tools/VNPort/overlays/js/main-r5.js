'use strict';
/* global Monogatari, monogatari */
const { $_ready, $_ } = Monogatari;
$_ready (() => {
    try {
        Promise.resolve(monogatari.init('#monogatari'))
            .then(function () {
                window.VeilNovelHost && window.VeilNovelHost.notify('ready');
            })
            .catch(function () {
                window.VeilNovelHost && window.VeilNovelHost.notify('init-failed');
            });
    } catch (_) {
        window.VeilNovelHost && window.VeilNovelHost.notify('init-failed');
    }
});
