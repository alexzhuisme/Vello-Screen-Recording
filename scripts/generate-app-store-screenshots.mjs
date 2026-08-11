import fs from "node:fs/promises";
import path from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const sharp = require("sharp");

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(scriptDir, "..");
const outputDir = path.join(root, "AppStoreScreenshots");
const backgroundPath = path.join(outputDir, "source", "vello-master-background.png");
const iconPath = path.join(root, "App", "Resources", "branding", "vello-app-icon.png");

const width = 2560;
const height = 1600;

await fs.mkdir(outputDir, { recursive: true });

const [backgroundBuffer, iconBuffer] = await Promise.all([
  sharp(backgroundPath).resize(width, height, { fit: "cover" }).png().toBuffer(),
  sharp(iconPath).png().toBuffer(),
]);

const backgroundData = backgroundBuffer.toString("base64");
const iconData = iconBuffer.toString("base64");

function base(title, subtitle, body, accent = "#2563EB") {
  return `
  <svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
    <defs>
      <filter id="shadow" x="-20%" y="-20%" width="140%" height="160%">
        <feDropShadow dx="0" dy="34" stdDeviation="40" flood-color="#12345F" flood-opacity="0.24"/>
      </filter>
      <filter id="softShadow" x="-30%" y="-30%" width="160%" height="180%">
        <feDropShadow dx="0" dy="18" stdDeviation="24" flood-color="#12345F" flood-opacity="0.18"/>
      </filter>
      <linearGradient id="glass" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.96"/>
        <stop offset="1" stop-color="#EEF6FF" stop-opacity="0.90"/>
      </linearGradient>
      <linearGradient id="darkGlass" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stop-color="#18263D" stop-opacity="0.96"/>
        <stop offset="1" stop-color="#0E1728" stop-opacity="0.98"/>
      </linearGradient>
      <linearGradient id="accentGradient" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stop-color="#22C7E8"/>
        <stop offset="0.52" stop-color="#2563EB"/>
        <stop offset="1" stop-color="#8B5CF6"/>
      </linearGradient>
      <clipPath id="windowClip"><rect x="230" y="390" width="2100" height="1120" rx="34"/></clipPath>
    </defs>
    <image href="data:image/png;base64,${backgroundData}" x="0" y="0" width="${width}" height="${height}"/>
    <rect x="0" y="0" width="${width}" height="${height}" fill="#FFFFFF" opacity="0.10"/>
    <g transform="translate(108 92)">
      <image href="data:image/png;base64,${iconData}" x="0" y="0" width="74" height="74"/>
      <text x="92" y="51" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="39" font-weight="700" fill="#13213A">Vello</text>
    </g>
    <text x="1280" y="164" text-anchor="middle" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="86" font-weight="750" letter-spacing="-2.8" fill="#111C31">${title}</text>
    <text x="1280" y="245" text-anchor="middle" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="34" font-weight="450" fill="#40506B">${subtitle}</text>
    <rect x="1110" y="288" width="340" height="8" rx="4" fill="${accent}" opacity="0.95"/>
    ${body}
  </svg>`;
}

function windowChrome(title, content, x = 230, y = 390, w = 2100, h = 1120) {
  return `
    <g filter="url(#shadow)">
      <rect x="${x}" y="${y}" width="${w}" height="${h}" rx="34" fill="#F4F6FA" stroke="#FFFFFF" stroke-width="2"/>
      <rect x="${x}" y="${y}" width="${w}" height="78" rx="34" fill="#FAFBFD"/>
      <rect x="${x}" y="${y + 52}" width="${w}" height="26" fill="#FAFBFD"/>
      <circle cx="${x + 34}" cy="${y + 38}" r="10" fill="#FF5F57"/>
      <circle cx="${x + 68}" cy="${y + 38}" r="10" fill="#FFBD2E"/>
      <circle cx="${x + 102}" cy="${y + 38}" r="10" fill="#28C840"/>
      <text x="${x + w / 2}" y="${y + 49}" text-anchor="middle" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="24" font-weight="600" fill="#313B4E">${title}</text>
      <line x1="${x}" y1="${y + 78}" x2="${x + w}" y2="${y + 78}" stroke="#D8DEE8" stroke-width="2"/>
      ${content}
    </g>`;
}

function iconCircle(cx, cy, glyph, selected = false) {
  return `<circle cx="${cx}" cy="${cy}" r="31" fill="${selected ? "#E7F0FF" : "#F0F3F7"}"/>
    <text x="${cx}" y="${cy + 10}" text-anchor="middle" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="29" font-weight="700" fill="${selected ? "#2563EB" : "#536078"}">${glyph}</text>`;
}

