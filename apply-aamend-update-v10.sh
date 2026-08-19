#!/usr/bin/env bash
set -euo pipefail

# apply-aamend-update-v10.sh
# Run this from inside your local "aamend" repo checkout, e.g.:
#   cd ~/Desktop/aamend   (or wherever you cloned it)
#   chmod +x apply-aamend-update-v10.sh
#   ./apply-aamend-update-v10.sh
#
# What this does:
#  - Admin "-" button: removed the redundant client-side password prompt,
#    now goes straight to the admin tool's real (server-side) login screen
#  - Pics page: split-flap caption now overlays near the bottom of the photo
#    itself (was previously below the fold, invisible without scrolling)
#  - Pics page on computer screens (wider than 700px): the slideshow is now
#    cropped into the screen of a real iPhone photo -- looks like you're
#    browsing the photos on a phone. Phone screens: unchanged, full-screen.

if [ ! -f server.js ] || [ ! -d img ]; then
  echo "This does not look like the aamend repo root (no server.js / img/ found)."
  echo "cd into your aamend checkout first, then re-run this script."
  exit 1
fi

echo "Writing updated files..."

mkdir -p "$(dirname "index.html")"
cat > 'index.html' <<'__AAMEND_V10_EOF_index_html__'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Amend</title>
<meta name="description" content="Aaron Amend is an architect based in Paris, currently at Plan Común. Selected projects, thesis work, and professional practice.">
<meta property="og:title" content="Aaron Amend — Architect">
<meta property="og:description" content="Selected architecture projects and practice, based in Paris.">
<meta property="og:type" content="website">
<meta property="og:image" content="img/capella004.jpg">
<meta name="theme-color" content="#ffffff">
<style>
  @font-face {
    font-family: 'Waldenburg';
    src: url('assets/fonts/Waldenburg-Regular.woff2') format('woff2');
    font-weight: 400;
    font-style: normal;
    font-display: swap;
  }
  @font-face {
    font-family: 'Waldenburg';
    src: url('assets/fonts/Waldenburg-Bold.woff2') format('woff2');
    font-weight: 700;
    font-style: normal;
    font-display: swap;
  }

  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  :root {
    --black: #1a1a1a;
    --gray: rgba(0,0,0,0.5);
    --font: 'Waldenburg', -apple-system, BlinkMacSystemFont, 'Helvetica Neue', Arial, sans-serif;
    --ink: rgba(0,0,0,0.85);
  }

  html { font-size: 16px; scroll-behavior: smooth; }

  /* ── CURSOR: custom arrow by default, native hand pointer over clickable elements ── */
  body {
    cursor: url('assets/cursor-arrow.svg') 3 0, auto;
  }

  a, .project-item, .slide-arrow, button, #page-pics .slide-track {
    cursor: url('assets/cursor-hand.png') 12 2, pointer;
  }

  /* CV/about page: cursor is the speaker image everywhere on the page, not the hand pointer */
  #cv-page, #cv-page a, #cv-page button,
  #cv-footer, #cv-footer a, #cv-footer button {
    cursor: url('assets/cursor-box.png') 64 64, auto;
  }

  body {
    background: #fff;
    color: var(--ink);
    font-family: var(--font);
    font-weight: 400;
    overflow-x: hidden;
  }

  /* ── NAV ── */
  nav {
    position: fixed;
    top: 0; left: 0; right: 0;
    z-index: 100;
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    padding: 2rem 2.5rem;
    pointer-events: none;
  }

  nav a {
    pointer-events: all;
    text-decoration: none;
    color: var(--ink);
    font-size: 2.6rem;
    font-weight: 400;
    opacity: 0.75;
    transition: opacity 0.15s;
    line-height: 1;
  }

  nav a:hover { opacity: 1; }

  /* ── SCROLL ARROW ── */
  #scroll-arrow {
    position: fixed;
    bottom: 2rem;
    left: 50%;
    transform: translateX(-50%);
    font-size: 1rem;
    color: var(--gray);
    pointer-events: none;
    z-index: 50;
    transition: opacity 0.4s;
    animation: bob 2s ease-in-out infinite;
  }

  @keyframes bob {
    0%, 100% { transform: translateX(-50%) translateY(0); }
    50%       { transform: translateX(-50%) translateY(6px); }
  }

  /* ── HOME ── */
  #home {
    position: relative;
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    align-items: center;
    padding-top: 22vh;
  }

  /* Name: two identical <h1>s stacked exactly on top of each other.
     .name-base is always fully rendered (dark on white) -- it never
     disappears, full stop. .name-invert is a white copy of the exact same
     text, clipped (via clip-path, kept in sync with the circle's position
     every animation frame in JS) to a circle matching the black backdrop
     -- so it only shows, in white, in the precise region where the circle
     currently overlaps the name. No blend-mode trickery, so it holds up
     at any zoom level. */
  .name-wrap {
    position: relative;
    margin-bottom: 8vh;
  }

  #home h1 {
    font-size: clamp(2.4rem, 4.6vw, 5.4rem);
    font-weight: 400;
    letter-spacing: 0.02em;
    text-align: center;
    margin: 0;
  }

  .name-base { color: rgba(0,0,0,0.88); }

  .name-invert {
    position: absolute;
    top: 0; left: 0; right: 0;
    color: #fff;
    clip-path: circle(0px at 50% 0%);
    pointer-events: none;
  }

  /* ── CIRCLE BACKDROP: hidden above the screen on load, slides down as you
     scroll -- timed (in JS) so it exits the bottom edge exactly when you
     reach the footer, never before. Position is fully driven by the JS
     transform below; `top: 0` is just the reference line it measures from. ── */
  #circle-backdrop {
    position: fixed;
    top: 0;
    left: 50%;
    width: min(58vw, 760px);
    height: min(58vw, 760px);
    border-radius: 50%;
    background: #0a0a0a;
    transform: translate(-50%, -100vh);
    z-index: -1;
    pointer-events: none;
    opacity: 0;
    transition: opacity 0.6s ease;
  }

  #home.circle-ready #circle-backdrop { opacity: 1; }

  .projects-feed {
    width: 100%;
    max-width: 1800px;
    padding: 0 2.5rem;
    display: flex;
    flex-direction: column;
    align-items: center;
  }

  .project-item {
    display: flex;
    flex-direction: column;
    align-items: center;
  }

  .project-item img,
  .project-item video {
    display: block;
    margin: 0 auto;
  }

  @media (max-width: 700px) {
    .project-item img, .project-item video {
      width: 82vw !important;
      max-width: 82vw !important;
    }
  }

  /* ── FOOTER (black, shared across home / project / CV pages) ── */
  .bottom-nav {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2rem;
    padding: 5rem 0 6rem;
    width: 100%;
    background: #0a0a0a;
    margin-top: 4rem;
  }

  .bottom-nav a {
    font-size: 0.8rem;
    letter-spacing: 0.15rem;
    text-transform: uppercase;
    color: rgba(255,255,255,0.5);
    text-decoration: none;
    transition: color 0.15s;
  }

  .bottom-nav a:hover { color: rgba(255,255,255,0.95); }

  .bottom-nav .email-link {
    font-size: 1.3rem;
    letter-spacing: 0.1rem;
    text-transform: none;
    color: rgba(255,255,255,0.92);
  }

  .bottom-nav .footer-arrow {
    color: rgba(255,255,255,0.45);
    font-size: 1rem;
    line-height: 1;
  }

  /* project-meta is already black -- butt it straight up against the
     footer instead of leaving a white gap between two black blocks */
  .project-meta + .bottom-nav { margin-top: 0; padding-top: 3rem; }

  /* ── PROJECT PAGE: fullscreen slideshow, one image at a time ── */
  .page {
    display: none;
    min-height: 100vh;
  }

  #page-globe { background: #0a0a0a; }
  body.globe-active nav a { color: #fff; }

  #page-pics { background: #0a0a0a; }
  body.pics-active nav a { color: #fff; }

  /* ── Pics: split-flap metadata board, overlaid near the bottom of the
     photo itself so it's visible immediately -- no scrolling needed. ── */
  .pics-meta {
    position: absolute;
    left: 0;
    right: 0;
    bottom: 5%;
    z-index: 5;
    display: flex;
    justify-content: center;
    align-items: center;
    flex-wrap: wrap;
    gap: 0.16rem;
    padding: 0.6rem 1rem;
    min-height: 1.9rem;
    pointer-events: none;
    user-select: none;
  }

  .pics-meta .flap {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 0.92em;
    height: 1.3em;
    font-family: 'Courier New', monospace;
    font-size: 0.78rem;
    letter-spacing: 0;
    text-transform: uppercase;
    color: rgba(255,255,255,0.85);
    background: rgba(0,0,0,0.55);
    border: 1px solid rgba(255,255,255,0.18);
    border-radius: 2px;
  }

  .page.active { display: flex; flex-direction: column; }

  #globe-canvas-wrap {
    width: 100%;
    height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: grab;
    touch-action: none;
  }
  #globe-canvas-wrap:active { cursor: grabbing; }
  #globe-svg {
    width: min(88vw, 88vh);
    height: min(88vw, 88vh);
    display: block;
  }
  #globe-svg .globe-dot { fill: #f2f2f2; }
  #globe-svg .globe-marker { cursor: pointer; }

  #pics-lightbox {
    display: none;
    position: fixed;
    inset: 0;
    z-index: 300;
    background: rgba(10,10,10,0.92);
    align-items: center;
    justify-content: center;
  }
  #pics-lightbox img {
    max-width: 90vw;
    max-height: 88vh;
    object-fit: contain;
  }
  #pics-lightbox-close {
    position: fixed;
    top: 1.5rem;
    right: 2rem;
    color: #fff;
    font-size: 2.5rem;
    font-weight: 300;
    opacity: 0.7;
    line-height: 1;
  }
  #pics-lightbox-close:hover { opacity: 1; }

  .slideshow {
    position: relative;
    width: 100%;
    height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
  }

  .slide-track { width: 100%; height: 100%; display: flex; align-items: center; justify-content: center; }

  .slide-track img,
  .slide-track video {
    display: none;
    max-width: 92vw;
    max-height: 92vh;
    width: auto;
    height: auto;
    object-fit: contain;
  }

  .slide-track img.active,
  .slide-track video.active { display: block; }

  /* Pics page: photos shown ~30% smaller than the default slideshow sizing above */
  #pics-slide-track img {
    max-width: 64vw;
    max-height: 64vh;
  }

  /* ── Pics page on computer screens: show the slideshow cropped into the
     screen of a real iPhone photo, so it looks like you're browsing the
     photos on a phone. Phone image + crop percentages are keyed to the
     device photo's exact pixel geometry (791x1600 source; screen area is
     the box from 55,140 to 735,1370 within that image). Below the 700px
     breakpoint (phones) this whole treatment is skipped -- the slideshow
     just fills the screen as it always did, since on an actual phone
     you're already looking at the photos "on your phone". ── */
  #pics-phone-img { display: none; }

  @media (min-width: 701px) {
    #page-pics {
      position: relative;
      --phone-h: min(88vh, 900px);
      --phone-w: calc(var(--phone-h) * 791 / 1600);
      --phone-top: max(4vh, 24px);
      --phone-left: calc(50% - var(--phone-w) / 2);
    }
    #pics-phone-img {
      display: block;
      position: absolute;
      left: var(--phone-left);
      top: var(--phone-top);
      width: var(--phone-w);
      height: var(--phone-h);
      z-index: 1;
      pointer-events: none;
      user-select: none;
    }
    #page-pics .slideshow {
      position: absolute;
      left: calc(var(--phone-left) + var(--phone-w) * 0.06953);
      top: calc(var(--phone-top) + var(--phone-h) * 0.0875);
      width: calc(var(--phone-w) * (1 - 0.06953 - 0.07079));
      height: calc(var(--phone-h) * (1 - 0.0875 - 0.14375));
      z-index: 2;
      background: #000;
      border-radius: 8px;
      overflow: hidden;
    }
    #pics-slide-track img {
      max-width: 100%;
      max-height: 100%;
    }
    #page-pics .bottom-nav {
      position: relative;
      z-index: 3;
      margin-top: calc(var(--phone-top) + var(--phone-h) + 4vh);
    }
  }

  .slide-arrow {
    position: absolute;
    top: 50%;
    transform: translateY(-50%);
    background: none;
    border: none;
    font-size: 2.2rem;
    font-family: var(--font);
    color: var(--black);
    opacity: 0.3;
    padding: 1.2rem 1.6rem;
    transition: opacity 0.15s;
    z-index: 10;
    line-height: 1;
  }

  .slide-arrow:hover { opacity: 0.9; }
  .slide-arrow.prev { left: 0.5rem; }
  .slide-arrow.next { right: 0.5rem; }

  .page[data-single="true"] .slide-arrow { display: none; }

  /* ── PROJECT META (2-column info block below slideshow) ──
     Black, full-bleed, same tone as the bottom-nav footer -- every
     project page reads as "images, then a black block" the way the
     print portfolio's black title pages do. ── */
  .project-meta {
    position: relative;
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 2.5rem;
    max-width: 1400px;
    margin: 0 auto;
    padding: 4rem 2.5rem;
    font-size: 0.95rem;
    line-height: 1.75;
    color: rgba(255,255,255,0.6);
    text-align: left;
  }

  .project-meta::before {
    content: "";
    position: absolute;
    top: 0; bottom: 0;
    left: 50%;
    width: 100vw;
    transform: translateX(-50%);
    background: #0a0a0a;
    z-index: -1;
  }

  .project-meta strong { font-weight: 700; color: rgba(255,255,255,0.95); }

  @media (max-width: 700px) {
    .project-meta { grid-template-columns: 1fr; gap: 1.25rem; padding: 2rem 1.5rem 4rem; }
  }

  /* ── CV PAGE ── */
  #cv-page {
    display: none;
    min-height: 100vh;
    padding: 8rem 2.5rem 6rem;
    max-width: 1040px;
    margin: 0 auto;
  }

  #cv-page.active { display: block; }

  #cv-page h2 {
    font-size: clamp(2rem, 6vw, 4rem);
    font-weight: 400;
    margin-bottom: 5rem;
  }

  .cv-text {
    font-size: 1.05rem;
    line-height: 1.85;
    color: rgba(0,0,0,0.42);
    margin-bottom: 1.75rem;
  }

  .cv-text strong { font-weight: 700; color: rgba(0,0,0,0.92); }

  .cv-section { margin-bottom: 1.75rem; }

  .cv-section .date {
    font-family: 'Courier New', monospace;
    font-size: 0.72rem;
    color: var(--gray);
    margin-bottom: 0.2rem;
  }

  .cv-section .place {
    font-size: 0.9rem;
    margin-bottom: 0.1rem;
  }

  .cv-section .location {
    font-family: 'Courier New', monospace;
    font-size: 0.72rem;
    color: var(--gray);
  }

  .cv-divider {
    height: 1px;
    background: rgba(0,0,0,0.08);
    margin: 2.5rem 0;
  }

  /* fade-in on scroll (home only) */
  .project-item {
    opacity: 0; transform: translateY(14px); transition: opacity .6s ease, transform .6s ease;
  }
  .project-item.in-view {
    opacity: 1; transform: translateY(0);
  }
