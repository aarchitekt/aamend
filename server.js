const express = require('express');
const path = require('path');
const fs = require('fs');
const { execFile } = require('child_process');
const multer = require('multer');
const sharp = require('sharp');

const app = express();
const PORT = process.env.PORT || 3000;
const ROOT = __dirname;
const INDEX_PATH = path.join(ROOT, 'index.html');

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 40 * 1024 * 1024 } });

app.use(express.json());
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
app.get('/api/projects', (req, res) => {
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
app.post('/api/replace-image', upload.single('image'), async (req, res) => {
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
app.post('/api/add-image', upload.single('image'), async (req, res) => {
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
app.post('/api/reorder-images', (req, res) => {
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
app.post('/api/delete-image', (req, res) => {
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
app.post('/api/update-meta', (req, res) => {
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
app.post('/api/reorder-home', (req, res) => {
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
app.post('/api/add-project', upload.single('image'), async (req, res) => {
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
app.post('/api/publish', (req, res) => {
  const message = (req.body && req.body.message) || 'Update site via admin tool';
  const run = (cmd, args) => new Promise((resolve, reject) => {
    execFile(cmd, args, { cwd: ROOT }, (err, stdout, stderr) => {
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
      await run('git', ['push']);
      res.json({ ok: true, changed: true, message: 'Veröffentlicht. Live in ~1 Minute.' });
    } catch (e) {
      res.status(500).json({ ok: false, error: e.message });
    }
  })();
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

