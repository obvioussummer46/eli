// ==UserScript==
// @name         Schulportal Hessen — Struktur-Dump
// @namespace    buzz.catcher.schulportal
// @version      1.0.0
// @description  Exportiert das HTML-Gerüst einer Schulportal-Seite mit maskierten Texten, damit man es gefahrlos weitergeben kann (z. B. um den Parser der iOS-App anzupassen).
// @match        https://start.schulportal.hessen.de/*
// @run-at       document-idle
// @grant        none
// ==/UserScript==

// Was hier passiert, und warum es sicher ist:
//
//   BLEIBT ERHALTEN  Tags, Verschachtelung, class, id, data-*, style,
//                    rowspan/colspan, Zahlen, Datumsangaben, Uhrzeiten und die
//                    Statuswörter "offen"/"erledigt". Genau daran hängt der
//                    Parser.
//   WIRD MASKIERT    Jeder andere Text: Buchstaben werden zu x/X, Länge und
//                    Zeichensetzung bleiben. "Vokabeln lernen" -> "xxxxxxxx xxxxxx".
//   FLIEGT RAUS      <script>, <style>, title/alt/value/placeholder/aria-*,
//                    onclick & Co., sowie sid/token/auth in jeder URL.
//
// Ergebnis: Namen, Noten, Nachrichten und die Sitzung sind weg, die Struktur ist
// vollständig. Trotzdem: vor dem Weitergeben einmal drüberlesen.