</style>
</head>
<body>

<nav>
  <a id="nav-admin" onclick="openAdminGate()">−</a>
  <a id="nav-back" onclick="goHome()" style="display:none">−</a>
  <div style="flex:1"></div>
  <a id="nav-cv" onclick="showCV()">+</a>
</nav>

<div id="scroll-arrow">↓</div>

<!-- HOME -->
<div id="home">
  <div id="circle-backdrop" aria-hidden="true"></div>
  <div class="name-wrap">
    <h1 class="name-base">Aaron Amend</h1>
    <h1 class="name-invert" aria-hidden="true">Aaron Amend</h1>
  </div>

  <div class="projects-feed">

    <div class="project-item" onclick="showProject('page-project10')">
      <img src="img/python-3.png" alt="" style="width:27.72vw;max-width:499px;" loading="lazy">
    </div>
    <div style="height:9vh;width:100%"></div>

    <div class="project-item" onclick="showProject('page-pfe')">
      <img src="img/capella004.jpg" alt="" style="width:23.89vw;max-width:430px;" loading="lazy">
    </div>
    <div style="height:9vh;width:100%"></div>

    <div class="project-item" onclick="showProject('page-project11')">
      <img src="img/chartreuse_gif_01.gif" alt="" style="width:15.28vw;max-width:275px;" loading="lazy">
    </div>
    <div style="height:9vh;width:100%"></div>

    <div class="project-item" onclick="showProject('page-project6')">
      <img src="img/scheune_0.jpg" alt="" style="width:26.78vw;max-width:482px;" loading="lazy">
    </div>
    <div style="height:9vh;width:100%"></div>

    <div class="project-item" onclick="showProject('page-project9')">
      <img src="img/IMG_1359-3.png" alt="" style="width:23.89vw;max-width:430px;" loading="lazy">
    </div>
    <div style="height:9vh;width:100%"></div>

    <div class="project-item" onclick="showProject('page-project1')">
      <img src="img/Entwurf_Beten_Perspektiven__02.png" alt="" style="width:29.61vw;max-width:533px;" loading="lazy">
    </div>
    <div style="height:9vh;width:100%"></div>

    <div class="project-item" onclick="showProject('page-roubaix')">
      <img src="img/roubaix-out.jpg" alt="" style="width:29.61vw;max-width:533px;" loading="lazy">
    </div>
    <div style="height:9vh;width:100%"></div>

    <div class="project-item" onclick="showProject('page-project9')">
      <img src="img/gifquick.gif" alt="" style="width:25.78vw;max-width:464px;" loading="lazy">
    </div>
    <div style="height:9vh;width:100%"></div>

    <div class="project-item" onclick="showProject('page-project7')">
      <img src="img/st_24_1.jpeg" alt="" style="width:27.72vw;max-width:499px;" loading="lazy">
    </div>
    <div style="height:9vh;width:100%"></div>

    <div class="project-item" onclick="showProject('page-project4')">
      <img src="img/Groninger_Hof_Amend-Henschel-Mank_210712_2_verschoben_3.png" alt="" style="width:31.5vw;max-width:567px;" loading="lazy">
    </div>
    <div style="height:9vh;width:100%"></div>

    <div class="project-item" onclick="showProject('page-project2')">
      <img src="img/rendu1.jpeg" alt="" style="width:29.61vw;max-width:533px;" loading="lazy">
      <div style="height:9vh;width:100%"></div>
      <img src="img/PerspektiveAu_en_3KM.png" alt="" style="width:44.89vw;max-width:808px;" loading="lazy">
    </div>
    <div style="height:9vh;width:100%"></div>

    <div class="project-item" onclick="showProject('page-project8')">
      <img src="img/Bildschirmfoto-2024-09-11-um-13.34.53.jpeg" alt="" style="width:30.56vw;max-width:550px;" loading="lazy">
    </div>
    <div style="height:9vh;width:100%"></div>

  </div>

  <div class="bottom-nav">
    <a class="email-link" href="mailto:aaron.amend@icloud.com">Email</a>
    <div class="footer-arrow">↓</div>
    <a onclick="showPicsSlideshow()">Pics</a>
  </div>
</div>

<!-- CV -->
<div id="cv-page">
  <h2>about</h2>

  <p class="cv-text">Aaron Amend is an architect based in Paris, currently collaborating with <strong>Plan Común</strong>. Previously he has worked at <strong>Nicolas Dorval-Bory Architectes</strong> in Paris, <strong>Bangkok Tokyo Architecture</strong> in Bangkok, and <strong>tiburg Architekten</strong> in Vienna.</p>

  <p class="cv-text">He completed his Master of Architecture at the <strong>École Nationale Supérieure d'Architecture de Paris-Belleville</strong>, with a semester at the <strong>NTUT Taipei</strong>, after graduating with a Bachelor of Architecture from <strong>Bauhaus-Universität Weimar</strong> and an exchange semester at the <strong>TU Vienna</strong>.</p>

  <div class="cv-divider"></div>

  <div class="cv-section" style="font-family:'Courier New',monospace;font-size:0.78rem;line-height:1.9;color:var(--gray)">
    German, English and French, (Japanese A2)<br><br>
    ARCHICAD (Drawing + BIM Modelling)<br>
    AUTOCAD<br>
    REVIT<br>
    QGIS (Geoinformation and Analytics Software)<br><br>
    CINEMA4D (+CORONA RENDER PLUGIN)<br>
    BLENDER (RENDERING + ANIMATION)<br>
    RHINO (+Grasshopper)<br><br>
    Adobe Suite<br><br>
    Nano Banana Ai Imaging<br>
    Claude Ai coding and analysis<br><br>
    Final Cut (Video)<br>
    Ableton Live (Sound)
  </div>

  <div class="cv-divider"></div>

  <div class="cv-section">
    <div class="place" style="font-size:0.85rem">aaron.amend@icloud.com</div>
    <div class="location">+49 (0) 17631300747</div>
    <div class="location">+33 (0) 749176753</div>
  </div>
</div>

<div id="cv-footer" class="bottom-nav" style="display:none;width:100vw;margin-left:calc(50% - 50vw);margin-right:calc(50% - 50vw);">
  <a class="email-link" href="mailto:aaron.amend@icloud.com">Email</a>
  <div class="footer-arrow">↓</div>
  <a onclick="showPicsSlideshow()">Pics</a>
</div>

<!-- PROJECT PAGES -->

<div id="page-project10" class="page">
  <div class="slideshow" data-count="3">
    <div class="slide-track">
    <img src="img/paython-drawing-2.jpg" alt="">
    <img src="img/paythd2.jpg" alt="">
    <img src="img/pyth3.jpg" alt="">
    </div>
    <button class="slide-arrow prev" onclick="stepSlide(-1)">&#8249;</button>
    <button class="slide-arrow next" onclick="stepSlide(1)">&#8250;</button>
  </div>
    <div class="project-meta">
    <div class="meta-col"></div><div class="meta-col"></div>
  </div>
<div class="bottom-nav">
    <a class="email-link" href="mailto:aaron.amend@icloud.com">Email</a>
    <div class="footer-arrow">↓</div>
    <a onclick="showPicsSlideshow()">Pics</a>
  </div>
</div>

<div id="page-pfe" class="page">
  <div class="slideshow" data-count="15">
    <div class="slide-track">
    <img src="img/capella004.jpg" alt="">
    <img src="img/capella005.jpg" alt="">
    <img src="img/palimsest_nolli.jpg" alt="">
    <img src="img/axes_dB_Map.jpg" alt="">
    <img src="img/capella003.jpg" alt="">
    <img src="img/capella002.jpg" alt="">
    <img src="img/0016.jpg" alt="">
    <img src="img/capella001.jpg" alt="">
    <img src="img/0020.jpg" alt="">
    <img src="img/Modell_1_100.jpg" alt="">
    <img src="img/IMG_51.jpg" alt="">
    <img src="img/0017.jpg" alt="">
    <img src="img/0013.jpg" alt="">
    <img src="img/0002.jpg" alt="">
    <img src="img/0007.jpg" alt="">
    </div>
    <button class="slide-arrow prev" onclick="stepSlide(-1)">&#8249;</button>
    <button class="slide-arrow next" onclick="stepSlide(1)">&#8250;</button>
  </div>
  <div class="project-meta">
    <div class="meta-col">Projet Finale Étude<br><br>ENSA Belleville Paris<br><br>with Diego Kühle</div><div class="meta-col"><strong></strong>Capella: une plateforme pour la musique et la <br>communauté à La Chapelle<strong></strong></div>
  </div>
  <div class="bottom-nav">
    <a class="email-link" href="mailto:aaron.amend@icloud.com">Email</a>
    <div class="footer-arrow">↓</div>
    <a onclick="showPicsSlideshow()">Pics</a>
  </div>
</div>

<div id="page-project11" class="page">
  <div class="slideshow" data-count="6">
    <div class="slide-track">
    <img src="img/abbruch.jpg" alt="">
    <img src="img/done.jpg" alt="">
    <img src="img/Axo2.jpg" alt="">
    <img src="img/Axo1.jpg" alt="">
    <img src="img/section.jpg" alt="">
    <img src="img/Chartreuse-3-pics.jpg" alt="">
    </div>
    <button class="slide-arrow prev" onclick="stepSlide(-1)">&#8249;</button>
    <button class="slide-arrow next" onclick="stepSlide(1)">&#8250;</button>
  </div>
    <div class="project-meta">
    <div class="meta-col"></div><div class="meta-col"></div>
  </div>
<div class="bottom-nav">
    <a class="email-link" href="mailto:aaron.amend@icloud.com">Email</a>
    <div class="footer-arrow">↓</div>
    <a onclick="showPicsSlideshow()">Pics</a>
  </div>
</div>

<div id="page-project6" class="page">
  <div class="slideshow" data-count="7">
    <div class="slide-track">
    <img src="img/Endprasentation_verschoben_3.png" alt="">
    <img src="img/Endprasentation_verschoben_7.png" alt="">
    <img src="img/Endprasentation_verschoben_4.png" alt="">
    <img src="img/Endprasentation_verschoben_6.jpg" alt="">
    <img src="img/Endprasentation_verschoben.png" alt="">
    <img src="img/Endprasentation_verschoben_2.png" alt="">
    <img src="img/Endprasentation_verschoben_5.png" alt="">
    </div>
    <button class="slide-arrow prev" onclick="stepSlide(-1)">&#8249;</button>
    <button class="slide-arrow next" onclick="stepSlide(1)">&#8250;</button>
  </div>
  <div class="project-meta">
    <div class="meta-col">Bachelor Thesis<br><br><strong>Designing and Housing Construction Studio<br><br>Bauahus Universität Weimar<br><br></strong>Prof. Verena von Beckerath</div><div class="meta-col">Transformation of Two Barns<br>Atelier and Student housing</div>
  </div>
  <div class="bottom-nav">
    <a class="email-link" href="mailto:aaron.amend@icloud.com">Email</a>
    <div class="footer-arrow">↓</div>
    <a onclick="showPicsSlideshow()">Pics</a>
  </div>
</div>

<div id="page-project9" class="page">
  <div class="slideshow" data-count="6">
    <div class="slide-track">
    <img src="img/gifquick.gif" alt="">
    <img src="img/martel2.jpg" alt="">
    <img src="img/martel1.jpg" alt="">
    <img src="img/martel.jpg" alt="">
    <img src="img/pic.jpg" alt="">
    <img src="img/pic3.jpg" alt="">
    </div>
    <button class="slide-arrow prev" onclick="stepSlide(-1)">&#8249;</button>
    <button class="slide-arrow next" onclick="stepSlide(1)">&#8250;</button>
  </div>
  <div class="project-meta">
    <div class="meta-col">Rue Martel<br>10e arrondissement de Paris</div><div class="meta-col">Apartment renovation for a couple after their children moved out. The existing interior is fully stripped and reorganized. Up to 20 cm of insulation are removed and replaced with custom crafted built in storage and a compact kitchen that redefine the living space. The former corridor disappears in favor of a triangular dressing room that reinterprets circulation and storage.</div>
  </div>
  <div class="bottom-nav">
    <a class="email-link" href="mailto:aaron.amend@icloud.com">Email</a>
    <div class="footer-arrow">↓</div>
    <a onclick="showPicsSlideshow()">Pics</a>
  </div>
</div>

