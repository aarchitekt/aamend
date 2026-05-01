import { useState } from "react";

const code = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Aaron Amend</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500&display=swap');

  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  :root {
    --black: #1a1a1a;
    --gray: rgba(0,0,0,0.55);
    --light-gray: rgba(0,0,0,0.35);
    --font: 'Inter', -apple-system, sans-serif;
  }

  html { font-size: 16px; scroll-behavior: smooth; }

  body {
    background: #fff;
    color: var(--black);
    font-family: var(--font);
    font-weight: 400;
    overflow-x: hidden;
  }

  /* NAV */
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
    color: var(--black);
    font-size: 1.25rem;
    font-weight: 300;
    line-height: 1;
    opacity: 0.75;
    transition: opacity 0.15s;
    cursor: pointer;
  }

  nav a:hover { opacity: 1; }

  /* SCROLL ARROW – fixed overlay */
  .scroll-hint {
    position: fixed;
    bottom: 2rem;
    left: 50%;
    transform: translateX(-50%);
    font-size: 1rem;
    color: var(--gray);
    text-align: center;
    animation: bob 2s ease-in-out infinite;
    pointer-events: none;
    z-index: 50;
    transition: opacity 0.3s;
  }

  @keyframes bob {
    0%, 100% { transform: translateX(-50%) translateY(0); }
    50%       { transform: translateX(-50%) translateY(5px); }
  }

  /* HOME PAGE */
  #home {
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    align-items: center;
    padding-top: 12vh;
  }

  #home h1 {
    font-size: clamp(2.5rem, 8vw, 6rem);
    font-weight: 300;
    letter-spacing: 0.25rem;
    text-align: center;
    color: var(--black);
    margin-bottom: 8vh;
  }

  .projects-feed {
    width: 100%;
    max-width: 700px;
    padding: 0 2rem;
  }

  .project-item {
    margin-bottom: 4vh;
    cursor: pointer;
  }

  .project-item img {
    width: 100%;
    display: block;
    transition: opacity 0.2s;
  }

  .project-item:hover img { opacity: 0.85; }

  .feed-image, .feed-video {
    width: 100%;
    max-width: 700px;
    padding: 0 2rem;
  }

  .feed-image img, .feed-video video {
    width: 100%;
    display: block;
  }

  /* BOTTOM NAV */
  .bottom-nav {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2.5rem;
    padding: 4rem 0 6rem;
    width: 100%;
  }

  .bottom-nav a {
    font-size: 1rem;
    letter-spacing: 0.12rem;
    text-transform: uppercase;
    color: var(--gray);
    text-decoration: none;
    font-weight: 400;
    transition: color 0.15s;
  }

  .bottom-nav a:hover { color: var(--black); }

  .bottom-nav .email-link {
    font-size: 1.5rem;
    letter-spacing: 0.15rem;
    color: var(--black);
  }

  /* PROJECT PAGE */
  .page {
    display: none;
    min-height: 100vh;
    padding: 8rem 2rem 6rem;
    max-width: 700px;
    margin: 0 auto;
  }

  .page.active { display: block; }

  .page h2 {
    font-size: clamp(1.5rem, 4vw, 2.5rem);
    font-weight: 300;
    margin-bottom: 0.5rem;
    line-height: 1.15;
  }

  .page .meta {
    font-size: 0.75rem;
    letter-spacing: 0.08rem;
    color: var(--gray);
    text-transform: uppercase;
    margin-bottom: 2.5rem;
  }

  .page .description {
    font-size: 0.95rem;
    line-height: 1.75;
    color: rgba(0,0,0,0.7);
    margin-bottom: 3rem;
    max-width: 520px;
  }

  .gallery {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }

  .gallery img, .gallery video {
    width: 100%;
    display: block;
  }

  .gallery .caption {
    font-size: 0.72rem;
    color: var(--light-gray);
    letter-spacing: 0.05rem;
    margin-top: 0.4rem;
  }

  /* CV PAGE */
  #cv-page {
    display: none;
    min-height: 100vh;
    padding: 8rem 2.5rem 6rem;
    max-width: 700px;
    margin: 0 auto;
  }

  #cv-page.active { display: block; }

  #cv-page h2 {
    font-size: clamp(2rem, 6vw, 4rem);
    font-weight: 300;
    margin-bottom: 5rem;
  }

  .cv-section { margin-bottom: 1.75rem; }

  .cv-section .date {
    font-family: 'Courier New', monospace;
    font-size: 0.75rem;
    color: var(--gray);
    letter-spacing: 0.03rem;
    margin-bottom: 0.2rem;
  }

  .cv-section .place {
    font-size: 0.95rem;
    font-weight: 400;
    color: var(--black);
    margin-bottom: 0.1rem;
  }

  .cv-section .location {
    font-family: 'Courier New', monospace;
    font-size: 0.75rem;
    color: var(--gray);
  }

  .cv-divider {
    height: 1px;
    background: rgba(0,0,0,0.08);
    margin: 2.5rem 0;
  }