function captureScreenshot() {
  const body = `
    <g filter="url(#shadow)">
      <rect x="190" y="385" width="2180" height="1115" rx="38" fill="#0E1728"/>
      <rect x="190" y="385" width="2180" height="74" rx="38" fill="#F4F6F9"/>
      <rect x="190" y="433" width="2180" height="26" fill="#F4F6F9"/>
      <circle cx="226" cy="423" r="10" fill="#FF5F57"/><circle cx="260" cy="423" r="10" fill="#FFBD2E"/><circle cx="294" cy="423" r="10" fill="#28C840"/>
      <text x="1280" y="433" text-anchor="middle" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="23" font-weight="600" fill="#344157">Project Overview</text>
      <rect x="190" y="459" width="2180" height="1041" fill="#1B2740"/>
      <rect x="260" y="520" width="420" height="820" rx="22" fill="#24334F"/>
      <rect x="310" y="580" width="290" height="30" rx="15" fill="#3B4D6D"/>
      <rect x="310" y="652" width="240" height="22" rx="11" fill="#33435F"/>
      <rect x="310" y="710" width="300" height="22" rx="11" fill="#33435F"/>
      <rect x="310" y="768" width="200" height="22" rx="11" fill="#33435F"/>
      <rect x="745" y="520" width="1555" height="180" rx="22" fill="#F8FBFF"/>
      <text x="810" y="590" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="27" font-weight="700" fill="#1B2941">Weekly progress</text>
      <rect x="810" y="632" width="1130" height="18" rx="9" fill="#DCE7F6"/>
      <rect x="810" y="632" width="760" height="18" rx="9" fill="url(#accentGradient)"/>
      <rect x="745" y="735" width="480" height="465" rx="22" fill="#F8FBFF"/>
      <rect x="1265" y="735" width="1035" height="465" rx="22" fill="#F8FBFF"/>
      <circle cx="985" cy="925" r="126" fill="none" stroke="#DDE6F2" stroke-width="42"/>
      <path d="M985 799 A126 126 0 0 1 1092 991" fill="none" stroke="#2563EB" stroke-width="42" stroke-linecap="round"/>
      <polyline points="1330,1080 1450,970 1570,1015 1705,845 1840,910 1995,790 2215,925" fill="none" stroke="#22C7E8" stroke-width="19" stroke-linecap="round" stroke-linejoin="round"/>
      <rect x="190" y="459" width="2180" height="1041" fill="#07101F" opacity="0.48"/>
      <rect x="625" y="545" width="1310" height="700" fill="#FFFFFF" opacity="0.05" stroke="#FFFFFF" stroke-width="5"/>
      <rect x="625" y="545" width="1310" height="700" fill="#000000" opacity="0.01"/>
      <g fill="#FFFFFF">${[[625,545],[1280,545],[1935,545],[625,895],[1935,895],[625,1245],[1280,1245],[1935,1245]].map(([x,y])=>`<rect x="${x-8}" y="${y-8}" width="16" height="16"/>`).join("")}</g>
      <g transform="translate(835 1268)" filter="url(#softShadow)">
        <rect x="0" y="0" width="890" height="116" rx="34" fill="#151E2D" fill-opacity="0.94" stroke="#FFFFFF" stroke-opacity="0.18"/>
        <text x="44" y="49" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="25" font-weight="650" fill="#FFFFFF">1310 × 700</text>
        <text x="44" y="79" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="18" fill="#AEB9CA">2620 × 1400 px</text>
        <circle cx="442" cy="58" r="40" fill="none" stroke="#FFFFFF" stroke-width="4"/>
        <circle cx="442" cy="58" r="28" fill="#FF3B30"/>
        ${iconCircle(660,58,"●",true)}
        ${iconCircle(738,58,"↗",true)}
        ${iconCircle(816,58,"•••",false)}
      </g>
      <g filter="url(#softShadow)"><rect x="850" y="485" width="860" height="66" rx="33" fill="#111827" opacity="0.88"/><text x="1280" y="528" text-anchor="middle" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="23" font-weight="620" fill="#FFFFFF">Drag to select · Press Space to capture a window</text></g>
    </g>`;
  return base("Record exactly what matters", "Choose a region, a window, or your full display.", body);
}

