'use strict';
/* global Monogatari, monogatari */
const { $_ready } = Monogatari;
// The bundled engine is self-contained. Do not inject a native message bridge.
$_ready(() => {
    monogatari.init('#monogatari');
});