</style>
</head>
<body>

<nav>
  <a id="nav-back" onclick="goHome()" style="display:none">−</a>
  <div style="flex:1"></div>
  <a id="nav-cv" onclick="showCV()">+</a>
</nav>

<div class="scroll-hint" id="scroll-arrow">↓</div>

<!-- HOME PAGE -->
<div id="home">
  <h1>AARON AMEND</h1>

  <div class="projects-feed">

    <div class="project-item" onclick="showProject('capella')">
      <img src="capella_main.jpg" alt="Capella">
    </div>

    <div style="height:6vh"></div>

    <div class="project-item" onclick="showProject('twobarns')">
      <img src="scheine_main.png" alt="Two Barns">
    </div>

    <div style="height:6vh"></div>

    <div class="project-item" onclick="showProject('roubaix')">
      <img src="Roubaix_main.jpeg" alt="ENSA Roubaix">
    </div>

    <div style="height:6vh"></div>

    <div class="project-item" onclick="showProject('groninger')">
      <img src="groeninger_main.png" alt="Gröninger Hof">
    </div>

    <div style="height:6vh"></div>

    <div class="project-item" onclick="showProject('plancomun')">
      <img src="Pantin_main.jpeg" alt="Plan Comùn">
    </div>

    <div style="height:6vh"></div>

    <div class="project-item" onclick="showProject('beten')">
      <img src="beten_main.png" alt="Seminary – Wittenberg">
    </div>

    <div style="height:6vh"></div>

    <div class="project-item" onclick="showProject('mosterei')">
      <img src="mosterei_main.png" alt="Cider Factory – Thuringia">
    </div>

    <div style="height:6vh"></div>

    <div class="feed-image">
      <img src="atrium_main.png" alt="">
    </div>

    <div style="height:6vh"></div>

    <div class="feed-video">
      <video src="vid_main.mp4" autoplay muted loop playsinline></video>
    </div>

  </div>

  <div class="bottom-nav">
    <a href="#" onclick="showProject('archive')">ARCHIVE</a>
    <a class="email-link" href="mailto:aaron.amend@icloud.com">EMAIL</a>
    <a href="./AA_CVP_PRINT22.pdf" target="_blank">↓ PORTFOLIO PDF</a>
    <a href="https://aamend.com/pics" target="_blank">PICS</a>
  </div>
</div>

<!-- CV PAGE -->
<div id="cv-page">
  <h2>CV</h2>

  <div class="cv-section">
    <div class="date">August 2025 – now</div>
    <div class="place">Plan Comùn Architects</div>
    <div class="location">Paris, France</div>
  </div>
  <div class="cv-section">
    <div class="date">July 2024 – September 2024</div>
    <div class="place">Bangkok Tokyo Architects</div>
    <div class="location">Bangkok, Thailand</div>
  </div>
  <div class="cv-section">
    <div class="date">January 2023 – July 2023</div>
    <div class="place">Nicolas Dorval-Bory Architects</div>
    <div class="location">Paris, France</div>
  </div>
  <div class="cv-section">
    <div class="date">March 2021 – August 2021</div>
    <div class="place">tiburg Architekten</div>
    <div class="location">Vienna, Austria</div>
  </div>
  <div class="cv-section">
    <div class="date">July 2019 – October 2019</div>
    <div class="place">Jourdan Müller Steinhauser Architects</div>
    <div class="location">Frankfurt am Main, Germany</div>
  </div>

  <div class="cv-divider"></div>

  <div class="cv-section">
    <div class="date">July 2025</div>
    <div class="place">M.Arch – ENSA Paris-Belleville</div>
    <div class="location">Paris, France</div>
  </div>
  <div class="cv-section">
    <div class="date">September 2024 – January 2025</div>
    <div class="place">Exchange – National Technical University</div>
    <div class="location">Taipei, Taiwan</div>
  </div>
  <div class="cv-section">
    <div class="date">October 2018 – April 2022</div>
    <div class="place">B.Sc. Architecture – Bauhaus Universität</div>
    <div class="location">Weimar, Germany</div>
  </div>

  <div class="cv-divider"></div>

  <div class="cv-section" style="font-family:'Courier New',monospace;font-size:0.8rem;line-height:1.8;color:var(--gray)">
    Archicad · Autocad · Revit<br>
    Cinema 4D · Rhino · Blender · SketchUp<br>
    Adobe Suite · AI image prompting<br>
    German · French · English · Japanese (A1)
  </div>

  <div class="cv-divider"></div>

  <div class="cv-section">
    <div class="date">Contact</div>
    <div class="place" style="font-size:0.85rem">aaron.amend@icloud.com</div>
    <div class="location">+49 (0) 17631300747</div>
  </div>