function editorContent() {
  const x = 230, y = 390;
  let thumbs = "";
  const colors = ["#1D4ED8","#2563EB","#0EA5E9","#22C7E8","#7C3AED","#8B5CF6","#2563EB","#0891B2","#4F46E5","#2563EB","#8B5CF6","#22C7E8"];
  for (let i = 0; i < 12; i++) {
    thumbs += `<rect x="${470 + i * 118}" y="1251" width="108" height="82" rx="7" fill="${colors[i]}"/><path d="M${470+i*118} 1325 L${530+i*118} 1266 L${578+i*118} 1325 Z" fill="#FFFFFF" opacity="0.22"/>`;
  }
  return `
    <rect x="${x}" y="${y+78}" width="2100" height="690" fill="#0C1322"/>
    <image href="data:image/png;base64,${backgroundData}" x="475" y="520" width="1610" height="575" preserveAspectRatio="xMidYMid slice"/>
    <rect x="475" y="520" width="1610" height="575" fill="#0B1830" opacity="0.12"/>
    <text x="1280" y="750" text-anchor="middle" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="74" font-weight="760" fill="#17305B">Make every moment clear.</text>
    <rect x="870" y="800" width="820" height="8" rx="4" fill="url(#accentGradient)"/>
    <text x="1280" y="875" text-anchor="middle" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="32" fill="#40577D">A polished walkthrough, ready to share.</text>
    <rect x="${x}" y="${y+768}" width="2100" height="178" fill="#F5F7FA"/>
    <circle cx="302" cy="1258" r="29" fill="#E7ECF3"/><path d="M294 1244 L294 1272 L315 1258 Z" fill="#25324A"/>
    <text x="352" y="1269" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="21" fill="#647087">0:04</text>
    ${thumbs}
    <rect x="825" y="1237" width="890" height="110" fill="#2563EB" opacity="0.10" stroke="#2563EB" stroke-width="4"/>
    <rect x="811" y="1228" width="16" height="128" rx="8" fill="#2563EB"/><rect x="1713" y="1228" width="16" height="128" rx="8" fill="#2563EB"/>
    <text x="2178" y="1269" text-anchor="end" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="21" fill="#647087">0:17</text>
    <line x1="${x}" y1="1360" x2="2330" y2="1360" stroke="#D9DFE8" stroke-width="2"/>
    <rect x="${x}" y="1362" width="2100" height="148" fill="#FAFBFC"/>
    <g font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="22" fill="#25324A">
      <rect x="285" y="1400" width="124" height="64" rx="13" fill="#EEF1F5"/><text x="347" y="1441" text-anchor="middle">100%</text>
      <rect x="434" y="1400" width="140" height="64" rx="13" fill="#EEF1F5"/><text x="504" y="1441" text-anchor="middle">60 fps</text>
      <text x="615" y="1441" fill="#6C7688">2560 × 1600</text>
      <rect x="1616" y="1400" width="124" height="64" rx="13" fill="#EEF1F5"/><text x="1678" y="1441" text-anchor="middle">MP4</text>
      <rect x="1765" y="1400" width="210" height="64" rx="13" fill="#EEF1F5"/><text x="1870" y="1441" text-anchor="middle">Downloads</text>
      <text x="2055" y="1441" fill="#B42318">Discard</text>
      <rect x="2163" y="1394" width="126" height="74" rx="15" fill="#2563EB"/><text x="2226" y="1441" text-anchor="middle" fill="#FFFFFF" font-weight="700">Export</text>
    </g>`;
}

function editorScreenshot() {
  return base("Trim it in seconds", "Preview, resize, mute, and export in one focused editor.", windowChrome("Vello Recording — Editor", editorContent()), "#22C7E8");
}

