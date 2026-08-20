const express = require('express');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const { execFile } = require('child_process');
const multer = require('multer');
const sharp = require('sharp');

const app = express();
const PORT = process.env.PORT || 3000;
const ROOT = __dirname;
const INDEX_PATH = path.join(ROOT, 'index.html');
const PICS_DIR = path.join(ROOT, 'img', 'pics');
const PICS_THUMB_DIR = path.join(ROOT, 'img', 'pics-thumb');
const PICS_JSON_PATH = path.join(ROOT, 'assets', 'pics.json');

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 40 * 1024 * 1024 } });

app.use(express.json());

// ───────────────────────────────── Password gate ────────────────────────────────
// Protects /admin and everything under /api/* (except the login call itself).
// Deliberately simple (in-memory sessions, no DB) since this is a single-user
// tool. When run locally this barely matters; when hosted publicly (see
// render.yaml) it's the only thing standing between the internet and your
// git repo, so keep ADMIN_PASSWORD set via an environment variable there
// rather than relying on the hardcoded fallback below.
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'Frankfurt1998';
const SESSION_COOKIE = 'aamend_admin_session';
const sessions = new Set();

function parseCookies(req) {
  const header = req.headers.cookie || '';
  const out = {};
  header.split(';').forEach(part => {
    const idx = part.indexOf('=');
    if (idx > -1) out[part.slice(0, idx).trim()] = decodeURIComponent(part.slice(idx + 1).trim());
  });
  return out;
}

function isAuthed(req) {
  const cookies = parseCookies(req);
  return !!(cookies[SESSION_COOKIE] && sessions.has(cookies[SESSION_COOKIE]));
}

function requireAuth(req, res, next) {
  if (isAuthed(req)) return next();
  res.status(401).json({ error: 'not authenticated' });
}

app.post('/api/login', (req, res) => {
  const { password } = req.body || {};
  if (password === ADMIN_PASSWORD) {
    const token = crypto.randomBytes(24).toString('hex');
    sessions.add(token);
    res.setHeader('Set-Cookie', `${SESSION_COOKIE}=${token}; HttpOnly; Path=/; Max-Age=${60 * 60 * 24 * 7}; SameSite=Lax`);
    res.json({ ok: true });
  } else {
    res.status(401).json({ ok: false, error: 'Falsches Passwort.' });
  }
});

app.post('/api/logout', (req, res) => {
  const cookies = parseCookies(req);
  if (cookies[SESSION_COOKIE]) sessions.delete(cookies[SESSION_COOKIE]);
  res.setHeader('Set-Cookie', `${SESSION_COOKIE}=; HttpOnly; Path=/; Max-Age=0`);
  res.json({ ok: true });
});

app.get('/api/session', (req, res) => res.json({ authed: isAuthed(req) }));

app.use(express.static(ROOT, { extensions: ['html'] }));

// ───────────────────────── helpers: safe, targeted HTML surgery ─────────────────────────
// We never fully re-parse/re-serialize index.html (risky for a large hand-written file
// full of inline <script>/<style>). Instead we locate small, self-contained regions
// (a project's <div class="slide-track">...</div>, its <div class="project-meta">...</div>,
// the <div class="projects-feed">...</div> home list) with a simple tag-depth counter, and
// only rewrite text inside that region.

function findDivBlock(html, startIdx) {
  // startIdx must point at the '<' of the opening <div ...> tag.
  // Returns { openEnd, closeStart, closeEnd } for the matching </div>, using tag-depth counting.
  const openTagEnd = html.indexOf('>', startIdx);
  if (openTagEnd === -1) return null;
  let depth = 1;
  const tagRe = /<div\b[^>]*>|<\/div>/gi;
  tagRe.lastIndex = openTagEnd + 1;
  let m;
  while ((m = tagRe.exec(html))) {
    if (m[0].toLowerCase().startsWith('</div')) {
      depth--;
      if (depth === 0) {
        return { openEnd: openTagEnd + 1, closeStart: m.index, closeEnd: m.index + m[0].length };
      }
    } else {
      depth++;
    }
  }
  return null;
}

