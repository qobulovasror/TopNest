async function loadExtensions() {
  const status = document.getElementById('catalog-status');
  const grid = document.getElementById('extension-grid');
  try {
    const response = await fetch('./catalog.json', { cache: 'no-store' });
    if (!response.ok) throw new Error('Catalog unavailable');
    const catalog = await response.json();
    if (catalog.schemaVersion !== 1 || !Array.isArray(catalog.extensions)) throw new Error('Invalid catalog');
    status.textContent = catalog.extensions.length ? '' : 'No extensions are available yet.';
    for (const entry of catalog.extensions) {
      if (!/^[a-z0-9]+(?:[.-][a-z0-9]+)+$/.test(entry.id)) continue;
      let packageURL;
      try { packageURL = new URL(entry.packageURL); } catch (_) { continue; }
      if (packageURL.protocol !== 'https:') continue;
      const card = document.createElement('article');
      card.className = 'extension-card';
      const top = document.createElement('div');
      top.className = 'extension-top';
      const icon = document.createElement('div');
      icon.className = 'extension-icon';
      icon.setAttribute('aria-hidden', 'true');
      icon.textContent = '✦';
      const heading = document.createElement('div');
      const name = document.createElement('h2');
      name.textContent = entry.name;
      const byline = document.createElement('p');
      byline.className = 'byline';
      byline.textContent = `${entry.author} · v${entry.version}`;
      heading.append(name, byline);
      top.append(icon, heading);
      const summary = document.createElement('p');
      summary.textContent = entry.summary;
      const actions = document.createElement('div');
      actions.className = 'extension-actions';
      const install = document.createElement('a');
      install.className = 'button button-primary';
      install.href = `topnest://install?id=${encodeURIComponent(entry.id)}`;
      install.textContent = 'Open in TopNest →';
      const download = document.createElement('a');
      download.className = 'button';
      download.href = packageURL.href;
      download.textContent = 'Download JSON';
      actions.append(install, download);
      card.append(top, summary, actions);
      grid.append(card);
    }
  } catch (_) {
    status.textContent = 'The catalog could not be loaded. Please try again later.';
  }
}
loadExtensions();
