const fs = require('fs');
const html = fs.readFileSync('assets/intravel/index.html', 'utf8');
const idx = html.indexOf("function ensureMap()");
console.log(html.slice(idx, idx + 2450));