function getProjectPageBlock(html, pageId) {
  const marker = `id="${pageId}"`;
  const markerIdx = html.indexOf(marker);
  if (markerIdx === -1) return null;
  const divStart = html.lastIndexOf('<div', markerIdx);
  const block = findDivBlock(html, divStart);
  if (!block) return null;
  return { pageStart: divStart, pageOpenEnd: block.openEnd, pageCloseStart: block.closeStart, pageCloseEnd: block.closeEnd };
}

function listAllProjectPages(html) {
  const ids = [];
  const re = /<div id="(page-[a-z0-9-]+)" class="page">/gi;
  let m;
  while ((m = re.exec(html))) {
    if (m[1] !== 'page-pics' && m[1] !== 'page-globe') ids.push(m[1]);
  }
  return ids;
}

function nextProjectId(html) {
  const re = /id="page-project(\d+)"/g;
  let m, max = 0;
  while ((m = re.exec(html))) max = Math.max(max, parseInt(m[1], 10));
  return `page-project${max + 1}`;
}

function extractSlideImages(pageHtml) {
  const trackMatch = /<div class="slide-track">([\s\S]*?)<\/div>/.exec(pageHtml);
  if (!trackMatch) return [];
  const imgRe = /<img src="([^"]+)"[^>]*>/g;
  const imgs = [];
  let m;
  while ((m = imgRe.exec(trackMatch[1]))) imgs.push(m[1]);
  return imgs;
}

function getMetaBlock(pageHtml) {
  const idx = pageHtml.indexOf('<div class="project-meta">');
  if (idx === -1) return null;
  return findDivBlock(pageHtml, idx);
}

// ── plain-text <-> stored-HTML conversion for the two meta columns ──
// So the admin UI can be a plain textarea: no visible <br>/<strong> tags.
// A blank line (double newline) round-trips to "<br><br>" exactly like the
// hand-authored originals did.
function htmlToPlainText(html) {
  return html
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/?strong>/gi, '')
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'")
    .trim();
}