</div>

<!-- PROJECT PAGES -->
<div id="project-capella" class="page">
  <div class="meta">Master Thesis · ENSA Paris-Belleville · 2025</div>
  <h2>Capella – A Platform for Music and Community in La Chapelle</h2>
  <p class="description">
    Supervised by Julie Lafortune, Etienne Barré and Julie Maillard.
    In collaboration with Diego Kühle Ramos. Grade: A (with congratulations from the jury).<br><br>
    The thesis examines rapid densification on public space in disadvantaged neighbourhoods.
    An infrastructural element that weaves the new neighbourhood into the existing urban fabric
    and creates a place for making and experiencing music.
  </p>
  <div class="gallery">
    <div><img src="capella_main.jpg" alt="Capella"></div>
  </div>
</div>

<div id="project-twobarns" class="page">
  <div class="meta">Bachelor Thesis · Bauhaus Universität Weimar · 2022 · Grade 1,7</div>
  <h2>Two Barns – Youth Housing in the Countryside</h2>
  <p class="description">
    Supervised by Prof. Verena von Beckerath and Till Hoffmann.<br><br>
    Two barns opposite each other were transformed: one for living with shared kitchens
    on two floors, one dedicated to concentrated work, usable as studio, home office, or event space.
  </p>
  <div class="gallery">
    <div><img src="scheine_main.png" alt="Two Barns"></div>
  </div>
</div>

<div id="project-roubaix" class="page">
  <div class="meta">Semester Project · ENSA Paris-Belleville · 2023 · Grade A</div>
  <h2>ENSA Roubaix – Transformation of a Former Factory into an Architecture School</h2>
  <p class="description">
    Supervised by Prof. Louis Burriel. With Diego Kühle Ramos.<br><br>
    Developing a consistent system of tools and parameters to organize interventions
    and evaluate their consequences on the former Roubaix factory.
  </p>
  <div class="gallery">
    <div><img src="Roubaix_main.jpeg" alt="ENSA Roubaix"></div>
  </div>
</div>

<div id="project-groninger" class="page">
  <div class="meta">Semester Project · Bauhaus Universität Weimar · 2022 · Grade A</div>
  <h2>Gröninger Hof – Cooperative Transformation of a Parking Garage into Housing</h2>
  <p class="description">
    Supervised by Prof. Verena von Beckerath. With Charlotte Henschel and Vincent Mank.<br><br>
    Reusing the existing structure of a Hamburg parking garage to generate new cooperative
    living space with three apartment typologies and hybrid office/communal areas.
  </p>
  <div class="gallery">
    <div><img src="groeninger_main.png" alt="Gröninger Hof"></div>
  </div>
</div>

<div id="project-plancomun" class="page">
  <div class="meta">Plan Comùn Architects · Paris · 2025–26</div>
  <h2>Plan Comùn – Paris</h2>
  <p class="description">
    Competition work including Python (rehabilitation of 3 residential towers on the eastern
    Périphérique in collaboration with NP2F), Hebert Lot C, Pantin St. Denis 2, and a full
    apartment renovation for a retiring couple in Paris 10ème.
  </p>
  <div class="gallery">
    <div><img src="Pantin_main.jpeg" alt="Plan Comùn"></div>
  </div>
</div>