<div id="page-project1" class="page">
  <div class="slideshow" data-count="4">
    <div class="slide-track">
    <img src="img/Entwurf_Beten_Perspektiven__02.png" alt="">
    <img src="img/Beten_Ansicht_Materialitat_01.png" alt="">
    <img src="img/konzept_kirche.png" alt="">
    <img src="img/Beten_Grundriss_1-50_01.png" alt="">
    </div>
    <button class="slide-arrow prev" onclick="stepSlide(-1)">&#8249;</button>
    <button class="slide-arrow next" onclick="stepSlide(1)">&#8250;</button>
  </div>
  <div class="project-meta">
    <div class="meta-col"><strong>Design Studio <br><br>Bauhaus Universität Weimar<br></strong><br><br>Professor José Mario Gutiérrez Marquez<br><br>with Undine Kunze and Vincent Mank</div><div class="meta-col"><strong>Seminary and church for educational purposes in the forest near Wittenberg</strong></div>
  </div>
  <div class="bottom-nav">
    <a class="email-link" href="mailto:aaron.amend@icloud.com">Email</a>
    <div class="footer-arrow">↓</div>
    <a onclick="showPicsSlideshow()">Pics</a>
  </div>
</div>

<div id="page-roubaix" class="page">
  <div class="slideshow" data-count="22">
    <div class="slide-track">
    <img src="img/solutions1.jpg" alt="">
    <img src="img/roubaix-mensa.jpg" alt="">
    <img src="img/roubaix-out.jpg" alt="">
    <img src="img/rubaix-atrium.jpg" alt="">
    <img src="img/roubaix-studio.jpg" alt="">
    <img src="img/A3_compressed_page-0004.jpg" alt="">
    <img src="img/A3_compressed_page-0003.jpg" alt="">
    <img src="img/4.jpeg" alt="">
    <img src="img/A3_compressed_page-0001.jpg" alt="">
    <img src="img/A3_compressed_page-0002.jpg" alt="">
    <img src="img/3.jpeg" alt="">
    <img src="img/2.jpeg" alt="">
    <img src="img/A3_compressed_page-0005.jpg" alt="">
    <img src="img/A3_compressed_page-0006.jpg" alt="">
    <img src="img/5.jpeg" alt="">
    <img src="img/7.jpeg" alt="">
    <img src="img/A3_compressed_page-0007.jpg" alt="">
    <img src="img/A3_compressed_page-0008.jpg" alt="">
    <img src="img/A3_compressed_page-0012.jpg" alt="">
    <img src="img/A3_compressed_page-0011.jpg" alt="">
    <img src="img/A3_compressed_page-0010.jpg" alt="">
    <img src="img/A3_compressed_page-0009.jpg" alt="">
    </div>
    <button class="slide-arrow prev" onclick="stepSlide(-1)">&#8249;</button>
    <button class="slide-arrow next" onclick="stepSlide(1)">&#8250;</button>
  </div>
  <div class="project-meta">
    <div class="meta-col"><strong>ENSA Belleville Paris<br></strong><br><br>Professor Luis Burriel<br><br>with Diego Kühle</div><div class="meta-col">Transformation of an Industrial Building into an Architecture School, Roubaix France</div>
  </div>
  <div class="bottom-nav">
    <a class="email-link" href="mailto:aaron.amend@icloud.com">Email</a>
    <div class="footer-arrow">↓</div>
    <a onclick="showPicsSlideshow()">Pics</a>
  </div>
</div>

<div id="page-project7" class="page">
  <div class="slideshow" data-count="9">
    <div class="slide-track">
    <img src="img/st_24_6.jpeg" alt="">
    <img src="img/st_24_3.jpeg" alt="">
    <img src="img/st_24_2.jpeg" alt="">
    <img src="img/333.jpeg" alt="">
    <img src="img/st_24_5.jpeg" alt="">
    <img src="img/3334.jpg" alt="">
    <img src="img/st_24_1.jpeg" alt="">
    <img src="img/st_24_7.jpeg" alt="">
    <img src="img/st_24_4.jpeg" alt="">
    </div>
    <button class="slide-arrow prev" onclick="stepSlide(-1)">&#8249;</button>
    <button class="slide-arrow next" onclick="stepSlide(1)">&#8250;</button>
  </div>
  <div class="project-meta">
    <div class="meta-col"><strong>École Nationale Supérieure d'Architecture de Paris-Belleville<br><br></strong>Prof. Paul Gresham</div><div class="meta-col">Experimental Music Residency in Pantin</div>
  </div>
  <div class="bottom-nav">
    <a class="email-link" href="mailto:aaron.amend@icloud.com">Email</a>
    <div class="footer-arrow">↓</div>
    <a onclick="showPicsSlideshow()">Pics</a>
  </div>
</div>

<div id="page-project4" class="page">
  <div class="slideshow" data-count="11">
    <div class="slide-track">
    <img src="img/Bildschirmfoto-2022-11-25-um-15.21.33-Kopie.jpg" alt="">
    <img src="img/Groninger_Hof_Amend-Henschel-Mank_210712_2_verschoben_3.png" alt="">
    <img src="img/Groninger_Hof_Amend-Henschel-Mank_210712_2_verschoben_5.png" alt="">
    <img src="img/Groninger_Hof_Amend-Henschel-Mank_210712_2_verschoben_4.png" alt="">
    <img src="img/Groninger_Hof_Amend-Henschel-Mank_210712_2_verschoben_6.png" alt="">
    <img src="img/Groninger_Hof_Amend-Henschel-Mank_210712_2_verschoben.png" alt="">
    <img src="img/Groninger_Hof_Amend-Henschel-Mank_210712_2_verschoben_2.png" alt="">
    <img src="img/Groninger_Hof_Amend-Henschel-Mank_210712_2_verschoben_81.png" alt="">
    <img src="img/Groninger_Hof_Amend-Henschel-Mank_210712_2_verschoben_9.png" alt="">
    <img src="img/Groninger_Hof_Amend-Henschel-Mank_210712_2_verschoben_8.png" alt="">
    <img src="img/Groninger_Hof_Amend-Henschel-Mank_210712_2_verschoben_7.png" alt="">
    </div>
    <button class="slide-arrow prev" onclick="stepSlide(-1)">&#8249;</button>
    <button class="slide-arrow next" onclick="stepSlide(1)">&#8250;</button>
  </div>
  <div class="project-meta">
    <div class="meta-col"><strong>Housing Studio<br><br>Bauhaus Universität Weimar<br><br></strong>Prof. Verena von Beckerath<br><br>with Charlotte Henschel and Vincent Mank</div><div class="meta-col">Gröninger Hof cooperative Competition<br><br>transforming parking to housing</div>
  </div>
  <div class="bottom-nav">
    <a class="email-link" href="mailto:aaron.amend@icloud.com">Email</a>
    <div class="footer-arrow">↓</div>
    <a onclick="showPicsSlideshow()">Pics</a>
  </div>
</div>

<div id="page-project2" class="page">
  <div class="slideshow" data-count="7">
    <div class="slide-track">
    <img src="img/portfolio_aaron_amend_verschoben.png" alt="">
    <img src="img/PerspektiveAu_en_3KM.png" alt="">
    <img src="img/Bildschirmfoto-2022-12-05-um-13.28.33.jpg" alt="">
    <img src="img/faltung.png" alt="">
    <img src="img/grundrissclean.png" alt="">
    <img src="img/fassadenschnitt.png" alt="">
    <img src="img/Explo_Iso_200_Final_3KM.png" alt="">
    </div>
    <button class="slide-arrow prev" onclick="stepSlide(-1)">&#8249;</button>
    <button class="slide-arrow next" onclick="stepSlide(1)">&#8250;</button>
  </div>
  <div class="project-meta">
    <div class="meta-col"><strong>Design and Building Construction Studio<br><br></strong><br>Prof. Dipl. -Ing. Johannes Kühn <br><br>with Elias Martinez</div><div class="meta-col"><strong>Cider factory on the Thuringia cycle path</strong></div>
  </div>
  <div class="bottom-nav">
    <a class="email-link" href="mailto:aaron.amend@icloud.com">Email</a>
    <div class="footer-arrow">↓</div>
    <a onclick="showPicsSlideshow()">Pics</a>
  </div>
</div>

<div id="page-project8" class="page">
  <div class="slideshow" data-count="11">
    <div class="slide-track">
    <img src="img/Bildschirmfoto-2024-09-11-um-13.34.22.jpeg" alt="">
    <img src="img/Bildschirmfoto-2024-09-11-um-13.33.53.jpeg" alt="">
    <img src="img/Bildschirmfoto-2024-09-11-um-13.35.34.jpeg" alt="">
    <img src="img/Bildschirmfoto-2024-09-11-um-13.35.29.jpeg" alt="">
    <img src="img/Bildschirmfoto-2024-09-11-um-13.37.30.jpeg" alt="">
    <img src="img/Bildschirmfoto-2024-09-11-um-13.35.39.jpeg" alt="">
    <img src="img/Bildschirmfoto-2024-09-11-um-13.35.16.jpeg" alt="">
    <img src="img/Bildschirmfoto-2024-09-11-um-13.35.01.jpeg" alt="">
    <img src="img/Bildschirmfoto-2024-09-11-um-13.34.53.jpeg" alt="">
    <img src="img/Bildschirmfoto-2024-09-11-um-13.34.41.jpeg" alt="">
    <img src="img/Bildschirmfoto-2024-09-11-um-13.34.31.jpeg" alt="">
    </div>
    <button class="slide-arrow prev" onclick="stepSlide(-1)">&#8249;</button>
    <button class="slide-arrow next" onclick="stepSlide(1)">&#8250;</button>
  </div>
    <div class="project-meta">
    <div class="meta-col"></div><div class="meta-col"></div>
  </div>
<div class="bottom-nav">
    <a class="email-link" href="mailto:aaron.amend@icloud.com">Email</a>
    <div class="footer-arrow">↓</div>
    <a onclick="showPicsSlideshow()">Pics</a>
  </div>
</div>

<div id="page-pics" class="page">
  <img id="pics-phone-img" src="img/iphone-frame.jpg" alt="">
  <div class="slideshow">
    <div class="slide-track" id="pics-slide-track" onclick="stepPicsSlide()"></div>
    <div id="pics-meta" class="pics-meta" aria-hidden="true"></div>
  </div>
  <div class="bottom-nav">
    <a class="email-link" href="mailto:aaron.amend@icloud.com">Email</a>
    <div class="footer-arrow">↓</div>
    <a onclick="showPicsSlideshow()">Pics</a>
  </div>
</div>

<div id="page-globe" class="page">
  <div id="globe-canvas-wrap">
    <svg id="globe-svg" viewBox="0 0 340 340" preserveAspectRatio="xMidYMid meet">
      <g id="globe-dots-layer"></g>
      <g id="globe-markers-layer"></g>
    </svg>
  </div>
  <div class="bottom-nav">
    <a class="email-link" href="mailto:aaron.amend@icloud.com">Email</a>
    <div class="footer-arrow">↓</div>
    <a onclick="showPicsSlideshow()">Pics</a>
  </div>
</div>

<div id="pics-lightbox" onclick="closePicsLightbox(event)">
  <span id="pics-lightbox-close" onclick="closePicsLightbox(event)">&times;</span>
  <img id="pics-lightbox-img" src="" alt="">
</div>