function escapeHtml(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function plainTextToHtml(text) {
  return String(text || '').split('\n').map(escapeHtml).join('<br>');
}

function extractMeta(pageHtml) {
  const block = getMetaBlock(pageHtml);
  if (!block) return null;
  const inner = pageHtml.slice(block.openEnd, block.closeStart);
  const cols = [...inner.matchAll(/<div class="meta-col">([\s\S]*?)<\/div>/g)].map(m => htmlToPlainText(m[1]));
  return { col1: cols[0] || '', col2: cols[1] || '' };
}

function getProjectsFeedBlock(html) {
  const idx = html.indexOf('class="projects-feed"');
  if (idx === -1) return null;
  const divStart = html.lastIndexOf('<div', idx);
  return findDivBlock(html, divStart);
}

const HOME_SPACER = '<div style="height:9vh;width:100%"></div>';

function extractHomeItems(html) {
  const block = getProjectsFeedBlock(html);
  if (!block) return [];
  const inner = html.slice(block.openEnd, block.closeStart);
  const items = [];
  const itemRe = /<div class="project-item" onclick="showProject\('([^']+)'\)">/g;
  let m;
  while ((m = itemRe.exec(inner))) {
    const itemBlock = findDivBlock(inner, m.index);
    if (!itemBlock) continue;
    const outerHtml = inner.slice(m.index, itemBlock.closeEnd);
    const imgs = [...outerHtml.matchAll(/<img src="([^"]+)"/g)].map(x => x[1]);
    items.push({ pageId: m[1], html: outerHtml, images: imgs });
  }
  return items;
}

// ── image processing: keep real transparency as PNG, otherwise flatten to a white JPEG ──
// "Real" alpha = the image actually uses transparency (min alpha < 250), not just a PNG
// that happens to carry an unused, fully-opaque alpha channel.
async function hasRealAlpha(img, meta) {
  if (!meta.hasAlpha) return false;
  const stats = await img.clone().stats();
  const alphaChan = stats.channels[stats.channels.length - 1];
  return !!alphaChan && alphaChan.min < 250;
}

async function processUpload(buffer) {
  let img = sharp(buffer).rotate();
  const meta = await img.metadata();
  const MAX_DIM = 2400;
  if (Math.max(meta.width || 0, meta.height || 0) > MAX_DIM) {
    img = img.resize({ width: MAX_DIM, height: MAX_DIM, fit: 'inside', withoutEnlargement: true });
  }
  const keepPng = await hasRealAlpha(img, meta);
  return { img, keepPng };
}

// ───────────────────────────────── API: read project data ─────────────────────────────────
app.get('/api/projects', requireAuth, (req, res) => {
  const html = fs.readFileSync(INDEX_PATH, 'utf8');

  const homeItems = extractHomeItems(html).map((it, i) => ({ index: i, pageId: it.pageId, images: it.images }));

  const pageIds = listAllProjectPages(html);
  const projects = pageIds.map(id => {
    const block = getProjectPageBlock(html, id);
    const pageHtml = html.slice(block.pageOpenEnd, block.pageCloseStart);
    return {
      id,
      images: extractSlideImages(pageHtml),
      meta: extractMeta(pageHtml)
    };
  });

  res.json({ home: homeItems, projects });
});

// ───────────────────────────────── API: replace an image file in place ─────────────────────
app.post('/api/replace-image', requireAuth, upload.single('image'), async (req, res) => {
  try {
    const relPath = req.body.path;
    if (!relPath || relPath.includes('..')) return res.status(400).json({ error: 'invalid path' });
    const abs = path.join(ROOT, relPath);
    if (!abs.startsWith(ROOT)) return res.status(400).json({ error: 'invalid path' });
    if (!req.file) return res.status(400).json({ error: 'no file' });

    const { img, keepPng } = await processUpload(req.file.buffer);

    const dir = path.dirname(abs);
    const base = path.basename(abs, path.extname(abs));
    const newAbs = path.join(dir, base + (keepPng ? '.png' : '.jpg'));

    if (keepPng) {
      await img.png({ compressionLevel: 9 }).toFile(newAbs + '.tmp');
    } else {
      await img.flatten({ background: '#ffffff' }).jpeg({ quality: 86, progressive: true, mozjpeg: true }).toFile(newAbs + '.tmp');
    }
    fs.renameSync(newAbs + '.tmp', newAbs);
    if (newAbs !== abs && fs.existsSync(abs)) fs.unlinkSync(abs);

    const newRelPath = path.relative(ROOT, newAbs).split(path.sep).join('/');
    if (newRelPath !== relPath) {
      const html = fs.readFileSync(INDEX_PATH, 'utf8');
      fs.writeFileSync(INDEX_PATH, html.split(`src="${relPath}"`).join(`src="${newRelPath}"`));
    }

    res.json({ ok: true, path: newRelPath, size: fs.statSync(newAbs).size });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: String(e) });
  }
});

// ───────────────────────────────── API: add a new image to a project's slideshow ────────────
app.post('/api/add-image', requireAuth, upload.single('image'), async (req, res) => {
  try {
    const { pageId } = req.body;
    if (!pageId || !req.file) return res.status(400).json({ error: 'missing pageId or file' });

    const base = path.basename(req.file.originalname, path.extname(req.file.originalname))
      .replace(/[^a-zA-Z0-9_-]/g, '_') || 'img';

    const { img, keepPng } = await processUpload(req.file.buffer);
    const wantExt = keepPng ? '.png' : '.jpg';

    let filename = `${base}${wantExt}`;
    let counter = 1;
    while (fs.existsSync(path.join(ROOT, 'img', filename))) {
      filename = `${base}-${counter}${wantExt}`;
      counter++;
    }
    const abs = path.join(ROOT, 'img', filename);

    if (keepPng) {
      await img.png({ compressionLevel: 9 }).toFile(abs);
    } else {
      await img.flatten({ background: '#ffffff' }).jpeg({ quality: 86, progressive: true, mozjpeg: true }).toFile(abs);
    }

    const relSrc = `img/${filename}`;
    const html = fs.readFileSync(INDEX_PATH, 'utf8');
    const block = getProjectPageBlock(html, pageId);
    if (!block) return res.status(404).json({ error: 'project not found' });
    const pageHtml = html.slice(block.pageOpenEnd, block.pageCloseStart);

    const trackRe = /(<div class="slide-track">)([\s\S]*?)(<\/div>)/;
    const trackMatch = trackRe.exec(pageHtml);
    if (!trackMatch) return res.status(500).json({ error: 'slide-track not found' });
    const newInner = trackMatch[2].replace(/\s*$/, '') + `\n    <img src="${relSrc}" alt="">\n    `;
    const newPageHtml = pageHtml.replace(trackRe, `$1${newInner}$3`)
      .replace(/(data-count=")(\d+)(")/, (m, a, n, c) => `${a}${parseInt(n, 10) + 1}${c}`);

    const newHtml = html.slice(0, block.pageOpenEnd) + newPageHtml + html.slice(block.pageCloseStart);
    fs.writeFileSync(INDEX_PATH, newHtml);
    res.json({ ok: true, src: relSrc });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: String(e) });
  }
});