<div id="project-beten" class="page">
  <div class="meta">Semester Project · Bauhaus Universität Weimar</div>
  <h2>Seminary and Church for Educational Purposes in the Forest near Wittenberg</h2>
  <p class="description">
    A seminary and church complex embedded in the landscape of the forest near Wittenberg.
    The project explores the relationship between sacred space, education, and nature.
  </p>
  <div class="gallery">
    <div><img src="beten_main.png" alt="Seminary – Wittenberg"></div>
  </div>
</div>

<div id="project-mosterei" class="page">
  <div class="meta">Semester Project · Bauhaus Universität Weimar</div>
  <h2>Cider Factory on the Thuringia Cycle Path</h2>
  <p class="description">
    A cider press and production facility sited along the Thuringia cycle path,
    connecting agricultural landscape with passing cyclists and visitors.
  </p>
  <div class="gallery">
    <div><img src="mosterei_main.png" alt="Cider Factory – Thuringia"></div>
  </div>
</div>

<div id="project-archive" class="page">
  <div class="meta">Archive · Internships & Competition Work</div>
  <h2>Archive</h2>
  <p class="description">
    Selected work from internships at Nicolas Dorval-Bory Architects,
    Bangkok Tokyo Architects, tiburg Architekten — and competition entries.
  </p>
  <div class="gallery">
    <div><img src="ndba_main.jpeg" alt="Nicolas Dorval-Bory Architects"></div>
    <div><img src="tokyobkk_main.jpeg" alt="Bangkok Tokyo Architects"></div>
  </div>
</div>

<script>
  const home = document.getElementById('home');
  const cvPage = document.getElementById('cv-page');
  const navBack = document.getElementById('nav-back');
  const navCV = document.getElementById('nav-cv');
  const arrow = document.getElementById('scroll-arrow');

  let currentPage = 'home';

  function showHome() { home.style.display = 'flex'; }
  function hideHome() { home.style.display = 'none'; }

  function showCV() {
    hideHome();
    document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
    cvPage.classList.add('active');
    navBack.style.display = 'block';
    navCV.style.display = 'none';
    window.scrollTo(0, 0);
    currentPage = 'cv';
    arrow.style.display = 'none';
  }

  function showProject(id) {
    hideHome();
    document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
    cvPage.classList.remove('active');
    const page = document.getElementById('project-' + id);
    if (page) {
      page.classList.add('active');
      navBack.style.display = 'block';
      navCV.style.display = 'none';
      window.scrollTo(0, 0);
      currentPage = id;
      arrow.style.display = 'none';
    }
  }

  function goHome() {
    document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
    cvPage.classList.remove('active');
    showHome();
    navBack.style.display = 'none';
    navCV.style.display = 'block';
    currentPage = 'home';
    window.scrollTo(0, 0);
    arrow.style.display = 'block';
    arrow.style.opacity = '1';
  }

  window.addEventListener('scroll', () => {
    if (currentPage !== 'home') return;
    arrow.style.opacity = window.scrollY > 60 ? '0' : '1';
  });
</script>
</body>
</html>`;

export default function CodeViewer() {
  const [copied, setCopied] = useState(false);

  const handleCopy = () => {
    navigator.clipboard.writeText(code).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    });
  };

  return (
    <div style={{ fontFamily: "monospace", fontSize: "12px", height: "100vh", display: "flex", flexDirection: "column" }}>
      <div style={{
        display: "flex", justifyContent: "space-between", alignItems: "center",
        padding: "10px 16px", borderBottom: "0.5px solid var(--color-border-tertiary)",
        background: "var(--color-background-secondary)", position: "sticky", top: 0
      }}>
        <span style={{ fontSize: "13px", color: "var(--color-text-secondary)" }}>index.html</span>
        <button onClick={handleCopy} style={{
          fontSize: "12px", padding: "5px 14px", cursor: "pointer",
          background: copied ? "var(--color-background-success)" : "var(--color-background-primary)",
          color: copied ? "var(--color-text-success)" : "var(--color-text-primary)",
          border: "0.5px solid var(--color-border-secondary)",
          borderRadius: "var(--border-radius-md)", transition: "all 0.15s"
        }}>
          {copied ? "Kopiert ✓" : "Alles kopieren"}
        </button>
      </div>
      <pre style={{
        flex: 1, overflow: "auto", padding: "16px",
        margin: 0, lineHeight: "1.6", whiteSpace: "pre-wrap", wordBreak: "break-word",
        color: "var(--color-text-primary)", background: "var(--color-background-primary)"
      }}>
        {code}
      </pre>
    </div>
  );
}