<script src="https://cdnjs.cloudflare.com/ajax/libs/d3/7.9.0/d3.min.js"></script>
<script src="assets/topojson-client.min.js"></script>
<script>
  const home     = document.getElementById('home');
  const cvPage   = document.getElementById('cv-page');
  const navBack  = document.getElementById('nav-back');
  const navAdmin = document.getElementById('nav-admin');
  const navCV    = document.getElementById('nav-cv');
  const arrow   = document.getElementById('scroll-arrow');
  let currentPage = 'home';
  let slideIdx = 0;

  /* ── Navigation ── */
  function showHome() { home.style.display = 'flex'; }
  function hideHome() { home.style.display = 'none'; }

  /* ── Admin access: go straight to the admin tool, which has its own
     server-side password screen. (Previously there was a second, client-side
     password prompt here too -- redundant and confusing, since the real
     check always happens on the server. Removed so there's exactly one
     password prompt.) ── */
  const ADMIN_URL = 'https://aamend-admin.onrender.com/admin';
  function openAdminGate() {
    window.location.href = ADMIN_URL;
  }

  function showCV() {
    hideHome();
    document.body.classList.remove('globe-active');
    document.body.classList.remove('pics-active');
    document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
    cvPage.classList.add('active');
    document.getElementById('cv-footer').style.display = 'flex';
    navBack.style.display = 'block';
    navAdmin.style.display = 'none';
    navCV.style.display   = 'none';
    window.scrollTo(0, 0);
    currentPage = 'cv';
    arrow.style.display = 'none';
  }

  function showProject(id) {
    hideHome();
    document.body.classList.remove('globe-active');
    document.body.classList.remove('pics-active');
    document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
    cvPage.classList.remove('active');
    document.getElementById('cv-footer').style.display = 'none';
    const page = document.getElementById(id);
    if (page) {
      page.classList.add('active');
      navBack.style.display = 'block';
      navAdmin.style.display = 'none';
      navCV.style.display   = 'block';
      window.scrollTo(0, 0);
      currentPage = id;
      arrow.style.display = 'none';
      initSlideshow(page);
    }
  }

  function goHome() {
    document.body.classList.remove('globe-active');
    document.body.classList.remove('pics-active');
    document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
    cvPage.classList.remove('active');
    document.getElementById('cv-footer').style.display = 'none';
    showHome();
    navBack.style.display = 'none';
    navAdmin.style.display = 'block';
    navCV.style.display   = 'block';
    currentPage = 'home';
    window.scrollTo(0, 0);
    arrow.style.display = 'block';
    arrow.style.opacity = '1';
    if (typeof updateCircleParallax === 'function') updateCircleParallax();
  }

  function showGlobe() {
    hideHome();
    document.body.classList.add('globe-active');
    document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
    cvPage.classList.remove('active');
    document.getElementById('cv-footer').style.display = 'none';
    const page = document.getElementById('page-globe');
    page.classList.add('active');
    navBack.style.display = 'block';
    navAdmin.style.display = 'none';
    navCV.style.display   = 'block';
    window.scrollTo(0, 0);
    currentPage = 'page-globe';
    arrow.style.display = 'none';
    initGlobe();
  }

  /* ── Pics: simple fullscreen slideshow, random order, click the image to
     advance. The globe view above is kept around (unlinked) in case it's
     wanted again later -- showGlobe() still works if a Pics link is ever
     pointed back at it. ── */
  let picsShuffled = null;
  let picsIdx = 0;

  function showPicsSlideshow() {
    hideHome();
    document.body.classList.remove('globe-active');
    document.body.classList.add('pics-active');
    document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
    cvPage.classList.remove('active');
    document.getElementById('cv-footer').style.display = 'none';
    const page = document.getElementById('page-pics');
    page.classList.add('active');
    navBack.style.display = 'block';
    navAdmin.style.display = 'none';
    navCV.style.display   = 'block';
    window.scrollTo(0, 0);
    currentPage = 'page-pics';
    arrow.style.display = 'none';
    initPicsSlideshow();
  }

  function initPicsSlideshow() {
    fetch('assets/pics.json').then(r => r.json()).then(items => {
      picsShuffled = items.slice();
      for (let i = picsShuffled.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        const tmp = picsShuffled[i]; picsShuffled[i] = picsShuffled[j]; picsShuffled[j] = tmp;
      }
      picsIdx = 0;
      const track = document.getElementById('pics-slide-track');
      track.innerHTML = '';
      picsShuffled.forEach((it, i) => {
        const img = document.createElement('img');
        img.src = 'img/pics/' + encodeURIComponent(it.full);
        img.loading = i === 0 ? 'eager' : 'lazy';
        img.alt = '';
        if (i === 0) img.classList.add('active');
        track.appendChild(img);
      });
      animatePicsMeta(picsMetaText(picsShuffled[0], 0, picsShuffled.length));
    });
  }

  function stepPicsSlide() {
    if (!picsShuffled || !picsShuffled.length) return;
    const track = document.getElementById('pics-slide-track');
    const slides = track.children;
    slides[picsIdx].classList.remove('active');
    picsIdx = (picsIdx + 1) % slides.length;
    slides[picsIdx].classList.add('active');
    animatePicsMeta(picsMetaText(picsShuffled[picsIdx], picsIdx, picsShuffled.length));
  }

  /* ── Split-flap ("departure board") metadata line under each photo.
     Real GPS-derived place names are shown for photos with genuine
     location data; the remaining photos (no reliable location) show an
     archive index instead of a made-up place. ── */
  const PICS_FLAP_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ,./·-';
  let picsMetaToken = 0;

  function picsMetaText(it, idx, total) {
    if (it && it.place) return it.place;
    const pad = n => String(n).padStart(3, '0');
    return 'AAMEND ARCHIVE · ' + pad(idx + 1) + '/' + pad(total);
  }

  function animatePicsMeta(text) {
    const el = document.getElementById('pics-meta');
    if (!el) return;
    const myToken = ++picsMetaToken;
    const chars = text.split('');
    el.innerHTML = '';
    const flaps = chars.map(() => {
      const span = document.createElement('span');
      span.className = 'flap';
      span.textContent = ' ';
      el.appendChild(span);
      return span;
    });
    const CYCLES = 9;
    const STEP_MS = 32;
    let step = 0;
    function tick() {
      if (myToken !== picsMetaToken) return;
      let allDone = true;
      flaps.forEach((span, i) => {
        const settleAt = CYCLES + i;
        if (step >= settleAt) {
          span.textContent = chars[i] === ' ' ? ' ' : chars[i];
        } else {
          allDone = false;
          span.textContent = PICS_FLAP_CHARS[Math.floor(Math.random() * PICS_FLAP_CHARS.length)];
        }
      });
      step++;
      if (!allDone) setTimeout(tick, STEP_MS);
    }
    tick();
  }

  function openPicsLightbox(filename) {
    document.getElementById('pics-lightbox-img').src = 'img/pics/' + encodeURIComponent(filename);
    document.getElementById('pics-lightbox').style.display = 'flex';
  }
  function closePicsLightbox(e) {
    if (e && e.target.tagName === 'IMG') return;
    document.getElementById('pics-lightbox').style.display = 'none';
  }
  document.addEventListener('keydown', e => {
    if (e.key === 'Escape') closePicsLightbox();
  });

  /* ── Globe (Pics) ── */
  /* ── Globe (Pics): fixed screen-space dot raster, like a status-light
     wall -- land dots never move, rotation only toggles which ones are
     currently over land (via an orthographic projection + a rasterised
     land/water lookup). Photo markers are projected for real and snapped
     onto the nearest raster dot so they read as part of the same grid. ── */
  let globeInited = false;
  let globeSvgEl, globeDotsLayer, globeMarkersLayer, globeWrapEl;
  const GLOBE_SIZE = 340;
  const GLOBE_GRID_STEP = 2.9;
  const GLOBE_DOT_R = 1.1;
  const GLOBE_MIN_VB = GLOBE_SIZE / 14;
  const GLOBE_MAX_VB = GLOBE_SIZE * 1.15;
  let globeViewBox = { x: 0, y: 0, w: GLOBE_SIZE, h: GLOBE_SIZE };
  let globeRotation = [10, -12];
  let globeLandMask = null;
  let globeGridPts = null;
  let globeDotEls = null;
  let globeGridIndex = null;
  let globeGridBuiltForScale = 1;
  let globeMarkerData = [];

  function initGlobe() {
    globeWrapEl = document.getElementById('globe-canvas-wrap');
    if (globeInited) return;
    globeInited = true;
    globeSvgEl = document.getElementById('globe-svg');
    globeDotsLayer = document.getElementById('globe-dots-layer');
    globeMarkersLayer = document.getElementById('globe-markers-layer');
    applyGlobeVB();

    Promise.all([
      fetch('assets/land-110m.json').then(r => r.json()),
      fetch('assets/pics.json').then(r => r.json())
    ]).then(([topo, pics]) => {
      const land = window.topojson.feature(topo, topo.objects.land);
      buildLandMask(land);
      createMarkerEls(pics);
      rebuildGlobeGrid();
      drawGlobe();
      wireGlobeInteraction();
    });
  }

  function applyGlobeVB() {
    globeSvgEl.setAttribute('viewBox',
      globeViewBox.x.toFixed(2) + ' ' + globeViewBox.y.toFixed(2) + ' ' +
      globeViewBox.w.toFixed(2) + ' ' + globeViewBox.h.toFixed(2));
  }

  function buildLandMask(landFeature) {
    const W = 360, H = 180;
    const canvas = document.createElement('canvas');
    canvas.width = W; canvas.height = H;
    const ctx = canvas.getContext('2d');
    const proj = d3.geoEquirectangular().translate([W / 2, H / 2]).scale(W / (2 * Math.PI));
    const path = d3.geoPath(proj, ctx);
    ctx.fillStyle = '#000';
    ctx.beginPath();
    path(landFeature);
    ctx.fill();
    const px = ctx.getImageData(0, 0, W, H).data;
    globeLandMask = new Uint8Array(W * H);
    for (let i = 0; i < W * H; i++) globeLandMask[i] = px[i * 4 + 3] > 128 ? 1 : 0;
  }

  function isLand(lon, lat) {
    if (!globeLandMask) return false;
    let xi = Math.floor(lon + 180); xi = ((xi % 360) + 360) % 360;
    const yi = Math.max(0, Math.min(179, Math.floor(90 - lat)));
    return globeLandMask[yi * 360 + xi] === 1;
  }

  function globeProjection() {
    return d3.geoOrthographic()
      .scale(GLOBE_SIZE / 2 - 6)
      .translate([GLOBE_SIZE / 2, GLOBE_SIZE / 2])
      .rotate(globeRotation)
      .clipAngle(90);
  }

  /* d3 only clips GeoJSON paths against the visible hemisphere -- a lone
     point run through the projection still comes back with real x/y even
     when it is on the far side. Markers need this manual front/back check
     or the globe looks transparent (photos from the far side showing
     through onto the front). */
  function angularDistDeg(lon1, lat1, lon2, lat2) {
    const r = Math.PI / 180;
    const p1 = lat1 * r, p2 = lat2 * r;
    const cosC = Math.sin(p1) * Math.sin(p2) + Math.cos(p1) * Math.cos(p2) * Math.cos((lon2 - lon1) * r);
    return Math.acos(Math.max(-1, Math.min(1, cosC))) * 180 / Math.PI;
  }

  function rebuildGlobeGrid() {
    const zoomScale = globeViewBox.w / GLOBE_SIZE;
    globeGridBuiltForScale = zoomScale;
    const step = GLOBE_GRID_STEP * zoomScale;
    const r = GLOBE_DOT_R * zoomScale;
    const cx = GLOBE_SIZE / 2, cy = GLOBE_SIZE / 2, radius = GLOBE_SIZE / 2 - 6;
    const pad = step * 2;
    const left = Math.max(cx - radius, globeViewBox.x - pad);
    const right = Math.min(cx + radius, globeViewBox.x + globeViewBox.w + pad);
    const top = Math.max(cy - radius, globeViewBox.y - pad);
    const bottom = Math.min(cy + radius, globeViewBox.y + globeViewBox.h + pad);
    const pts = [];
    for (let y = top; y <= bottom; y += step) {
      for (let x = left; x <= right; x += step) {
        if ((x - cx) * (x - cx) + (y - cy) * (y - cy) <= radius * radius) pts.push([x, y]);
      }
    }
    globeGridPts = pts;
    const idx = new Map();
    pts.forEach(([x, y]) => {
      const key = Math.round(x / step) + ',' + Math.round(y / step);
      if (!idx.has(key)) idx.set(key, []);
      idx.get(key).push([x, y]);
    });
    globeGridIndex = { map: idx, step };

    if (globeDotEls) globeDotEls.forEach(el => el.remove());
    const frag = document.createDocumentFragment();
    globeDotEls = pts.map(([x, y]) => {
      const c = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
      c.setAttribute('class', 'globe-dot');
      c.setAttribute('cx', x.toFixed(2));
      c.setAttribute('cy', y.toFixed(2));
      c.setAttribute('r', r.toFixed(2));
      frag.appendChild(c);
      return c;
    });
    globeDotsLayer.appendChild(frag);
  }

  function nearestGridPoint(x, y) {
    if (!globeGridIndex) return [x, y];
    const step = globeGridIndex.step;
    const cx = Math.round(x / step), cy = Math.round(y / step);
    let best = null, bestDist = Infinity;
    for (let dx = -1; dx <= 1; dx++) {
      for (let dy = -1; dy <= 1; dy++) {
        const bucket = globeGridIndex.map.get((cx + dx) + ',' + (cy + dy));
        if (!bucket) continue;
        for (const pt of bucket) {
          const ddx = pt[0] - x, ddy = pt[1] - y;
          const d = ddx * ddx + ddy * ddy;
          if (d < bestDist) { bestDist = d; best = pt; }
        }
      }
    }
    return best || [x, y];
  }

  function createMarkerEls(pics) {
    const frag = document.createDocumentFragment();
    globeMarkerData = pics.map(it => {
      const img = document.createElementNS('http://www.w3.org/2000/svg', 'image');
      img.setAttributeNS('http://www.w3.org/1999/xlink', 'href', 'img/pics-thumb/' + encodeURIComponent(it.thumb));
      img.setAttribute('class', 'globe-marker');
      img.style.display = 'none';
      img.addEventListener('click', () => openPicsLightbox(it.full));
      frag.appendChild(img);
      return { el: img, lon: it.lon, lat: it.lat };
    });
    globeMarkersLayer.appendChild(frag);
  }

  function drawGlobe() {
    const proj = globeProjection();
    for (let i = 0; i < globeDotEls.length; i++) {
      const el = globeDotEls[i];
      const x = globeGridPts[i][0], y = globeGridPts[i][1];
      const inv = proj.invert([x, y]);
      let show = false;
      if (inv && isFinite(inv[0]) && isFinite(inv[1])) show = isLand(inv[0], inv[1]);
      el.style.display = show ? '' : 'none';
    }
    const zoomScale = globeViewBox.w / GLOBE_SIZE;
    // Grows the closer you zoom in (opposite of the land-dot grid, which
    // stays a constant physical size) -- clamped so it never balloons into
    // an oversized blob at the deepest zoom level.
    const size = Math.min(30, GLOBE_DOT_R * 3.4 * Math.pow(1 / zoomScale, 0.62));
    const centerLon = -globeRotation[0], centerLat = -globeRotation[1];
    globeMarkerData.forEach(m => {
      if (angularDistDeg(m.lon, m.lat, centerLon, centerLat) > 89) {
        m.el.style.display = 'none';
        return;
      }
      const p = proj([m.lon, m.lat]);
      if (!p) { m.el.style.display = 'none'; return; }
      const [sx, sy] = nearestGridPoint(p[0], p[1]);
      m.el.setAttribute('x', (sx - size / 2).toFixed(2));
      m.el.setAttribute('y', (sy - size / 2).toFixed(2));
      m.el.setAttribute('width', size.toFixed(2));
      m.el.setAttribute('height', size.toFixed(2));
      m.el.style.display = '';
    });
  }

  // Converts a client-space (viewport pixel) point into the current
  // viewBox's own coordinate space, so zoom can anchor on exactly the
  // point under the cursor/pinch instead of always snapping back to the
  // globe's center (which is what made zooming feel like it was cropping
  // into a fixed square rather than homing in on what you pointed at).
  function clientToSvgPoint(clientX, clientY) {
    const rect = globeSvgEl.getBoundingClientRect();
    const px = (clientX - rect.left) / rect.width;
    const py = (clientY - rect.top) / rect.height;
    return [globeViewBox.x + px * globeViewBox.w, globeViewBox.y + py * globeViewBox.h];
  }

  function zoomGlobeBy(factor, anchorClientX, anchorClientY) {
    const [ax, ay] = (anchorClientX != null)
      ? clientToSvgPoint(anchorClientX, anchorClientY)
      : [globeViewBox.x + globeViewBox.w / 2, globeViewBox.y + globeViewBox.h / 2];
    const newW = Math.max(GLOBE_MIN_VB, Math.min(GLOBE_MAX_VB, globeViewBox.w * factor));
    const ratio = newW / globeViewBox.w;
    let nextX = ax - (ax - globeViewBox.x) * ratio;
    let nextY = ay - (ay - globeViewBox.y) * ratio;
    // Keep the crop from drifting off the globe entirely after many
    // zoom-toward-the-edge steps -- clamp its center to stay within a
    // sane distance of the true globe center, same idea as Memori's fix.
    const maxDrift = (GLOBE_MAX_VB - newW) / 2 + GLOBE_SIZE * 0.12;
    const cx = Math.max(GLOBE_SIZE / 2 - maxDrift, Math.min(GLOBE_SIZE / 2 + maxDrift, nextX + newW / 2));
    const cy = Math.max(GLOBE_SIZE / 2 - maxDrift, Math.min(GLOBE_SIZE / 2 + maxDrift, nextY + newW / 2));
    globeViewBox = { x: cx - newW / 2, y: cy - newW / 2, w: newW, h: newW };
    applyGlobeVB();
    const zoomScale = newW / GLOBE_SIZE;
    if (Math.abs(zoomScale - globeGridBuiltForScale) / globeGridBuiltForScale > 0.12) {
      rebuildGlobeGrid();
    }
    drawGlobe();
  }

  function wireGlobeInteraction() {
    const wrap = globeWrapEl;
    // No idle auto-spin -- the globe only turns while dragging, plus a
    // short momentum decay right after a drag ends. momentumRunning makes
    // sure the rAF loop actually stops (and the ~3-4k dot elements stop
    // being redrawn every frame) once that momentum has settled, instead
    // of looping forever in the background.
    let dragging = false, lastX = 0, lastY = 0, velX = 0, velY = 0, downX = 0, downY = 0;
    let momentumRunning = false;

    function pxToDeg(px) {
      const rect = globeSvgEl.getBoundingClientRect();
      const svgPerPx = globeViewBox.w / rect.width;
      const scale = globeProjection().scale();
      return (px * svgPerPx) * (90 / (Math.PI * scale));
    }

    wrap.addEventListener('pointerdown', e => {
      dragging = true; lastX = e.clientX; lastY = e.clientY;
      downX = e.clientX; downY = e.clientY;
      velX = 0; velY = 0;
      wrap.setPointerCapture(e.pointerId);
    });
    wrap.addEventListener('pointermove', e => {
      if (!dragging) return;
      const dx = e.clientX - lastX, dy = e.clientY - lastY;
      lastX = e.clientX; lastY = e.clientY;
      const dDeg = pxToDeg(dx), dDegY = pxToDeg(dy);
      globeRotation[0] += dDeg;
      globeRotation[1] = Math.max(-90, Math.min(90, globeRotation[1] - dDegY));
      velX = dDeg * 0.18; velY = dDegY * 0.18;
      drawGlobe();
    });
    function endDrag() {
      dragging = false;
      if (!momentumRunning && (Math.abs(velX) > 0.03 || Math.abs(velY) > 0.03)) {
        momentumRunning = true;
        requestAnimationFrame(momentumTick);
      }
    }
    wrap.addEventListener('pointerup', endDrag);
    wrap.addEventListener('pointerleave', endDrag);

    function momentumTick() {
      if (dragging) { momentumRunning = false; return; }
      globeRotation[0] += velX;
      globeRotation[1] = Math.max(-90, Math.min(90, globeRotation[1] - velY));
      velX *= 0.9; velY *= 0.9;
      drawGlobe();
      if (Math.abs(velX) > 0.03 || Math.abs(velY) > 0.03) {
        requestAnimationFrame(momentumTick);
      } else {
        momentumRunning = false;
      }
    }

    wrap.addEventListener('wheel', e => {
      e.preventDefault();
      zoomGlobeBy(Math.exp(e.deltaY * 0.0016), e.clientX, e.clientY);
    }, { passive: false });

    let pinchDist = null, pinchMidX = 0, pinchMidY = 0;
    wrap.addEventListener('touchstart', e => {
      if (e.touches.length === 2) {
        pinchDist = Math.hypot(
          e.touches[0].clientX - e.touches[1].clientX,
          e.touches[0].clientY - e.touches[1].clientY
        );
        pinchMidX = (e.touches[0].clientX + e.touches[1].clientX) / 2;
        pinchMidY = (e.touches[0].clientY + e.touches[1].clientY) / 2;
      }
    }, { passive: true });
    wrap.addEventListener('touchmove', e => {
      if (e.touches.length === 2 && pinchDist) {
        const d = Math.hypot(
          e.touches[0].clientX - e.touches[1].clientX,
          e.touches[0].clientY - e.touches[1].clientY
        );
        pinchMidX = (e.touches[0].clientX + e.touches[1].clientX) / 2;
        pinchMidY = (e.touches[0].clientY + e.touches[1].clientY) / 2;
        zoomGlobeBy(pinchDist / d, pinchMidX, pinchMidY);
        pinchDist = d;
      }
    }, { passive: true });
    wrap.addEventListener('touchend', e => { if (e.touches.length < 2) pinchDist = null; });
  }

  /* ── Slideshow ── */
  function initSlideshow(page) {
    const track = page.querySelector('.slide-track');
    const slides = Array.from(track.children);
    slideIdx = 0;
    slides.forEach((el, i) => el.classList.toggle('active', i === 0));
    page.dataset.single = slides.length <= 1 ? 'true' : 'false';
    page._slides = slides;
  }

  function stepSlide(dir) {
    const page = document.getElementById(currentPage);
    if (!page || !page._slides) return;
    const slides = page._slides;
    if (!slides.length) return;
    slides[slideIdx].classList.remove('active');
    slideIdx = (slideIdx + dir + slides.length) % slides.length;
    slides[slideIdx].classList.add('active');
  }

  document.addEventListener('keydown', e => {
    if (!currentPage.startsWith('page-')) return;
    if (e.key === 'ArrowRight') stepSlide(1);
    if (e.key === 'ArrowLeft')  stepSlide(-1);
  });

  /* Floating arrow stays visible while scrolling the home feed;
     hides only once the black footer (with its own arrow) comes into view. */
  const homeFooterArrow = document.querySelector('#home .footer-arrow');
  if (homeFooterArrow) {
    const footerIO = new IntersectionObserver((entries) => {
      entries.forEach(en => {
        if (currentPage !== 'home') return;
        arrow.style.opacity = en.isIntersecting ? '0' : '1';
      });
    }, { threshold: 0 });
    footerIO.observe(homeFooterArrow);
  }

  /* ── Fade-in on scroll (home feed) ── */
  const io = new IntersectionObserver((entries) => {
    entries.forEach(en => { if (en.isIntersecting) { en.target.classList.add('in-view'); io.unobserve(en.target); } });
  }, { threshold: 0.1 });
  document.querySelectorAll('.project-item').forEach(el => io.observe(el));

  /* ── Circle backdrop parallax ──
     Starts fully hidden above the top edge of the screen. As you scroll,
     it slides down -- timed against the *entire* scrollable height of the
     home feed, so its top edge crosses the bottom edge of the screen at
     exactly the same moment scrollY hits its maximum (i.e. right as the
     footer comes into view), never before. */
  const circleBackdrop = document.getElementById('circle-backdrop');
  const nameInvert = document.querySelector('.name-invert');
  const nameWrap = document.querySelector('.name-wrap');
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  let parallaxTicking = false;

  function updateCircleParallax() {
    parallaxTicking = false;
    if (currentPage !== 'home' || !circleBackdrop) return;
    const vh = window.innerHeight;
    const diameter = circleBackdrop.offsetHeight;
    const maxScroll = Math.max(1, document.body.scrollHeight - vh);
    const progress = reduceMotion ? 0 : Math.min(1, Math.max(0, window.scrollY / maxScroll));
    // top edge goes from -diameter (fully hidden above) to vh (fully hidden below)
    const top = -diameter + progress * (vh + diameter);
    circleBackdrop.style.transform = 'translate(-50%, ' + top.toFixed(1) + 'px)';

    // Keep the white "negative" name-copy's clip circle locked to the
    // black circle's actual on-screen position/size, every frame -- the
    // base black name underneath is never touched, so it can never vanish.
    if (nameInvert && nameWrap) {
      const wrapRect = nameWrap.getBoundingClientRect();
      const circleCenterX = window.innerWidth / 2;
      const circleCenterY = top + diameter / 2;
      const cx = circleCenterX - wrapRect.left;
      const cy = circleCenterY - wrapRect.top;
      const r = diameter / 2;
      nameInvert.style.clipPath = 'circle(' + r.toFixed(1) + 'px at ' + cx.toFixed(1) + 'px ' + cy.toFixed(1) + 'px)';
    }
  }

  window.addEventListener('scroll', () => {
    if (!parallaxTicking) { requestAnimationFrame(updateCircleParallax); parallaxTicking = true; }
  }, { passive: true });

  window.addEventListener('resize', updateCircleParallax);
  window.addEventListener('load', updateCircleParallax);

  /* fade the circle in once on load, then keep it in sync whenever home
     becomes the active page again */
  requestAnimationFrame(() => {
    home.classList.add('circle-ready');
    updateCircleParallax();
  });