// ───────────────────────────────── API: reorder a project's slideshow images ────────────────
app.post('/api/reorder-images', requireAuth, (req, res) => {
  try {
    const { pageId, order } = req.body;
    if (!pageId || !Array.isArray(order)) return res.status(400).json({ error: 'missing pageId or order' });

    const html = fs.readFileSync(INDEX_PATH, 'utf8');
    const block = getProjectPageBlock(html, pageId);
    if (!block) return res.status(404).json({ error: 'project not found' });
    const pageHtml = html.slice(block.pageOpenEnd, block.pageCloseStart);

    const trackRe = /(<div class="slide-track">)([\s\S]*?)(<\/div>)/;
    const trackMatch = trackRe.exec(pageHtml);
    if (!trackMatch) return res.status(500).json({ error: 'slide-track not found' });

    const existingImgs = [...trackMatch[2].matchAll(/<img[^>]*src="([^"]+)"[^>]*>/g)];
    const bySrc = {};
    for (const m of existingImgs) bySrc[m[1]] = m[0];

    const reordered = order.filter(src => bySrc[src]).map(src => bySrc[src]);
    const newInner = '\n    ' + reordered.join('\n    ') + '\n    ';
    const newPageHtml = pageHtml.replace(trackRe, `$1${newInner}$3`);
    const newHtml = html.slice(0, block.pageOpenEnd) + newPageHtml + html.slice(block.pageCloseStart);
    fs.writeFileSync(INDEX_PATH, newHtml);
    res.json({ ok: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: String(e) });
  }
});

// ───────────────────────────────── API: delete an image from a project's slideshow ──────────
app.post('/api/delete-image', requireAuth, (req, res) => {
  try {
    const { pageId, src } = req.body;
    if (!pageId || !src) return res.status(400).json({ error: 'missing pageId or src' });

    const html = fs.readFileSync(INDEX_PATH, 'utf8');
    const block = getProjectPageBlock(html, pageId);
    if (!block) return res.status(404).json({ error: 'project not found' });
    const pageHtml = html.slice(block.pageOpenEnd, block.pageCloseStart);

    const trackRe = /(<div class="slide-track">)([\s\S]*?)(<\/div>)/;
    const trackMatch = trackRe.exec(pageHtml);
    if (!trackMatch) return res.status(500).json({ error: 'slide-track not found' });

    const escaped = src.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const imgLineRe = new RegExp(`\\s*<img[^>]*src="${escaped}"[^>]*>`, 'g');
    const newInner = trackMatch[2].replace(imgLineRe, '');
    const newPageHtml = pageHtml.replace(trackRe, `$1${newInner}$3`)
      .replace(/(data-count=")(\d+)(")/, (m, a, n, c) => `${a}${Math.max(0, parseInt(n, 10) - 1)}${c}`);

    const newHtml = html.slice(0, block.pageOpenEnd) + newPageHtml + html.slice(block.pageCloseStart);
    fs.writeFileSync(INDEX_PATH, newHtml);
    res.json({ ok: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: String(e) });
  }
});

