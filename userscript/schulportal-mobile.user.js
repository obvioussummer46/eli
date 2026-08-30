// ==UserScript==
// @name         Schulportal Hessen — Mobile
// @namespace    buzz.catcher.schulportal
// @version      2.1.0
// @description  Mobile redesign of the whole Schulportal Hessen: cards for Mein Unterricht with full subject names and an open-homework digest, polished tables, panels, calendar, messages — with automatic dark mode.
// @match        https://start.schulportal.hessen.de/*
// @run-at       document-end
// @grant        none
// ==/UserScript==

(function () {
  'use strict';

  // Tag <html> with the current page so CSS can be scoped per page.
  const m = location.pathname.match(/\/(\w+)\.php/);
  const pageName = m ? m[1] : 'start';
  const root = document.documentElement;
  root.classList.add('sp-' + pageName);
  // Pages that get the table -> card transformation:
  if (pageName === 'meinunterricht') root.classList.add('sp-cards');

  const css = `
  :root {
    --sp-bg: #f2f2f7;
    --sp-card: #ffffff;
    --sp-text: #1c1c1e;
    --sp-text2: #6e6e73;
    --sp-accent: #007aff;
    --sp-green: #34c759;
    --sp-orange: #ff9500;
    --sp-red: #ff3b30;
    --sp-border: rgba(0,0,0,0.08);
    --sp-shadow: 0 1px 3px rgba(0,0,0,0.08);
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --sp-bg: #000000;
      --sp-card: #1c1c1e;
      --sp-text: #f2f2f7;
      --sp-text2: #98989d;
      --sp-accent: #0a84ff;
      --sp-green: #30d158;
      --sp-orange: #ff9f0a;
      --sp-red: #ff453a;
      --sp-border: rgba(255,255,255,0.12);
      --sp-shadow: 0 1px 3px rgba(0,0,0,0.5);
    }
  }

  /* ============ Global ============ */
  body {
    background: var(--sp-bg) !important;
    color: var(--sp-text) !important;
    font-family: -apple-system, "SF Pro Text", "Helvetica Neue", sans-serif !important;
    -webkit-text-size-adjust: 100%;
  }
  #content, .container { background: transparent !important; }
  h1, h2, h3, h4 { color: var(--sp-text) !important; letter-spacing: -0.02em; }
  hr { border-color: var(--sp-border) !important; }
  a { color: var(--sp-accent); }
  #content h1 { font-size: 26px; font-weight: 700; margin: 10px 0 4px; }

  /* Navbar */
  .navbar, .navbar-default, .navbar-inverse {
    background: var(--sp-card) !important;
    border: none !important;
    box-shadow: var(--sp-shadow);
  }
  .navbar .navbar-brand, .navbar a { color: var(--sp-text) !important; font-weight: 600; }
  .navbar-toggle { border-color: var(--sp-border) !important; }
  .navbar-toggle .icon-bar { background: var(--sp-text) !important; }
  .navbar-collapse { background: var(--sp-card) !important; border-top: 1px solid var(--sp-border) !important; }
  .navbar .dropdown-menu { background: var(--sp-card) !important; }

  /* Tabs -> segmented pills (student tabs, Historie/Leistungen tabs, ...) */
  .nav-tabs { border-bottom: none !important; margin-bottom: 6px; }
  .nav-tabs > li > a {
    border: none !important;
    border-radius: 999px !important;
    background: var(--sp-card) !important;
    color: var(--sp-text2) !important;
    font-weight: 600;
    padding: 7px 14px;
    box-shadow: var(--sp-shadow);
    margin-right: 4px;
  }
  .nav-tabs > li.active > a { background: var(--sp-accent) !important; color: #fff !important; }
  .pupilbox > h2, .pupilbox > h3 { display: none; }  /* duplicate student name + heading */

  /* Panels, wells, thumbnails -> cards */
  .panel {
    background: var(--sp-card) !important;
    border: 1px solid var(--sp-border) !important;
    border-radius: 14px !important;
    box-shadow: var(--sp-shadow) !important;
    overflow: hidden;
  }
  .panel-heading {
    background: var(--sp-card) !important;
    color: var(--sp-text) !important;
    font-weight: 600;
    border-bottom: 1px solid var(--sp-border) !important;
  }
  .panel-heading a { color: var(--sp-text) !important; }
  .panel-body { background: var(--sp-card) !important; color: var(--sp-text) !important; }
  .well, .thumbnail {
    background: var(--sp-card) !important;
    border: 1px solid var(--sp-border) !important;
    border-radius: 14px !important;
    color: var(--sp-text) !important;
  }
  .list-group-item {
    background: var(--sp-card) !important;
    border-color: var(--sp-border) !important;
    color: var(--sp-text) !important;
  }

  /* Alerts */
  .alert { border-radius: 12px !important; border: none !important; color: var(--sp-text) !important; }
  .alert-warning { background: color-mix(in srgb, var(--sp-orange) 16%, var(--sp-card)) !important; }
  .alert-info    { background: color-mix(in srgb, var(--sp-accent) 14%, var(--sp-card)) !important; }
  .alert-danger  { background: color-mix(in srgb, var(--sp-red) 14%, var(--sp-card)) !important; }
  .alert-success { background: color-mix(in srgb, var(--sp-green) 14%, var(--sp-card)) !important; }

  /* Buttons, dropdowns, forms, modals */
  .btn { border-radius: 10px; }
  .btn-primary { background: var(--sp-accent) !important; border-color: var(--sp-accent) !important; }
  .btn-default {
    background: var(--sp-card) !important;
    color: var(--sp-text) !important;
    border: 1px solid var(--sp-border) !important;
  }
  .dropdown-menu {
    background: var(--sp-card) !important;
    border: 1px solid var(--sp-border) !important;
    border-radius: 12px;
    box-shadow: var(--sp-shadow);
  }
  .dropdown-menu > li > a { color: var(--sp-text) !important; padding: 8px 14px; }
  .dropdown-menu .divider { background: var(--sp-border) !important; }
  input.form-control, select.form-control, textarea.form-control, .input-group-addon {
    background: var(--sp-card) !important;
    color: var(--sp-text) !important;
    border: 1px solid var(--sp-border) !important;
    border-radius: 10px !important;
  }
  .modal-content {
    background: var(--sp-card) !important;
    color: var(--sp-text) !important;
    border-radius: 16px !important;
    border: 1px solid var(--sp-border) !important;
  }
  .badge-danger, .badge.badge-danger {
    background: var(--sp-red) !important; color: #fff !important;
    border-radius: 999px; font-size: 12px; vertical-align: 2px;
  }
  .label { border-radius: 6px !important; }

  /* ============ Generic tables (all pages WITHOUT card transform) ============ */
  html:not(.sp-cards) .sp-scroll {
    overflow-x: auto;
    -webkit-overflow-scrolling: touch;
    background: var(--sp-card);
    border: 1px solid var(--sp-border);
    border-radius: 14px;
    box-shadow: var(--sp-shadow);
    margin: 10px 0;
  }
  html:not(.sp-cards) .sp-scroll > table.table { margin: 0 !important; }
  html:not(.sp-cards) .table > thead > tr > th {
    background: var(--sp-card) !important;
    color: var(--sp-text2) !important;
    font-size: 12px; text-transform: uppercase; letter-spacing: 0.04em;
    border-bottom: 1px solid var(--sp-border) !important;
  }
  html:not(.sp-cards) .table > tbody > tr > td,
  html:not(.sp-cards) .table > tbody > tr > th {
    border-color: var(--sp-border) !important;
    color: var(--sp-text) !important;
    background: transparent;
  }
  html:not(.sp-cards) .table-striped > tbody > tr:nth-of-type(odd) {
    background: color-mix(in srgb, var(--sp-text) 4%, var(--sp-card)) !important;
  }
  html:not(.sp-cards) .table-bordered,
  html:not(.sp-cards) .table-bordered > tbody > tr > td,
  html:not(.sp-cards) .table-bordered > thead > tr > th {
    border-color: var(--sp-border) !important;
  }
  html:not(.sp-cards) .table > tbody > tr:hover { background: color-mix(in srgb, var(--sp-accent) 6%, var(--sp-card)) !important; }

  /* Small utility tables on card pages stay tables, just recolored */
  html.sp-cards .table-nonfluid { background: var(--sp-card); border-radius: 12px; }
  html.sp-cards .table-nonfluid th, html.sp-cards .table-nonfluid td {
    border-color: var(--sp-border) !important; color: var(--sp-text) !important;
  }

  /* ============ Mein Unterricht: table -> cards ============ */
  html.sp-cards table.table:not(.table-nonfluid) thead { display: none; }
  html.sp-cards table.table:not(.table-nonfluid),
  html.sp-cards table.table:not(.table-nonfluid) > tbody { display: block; width: 100%; border: none !important; }
  html.sp-cards table.table:not(.table-nonfluid) > tbody > tr {
    display: block;
    background: var(--sp-card) !important;
    border: 1px solid var(--sp-border);
    border-radius: 16px;
    margin: 12px 0;
    padding: 14px 14px 10px;
    box-shadow: var(--sp-shadow);
  }
  html.sp-cards table.table:not(.table-nonfluid) > tbody > tr > td {
    display: block;
    width: auto !important;
    border: none !important;
    padding: 2px 0 !important;
    background: transparent !important;
    color: var(--sp-text) !important;
  }
  html.sp-cards .table td h3 { font-size: 17px !important; line-height: 1.3; display: inline; }
  html.sp-cards .table td h3 a { color: var(--sp-text) !important; text-decoration: none; font-weight: 700; }
  html.sp-cards .table td h3 .fa-address-book { color: var(--sp-accent); margin-right: 2px; }
  html.sp-cards .teacher .btn { border-radius: 999px !important; }
  html.sp-cards .table .printable.btn { display: none; }   /* print button is useless on a phone */
  html.sp-cards b.thema { font-size: 15px; font-weight: 600; color: var(--sp-text) !important; }
  html.sp-cards span.datum { color: var(--sp-text2) !important; font-size: 13px; }
  html.sp-cards .btn.showInhalt {
    background: transparent !important; border: none !important;
    color: var(--sp-accent) !important; box-shadow: none !important; padding: 0 6px !important;
  }
  html.sp-cards .inhalt {
    background: var(--sp-bg); border-radius: 10px; padding: 10px !important;
    margin: 6px 0; font-size: 14px; color: var(--sp-text) !important;
  }
  html.sp-cards .homework { margin-top: 8px; }
  html.sp-cards .homework .label { font-size: 12px; font-weight: 600; padding: 3px 8px; }
  html.sp-cards .homework .label-success { background: var(--sp-green) !important; }
  html.sp-cards .homework .done.label-warning { background: var(--sp-orange) !important; }
  html.sp-cards .homework .done.label-success { background: var(--sp-green) !important; }
  html.sp-cards .homework .realHomework {
    border: none !important;
    background: color-mix(in srgb, var(--sp-green) 12%, var(--sp-card)) !important;
    border-left: 3px solid var(--sp-green) !important;
    border-radius: 0 10px 10px 10px !important;
    padding: 10px !important;
    margin-top: 2px;
    font-size: 14.5px; line-height: 1.45;
    color: var(--sp-text) !important;
  }
  html.sp-cards .table td > a.btn.btn-primary {
    display: block; width: 100%; text-align: center;
    background: var(--sp-accent) !important; border: none !important;
    border-radius: 12px !important; padding: 10px !important;
    font-size: 15px; font-weight: 600; margin-top: 8px;
  }
  html.sp-cards .table td > br { display: none; }

  /* ============ Start page (index.php) ============ */
  .sp-index .box, .sp-start .box {
    border-radius: 16px !important;
    overflow: hidden;
    box-shadow: var(--sp-shadow) !important;
    border: none !important;
    margin-bottom: 12px;
  }
  .sp-index .preshow, .sp-start .preshow { font-size: 13px; }

  /* ============ Stundenplan ============ */
  .sp-stundenplan .stunde {
    background: color-mix(in srgb, var(--sp-accent) 10%, var(--sp-card));
    border: 1px solid var(--sp-border);
    border-radius: 8px;
    padding: 3px 4px;
    margin: 2px 0;
    font-size: 12px;
  }
  .sp-stundenplan .table td { vertical-align: middle !important; }
  .sp-stundenplan .VonBis { color: var(--sp-text2); }

  /* ============ Kalender (FullCalendar) ============ */
  .sp-kalender .fc {
    background: var(--sp-card);
    border-radius: 14px;
    padding: 8px;
    box-shadow: var(--sp-shadow);
    color: var(--sp-text);
  }
  .sp-kalender .fc th, .sp-kalender .fc td { border-color: var(--sp-border) !important; }
  .sp-kalender .fc-toolbar h2 { font-size: 17px !important; }
  .sp-kalender .fc button {
    background: var(--sp-card); color: var(--sp-text);
    border: 1px solid var(--sp-border); border-radius: 8px;
    box-shadow: none; text-shadow: none;
  }
  .sp-kalender .fc button.fc-state-active { background: var(--sp-accent); color: #fff; }
  .sp-kalender .fc-unthemed td.fc-today { background: color-mix(in srgb, var(--sp-accent) 12%, var(--sp-card)) !important; }
  .sp-kalender .fc-event { border-radius: 6px; border: none; padding: 1px 3px; }

  /* ============ Nachrichten ============ */
  .sp-nachrichten .msgBox {
    border-radius: 16px !important;
    box-shadow: var(--sp-shadow);
    border: 1px solid var(--sp-border) !important;
    background: var(--sp-card) !important;
  }
  .sp-nachrichten .btn-toolbar .btn { border-radius: 10px !important; }

  /* ============ Mein Unterricht: subject chips + homework digest ============ */
  .sp-code { color: var(--sp-text2); font-weight: 600; font-size: 12px; margin-left: 6px; }
  .sp-chip {
    display: inline-block; color: #fff; font-size: 12px; font-weight: 700;
    padding: 2px 10px; border-radius: 999px; vertical-align: 2px;
  }
  .sp-hw-digest {
    background: var(--sp-card);
    border: 1px solid var(--sp-border);
    border-radius: 16px;
    padding: 14px;
    margin: 12px 0;
    box-shadow: var(--sp-shadow);
  }
  .sp-hw-title { font-weight: 700; font-size: 17px; margin-bottom: 4px; }
  .sp-hw-note { font-size: 12px; color: var(--sp-text2); margin-bottom: 6px; }
  .sp-hw-item { padding: 10px 0 8px; border-top: 1px solid var(--sp-border); cursor: pointer; }
  .sp-hw-head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 4px; }
  .sp-hw-date { color: var(--sp-text2); font-size: 12px; }
  .sp-hw-text { font-size: 14px; line-height: 1.4; color: var(--sp-text); white-space: pre-line; }

  /* Footer */
  #content + div, body > table:last-of-type { opacity: 0.6; }
  `;

  const style = document.createElement('style');
  style.id = 'sp-mobile-restyle';
  style.textContent = css;
  document.head.appendChild(style);

  // Non-card pages: wrap data tables in a rounded, horizontally scrollable card.
  // (Timetable grids stay grids — on a phone you swipe them sideways.)
  const wrapTables = () => {
    const sel = root.classList.contains('sp-cards')
      ? '#content table.table-nonfluid'
      : '#content table.table';
    document.querySelectorAll(sel).forEach(t => {
      if (t.closest('.fc') || t.closest('.sp-scroll') || t.closest('.fixed-table-container')) return;
      const w = document.createElement('div');
      w.className = 'sp-scroll';
      t.parentNode.insertBefore(w, t);
      w.appendChild(t);
    });
  };
  wrapTables();

  // ============ Mein Unterricht extras ============
  if (pageName === 'meinunterricht') {
    // Tap the topic line to expand the hidden lesson details.
    document.querySelectorAll('b.thema').forEach(t => {
      const inhalt = t.parentElement.querySelector('.inhalt');
      if (inhalt) {
        t.style.cursor = 'pointer';
        t.addEventListener('click', () => {
          inhalt.style.display = inhalt.style.display === 'none' ? 'block' : 'none';
        });
      }
    });

    // Hessen course-code -> full subject name.
    const SUBJECTS = {
      D: 'Deutsch', E: 'Englisch', M: 'Mathematik', DW: 'Digitale Welt',
      MU: 'Musik', KU: 'Kunst', GEO: 'Erdkunde', EK: 'Erdkunde',
      ETHI: 'Ethik', ETH: 'Ethik', NAWI: 'Naturwissenschaften',
      SPO: 'Sport', SPORT: 'Sport', TUT: 'Tutorenstunde',
      REV: 'Religion (ev.)', RKA: 'Religion (kath.)', REL: 'Religion',
      BIO: 'Biologie', PH: 'Physik', CH: 'Chemie', G: 'Geschichte',
      POWI: 'Politik & Wirtschaft', F: 'Französisch', L: 'Latein',
      SPA: 'Spanisch', INFO: 'Informatik', IT: 'Informatik',
      DS: 'Darstellendes Spiel', GL: 'Gesellschaftslehre', AL: 'Arbeitslehre'
    };
    const CHIP_COLORS = {
      Deutsch: '#d70015', 'Englisch': '#248a3d', Mathematik: '#0040dd',
      'Digitale Welt': '#5856d6', Naturwissenschaften: '#0071a4',
      Erdkunde: '#a2845e', Kunst: '#c93400', Musik: '#c11f6a',
      Sport: '#008577', Ethik: '#6c6c70', Tutorenstunde: '#3634a3',
      'Religion (ev.)': '#8944ab', 'Religion (kath.)': '#8944ab',
      Geschichte: '#7d5a3c', Biologie: '#2d7d46', Physik: '#005ea3', Chemie: '#9f1d63'
    };
    const subjectOf = (courseName) => {
      const mm = courseName.match(/^([A-ZÄÖÜa-z]{1,6})\s+\S/);
      return (mm && SUBJECTS[mm[1].toUpperCase()]) || null;
    };
    const chipColor = (subject) => CHIP_COLORS[subject] ||
      'hsl(' + ([...subject].reduce((a, c) => a + c.charCodeAt(0), 0) % 360) + ',65%,38%)';

    // Build one "open homework" digest per course table, BEFORE renaming titles.
    document.querySelectorAll('table.table:not(.table-nonfluid)').forEach(table => {
      const items = [];
      table.querySelectorAll('tr[data-book]').forEach(row => {
        const nameEl = row.querySelector('.name');
        if (!nameEl) return;
        const courseName = nameEl.textContent.trim();
        const subject = subjectOf(courseName) || courseName.split(',')[0];
        const date = (row.querySelector('span.datum') || {}).textContent || '';
        row.querySelectorAll('.homework').forEach(hw => {
          const done = hw.querySelector('.done');
          const text = hw.querySelector('.realHomework');
          if (!text || !done || !/offen/i.test(done.textContent)) return;
          items.push({ subject, date: date.trim(), text: text.innerText.trim(), row });
        });
      });
      if (!items.length) return;

      const parseDate = (s) => {
        const p = s.match(/(\d{2})\.(\d{2})\.(\d{4})/);
        return p ? new Date(p[3], p[2] - 1, p[1]).getTime() : 0;
      };
      items.sort((a, b) => parseDate(a.date) - parseDate(b.date));

      const digest = document.createElement('div');
      digest.className = 'sp-hw-digest';
      const title = document.createElement('div');
      title.className = 'sp-hw-title';
      title.textContent = '\u{1F4DA} Offene Hausaufgaben (' + items.length + ')';
      digest.appendChild(title);
      const note = document.createElement('div');
      note.className = 'sp-hw-note';
      note.textContent = 'Datum = Stunde, in der sie aufgegeben wurde. Antippen springt zum Kurs.';
      digest.appendChild(note);
      items.forEach(it => {
        const item = document.createElement('div');
        item.className = 'sp-hw-item';
        const head = document.createElement('div');
        head.className = 'sp-hw-head';
        const chip = document.createElement('span');
        chip.className = 'sp-chip';
        chip.style.background = chipColor(it.subject);
        chip.textContent = it.subject;
        const d = document.createElement('span');
        d.className = 'sp-hw-date';
        d.textContent = it.date;
        head.append(chip, d);
        const txt = document.createElement('div');
        txt.className = 'sp-hw-text';
        txt.textContent = it.text;
        item.append(head, txt);
        item.addEventListener('click', () => it.row.scrollIntoView({ behavior: 'smooth', block: 'start' }));
        digest.appendChild(item);
      });
      table.parentNode.insertBefore(digest, table);
    });

    // Rewrite course titles: full subject name big, original code small; add subject chip.
    document.querySelectorAll('tr[data-book] .name').forEach(n => {
      const orig = n.textContent.trim();
      const subject = subjectOf(orig);
      if (!subject) return;
      n.textContent = subject;
      const sm = document.createElement('small');
      sm.className = 'sp-code';
      sm.textContent = orig;
      n.appendChild(sm);
    });
  }
})();