function settingsContent() {
  const row = (y, label, control) => `<text x="650" y="${y}" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="25" fill="#263248">${label}</text>${control}`;
  const toggle = (x,y,on=true) => `<rect x="${x}" y="${y-28}" width="72" height="40" rx="20" fill="${on ? "#2563EB" : "#CBD3DE"}"/><circle cx="${on ? x+52 : x+20}" cy="${y-8}" r="16" fill="#FFFFFF"/>`;
  const menu = (x,y,text,w=280) => `<rect x="${x}" y="${y-36}" width="${w}" height="50" rx="10" fill="#FFFFFF" stroke="#CDD5E0"/><text x="${x+20}" y="${y-3}" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="22" fill="#263248">${text}</text><text x="${x+w-25}" y="${y-3}" text-anchor="middle" font-size="18" fill="#6C7688">⌄</text>`;
  return `
    <rect x="230" y="468" width="2100" height="1042" fill="#EEF1F5"/>
    <rect x="440" y="520" width="1680" height="555" rx="24" fill="#FFFFFF"/>
    <text x="510" y="585" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="24" font-weight="700" fill="#536078">RECORDING</text>
    ${row(660,"Show cursor",toggle(1830,660,true))}
    ${row(735,"Highlight clicks",toggle(1830,735,true))}
    ${row(810,"Frame rate",menu(1620,810,"60 fps",282))}
    ${row(885,"Record microphone",toggle(1830,885,true))}
    ${row(960,"Input device",menu(1520,960,"System Default",382))}
    <rect x="440" y="1110" width="1680" height="310" rx="24" fill="#FFFFFF"/>
    <text x="510" y="1175" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="24" font-weight="700" fill="#536078">EXPORTS</text>
    ${row(1250,"Default format",menu(1620,1250,"MP4",282))}
    ${row(1325,"Loop GIF and APNG exports",toggle(1830,1325,true))}
    <g filter="url(#softShadow)">
      ${[[1860,535,"MP4","Universal video"],[2050,700,"HEVC","Smaller files"],[1970,910,"GIF","Easy sharing"],[2080,1100,"APNG","Crisp animation"]].map(([x,y,f,s],i)=>`<g transform="translate(${x-100} ${y-58}) rotate(${i%2?4:-4})"><rect x="0" y="0" width="280" height="116" rx="24" fill="${i<2?"#17243A":"#FFFFFF"}" stroke="#FFFFFF" stroke-width="2"/><text x="28" y="48" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="29" font-weight="760" fill="${i<2?"#FFFFFF":"#1C2B44"}">${f}</text><text x="28" y="82" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="18" fill="${i<2?"#AFC2DE":"#647087"}">${s}</text></g>`).join("")}
    </g>`;
}

function formatsScreenshot() {
  return base("One recording. Four formats.", "Choose MP4, HEVC, GIF, or APNG—then save where you want.", windowChrome("Vello Settings", settingsContent()), "#8B5CF6");
}

function privacyScreenshot() {
  const body = `
    <g filter="url(#shadow)">
      <rect x="250" y="405" width="2060" height="1060" rx="46" fill="url(#glass)" stroke="#FFFFFF" stroke-width="3"/>
      <image href="data:image/png;base64,${iconData}" x="380" y="560" width="540" height="540"/>
      <text x="650" y="1190" text-anchor="middle" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="30" font-weight="700" fill="#22314B">Native macOS recording</text>
      <text x="650" y="1235" text-anchor="middle" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="23" fill="#647087">Built with Swift and Apple media frameworks</text>
      <line x1="1045" y1="500" x2="1045" y2="1370" stroke="#D8E4F4" stroke-width="3"/>
      ${[
        [1130,560,"✓","Recordings stay on your Mac","Files remain local unless you choose to share them."],
        [1130,795,"⌁","Core features work offline","Recording, trimming, and export need no network."],
        [1130,1030,"○","No ads or analytics SDKs","A focused recorder without behavioral tracking."],
      ].map(([x,y,g,t,s],i)=>`<g transform="translate(${x} ${y})"><rect x="0" y="0" width="1030" height="190" rx="30" fill="#FFFFFF" fill-opacity="0.86" stroke="#DDE8F6" stroke-width="2"/><circle cx="92" cy="95" r="52" fill="${i===0?"#E8F4FF":i===1?"#ECF9FC":"#F2EDFF"}"/><text x="92" y="111" text-anchor="middle" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="46" font-weight="700" fill="${i===0?"#2563EB":i===1?"#0891B2":"#7C3AED"}">${g}</text><text x="175" y="83" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="33" font-weight="720" fill="#17243A">${t}</text><text x="175" y="128" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="23" fill="#647087">${s}</text></g>`).join("")}
    </g>`;
  return base("Private by design", "Your screen, your files, your Mac.", body, "#2563EB");
}

const screenshots = [
  ["01-record-exactly-what-matters.png", captureScreenshot()],
  ["02-trim-it-in-seconds.png", editorScreenshot()],
  ["03-one-recording-four-formats.png", formatsScreenshot()],
  ["04-private-by-design.png", privacyScreenshot()],
];

for (const [name, svg] of screenshots) {
  await sharp(Buffer.from(svg))
    .flatten({ background: "#FFFFFF" })
    .png({ compressionLevel: 9, adaptiveFiltering: true })
    .toFile(path.join(outputDir, name));
  console.log(`Wrote ${path.join(outputDir, name)}`);
}