// ───────────────────────────────── API: edit project-meta text ──────────────────────────────
app.post('/api/update-meta', requireAuth, (req, res) => {
  try {
    const { pageId, col1, col2 } = req.body;
    if (!pageId) return res.status(400).json({ error: 'missing pageId' });

    const html = fs.readFileSync(INDEX_PATH, 'utf8');
    const block = getProjectPageBlock(html, pageId);
    if (!block) return res.status(404).json({ error: 'project not found' });
    const pageHtml = html.slice(block.pageOpenEnd, block.pageCloseStart);

    const metaBlock = getMetaBlock(pageHtml);
    if (!metaBlock) return res.status(404).json({ error: 'no project-meta block on this page' });

    const html1 = plainTextToHtml(col1);
    const html2 = plainTextToHtml(col2);
    const newInner = `\n    <div class="meta-col">${html1}</div><div class="meta-col">${html2}</div>\n  `;
    const newPageHtml = pageHtml.slice(0, metaBlock.openEnd) + newInner + pageHtml.slice(metaBlock.closeStart);
    const newHtml = html.slice(0, block.pageOpenEnd) + newPageHtml + html.slice(block.pageCloseStart);
    fs.writeFileSync(INDEX_PATH, newHtml);
    res.json({ ok: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: String(e) });
  }
});

// ───────────────────────────────── API: reorder home-feed project thumbnails ────────────────
app.post('/api/reorder-home', requireAuth, (req, res) => {
  try {
    const { order } = req.body;
    if (!Array.isArray(order)) return res.status(400).json({ error: 'missing order' });

    const html = fs.readFileSync(INDEX_PATH, 'utf8');
    const feedBlock = getProjectsFeedBlock(html);
    if (!feedBlock) return res.status(404).json({ error: 'projects-feed not found' });

    const items = extractHomeItems(html);
    if (order.length !== items.length) return res.status(400).json({ error: 'order length mismatch — reload and try again' });
    const reordered = order.map(i => items[i]);
    if (reordered.some(it => !it)) return res.status(400).json({ error: 'invalid order' });

    const newInner = '\n\n    ' + reordered.map(it => it.html).join(`\n    ${HOME_SPACER}\n\n    `) + `\n    ${HOME_SPACER}\n\n  `;
    const newHtml = html.slice(0, feedBlock.openEnd) + newInner + html.slice(feedBlock.closeStart);
    fs.writeFileSync(INDEX_PATH, newHtml);
    res.json({ ok: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: String(e) });
  }
});

// ───────────────────────────────── API: add a brand-new project ─────────────────────────────
app.post('/api/add-project', requireAuth, upload.single('image'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'no image' });

    const html = fs.readFileSync(INDEX_PATH, 'utf8');
    const pageId = nextProjectId(html);

    const base = path.basename(req.file.originalname, path.extname(req.file.originalname))
      .replace(/[^a-zA-Z0-9_-]/g, '_') || 'img';
    const { img, keepPng } = await processUpload(req.file.buffer);
    const wantExt = keepPng ? '.png' : '.jpg';
    let filename = `${base}${wantExt}`;
    let counter = 1;
    while (fs.existsSync(path.join(ROOT, 'img', filename))) {
      filename = `${base}-${counter}${wantExt}`;
      counter++;
    }
    const abs = path.join(ROOT, 'img', filename);
    if (keepPng) {
      await img.png({ compressionLevel: 9 }).toFile(abs);
    } else {
      await img.flatten({ background: '#ffffff' }).jpeg({ quality: 86, progressive: true, mozjpeg: true }).toFile(abs);
    }
    const relSrc = `img/${filename}`;

    // 1) new project page, inserted right before the Pics page so it sits among the others
    const pageHtml = `
<div id="${pageId}" class="page">
  <div class="slideshow" data-count="1">
    <div class="slide-track">
    <img src="${relSrc}" alt="">
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
`;
    const picsIdx = html.indexOf('<div id="page-pics" class="page">');
    if (picsIdx === -1) return res.status(500).json({ error: 'page-pics anchor not found' });
    let newHtml = html.slice(0, picsIdx) + pageHtml.replace(/^\n/, '') + '\n' + html.slice(picsIdx);

    // 2) new thumbnail appended to the home feed
    const feedBlock = getProjectsFeedBlock(newHtml);
    if (!feedBlock) return res.status(500).json({ error: 'projects-feed not found' });
    const itemHtml = `<div class="project-item" onclick="showProject('${pageId}')">\n      <img src="${relSrc}" alt="" style="width:26vw;max-width:470px;" loading="lazy">\n    </div>`;
    const insertion = `\n    ${itemHtml}\n    ${HOME_SPACER}\n`;
    newHtml = newHtml.slice(0, feedBlock.closeStart) + insertion + newHtml.slice(feedBlock.closeStart);

    fs.writeFileSync(INDEX_PATH, newHtml);
    res.json({ ok: true, pageId, src: relSrc });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: String(e) });
  }
});