(function () {
  'use strict';

  const VOID_TAGS = new Set(['area', 'base', 'br', 'col', 'embed', 'hr', 'img',
    'input', 'link', 'meta', 'param', 'source', 'track', 'wbr']);
  const DROP_TAGS = new Set(['script', 'style', 'noscript', 'svg', 'canvas',
    'iframe', 'template', 'object']);

  // Strukturtragende Attribute — unverändert übernommen.
  const KEEP_ATTR = /^(class|id|style|rowspan|colspan|colgroup|type|method|for|role|name)$/i;
  const DATA_ATTR = /^data-[\w-]+$/i;
  const URL_ATTR = /^(href|src|action)$/i;
  // Alles, was eine Sitzung verraten könnte.
  const SECRET_PARAM = /^(sid|token|auth|key|hash|pass|password|user|session|csrf)$/i;
  // Bezeichner wie "sus_homeworkDone" oder "12345" sind Struktur und bleiben.
  // "Arbeitsblatt_Lena_Schmidt.pdf" beginnt groß und hat eine Endung -> maskiert.
  const SAFE_PARAM_VALUE = /^(\d+|[a-z][A-Za-z0-9]*(_[a-z][A-Za-z0-9]*)*)$/;

  // Texte, die der Parser wörtlich braucht und die nichts über dich verraten.
  const SAFE_TEXT = [
    /^[\s\W_]*$/,                                        // nur Satzzeichen
    /^\d{1,2}\.\s?\d{1,2}\.(\s?\d{2,4})?\.?$/,           // 01.09.2025 / 01.09.
    /^\d{1,2}[:.]\d{2}(\s*[-–]\s*\d{1,2}[:.]\d{2})?$/,   // 07:45 - 08:30
    /^\d+[.)]?$/,                                        // Stundennummern
    /^(offen|erledigt|erledigen|Hausaufgabe|Hausaufgaben|Stunde|Stunden|Kurs|Kurse|Thema|Inhalt|Anhang|Anhänge|Lehrer|Lehrkraft|Raum|Woche|Uhr|gültig|ab|von|bis|heute|morgen)$/i,
    /^(Montag|Dienstag|Mittwoch|Donnerstag|Freitag|Samstag|Sonntag|Mo|Di|Mi|Do|Fr|Sa|So)\.?$/i
  ];

  const isSafeText = (text) => SAFE_TEXT.some((pattern) => pattern.test(text));

  // Buchstaben raus, Form behalten. Ziffern bleiben: "bis 12.09., S. 42 Nr. 3"
  // ist für die Datums- und Textauswertung wertvoll und verrät nichts.
  const mask = (text) => text
    .replace(/[A-ZÄÖÜ]/g, 'X')
    .replace(/[a-zäöüß]/g, 'x');

  const maskText = (text) => (isSafeText(text.trim()) ? text : mask(text));

  function maskURL(raw) {
    if (!raw || raw.startsWith('#') || raw.startsWith('javascript:')) return raw;
    let url;
    try {
      url = new URL(raw, location.href);
    } catch {
      return mask(raw);
    }
    const parts = [];
    url.searchParams.forEach((value, key) => {
      if (SECRET_PARAM.test(key)) {
        parts.push(`${key}=ENTFERNT`);
      } else if (SAFE_PARAM_VALUE.test(value)) {
        parts.push(`${key}=${value}`);   // sus_view, sus_homeworkDone, 12345, done
      } else {
        parts.push(`${key}=${mask(value)}`);
      }
    });
    // Nur der Dateiname, nie der ganze Pfad — so kann auch lokal nichts durchrutschen.
    const file = url.pathname.split('/').filter(Boolean).pop() || '';
    return file + (parts.length ? `?${parts.join('&')}` : '');
  }

  const escapeText = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  const escapeAttr = (s) => escapeText(s).replace(/"/g, '&quot;');
  const indent = (depth) => '  '.repeat(depth);

  function attributesOf(element) {
    const out = [];
    for (const attribute of element.attributes) {
      const name = attribute.name.toLowerCase();
      const value = attribute.value;
      if (URL_ATTR.test(name)) {
        out.push(`${name}="${escapeAttr(maskURL(value))}"`);
      } else if (KEEP_ATTR.test(name)) {
        out.push(`${name}="${escapeAttr(value)}"`);
      } else if (DATA_ATTR.test(name)) {
        // data-book / data-entry sind numerisch und werden gebraucht; alles
        // Längere könnte Text sein und wird maskiert.
        const safe = /^[\w.:-]{0,32}$/.test(value) ? value : mask(value);
        out.push(`${name}="${escapeAttr(safe)}"`);
      }
      // title, alt, value, placeholder, aria-*, on* … werden verworfen.
    }
    return out.length ? ' ' + out.join(' ') : '';
  }

  function serialize(node, depth, out) {
    if (node.nodeType === Node.TEXT_NODE) {
      const raw = node.nodeValue.replace(/\s+/g, ' ').trim();
      if (raw) out.push(indent(depth) + escapeText(maskText(raw)));
      return;
    }
    if (node.nodeType !== Node.ELEMENT_NODE) return;

    if (node.dataset && node.dataset.dumpUi !== undefined) return;

    const tag = node.tagName.toLowerCase();
    if (DROP_TAGS.has(tag)) {
      out.push(`${indent(depth)}<!-- <${tag}> entfernt -->`);
      return;
    }

    const open = `<${tag}${attributesOf(node)}>`;
    if (VOID_TAGS.has(tag)) {
      out.push(indent(depth) + open);
      return;
    }

    const children = Array.from(node.childNodes);
    const inner = [];
    for (const child of children) serialize(child, depth + 1, inner);

    if (inner.length === 0) {
      out.push(`${indent(depth)}${open}</${tag}>`);
    } else if (inner.length === 1 && !inner[0].includes('<')) {
      out.push(`${indent(depth)}${open}${inner[0].trim()}</${tag}>`);
    } else {
      out.push(indent(depth) + open);
      out.push(...inner);
      out.push(`${indent(depth)}</${tag}>`);
    }
  }

  function buildDump() {
    const page = (location.pathname.match(/\/(\w+)\.php/) || [, 'start'])[1];
    const lines = [];
    serialize(document.body, 1, lines);
    return [
      '<!-- Schulportal-Struktur-Dump',
      `     Seite:    ${page}.php`,
      `     Erzeugt:  ${new Date().toISOString()}`,
      '',
      '     Texte sind maskiert (Buchstaben -> x/X); Zahlen, Datums- und',
      '     Zeitangaben sowie "offen"/"erledigt" bleiben stehen, weil der Parser',
      '     sie braucht. Skripte, Styles, Titel und Session-IDs sind entfernt.',
      '-->',
      ...lines,
      ''
    ].join('\n');
  }

  // --- Knopf unten rechts -------------------------------------------------

  function toast(message) {
    const el = document.createElement('div');
    el.dataset.dumpUi = '';
    el.textContent = message;
    Object.assign(el.style, {
      position: 'fixed', left: '50%', bottom: '84px', transform: 'translateX(-50%)',
      background: 'rgba(0,0,0,0.85)', color: '#fff', font: '600 14px -apple-system, sans-serif',
      padding: '10px 16px', borderRadius: '999px', zIndex: 2147483647, maxWidth: '80vw',
      textAlign: 'center'
    });
    document.body.appendChild(el);
    setTimeout(() => el.remove(), 3500);
  }

  const button = document.createElement('button');
  button.dataset.dumpUi = '';
  button.textContent = '⬇︎ Struktur';
  Object.assign(button.style, {
    position: 'fixed', right: '16px', bottom: '24px', zIndex: 2147483647,
    background: '#007aff', color: '#fff', border: 'none', borderRadius: '999px',
    padding: '12px 18px', font: '600 15px -apple-system, sans-serif',
    boxShadow: '0 2px 10px rgba(0,0,0,0.3)'
  });

  button.addEventListener('click', async () => {
    const dump = buildDump();
    const size = new Blob([dump]).size;

    try {
      await navigator.clipboard.writeText(dump);
    } catch {
      /* Zwischenablage kann blockiert sein — der Download unten reicht. */
    }

    const page = (location.pathname.match(/\/(\w+)\.php/) || [, 'start'])[1];
    const url = URL.createObjectURL(new Blob([dump], { type: 'text/plain' }));
    const link = document.createElement('a');
    link.href = url;
    link.download = `${page}-struktur.html`;
    document.body.appendChild(link);
    link.click();
    link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 10000);

    toast(`${(size / 1024).toFixed(0)} kB kopiert & gesichert`);
  });

  document.body.appendChild(button);

  // Für Tools/capture-samples.mjs: dieselbe Maskierung, ohne Knopf.
  window.__schulportalDump = buildDump;
})();