</script>
</body>
</html>

__AAMEND_V10_EOF_index_html__

mkdir -p "$(dirname "img/iphone-frame.jpg")"
openssl base64 -d -out 'img/iphone-frame.jpg' <<'__AAMEND_V10_B64_img_iphone-frame_jpg__'
/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAMCAgMCAgMDAwMEAwMEBQgFBQQEBQoH
BwYIDAoMDAsKCwsNDhIQDQ4RDgsLEBYQERMUFRUVDA8XGBYUGBIUFRT/2wBDAQME
BAUEBQkFBQkUDQsNFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQU
FBQUFBQUFBQUFBQUFBT/wAARCAZAAxcDASIAAhEBAxEB/8QAHgABAAICAwEBAQAA
AAAAAAAAAAYHBAUCAwgBCQr/xABfEAEAAgEDAwEFBAQHCQkNBQkAAQIDBAURBhIh
MQcTIkFRCBRhgSMycZEVFkJ1obKzNjc4UlaUsdLwFyQzSFRidILTNDVDcoOEkpOV
osHR4RgnU1VjCUVXZXajpbTx/8QAFAEBAAAAAAAAAAAAAAAAAAAAAP/EABQRAQAA
AAAAAAAAAAAAAAAAAAD/2gAMAwEAAhEDEQA/APyqAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEsv0
rtmizafDXcMnUuutPN9DseO01isxHbPvrVnzzaPEY7eYmJ4ls9x2HcNp11tXG0bP
0zit3Y6afX3rqZmJnmO6uacnFoiI89tOY54jiZBDts2Hc9797/B23avX+649591w
WydnPPHPbE8c8T+6Ul6a9jnWHVWtjS6TZsmmtzETk3LJTRY45iZ57s01ifSfTn5R
6zHOdn3zbt409b7z1Rv2767Ne3do9Fj7cfxeta988RE+nivzj4fDJ0Xs41m491tB
0Tus48drVmd019MNrxPHbMVmmP04n05/Wnz6A46v2I5tt3nJtmv606O0WfFf3ea9
t297TFPziZx0tzx6TEczE+PWJRjV9K6HR6rNgnqvZss4r2pN8NdVeluJ45raMHEx
9JWL/uU9RYMHudL0zsWOvd3e8z5r5ss+PSZtbjj9kR/p568/ss6p09bXts3Tvu61
7rX4iIrHHM888enz/YCtcexaK9rRPUW2Y4j0m2PVcT5mPHGGfpE/nHz5iOWTYNDT
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
NT/qH8WOnf8ALLSf5hqf9RFQEq/ix07/AJZaT/MNT/qH8WOnf8stJ/mGp/1EVZGp
1WLPSK00eDTzE892ObzM/h8VpgE5r7NNj1FNJfB11tExnp3fponFNZj1iYmea/h3
dsz9HRrfZ9se22pOp642ucc37JnS476i0eImZ4pz8p9fEc+OUMrqMcYsVJ0uKbUt
3TeZvzePpPxccfsiJ8eroBOP4pdF/wCX3/8Ahs//AM2Ln6W6ZrltGHrXT5Mfytfb
tRWZ/KKz/pRbTZqYLza+DHqImOO3JNoiPx+GYlnbhhzYNFgy5dmjRYdTEzg1E1zR
GSImOZpNrTFvWOfX1BINu6N6c12txYLdb6PDGSeO+2izViPHzm8VrH5zDfdUeyrp
Dprs7PaftW7RevNb7fo8uWsW8/Dbz3R6R57ePPznwq/HaKXraaxeImJmtueJ/CeP
LsyZqX0+LHGDHS9JtNs1Zt3ZOeOInmePHHjiI9Z558cBN9h6B6b3rWXwX682/SRX
HbJ35tLkxxMxx45ydkczz9f6OZjTarpvZ6dv3fq3b8vr3e90uqpx9OOMU8tJpdHq
tZTJTTabJqIiYm3u8XdNfXjzEcx8/wBvH4OVdsz2wZss+6xxht2Xplz0pkieJnxS
Zi0+nyj18eoNl/F7Qf5T7V/6rV/9gsDpv2I9Nb5sldfqva50ltOW+PurotTGp993
c8cTHuuIjxzzM88THjnxFX7fpL7laNLhrpqZpmb++1Gorh8cfq917RX/AOLrnb8t
dROCbYO+L2x8xnpNea+vxc8cfSeeJ+UyCfYPZNtMaHHqNX7Rel8FsnExixZc2W1Y
mOfiiMfMT68+PzR/L0vstuyum6v2/JktaK8ZtNqcdYj693u5/p/e1mTp7U49PizT
n0Exkm0RSuuwzavHHmY7/HPPjn6S5aPb8mmyzfJh2/V1ms17M2tpERM/P4clZ5j9
vH1iQbPJ0RpsdLXnqvYZisTM9ubNM/lEYuZbDB7NNBlrWbdf9K4ZmvdMXy6uZieO
ePGnnz8vp+PHlDtdXs1V493ixenwYMnfSPHynmef3uumG18WTJE0itOOYm8RM8/S
Jnmfy9ASrP0DpcWW1K9YdO5qx6XpmzxE/vwxP9DKx+y+MmOt46v6WiLRExFtxmJ/
OJpzD7vnQ+Te921Op6Z0+3zss24084txpEzXj+VGa8Xrbz5iYjj5cxxM6bqHoLfe
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
3jbOkuvtNhnJhwabDXT6Pe5iY+DzaK4s/mZm0zxafX15qFMjYb/sG49Lbzq9p3bS
ZNDuOlv7vNgyx5rPrHmPExMTExMcxMTExMxMNeAAAAAAAAAAAAAADngwZdVnx4cO
O+bNktFKY8dZta1pniIiI9ZmfktLDteP2V6HBTHi0+59da7mtMcWplrtdeItzNeZ
/STFomLT49eJ7YnvdM6HT+yzpfH1TueHT6vetxxx/BOjyR3Rjr4n3tpj0niazxHE
xHEcxNp7dL1FGq2u2rwZp+/9R67T21O556zH+9eZmbYp8cRMV45iOOJmIjniAa6u
PV6neraXSZ76neJ7/vW5Z7WtPdxxaImeZiI9O/1mZ8TEet1ewnLHSeq0Or6J2ym/
75k4v9/1mCOyt+PNIrMR21rNZmJm0fFXnmeIUBtEajW7xptJtk6jT2z5Ix191Pdl
+LjnmaxE2jxzx/8AWV39Q9caL2R9N4tl2+Jz7zenPucmauX7r8NYickxFfPbxMRx
58/LjkLq6w9t/wDBu3zsHXGp27fOp9TnrXSZsU1x5NBa1p5peaR5p54iZniPHMTN
eI1XUPVPRm+6XJ0Lr9ijHv0xHvNTk1N5prKcWtzSs81niK/rUmOLU5ifk8ZZNXrd
23S2pvmyZ9flvOT3s3+O1/XxP1+kR+EQ9f8AtO1OHpbo72V+17aNPn1vS/W+0zte
v0eG1JyaPc9JmvS9Ij9a3PN7Rz2xbvmfHgET6U6W272Wblj084MWTFuep+7abc8l
49/EzSbRhycxEcTNJ4mv609sTWJ8zvvaV7UfZt01s2w06aprK9U59yrTqDV6nUVt
WsU7ceWYxUp3dtYpNaxaeZ57o7vHbW32j951unpt22Vin8H6ms5bd+Ktp95Sf5Np
jmJ4tHPHniePSZ5qfYdTp9jy7fu2PdL4dfi1decGDT998WL+Vk5v8E2+lfPPzmAe
g/aD1v0rven0nSWp0mr3LLuHbmprNqmmXmLWiKRE93ETWaWnmKzzF/PMKO649m26
dG6vUXnDfWbVW09muw1m+OK9/bEXmI4rbniJifn6cs/bdy2vpzojcdw2qmS2759w
tosWfUTMXppuybRbivwxMx4mszMfk6PZ17TdT0XmnR6zDG59P6iLU1OgyxFo4tHE
2pz84/xZ+G3pPrzAQkXj7TPs763SdCYPaL0lo76zo/JWn3j3N5yTpJtE9trRM99a
zERMxaPHdE+k8Vo4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAFrbZv2j9sWzaXp/qDNj03Vuixe52fesnFfvlY5mu
l1NvHMzM8UyWnmPETP1q7V6XNoNVm02oxziz4b2x5MdvWtoniYn9kw6k63PWaf2h
dNU1Puox9UbTg51eSZtNtx01f/CzPnnJjjiJ54maxzzPHEBBQAAAAAAAAAAAEz9l
XSmHqXqSMusyRg23borq9RkzYPeYbRW0TOPJMzFaxasX828fDPiUMWnvO1Zujult
u6XxzODdd6vjz6y1Mf6SMM1iZreOZ5iL8xHp/wAHk9IvMAxuq+p9fv8ArMnW05fu
2DT6n7rs+nzY4tMTXi03mOJrzHPdzMz8UxHMxXhFOo8FtkxYdB729tVnx11Gut76
L9155mtZ49O2J88zMzM8z8ojZbvvGLU4L5YwcaPbtN/BOjrimPd2tMX7svMcRNpj
m1vE8zaPTxxEcs4p7PdUvTisRbvtFubfOY8RxH4ef2gsza992z2a9GabV7bkwa3q
zcaTaMl61mdDjtH08+eIjiJ9eeeOPFqzz58uqz5M2bJfNmyWm98mS02ta0zzMzM+
szPzcAH3HktivW9LTS9Zia2rPExP1hl6vLF9Fp+NXOWbXyZL6WKTWmG0zEcxHp8U
Vr6R/JiPlDDATjrLq3N1r0jsubVZafedrt90tW02tlyzakfpLWmZ5591HrxzNp9e
EHZG37fm3LPbDgiJvXFlzT3Tx8OOlr2/92sscBzwYMuqz48OHHfNmyWilMeOs2ta
0zxEREeszPycGVtm56jZ9ZTV6S/utVj848seuOfrH48cx5+v14kHo72b+1jfPsy9
D6LFr8H8IX3XUZovservNsMaeaxFu6vmvMTxbtiaz+kmJ/lQ8571m02o3jX5dHjj
Do8mfJbDjrzxSk2maxHP0jh1a7X6nc9VfU6zUZdXqb8d+bPeb3txHEczPmfERH5O
gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAABmbNuufY9002v03HvsF4vFbc9t4+dbRExzW0cxMfOJmGGAlHXG1aOMm
m3zaeP4K3SJye6pxxpNR65NP4iP1eYmOaxzWY4545RdM/Z9qK7zh13SWqvjrg3WO
/SZc1+2un1dImcdomeYjv/UtxHdMTEQh+fBl0ufJhzY74c2O00vjyVmtq2ieJiYn
0mJ+QOAAAAAAAAAAJf7Jtgw9R9d7dptRix6jTY5nPlxZZ+G8VjnjjiefPHifExzH
zbLe+p7bt1L1L1Dp7ZM18szoNsyRF4/X+DurERHn3UX8THickT6xHO36L23F0z7J
N/6lva9dZrK30mniZjiKzMY4tXxE90TbJ5ifSPTxKO7RgttW+7Ht3dHPurarNWtv
MZL47TxaOZiJrXtjjxMeefUGt6wwzs8aPasNo+7VxVzWiKxHfl5tE3mfXz9OUbZm
77pm3jX5dTmmebT8NZnnsr8qx+z/AOrDAAAABtelt+/i1vul3GdLi12PF3VyabPH
wZaXrNL1n9tbT8pj6xPowdfqKavXajPiwU02PLkteuDH+rjiZ5isfhHo6AAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAH3HktivW9LTS9Zia2rPExP1hZPtk6aimn6Y600sYo27qzRW1PZhmOMOr
xW93qcfiI893bfmfP6T5+s1qs3b+qI6j9g25dK6qlLanYNxpu+35K0icnusv6LUY
+Yjnt5nHeZnnzx6RAKyAAAAAAAABsOntFh3Lf9s0movGPBqNVixZL2niK1teImZ8
x8p+oLh9p+24Nl6U6I6PyWxYbXzY51F8MzMVtEdt7x454m2W8/q+eJ+nCu9LuOKm
r6n1UanjU9towZom1vgm/HiYn/xIifl4+USmHtx3OK+0rQTxFq6HR0vOPNea0m0T
e/jj5zHbEfWYiJ5hXmk6frl6c1W65suTHGOe3HSuP9aeaxE8zPpzMx4+nz44BpQA
faY7ZJmKVm0xEzxWOfERzM/lEcvjI27cM2163FqsExGXHPMd0cxPjiYn9sTLv33U
6DV7lky7dp8ml01oifd5LRPxcfFMRHpHPPEeeAYAAAAAAAAAAAAAAAAAAAAAAAAA
mfS3V+wbV0N1Nsu79Mabddx11K223dOZpn0WXur3T3RPmnbH6vHr8+JlDAAAAAHf
odBqdz1VNNo9Pl1epvz2YcFJve3EczxEeZ8RM/k6Gw2Pf9x6a19dbtmryaPUxHb3
45/Wj14mJ8THiPE8x4gGZ/ETqX/J7df8yy/6p/ETqX/J7df8yy/6rL3L2ndV7rnr
lzb9raXrXsiNNl9xXjmZ/Vx9sTPn145/c+6T2o9WaK+e+PftZac0TFvfX95Ec/4s
W5iv/V4Bh/xE6l/ye3X/ADLL/qn8ROpf8nt1/wAyy/6rL1/tO6r3H3Xvd+1tPdV7
K+4y+55j8ezjun8Z5lifx76l/wAod1/z3L/rAfxE6l/ye3X/ADLL/quN+iOo8cRN
9g3SsTMV5toskeZniI/V+czEOX8e+pf8od1/z3L/AKx/HvqX/KHdf89y/wCsB/ET
qX/J7df8yy/6p/ETqX/J7df8yy/6p/HvqX/KHdf89y/6zM2j2pdXbFr8Wt0fUe40
1OKe7HfJqLZe2fWJiL8xEx8p9YBh/wAROpf8nt1/zLL/AKrjTojqPJEzTYN0tETN
ea6LJPmJ4mP1flMTDa9Qe2DrXqnW/fNz6m3HPqpji2WuacdreOI7ppx3eIiPPPiG
s/j31L/lDuv+e5f9YD+InUv+T26/5ll/1WNuHS287Tp51Gu2jX6PBExWcuo018de
Z9I5mOG32z2qdW7R733G+6vJ7zjn71aNRxxz6e8i3Hr8uOfH0hg/x76l/wAod1/z
3L/rA68HRfUGqwY82HYtzzYclYvTJj0eS1bVmOYmJiPMTHzdn8ROpf8AJ7df8yy/
6p/HvqX/ACh3X/Pcv+s54PaD1Pp8tcleoNzm0ekX1V7x+6ZmJBw/iJ1L/k9uv+ZZ
f9Vps+DLpc+TDmx3w5sdppfHkrNbVtE8TExPpMT8k16e9uHXnSufPm2rqncNJmzc
9+SMkWtxM89sTaJ4rzEeI4jxHhH+sOq9d1x1Jrt83KaTr9ZaL5rU7uLWisV5+KZm
ZnjmZmfWZBpwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEo9m24TpeqsGitM/dt2
pbbM9axE80zR2R+Pi01t4mJ+Hjnyi77jyWxXrelppesxNbVniYn6wBkx2xXtS9Zp
eszFq2jiYn6S+Nj1Jrb7nv8AuGuyYfu9tZmtqoxd3d2xknviOfn4tDXAAAAAAAJd
7KfveHrnbtXpeytNJb3uoyZP1aYP1ck/t4txHz5mERb7oi9Y6k0mLLqNTp9NnvXD
mnSZqYr2i1o7Y+P4Zjv7JmJiY4j8OYDZ9W7/AKfqPqrqXdsMU1WHNhj3Ns2Piaxz
jpE8fK0R45/D5tfqN5mvRml0EVnHe+W3PpPfjie7n6x8U8eP8SfPycd/m8bp1Jn4
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
fPnzz9FdLK6uwZdN7GOi6Zcd8V5zZ7xW9ZiZra97Vnz8piYmJ+cTCtQAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAXj/xYv9v+WqOX7tO3zuX2bL4YiZmuDNm+GYj/AIPUWv8AP/xV
BAAAAAAAAAuP2q1vk9k/Q+ScV60rhxVmZjxz7mOPMfWImYU4vPq/b8G/9P8Asu2b
VarHt+j1WnpfUa7LaIrgxUw4++3nxPFZmfX1jj5qa33TaPRb1rtPt2qvrdBizXpg
1N6RSctImYi3ETPHMfiDBAAAAAAAAAAAAGzydParJus6Db+N6y9lclbbbW+WL1ms
W8R2xbxzxMTETExMT6Nbkx2xXtS9ZpeszFq2jiYn6SD4AAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD0b0b/g86j+
btf/AFszzk9G9G/4POo/m7X/ANbM85AAAAAAAAAsX2navUavpXombZNNk0VNDGPB
OLujLW0YsEZK5Inx4mOYmPWJ9PnNdzjtFIvNZikzMRbjxMxxzH9MfvS7qPeNHuvQ
+x1jDEa3T58mn99MR7y9KYcHPfMevxT218eKUiPWJmYnOe9sFMM2/R0ta9a8ekzE
RP8AVj9wOAAAAAAAAAAAAPuPJbFet6Wml6zE1tWeJifrCSbf7Qd20safHrPu2+ab
BNpx6fd9PXU1rzWI4i1vjrHw1nitojmI/FGgG82HN07l12qtv2n3DDpr/FhrtN6f
o55/VmMvMzXifE93MceeeeY3n+5/su4/95+ttqz9n/C/wnS+h45/V7e6J7/SeePT
x9UHASPefZz1NsHdOt2XV0x0xzlvlxU97jpWOeZtenNY44mZ5nxHlHGZtm9bhsuS
99v1+p0F7x22tps1sc2j6TNZjlvNw9ou577mnJvmn0G+T2RSv3rTVx2rETzHF8XZ
f6+O7jzPgEXGw3zWaDX62M23bdO14JpWLaf385qxeI8zWbRzET68TM8Tz544iNeA
AAAAAAAAAAAAAAAD7a82isTEcVjiOIiPnM+fr6/N8AAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAHoronPTL9nzW0pbm2LQa6l449J5y2/0TDzq9
DdC6X7v9n/csnd3e/wBFrsnHHHb4vXj/AN3n83nkAAAAAAAAG41lot0jtfnF311u
qrxWkRfjswTE2n5xzM8c/SfP01lq4Y0uO1bTOeb2i9flFeK9s/nM2/c2+7U7umNg
y102kx4/98YrZ8McZsl4vFpjJ588VvTjxzxP7GkyZLZb2ve03vaZm1rTzMz9ZB8A
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAd+v0OfbNdqNHqae71OnyWxZacxPbas8THMe
J8x8nQ2/WHUNururd732+nx6O+6a7PrbafD+pinJktfsr+Ed3EfsBqAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAehOgtTbP7AN0paIiMO
j12OvHzjtvbz+dpee3ob2Yaf717Ct+pxzxotxv8Arcfq4b2+k/T8/wAPV55AAAAA
AAABvd3yWnpXp+k2maROotFefETN45nj8o/dDRMrV2/3poaRnvkr7u1pxzfmMdpv
aJiI+XMRWfzYoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALx9lu63y+x3q3TV78f3bSamvdFv
FovhvM/LmPE8T5nn8PPNHLj9k396zrr/AKNl/sLKcAAAAAAAABaPT/Qmz7h9njqv
qzNp723vb930ui0+aMtorXHkjm3NeeJn4fE/86fw4q5Z/SOTPufsP6z2/R6TPqcu
iz4dbqbUpNq48Nr447vHPpOOeeeIiJjz8lYAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAtb2R
aqZ6E9oOmtkjiNvtkpj8c+cWWLT9flX+j6qpT/2Wa7Bg23rLT5L9ubPsuo93Xifi
7aWmfPy8fVAAAAAAAAAAb7pzrHX9NaTXaLS6jPj2/c4ri3LT4rxT71graJ93Nu2Z
r8/MfWPHhrd5y6LPu2sybbhyafb7ZbTp8WW3dalOfhiZ/Z+M/tn1WD7DPZ9077Rt
Z1Pod83f+CNTptozavQZL0m1LZacTxM91YifSI5nieZj14VkAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
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
pPqPWZNRTHqtB92y4sPEd+Stsk0t+PbHdXnj5zVoHfo7395OGNT91xajjFlvabdn
b3RPxRWJmaxMRbjif1Y4jmIJ0Oorqsumvhvj1GLv95iyR22pNImbRMT6THE+PwB0
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMjbtu1O7a3Fo9Hin
Pqcs9tMdeObTxzxDHTb2f5K7Ds3UXUs2iuq0eCuk0MWntn3+bmvfS3ztSsWnt4nm
Jn09QQkAAAAAAAAAAAG46ax4tTnzaXU2y00+qrGGtqd3ZXLM/o5tETHPpPET/wDW
OOybbkt1BpdPfHgzZceefeabPM9tuzzNbTET4niY8fj+DXabVZNHlrlxTFclZia2
msTxMTExMc/jEf7Sm/WOWnUeDT9Z7bNMGbupi12C1q99NRWI/SRXxzW0TX0j1559
QWf1j9sLduq9Dtel2/Z9o6ZxbDo6aXa8ek0lYr20vz8UVrHxTHEfFzHj1h571+sv
uOu1GqyxSuTPktltGOvbWJtPM8R8o8+iR6HpXT7zbDGLW6eNRqrReMdMvffFEzz2
+6pTm9or8q8efER489Gi6A3bcd21W26amLJrdPhnPbBOTsvaOOe2KW4t3f8ANmIm
Pn8gRwfcmO2K9qXrNL1mYtW0cTE/SXwAduLHhthzWvlmmWsROOnZzF/PExzz48ef
T5OoBmW2XcKbbTcbaDU12+89tdXOG3upnmY4i/HHrEx6/Jt9nzdM6ytNPumn1e3T
FYidZpb+9mbRHmbUt8p+kfX14jibe9kG/dS+x/Jrt76R6h0e87R7rLe2n0vPv/1Y
+O2G1Z+lYmsz9J9YiYDz8Lq3Tp3pnqbdtLpup9Dl9mm7aus2ruMV9/oc1uK/FeIm
O2fPExXjtieZ77fDNZ9U7Xj6Z3a+24dZt286PFf3mPWaK8XrqK8zxMzE91fHiacx
xxz/AM6Q0I+0pOSZiJiJ4mfimI9I5+b4AADZ7Fs+PfM2bTRq40+tmnOkw2xzManJ
zEe6i0fq2mJnjmOJnxzHPLX58GXS58mHNjvhzY7TS+PJWa2raJ4mJifSYn5OD7ky
Wy3te9pve0zNrWnmZn6yD4AAAAAAAAAAAAAAAAAAmfWejx73se29W6fLky21M10W
41yREe71VMdfiifHPvKx3+InieeZ5niIYk/QnUen2fXZ9v3P4th3WtdLr+K91sVJ
nxmpHE83x8zaPE/lPEwEd1FcNZpOG02rNKzaLetbcfFH7+Zj8Jj58upMfaZ7Ntz9
l2+xotVams23XYa6rbN1xY/0Ov0t+LY82OZ545jt5jnmOZifxhwAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACdddauuydL9P9K4MmC84KTrtfOLs7vv
VrWj3eTjmYvjjms8z5iY5iOIa3oHHptBun8O7haKaLaonU0pa01nUZ68TixVmIme
Zt2zPieIiZnw0O67rq983HPr9fnvqdXnt35Mt/WZ/wDhERxERHiIiIgGKAAAAAAA
AAAAAk3s+3zBtO+00+vrp77Tr+NPra6ms8RjnxNotEc1tETPExx+XrEZAX77O+pN
x9i/Uur0WPFgyaiIvk2nX5aUtNsVueL45msxzxMzPE93nxMRD71d0nr9f/Cm8abP
SmauSNVj1+bFE2z+9488zT1mJiLTHHH48cIT7Ous9HqtJPTXUmuz6fb7TF9v10cT
9xzxFuOef5Fu7ieZmIjnxxMzFlZfadh9nex7Z0l1ftWfcdHzOo1MaO3b728WnttS
/wAPwz45j1j08cfEFU77XdPaD1VtG232rT7fqp/3r77T4JpTLxPN8vpHMRHNvHpH
7V6aD2a+0v2N+zPqnWfxHp1p7N9Nq8un1HUmmwxkxRWIrzNfWa4ptPFrzExxNome
OOYZovbXtXXe6fcNz0Wm6bwY4iu3arTz2Vwdvp3z8uYiOZmfWPWPEx689gnUOg9p
Whyey72o9bbj057KcGltq66fbtXODFut7XrPucmWtZv2W+K81taf1eIn4uZDxT1J
1R7M+tr7dGr23c+ntZhx0wajLo5xXxzaImPE1rPOOsVrWPhmeIjjx4i7/ZL/APs7
83t76Kv1r7Ot03Hqbp/71fQ/ds1NPoM9c1K0m8xfLk4vWO6fWlJ8x68eaB6y3Ho3
prd+o+mdJs9Nft2Dc8ttButYic19NN5nHHd8NvFe2OZmefPiHqX7Af25tv8AYJqM
vTOfQTk2bWTbnRzNcc3vFre6tjvMz8c90Ras/resTM8A8+e0P7KHUPQW7ajQbnp9
x6Y1Uar3GHT9UaG+krqKzM1rbDniJpn5mIiOyPn54nxOt9of2VPbZ7DMf3/qHoTq
HZdHak1nctLhtl08Vt47b5sU2rTmP5Npifw9X799C+172e+3vYcum27V6Pd9NqIn
Hn2ncsNe+0c2+G+K/MW8Um3HnxxM8cu/259Ja/qzoDX02zqjWdJa3TUtljW6fHOb
FfHx8ePNh4nvpNefMRzXjnzHdWwfzsbR7VYp0zGxb7tdN+0OPH24Iz3is4bViYp2
zWsTERHjnnniZ4n5MPrbpDZ9r2Tat82Hcsmq27Xzan3fWTWNRivWI7omI454nmJ4
jiPh8zFol+wX2gvsLdFe3TpPZd11Gw7NoOp8kUw5utej7xj0eor8UXz6nHWOJ4mI
mck9/juibRxWr86fb59gL2hewTXYMt8mk37a9RabaDcsPbXDraxMcTTm1q+az3TW
81njniJjiZDzAJ1170toNPpMW77fhz7NkyxFtTsm5VnFlw2m0xzh7oj3tOY/k8zX
xM8czFdD0dodi1+8dnUW5Zds26uO1pyYMc3ve3iIrHFbceszzMT+rx8+QaMbfqvT
bNpN8z4th1efXbZEV93m1Fe20z2x3fKPnz8o/wDjOoAAAAAHPBSmTPjrlye6x2tE
Wydvd2xz5nj58OOSsUvasWi8RMxFq88T+Mc+QfAAAAAAAAAAAAAAAAXZ7Kva109r
+icvs29pWLJm6R5yZ9r3XTYu/VbNqLc2m1IjzalrTPNfrM/XxAfaF7M909n2vj30
03HZs/bfQ73o4m2k1mO0d1bUv6RaY9aT8VfMTCIp97O/bBuHQ+l1e0a/R4OqOlNb
ivi1PT+6WtbTTMxPGTHxPOLJWbTMXpxb188+YCAiwbdFbB1vuWaOjdzjSZ7xlzY9
m3q8YcnbWJtFMeaZ7L2n0rWZi0/jKGbzse4dPa62j3LR5dFqa8/Blrx3RzMd1Z9L
V5ieJjmJ48SDBAAAAGRbbtRiw6XPmw5NPpdTMxi1GXHaMd+2eLTWePi4n1454fNZ
TTUyxGlzZc2PtiZtmxRjmLfOOItbx+PPn6QDoAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAB9yVil7Vi0XiJmItXnifxjnyDJ1OvnPpdPp6U9zix1+KlLT23vzPxzH
+NxMR+XyjxGKAAAAAAAAAAAAAAAC6PYl1h0z1N7j2e+0rcY2zpHWX40++2xWyX2j
L237ckRWJtNZtNefE+I4n4fNaXAWR7YfYZvPsj1mnzTqtN1D0zr4tk23qHa7e80u
qxxbiJm0cxW/pzXmYiZ8WtHlk+yv225eh/daHd9HfeNnpb4ccZJrkxV+cVn5x9I5
jifw8O32PfaO6k9keH+CZ02g6o6Oz5YvremN7w++0mprMx31/wAanMR/JnjnzMTw
k2s6D9nXtwyazdOg900ns9321ovl6T6j1tKaW972iIrotTaYm1fX4Lx3cz44jjgJ
j7G+lPZXq9637q7ftP8Afui9ZjyaHJfW287RnyzxXL5rPdPM14mYjt7ufnHEG9of
2Ydw6c2Tcd42rPivoNqtNNbbV67Fb1n9FbHasRE1vWJmOePpzz4V1n0/WHsr1es0
W4bfr9prknJptRo9fgvXDlntmtomJ+G3ifEx+U8Lc6c9sO07z7INw2HdqY9HpdJG
OM33eMeLU5+aWrGPFM8c0isWjt5+s+OQS37PftG2LW750909pOr9RsGsyZIxRue7
Tk5xVtaZmLXpE90ViYrx4iYiPSOePamm+0p7Y/s+dTxouqNZp+rNr+Ce22WmXT5I
7J4ri1GOPhmOY5r54mseOJ8/m5tftn2Xbt6t9x2rW/cM9qVtprVrkvMxPw2rzbxb
nzxzPn5+nFr+yD7WG/8AsM9u+m3PJgx7Vt+PFF40u4TEzes14muTsmYjurNvE8zW
eJ5+Uh+keydcfxI6Sv7UPZDnncugqZZ1vVXQHw2ttfdji2W+liKzbH2zzaaRPZx3
THw17ayXpL2qezj2uWy4tFpr7t0Zq+3DuXT27abHXHtGW0193qIpMzWlJte0Takx
EW7pi0z2w84ewv2i6v20e1vd6eybeY2DYerp433S440+b7rPN7ZrYcV+I8VjiJ4m
YjN6eY4hX2humv8A7FHWO3zXfMm4Vz4sutyZIxW9zTSzmrhwUzUrMTa8zOSfHMfB
MxxMeQjPth603f7Bn2o9XsvU/Tm39Z9A6zHn1vT1t2wUzRTQ563rOCZinNpx5O6s
1nzHda08+8iVefaO+wrl2+dm3romt9Jl37QW3fRdMau9Yv8AdprGTjDPdMRbm1v0
U+fMcRxFrLX+2z9p/on2y/Zr6K0+96HHuPWu0ayupw6nHeb4ZvWnZNJi/wDwlck8
e8jmfGOZ7uZiFWdM7hu3tF+zBvft51e9avf+sOi+pMei3Tb9RqLUjR7bmrWuDNpY
iZ4vXLmisTPmKRljmOObB4o3LbdZs2v1Gh3DS59DrdPecebTanHOPJivHia2rMRM
TH0ljv0360+x3vH2tfYjsHtL1up2fpzrXWbLTcts93M8bto8eGbZMWWIiIjPSe2a
2iIi0ZJ54is9vhTfvs99W9Jb9t22b7pY22Ny0P8ACWh1F+Yx6vTcT+lxzbt5rExx
M249J45BWYmer9lG96SclslcdNPF+3Hnyd0VyxxzExMRMTz+35TxzHl229luutpc
M0txmy+MczFppmtzETFfh8cT48d3P/N9AQcTTB7MdTGKttVrKYbW80imObRavpzz
Mx84mPyZeD2W5tv1lY3TJelYt3Rh93ak5KfKZmeOOZ9eOfT1BAHfrNDqNvyxj1OG
+HJNYvFbxxPE+n+37YTrX+zDLlyxqMNZ0W22jtpmtW2TvvzM8eeI8eY9Z/V+vLHx
+za2K9b03SaXrMTW1cPExP1j4gQYWhh6L0NtPhrrI+95qd83zeaTkm1uebTE8zMe
nmfnLX632caXNfu0uqyaeJmZmt698R9IjzE+Px5BX4nGs9m8VwTbTau98lcfPu70
j47xHynmOIn8eePq1us6A3DT6OM+O1M1oxxe+GPF4t86xxzE8ft8/QEZEqxdB7nq
9q0+XT7de18tu7Bn9741VZniIx1mI9PHrMT5nx8oxsPQe75aZLWxY8U0jmK3yRzf
8I45j9/HqCPDeX6O3LT67btNqcXuJ1vM0nmJ4rWZi0+vniImfE/h68w01MGXJiyZ
K472x4+O+8VmYrz6cz8uQcAAAduCMExl99OSs9k+7nHET8fMcc8z6cc+n4eoOoZl
cWgya+1PvGfDpJn4Ml8UWtHp+tEW+XnzH09PJnw6DHfNXHq8+WKx8Fvu8RF58/8A
P5iPTz6+fTx5DDHfpdPj1Hd36rFpuOOPexee79nbWf6Xbk0OClLWjcdNeYiZita5
eZ/COacAwxkbfo41+ojDOowaaZiZi+otNa/s54nj82Tn2LNiy2pXU6LNWPS9NXji
J/fMT/QDXN9oeud70Wnrpba2dboqxSsaPX0rqcMVr+rEUyRMV49Ph4l14+jd4y0r
emki9LRE1tXNjmJj6x8Tl/Enev8AkX/92n+sDa0622TW6zJn3bozbM/NYrWm3Zs2
jiJj5zFbTWf3R+1r9VuXS+o1GTJj2HcdLS08xhxbrSa0/CO7BM/vmWvydObpi57t
v1E8Wmvw45t5j19Pl59fSfk7NV0ru2k7e/QZbd3PHuo95+/t54/MGdp946a0eLP2
dOajWZr14xzr9ym1Mc/XtxY8cz/6TB/jJqsPjRY9Ptta5Pe450uKK5cU/wDNzTzl
4/CbtUzMmy7hipa99DqaUrEza1sNoiI+s+AY2fPl1OW2TNkvlyW9b3tNpn85cAAA
AAAAAAAAAAAAAAAAAAAdubSZ9PTHfLhyYqZI5pa9ZiLx9Y+vrH73UztFvm4bd2Rp
9Xlx1pz24+7mkc+vwz4+f0BgiR4Ov94we7n3uLJemSMndkw1nuiP5MxxxNfy5/Fm
ZfahuuXHWltPoIiIrETXB2z4548xPM+vn6+OfSARAb3P1lrNZqPeanT6PU0iOKYc
2CLVp6czHz+X1/8Agwcu7xl0mfBGh0eOct5vOWmOe+vM88VnnxHy4j5AwAAAAAAA
AEq9nns13r2l73j2/asVKU8zl1eovGPBiiI5nuvPERPHy5/HxETMcehNl2DdNRq8
/UW7xtui0sUt7qsTOTPzbiYrERM+PnxHMc8+kSkvU3tq1GXacez9NaKnT2gw2tX3
mmyc3vTnx2/DXs5mZtM/rTM+seeQgvU+z4+nuoNftmLVxrq6TLOGc9cc07rR4tHb
PpxPMfOPHiZjy1gAAAAAAAAAAAAAAAAAAAAAtHpr7SXWvT/Run6O1eo0XUvR2nta
+LYd/wBHTVabHa015mszEXpPFYiJreOPlxMRMYm6dRezfqTJOpy9Mbr0zqLZMmTJ
i2fWVz4L91uYitcsROOtY8RWJn9vpEVyAkO36PbNR1BknbtxnTYceWt9F/CdK07/
AJxGS0W7a8TERNufPrxHosWmwX1u3arTbz0DlnJat5/hfZZ772mPMXrS0/FzxzzF
vPPiPKmWVtu7a7Zs9s2363UaHNavZOTTZbY7TXmJ45iY8cxHj8AWT0H191L7AOtt
v1k4tZtWfBFtRh9znmuopS/6vbes8Rxasc+Of1o8czC2td7VMv2gfann9o28b7fT
W23Hj1m//eLTbNbR1maRg0lOPjtWl8kz3eniYm3bxPn7pP2m7z0jfXTgjTa2uumb
aiuuxe8nLaf5VrxMXt8/E2mPitPHM8snF7Ta4e/t6R6XnvtN579vm3mfpzfxH4R4
Bke1/J0rn646mzdIZc+TpjU7lk1ezzq7xOorgyT3dmWlfhpMRMRPjnmsRHdHmPQf
2ffbz0J7O/s3+2n2f2zZ4z9c4qafRZNwtWJ001i1YvkiI8+LxaO3nzXjxzzHm3Rd
W9P3y5sm59GaLU2t29kaLWZ9NFePXmO60T8vTj5+vLtnqHovNk7rdI6nBHvcdu3F
utrRFI/WjzXnz4/H6WqD9NugPtt9DdIfZU6d6ex6jSafeOmdJi2vQanVzXJTc8E1
ti1MVvxE4be7nnj4pm3ZxFo5fd26V2D7VHsV6N1Wa2PZ9l9l+25q7tvu6845z5cn
bGLBpu2ecnNazFeZ7ZnLWIiZ4h+c1N99lFcuS89O7xetuOKTkninH04zc+fxmVg4
/tNbFh6KxdI48W+Y+m8WqrrabfSKRjrmrWK1vHGXnmtY4jz4jmI45Bk+0ne9p2Pq
be+ndk3am89J483vdp3LX1rj1E4uO6a8Raf1I8c/4s8fKUEvv+34sPvcmswY68Wt
ETlrM2rEzHMREzzzxPp5/Pw57z117N+q+pMe57vte957WrTFkpE0x0msc+fhvzE8
T8uf1Y8evOBn1Hsmy6y0U0u64cc17omk2mkT6cebTbn5/T8fkDI03U21aqk3pr8F
YieP0luyf3W4lssO9V3LDbFh18arFSYtNKZu+tZ44ieIn6RxH4Q0v/3Tf/zb/wB5
y0er9lW3a7Dmrg3HW1m892PURM0pXsmPTxz5iPx5nn0jgG3xe0bDoNHm2+m8Yo00
47Wtjia3jtnxMRPE+f8AmxPPz4YH8Y9r9/7r+ENP3dvdz7yO3jnj9b05/DnlgaHa
fZdOoyX1G+a/3OWZvTFbT5K2w8W8Vm0VnnmPHpPiPWJZui2v2R49PFc28a3Lki1o
77480TMd08fq4+PTj/5R6Aycu66PBpaam+qxRp72ilcsXiazMzx4n9/7OJ+jBnrD
Z64oyTrqds8eIraZ+fy45+U/0fWOcz+DvY9/+aav/wBHP/2brwbV7IMWKtLbzrc1
o9b3pmiZ/djiP6AdNep9q1N8uCm448eSImO+fhiPlzFrR2z/AEuOff8Aa9H7nLl3
SmTsrOPil4v3TPE91q0j1+H14iPM/V80u2eynR6fHTUbxrNwyzficuPDlx8Vn5zH
bx4/Dz6eGHrY9muHLhrpp1eppXujNa85ccXn5TTxPEc8z5j6A22t6s0WLSUi25YM
uLFPw4/f93bE2ju7axzP4+I/bx6tfbrjYq6jDbJpb7vWndkjFXFMRS0Vni088T49
fH0nzDD12o9nOkpjti0Os1s2iJmuDVXiac/Ke/HWPH4c+ru3XF0BodR7jDpcurme
YjUYNfNsdJisTzPNazMefl6zExHkG/0u89PavcdtjW6muoy4MkzjnHnrbik+Jx1j
mOJtNv8AG+czETMId1Lq+m8+5ZPuFNRqMmbURFowc/pKReOa2jmImZjz8PraInlt
a4OgZpgi2hvx7us2zU3LiLWmfnWYm1Z8/TiIjzPPLB1/8SNuz4otpMupp7vm9dNq
ptNrc8eLelfrxPPiJ8+YBE9XsG4V1WatNu1MUi9orFcNpjjn5ev+mf2y57fsW5V1
VMs7Xny0wzGW+PJjmsXrExM18x55+nmfwSnnonBj1WbJs+tyY6ZKxFK7phm1Ymse
IiJ5vHPM8xE8c8T6OO7X6I02j0mXTbdntfNMTan333lqV7ZnzWIjiee2PM/X14BH
N4w4NRvmeZ0up27BekXphrpo7oiKxzPbzERHi088/JmabctDunT+37JfFeNZXNxj
1Hu68Um+SOfPPMx2/KfHP72+meh4vFP4E1nMxM/998PHjj588fP/AG4cfedDe/8A
dfwHre7t7uf4Vw9vHPH63PHP4c8gwPaPfp7S6rRbfsWGLfdMHudRqZp2zlyxMfH4
nzMxXzE+ndPjn0hixu3oj/8AJNX/AO2MH+s2Wo9llNZ921mi6Z3rFp81o4x21eny
VtHy+cWrWeJ8zPz9Y8ArbbdFodVS9tXuUaKYnitfc2yTP4+PEOjXayNbfHaNPg00
UpFIrgrMRPHznmZmZ/Fc+n6E2TU49PpsfQ+svbNecddXTeMd+Jj4piZrkmsfD8uO
ePTmWq1Xsk3WmOcWPoyb5YvE+/xbxTsmviZr228/hz+76gqUXDf2WXxblGC/Rus7
JmJr7jX1yVmvHn9JNqRE+J9a/T1Y+o6S2nRa2+k3Do/X01kRa9MWn3TDafdVjxa0
RPiYrxz+/wCYKmc8GfLpstcmHJfFkr6XpaazH5wsWfY7vGfHiy6PYNdnwZKRet8m
4abHM8+Y8eflw2+3+yLPptBM6no7c9ZrZ9azvGmpjjzPpMefTj1ifMAqjU7lq9ZS
KajVZ89InmK5Mk2iJ+vmXRkyWy3te9pve0zNrWnmZn6ytzS+ynXzrYnU9DZ66Pme
YxbxinJEcTx5m0RPy+Th1D7Hddk1967T0pr8elpM1i+TdtP+kj5W7ZiZr+zmfl6A
qUWxtnsl3bRar31+kdXmiuG0RjzbnpclbZePE8cV4r+E8/v4mOOp9k265tFGPH0R
nwannznrvWGY45+VZ54+XrM/P8gqkWnp/ZRumkx6vJq+jM+aJjupNt6wUph4555+
cx6es/L1aePZzr9flpbBsnu/e8dmGm86bnmfSOLc25/CQQQS3eel9J0xbFi3vQbr
t+pyd3GOMmK8TETxzEx6x+PH73HR9P7duEZZ02379njFijPf3eKk8Y5niLenp+P4
T9JBFBLd26W0+wWxxue171o+ccXvNopMV5niOJ44mOefM8ekePLZbPsOHQWx63F0
31Bqo7o91lyaObVi3PEcccRM8zx8/MRx5BABMsm0bfi3G2a+z75S9cs3tp7aWsUi
eeZrNePT5cMvc+l9PusxbTbNumh1l7xi91XHjiO7uisR7qbRaJ5558xHpPHiZkIE
Jxquha6PVV0+XY+pYzX57K101bd/EczxMRPPEevHo44+icGm1Vc2v2bqnBttYj3k
10Ed8Tz8rTxHn08x8+fPoCEiwcnQWknW2imxdY10fM9t7bdE5IjjxzHiJ8+PX8fw
Z2m9l+h1VJvTa+rqxE8fpNvw0n91skSCsBPM/QeOuW0Ydg6tyY/la+3xWZ/KIn/S
aXoSkazFbP0/1VGmjmb1jbu6Znxx/i+PWJ8/P18eQgYnWs6AjJmrfTbN1Tix2pab
4rbRM9l+J7Yrbv8ANeeI8xzxH4+OOu9n1/daeul2nqX3lcNZy3ttFpi+SeJmIjvj
iI5mOfnxHj5yEHEqt0HrdN7m+o2zfa48mT3cV/gya2tPj4Y5t6z8vH19eJdGl27p
3TZLRuWs3WlZxxasYtHSl4tFu21Zi1+J8xPnn+T9fEBHBvdww9N1iY0mbdOLRE0y
ZseKfn57q1t49J+f0l2RXpP7xhrOTefcTTnLf3eLurf6Vr3cWj8ZmP2AjwzNPi0E
TeNTqM/MTaK/d8UWrbx4tza0T6/Lj0+nyzsdenaUrF8m6Zb8R3Wrjx0jn58R3W/Z
6+fXx6A0oztXh2/Jr7U0Woy49LNpil9ZTiYrxHEz2d3mZ58RHjx5n5ZGh0+xTmrb
Wa7XxgieLVw6WnvJ8T5jnJx4mI55+oNSN5v+k2HT4sM7Vqdwy5LV7prqsWLjieOP
NMluJ9eYmOfRpLRWIr2zMzMfFExxxPM+nnz44+gPgzNZt33fT4tVjy48mmyzMU5y
4/e+PXux1vNq+eeOfXxPzdWCmmtWvvs2XHbu4mKYotEV49fNo88/L+n5A6AfYivZ
MzM9/McRx4mPPPnn9ny/+ofB34b6auLjLhy3yd0T3UyxWO3xzHHbPn188/OPHjz1
55xWy2nDS+PH8q3tFpj84iP9AODnlwZcHZ73HfH31i9e+sx3Vn0mPrH4uD7fJbJP
N7TaYiI5tPPiI4iPyiOAcsHuvf4/fd/ue6O/3fHd28+eOfnwzN3zbbkzdm2abPhw
Uvfty6nJFsmSkz8PdERFYmI+jAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAf/9k=
__AAMEND_V10_B64_img_iphone-frame_jpg__

echo "Verifying file sizes..."
sz=$(stat -c%s 'img/iphone-frame.jpg' 2>/dev/null || stat -f%z 'img/iphone-frame.jpg')
if [ "$sz" != "36758" ]; then echo "ERROR: img/iphone-frame.jpg size mismatch (got $sz, expected 36758)"; exit 1; fi

echo "Staging and committing..."
git add -A -- . ':(exclude)apply-aamend-update-v10.sh' ':(exclude)apply-aamend-update-v9.sh' ':(exclude)apply-aamend-update-v8.sh' ':(exclude)apply-aamend-update-v7.sh' ':(exclude)apply-aamend-update-v6.sh' ':(exclude)apply-aamend-update-v5.sh'
if git diff --cached --quiet; then
  echo "No changes to commit."
else
  git commit -m 'Fix admin nav button (single password prompt) and Pics caption visibility; add iPhone-frame treatment for Pics slideshow on desktop'
  git push
  echo "Pushed. Live on aamend.com in about a minute."
fi

echo "Done."