// ───────────────────────────────── API: publish (git add/commit/push) ───────────────────────
app.post('/api/publish', requireAuth, (req, res) => {
  const message = (req.body && req.body.message) || 'Update site via admin tool';
  // Hosted (Render) containers are a fresh checkout on every deploy/restart --
  // there's no persistent ~/.gitconfig, so `git commit` has no author identity
  // and fails with "Author identity unknown". Set it explicitly via env vars
  // on every git call rather than relying on `git config` (which wouldn't
  // survive a redeploy anyway). This was silently breaking every publish from
  // the hosted admin tool -- e.g. photo rotations looked instant in the admin
  // grid but never actually made it to the live site, since the commit (and
  // therefore the push) never happened.
  const GIT_ENV = {
    ...process.env,
    GIT_AUTHOR_NAME: 'Aaron Amend',
    GIT_AUTHOR_EMAIL: 'aaron.amend@icloud.com',
    GIT_COMMITTER_NAME: 'Aaron Amend',
    GIT_COMMITTER_EMAIL: 'aaron.amend@icloud.com',
  };
  const run = (cmd, args) => new Promise((resolve, reject) => {
    execFile(cmd, args, { cwd: ROOT, env: GIT_ENV }, (err, stdout, stderr) => {
      if (err) reject(new Error(stderr || stdout || err.message));
      else resolve(stdout);
    });
  });
  (async () => {
    try {
      await run('git', ['add', '-A']);
      const status = await run('git', ['diff', '--cached', '--name-only']);
      if (!status.trim()) {
        return res.json({ ok: true, changed: false, message: 'Keine Änderungen.' });
      }
      await run('git', ['commit', '-m', message]);
      // When hosted (not run on the user's own machine), plain `git push` has
      // no credentials to use. GIT_PUSH_URL (set as a host env var, e.g.
      // https://<token>@github.com/aarchitekt/aamend.git) supplies them
      // without ever putting the token in code or in this repo.
      const pushUrl = process.env.GIT_PUSH_URL;
      if (pushUrl) {
        await run('git', ['push', pushUrl, 'HEAD:main']);
      } else {
        await run('git', ['push']);
      }
      res.json({ ok: true, changed: true, message: 'Veröffentlicht. Live in ~1 Minute.' });
    } catch (e) {
      res.status(500).json({ ok: false, error: e.message });
    }
  })();
});

// ───────────────────────────────── API: CV / about page text ───────────────────────────────
// Deliberately kept as raw HTML round-trip (not the plain-text scheme used for project meta)
// because the bio paragraphs use inline <strong> on specific words mid-sentence — flattening
// to plain text on every save would silently destroy that emphasis.
function getCvData(html) {
  const paras = [...html.matchAll(/<p class="cv-text">([\s\S]*?)<\/p>/g)].map(m => m[1]);
  const skillsAnchor = `<div class="cv-section" style="font-family:'Courier New',monospace`;
  const skillsIdx = html.indexOf(skillsAnchor);
  let skillsHtml = '';
  if (skillsIdx !== -1) {
    const block = findDivBlock(html, skillsIdx);
    skillsHtml = html.slice(block.openEnd, block.closeStart).trim();
  }
  const emailM = /<div class="place" style="font-size:0\.85rem">([\s\S]*?)<\/div>/.exec(html);
  const locMs = [...html.matchAll(/<div class="location">([\s\S]*?)<\/div>/g)];
  return {
    bio1: paras[0] || '',
    bio2: paras[1] || '',
    skillsHtml,
    email: emailM ? emailM[1] : '',
    phone1: locMs[0] ? locMs[0][1] : '',
    phone2: locMs[1] ? locMs[1][1] : '',
  };
}

app.get('/api/cv', requireAuth, (req, res) => {
  const html = fs.readFileSync(INDEX_PATH, 'utf8');
  res.json(getCvData(html));
});

app.post('/api/update-cv', requireAuth, (req, res) => {
  try {
    const { bio1, bio2, skillsHtml, email, phone1, phone2 } = req.body || {};
    let html = fs.readFileSync(INDEX_PATH, 'utf8');

    let paraCount = 0;
    html = html.replace(/<p class="cv-text">([\s\S]*?)<\/p>/g, (m) => {
      paraCount++;
      if (paraCount === 1) return `<p class="cv-text">${bio1 || ''}</p>`;
      if (paraCount === 2) return `<p class="cv-text">${bio2 || ''}</p>`;
      return m;
    });

    const skillsAnchor = `<div class="cv-section" style="font-family:'Courier New',monospace`;
    const skillsIdx = html.indexOf(skillsAnchor);
    if (skillsIdx !== -1 && typeof skillsHtml === 'string') {
      const block = findDivBlock(html, skillsIdx);
      html = html.slice(0, block.openEnd) + `\n    ${skillsHtml}\n  ` + html.slice(block.closeStart);
    }

    if (typeof email === 'string') {
      html = html.replace(/(<div class="place" style="font-size:0\.85rem">)([\s\S]*?)(<\/div>)/, `$1${email}$3`);
    }
    let locCount = 0;
    html = html.replace(/(<div class="location">)([\s\S]*?)(<\/div>)/g, (m, a, inner, c) => {
      locCount++;
      if (locCount === 1 && typeof phone1 === 'string') return `${a}${phone1}${c}`;
      if (locCount === 2 && typeof phone2 === 'string') return `${a}${phone2}${c}`;
      return m;
    });

    fs.writeFileSync(INDEX_PATH, html);
    res.json({ ok: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: String(e) });
  }
});

// ───────────────────────────────── API: Pics page (img/pics + assets/pics.json) ─────────────
// The Pics slideshow and the Globe page both read assets/pics.json ({thumb, full, lat, lon}).
// full lives in img/pics/, thumb lives in the separate, smaller img/pics-thumb/ (used for the
// Globe markers) — both must stay in sync with the JSON on every add/delete/rotate.
function readPicsJson() {
  if (!fs.existsSync(PICS_JSON_PATH)) return [];
  return JSON.parse(fs.readFileSync(PICS_JSON_PATH, 'utf8'));
}
function writePicsJson(arr) {
  fs.writeFileSync(PICS_JSON_PATH, JSON.stringify(arr, null, 2));
}
// 2026-08: always auto-orient (.rotate() with no args, same as processUpload()) before
// resizing. This is what full/thumb consistency actually depends on -- a legacy batch of
// ~170 thumbnails predating this admin tool was generated by a different process than the
// one that wrote the matching full-size images, so 45 of them ended up rotated 90 degrees
// relative to their full counterpart (admin grid showed one orientation, the live Pics
// slideshow -- which reads "full", not "thumb" -- showed the other). All 189 thumbs were
// regenerated from their current full image in one pass to fix that backlog; this .rotate()
// call is the going-forward guarantee that a thumb can never again disagree with its full
// image, since both are always derived through the same auto-orient step.
async function writeThumb(fromPath, toPath) {
  await sharp(fromPath).rotate().resize({ width: 500, height: 500, fit: 'inside', withoutEnlargement: true })
    .jpeg({ quality: 80 }).toFile(toPath + '.tmp');
  fs.renameSync(toPath + '.tmp', toPath);
}

app.get('/api/pics', requireAuth, (req, res) => {
  res.json(readPicsJson());
});

// 2026-08: raised from 40 -- the admin UI now sends uploads in small batches
// (see PICS_UPLOAD_BATCH_SIZE in admin.html) so a single request should never
// come close to this, but keeping it generous avoids a hard rejection if
// someone scripts a bigger batch directly against the API.
app.post('/api/pics/add', requireAuth, upload.array('images', 100), async (req, res) => {
  try {
    if (!req.files || !req.files.length) return res.status(400).json({ error: 'no files' });
    const items = readPicsJson();
    const existing = new Set(items.map(i => i.full));
    const added = [];
    for (const file of req.files) {
      const base = path.basename(file.originalname, path.extname(file.originalname))
        .replace(/[^a-zA-Z0-9_-]/g, '_') || 'pic';
      let filename = `${base}.jpg`;
      let counter = 1;
      while (fs.existsSync(path.join(PICS_DIR, filename)) || existing.has(filename)) {
        filename = `${base}-${counter}.jpg`;
        counter++;
      }
      existing.add(filename);

      let img = sharp(file.buffer).rotate();
      const meta = await img.metadata();
      const MAX_DIM = 2400;
      if (Math.max(meta.width || 0, meta.height || 0) > MAX_DIM) {
        img = img.resize({ width: MAX_DIM, height: MAX_DIM, fit: 'inside', withoutEnlargement: true });
      }
      const fullPath = path.join(PICS_DIR, filename);
      await img.flatten({ background: '#ffffff' }).jpeg({ quality: 86, progressive: true, mozjpeg: true }).toFile(fullPath);
      await writeThumb(fullPath, path.join(PICS_THUMB_DIR, filename));

      const entry = { thumb: filename, full: filename, lat: 0, lon: 0 };
      items.push(entry);
      added.push(entry);
    }
    writePicsJson(items);
    res.json({ ok: true, added });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: String(e) });
  }
});

app.post('/api/pics/delete', requireAuth, (req, res) => {
  try {
    const { full } = req.body || {};
    if (!full) return res.status(400).json({ error: 'missing full' });
    const items = readPicsJson();
    const entry = items.find(i => i.full === full);
    if (!entry) return res.status(404).json({ error: 'not found' });
    writePicsJson(items.filter(i => i.full !== full));
    const fullPath = path.join(PICS_DIR, entry.full);
    const thumbPath = path.join(PICS_THUMB_DIR, entry.thumb);
    if (fs.existsSync(fullPath)) fs.unlinkSync(fullPath);
    if (fs.existsSync(thumbPath)) fs.unlinkSync(thumbPath);
    res.json({ ok: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: String(e) });
  }
});

app.post('/api/pics/rotate', requireAuth, async (req, res) => {
  try {
    const { full, deg } = req.body || {};
    if (!full || ![90, -90, 180].includes(deg)) return res.status(400).json({ error: 'bad params' });
    const items = readPicsJson();
    const entry = items.find(i => i.full === full);
    if (!entry) return res.status(404).json({ error: 'not found' });
    const fullPath = path.join(PICS_DIR, entry.full);
    if (!fs.existsSync(fullPath)) return res.status(404).json({ error: 'file missing' });
    const tmp = fullPath + '.tmp';
    // Auto-orient first (bakes in + strips any stray EXIF orientation tag, same as
    // processUpload()) before applying the explicit manual rotation on top -- belt-and-
    // suspenders so this endpoint can't produce a mismatched result even if it's ever run
    // against a file that didn't come through the normal upload path.
    const normalized = await sharp(fullPath).rotate().toBuffer();
    await sharp(normalized).rotate(deg).jpeg({ quality: 90, progressive: true, mozjpeg: true }).toFile(tmp);
    fs.renameSync(tmp, fullPath);
    await writeThumb(fullPath, path.join(PICS_THUMB_DIR, entry.thumb));
    res.json({ ok: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: String(e) });
  }
});

app.get('/admin', (req, res) => res.sendFile(path.join(ROOT, 'admin.html')));

// SPA-style fallback so direct/deep links still load the app
app.get('*', (req, res) => {
  res.sendFile(path.join(ROOT, 'index.html'));
});

app.listen(PORT, () => {
  console.log(`Aaron Amend site running on port ${PORT}`);
  console.log(`Admin tool: http://localhost:${PORT}/admin`);
});

