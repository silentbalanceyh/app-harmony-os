import fs from 'node:fs/promises';
import path from 'node:path';

const designRoot = new URL('./', import.meta.url);
const svgDir = new URL('./svg/', designRoot);

const W = 430;
const H = 932;

const c = {
  bg: '#F8F6F0',
  paper: '#FFFDF7',
  ink: '#1F2328',
  sub: '#5F6368',
  line: '#D8D1C5',
  blue: '#A5D8FF',
  lavender: '#D0BFFF',
  mint: '#B2F2BB',
  yellow: '#FFE066',
  orange: '#FFD8A8',
  pink: '#FFC9C9',
  green: '#B2F2BB',
  red: '#FFA8A8',
  shadow: '#D7D0C4'
};

const r = {
  phone: 24,
  phoneInner: 20,
  panel: 16,
  card: 14,
  small: 12,
  pill: 10,
  button: 12,
  tile: 12,
  input: 10,
  folder: 8
};

const FONT_FAMILY = 'EmbeddedHannotateTC';

function esc(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function text(x, y, value, size = 16, weight = 600, fill = c.ink, anchor = 'start') {
  return `<text x="${x}" y="${y}" font-family="'${FONT_FAMILY}','Hannotate TC','Hannotate SC','PingFang TC','PingFang SC','Noto Sans CJK TC',sans-serif" font-size="${size}" font-weight="${weight}" fill="${fill}" text-anchor="${anchor}">${esc(value)}</text>`;
}

let embeddedFontCss = '';

async function loadEmbeddedFonts() {
  const regularPath = new URL('./fonts/HannotateTC-Regular.subset.woff2', designRoot);
  const boldPath = new URL('./fonts/HannotateTC-Bold.subset.woff2', designRoot);
  const [regular, bold] = await Promise.all([
    fs.readFile(regularPath),
    fs.readFile(boldPath)
  ]);
  embeddedFontCss = `
    @font-face {
      font-family: '${FONT_FAMILY}';
      src: url(data:font/woff2;base64,${regular.toString('base64')}) format('woff2');
      font-style: normal;
      font-weight: 400 699;
    }
    @font-face {
      font-family: '${FONT_FAMILY}';
      src: url(data:font/woff2;base64,${bold.toString('base64')}) format('woff2');
      font-style: normal;
      font-weight: 700 900;
    }
  `;
}

function defs() {
  return `
    <style><![CDATA[
      ${embeddedFontCss}
    ]]></style>
    <filter id="softShadow" x="-20%" y="-20%" width="150%" height="160%">
      <feDropShadow dx="3" dy="5" stdDeviation="0.4" flood-color="${c.shadow}" flood-opacity="0.5"/>
    </filter>
    <filter id="smallShadow" x="-20%" y="-20%" width="150%" height="160%">
      <feDropShadow dx="2" dy="3" stdDeviation="0.3" flood-color="${c.shadow}" flood-opacity="0.45"/>
    </filter>
    <pattern id="dots" width="32" height="32" patternUnits="userSpaceOnUse">
      <path d="M0 31.5H32M31.5 0V32" stroke="#E9E0D3" stroke-width="1" opacity="0.55"/>
    </pattern>
  `;
}

function sketchRect(x, y, w, h, rx, fill = c.paper, strokeWidth = 2, filter = 'url(#smallShadow)') {
  return `
    <g ${filter ? `filter="${filter}"` : ''}>
      <rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${rx}" fill="${fill}" opacity="0.92"/>
      <rect x="${x + 0.8}" y="${y - 0.4}" width="${w - 1}" height="${h + 0.6}" rx="${rx}" fill="none" stroke="${c.ink}" stroke-width="${strokeWidth}" stroke-linejoin="round"/>
      <rect x="${x - 0.6}" y="${y + 0.9}" width="${w + 0.8}" height="${h - 1.2}" rx="${Math.max(2, rx - 1)}" fill="none" stroke="${c.ink}" stroke-width="${Math.max(1, strokeWidth - 0.7)}" stroke-linejoin="round" opacity="0.72"/>
    </g>
  `;
}

function phone({ title, subtitle = '', body }) {
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>${defs()}</defs>
  <rect width="${W}" height="${H}" rx="${r.phone}" fill="${c.bg}"/>
  <rect width="${W}" height="${H}" rx="${r.phone}" fill="url(#dots)" opacity="0.62"/>
  ${sketchRect(14, 14, 402, 904, r.phoneInner, 'transparent', 1.6, '')}
  <rect x="160" y="12" width="110" height="22" rx="8" fill="${c.ink}"/>
  ${text(42, 54, '9:41', 14, 700, c.ink)}
  <rect x="342" y="41" width="34" height="16" rx="3" stroke="${c.ink}" stroke-width="2"/>
  <rect x="346" y="45" width="22" height="8" rx="2" fill="${c.ink}"/>
  <circle cx="390" cy="49" r="7" fill="${c.ink}"/>
  ${title ? text(26, 106, title, 28, 800, c.ink) : ''}
  ${subtitle ? text(26, 134, subtitle, 14, 600, c.sub) : ''}
  ${body}
</svg>`;
}

function card(x, y, w, h, fill = c.paper, radius = r.panel) {
  return sketchRect(x, y, w, h, radius, fill, 2.1, 'url(#softShadow)');
}

function smallCard(x, y, w, h, fill = c.paper, radius = r.card) {
  return sketchRect(x, y, w, h, radius, fill, 1.9, 'url(#smallShadow)');
}

function pill(x, y, w, label, fill = '#FFF2C8', ink = c.ink) {
  return `
    ${sketchRect(x, y, w, 34, r.pill, fill, 1.6, '')}
    ${text(x + w / 2, y + 23, label, 13, 800, ink, 'middle')}
  `;
}

function mascot(x, y, scale = 1) {
  return `
    <g transform="translate(${x} ${y}) scale(${scale})">
      <ellipse cx="56" cy="80" rx="48" ry="42" fill="#FFF4D7" stroke="${c.ink}" stroke-width="2.6"/>
      <ellipse cx="55" cy="81" rx="46" ry="40" fill="none" stroke="${c.ink}" stroke-width="1.4" opacity="0.65"/>
      <circle cx="36" cy="62" r="8" fill="${c.ink}"/>
      <circle cx="76" cy="62" r="8" fill="${c.ink}"/>
      <path d="M46 82 Q56 92 68 82" stroke="${c.ink}" stroke-width="2.6" stroke-linecap="round" fill="none"/>
      <path d="M30 34 C22 8 54 18 48 42" fill="${c.yellow}" stroke="${c.ink}" stroke-width="2.4"/>
      <path d="M82 34 C92 8 58 18 64 42" fill="${c.yellow}" stroke="${c.ink}" stroke-width="2.4"/>
      ${sketchRect(28, 94, 56, 34, 9, c.blue, 2, '')}
      <circle cx="56" cy="111" r="7" fill="#FFF"/>
    </g>
  `;
}

function backButton(x = 26, y = 82) {
  return `
    <circle cx="${x + 18}" cy="${y + 18}" r="18" fill="#FFFFFF" stroke="${c.ink}" stroke-width="2.5" filter="url(#smallShadow)"/>
    ${text(x + 18, y + 25, '←', 22, 800, c.ink, 'middle')}
  `;
}

function menuDots(x = 368, y = 82) {
  return `
    <circle cx="${x + 18}" cy="${y + 18}" r="18" fill="#FFFFFF" stroke="${c.ink}" stroke-width="2.5" filter="url(#smallShadow)"/>
    ${text(x + 18, y + 24, '⋮', 22, 800, c.ink, 'middle')}
  `;
}

function numKey(x, y, label, fill = '#FFFFFF') {
  return `
    ${sketchRect(x, y, 78, 72, r.button, fill, 1.9, 'url(#smallShadow)')}
    ${text(x + 39, y + 46, label, label.length > 1 ? 15 : 28, 800, c.ink, 'middle')}
  `;
}

function renderUnlock() {
  const body = `
    ${mascot(144, 148, 1.25)}
    ${card(30, 320, 370, 554, '#FFFFFF')}
    ${text(56, 366, '加密相册', 28, 900)}
    ${text(56, 394, '请输入密码以解锁', 16, 700, c.sub)}
    ${[0, 1, 2, 3, 4, 5].map(i => `<circle cx="${96 + i * 48}" cy="448" r="12" fill="${i < 2 ? c.blue : '#F4E4CF'}" stroke="${c.ink}" stroke-width="2"/>`).join('')}
    ${text(215, 496, '密码错误时可触发闯入者拍摄', 13, 700, c.sub, 'middle')}
    ${numKey(58, 536, '1')}${numKey(176, 536, '2')}${numKey(294, 536, '3')}
    ${numKey(58, 628, '4')}${numKey(176, 628, '5')}${numKey(294, 628, '6')}
    ${numKey(58, 720, '7')}${numKey(176, 720, '8')}${numKey(294, 720, '9')}
    ${numKey(58, 812, '', '#FFF8EA')}${numKey(176, 812, '0')}${numKey(294, 812, '⌫', '#FFE2D8')}
  `;
  return phone({ title: '密码解锁', body });
}

function featureCard(x, y, color, icon, title, desc) {
  return `
    ${smallCard(x, y, 176, 150, '#FFFFFF')}
    <circle cx="${x + 56}" cy="${y + 50}" r="33" fill="${color}" stroke="${c.ink}" stroke-width="2.5"/>
    ${text(x + 56, y + 61, icon, 32, 800, '#FFFFFF', 'middle')}
    ${text(x + 22, y + 98, title, 19, 900)}
    ${text(x + 22, y + 124, desc, 13, 700, c.sub)}
  `;
}

function renderMain() {
  const body = `
    ${mascot(292, 78, 0.72)}
    ${card(26, 158, 378, 118, '#E9F2FF')}
    ${text(54, 202, '密码保护的安全空间', 24, 900)}
    ${text(54, 232, '照片、视频、动图、资料、录音和设置', 14, 700, c.sub)}
    ${pill(54, 248, 106, '返回应用中心', '#FFF2C8')}
    ${featureCard(26, 310, c.blue, '照', '照片', '目录管理')}
    ${featureCard(228, 310, c.pink, '影', '视频', '视频目录')}
    ${featureCard(26, 482, c.yellow, '动', '动图', 'GIF 收纳')}
    ${featureCard(228, 482, c.mint, '文', '资料', '文档资料')}
    ${featureCard(26, 654, c.orange, '录', '录音&文件', '音频文件')}
    ${featureCard(228, 654, c.lavender, '设', '设置', '安全配置')}
  `;
  return phone({ title: '首页', body });
}

function folderRow(y, name, count, color) {
  return `
    ${smallCard(30, y, 370, 82, '#FFFFFF', r.card)}
    ${sketchRect(52, y + 18, 50, 42, r.folder, color, 1.8, '')}
    <path d="M52 ${y + 30} H82 L90 ${y + 20} H102 V${y + 60} H52 Z" fill="${color}" stroke="${c.ink}" stroke-width="2.5"/>
    ${text(124, y + 36, name, 18, 900)}
    ${text(124, y + 62, count, 13, 700, c.sub)}
    ${text(370, y + 53, '›', 26, 900, c.ink, 'middle')}
  `;
}

function popupMenu(x, y, items, width = 124) {
  const rowH = 34;
  const h = items.length * rowH + 12;
  return `
    ${smallCard(x, y, width, h, '#FFFDF7', 10)}
    ${items.map((item, i) => text(x + 14, y + 26 + i * rowH, item, 13, 800, c.ink)).join('')}
  `;
}

function renderCategoryPage({ pageTitle, importLabel, accent, emptyIcon }) {
  const body = `
    ${backButton()}${menuDots()}
    ${text(82, 108, pageTitle, 28, 900)}
    ${popupMenu(258, 120, ['新建目录', importLabel], 114)}
    ${folderRow(340, '目录 01', '12 项', '#FFD166')}
    ${folderRow(444, '目录 02', '4 项', '#78D6B5')}
    ${folderRow(548, '目录 03', '28 项', '#6C8DFF')}
    ${card(30, 690, 370, 150, '#FFFFFF')}
    ${text(215, 734, emptyIcon, 56, 900, c.ink, 'middle')}
    ${text(215, 776, '暂无目录', 20, 900, c.ink, 'middle')}
    ${text(215, 804, '点击右上角菜单创建目录', 14, 700, c.sub, 'middle')}
  `;
  return phone({ title: '', body });
}

function renderPhotos() {
  return renderCategoryPage({
    pageTitle: '照片',
    importLabel: '导入照片',
    accent: '#EAF7FF',
    emptyIcon: '🖼'
  });
}

function renderVideos() {
  return renderCategoryPage({
    pageTitle: '视频',
    importLabel: '导入视频',
    accent: '#FFEAF3',
    emptyIcon: '🎬'
  });
}

function renderGifs() {
  return renderCategoryPage({
    pageTitle: '动图',
    importLabel: '导入动图',
    accent: '#FFF2C8',
    emptyIcon: '🎭'
  });
}

function renderDocs() {
  return renderCategoryPage({
    pageTitle: '资料',
    importLabel: '导入资料',
    accent: '#DDF7EA',
    emptyIcon: '📄'
  });
}

function renderRecords() {
  return renderCategoryPage({
    pageTitle: '录音&文件',
    importLabel: '导入文件',
    accent: '#E8E1FF',
    emptyIcon: '🎙'
  });
}

function assetTile(x, y, label, fill) {
  return `
    ${sketchRect(x, y, 112, 106, r.tile, fill, 1.8, 'url(#smallShadow)')}
    ${text(x + 56, y + 62, label, 17, 900, c.ink, 'middle')}
  `;
}

function renderFolderDetail() {
  const body = `
    ${backButton()}${menuDots()}
    ${text(82, 108, '目录详情', 26, 900)}
    ${popupMenu(246, 118, ['新建子目录', '导入照片', '重命名目录', '删除目录'], 126)}
    ${text(30, 334, '子目录', 18, 900)}
    ${folderRow(354, '子目录 01', '3 项', '#FFD166')}
    ${folderRow(458, '子目录 02', '5 项', '#78D6B5')}
    ${text(30, 600, '内容', 18, 900)}
    ${assetTile(30, 622, 'IMG', '#DDEAFF')}
    ${assetTile(158, 622, 'IMG', '#FFE2D8')}
    ${assetTile(286, 622, 'IMG', '#E2F7EA')}
    ${assetTile(30, 752, 'IMG', '#FFF0B8')}
    ${assetTile(158, 752, 'IMG', '#E8E1FF')}
    ${assetTile(286, 752, 'IMG', '#FFDDF0')}
  `;
  return phone({ title: '', body });
}

function importCard(y, color, icon, title, desc) {
  return `
    ${smallCard(30, y, 370, 92, '#FFFFFF')}
    <circle cx="82" cy="${y + 46}" r="33" fill="${color}" stroke="${c.ink}" stroke-width="2.5"/>
    ${text(82, y + 58, icon, 30, 900, '#FFFFFF', 'middle')}
    ${text(122, y + 38, title, 18, 900)}
    ${text(122, y + 64, desc, 13, 700, c.sub)}
    ${text(372, y + 55, '›', 26, 900, c.ink, 'middle')}
  `;
}

function renderImport() {
  const body = `
    ${backButton()}
    ${text(82, 108, '导入照片', 26, 900)}
    ${card(30, 174, 370, 86, '#EAF7FF')}
    ${text(58, 212, '导入到：主目录', 19, 900)}
    ${text(58, 238, '导入内容将保存在当前选中的目录中', 13, 700, c.sub)}
    ${importCard(296, c.blue, '相', '系统相册', '从手机自带相册中选择照片导入')}
    ${importCard(408, c.mint, '文', '本地文件', '从手机本地存储中选择图片文件')}
    ${importCard(520, c.orange, '拍', '拍照', '直接拍摄照片并保存到当前目录')}
    ${importCard(632, c.pink, '享', '应用分享', '从其他应用通过系统分享接收')}
  `;
  return phone({ title: '', body });
}

function settingsGroup(y, title, items) {
  const h = 46 + items.length * 42;
  return `
    ${text(30, y, title, 16, 900)}
    ${smallCard(30, y + 14, 370, h, '#FFFFFF', r.card)}
    ${items.map((item, i) => `
      ${text(60, y + 50 + i * 42, item[0], 24, 800)}
      ${text(102, y + 48 + i * 42, item[1], 15, 800)}
      ${text(370, y + 48 + i * 42, '›', 21, 900, c.ink, 'middle')}
    `).join('')}
  `;
}

function renderSettings() {
  const body = `
    ${backButton()}
    ${text(82, 108, '设置', 28, 900)}
    ${settingsGroup(184, '文件管理', [['🗑', '回收站'], ['📄', '查看重复文件'], ['📊', '大文件排序'], ['🧹', '清理临时文件']])}
    ${settingsGroup(406, '数据安全', [['💾', '备份数据'], ['📸', '闯入者拍摄'], ['📱', '手机互传']])}
    ${settingsGroup(586, '密码相关', [['🔐', '密码与密保'], ['👤', 'Face ID登录']])}
    ${settingsGroup(724, '配置', [['⚙', 'App设置'], ['🌐', '语言设置']])}
  `;
  return phone({ title: '', body });
}

function infoRow(y, left, right, accent = c.sub) {
  return `
    ${text(52, y, left, 15, 800, c.sub)}
    ${text(376, y, right, 14, 700, accent, 'end')}
  `;
}

function actionTag(x, y, label, fill) {
  return `
    ${sketchRect(x, y, 66, 28, r.pill, fill, 1.5, '')}
    ${text(x + 33, y + 19, label, 12, 800, c.ink, 'middle')}
  `;
}

function renderPreview() {
  const body = `
    ${backButton()}
    ${text(82, 108, '内容详情', 28, 900)}
    ${smallCard(30, 174, 370, 300, '#FFFFFF', r.panel)}
    ${sketchRect(58, 204, 314, 240, r.card, '#DDEAFF', 1.9, '')}
    ${text(215, 340, '图片预览', 24, 900, c.ink, 'middle')}
    ${actionTag(302, 188, '删除', '#FFE2D8')}
    ${smallCard(30, 510, 370, 322, '#FFFFFF', r.panel)}
    ${infoRow(556, '名称', 'IMG_20260422.jpg', c.ink)}
    <line x1="50" y1="574" x2="382" y2="574" stroke="${c.line}" stroke-width="2"/>
    ${infoRow(610, '类型', '照片', c.ink)}
    <line x1="50" y1="628" x2="382" y2="628" stroke="${c.line}" stroke-width="2"/>
    ${infoRow(664, '大小', '2.4 MB', c.ink)}
    <line x1="50" y1="682" x2="382" y2="682" stroke="${c.line}" stroke-width="2"/>
    ${infoRow(718, '创建时间', '2026-04-22 08:17', c.ink)}
    <line x1="50" y1="736" x2="382" y2="736" stroke="${c.line}" stroke-width="2"/>
    ${text(52, 772, '文件路径', 15, 800, c.sub)}
    ${text(376, 772, '/storage/media/IMG_20260422.jpg', 12, 700, c.ink, 'end')}
  `;
  return phone({ title: '', body });
}

function listItemRow(y, title, desc, rightA = '', rightB = '') {
  return `
    ${smallCard(30, y, 370, 84, '#FFFFFF', r.card)}
    ${text(52, y + 34, title, 16, 900)}
    ${text(52, y + 60, desc, 12, 700, c.sub)}
    ${rightA ? actionTag(274, y + 28, rightA, '#E8E1FF') : ''}
    ${rightB ? actionTag(342, y + 28, rightB, '#FFE2D8') : ''}
  `;
}

function renderRecycleBin() {
  const body = `
    ${backButton()}
    ${text(82, 108, '回收站', 28, 900)}
    ${pill(314, 100, 70, '清空', '#FFE2D8')}
    ${listItemRow(186, 'IMG_0012', '照片 · 可恢复', '恢复', '删除')}
    ${listItemRow(286, 'travel.mov', '视频 · 可恢复', '恢复', '删除')}
    ${listItemRow(386, 'contract.pdf', '资料 · 可恢复', '恢复', '删除')}
  `;
  return phone({ title: '', body });
}

function renderDuplicateFiles() {
  const body = `
    ${backButton()}
    ${text(82, 108, '查看重复文件', 28, 900)}
    ${smallCard(30, 180, 370, 146, '#FFFFFF', r.panel)}
    ${text(52, 220, '重复项分组', 20, 900)}
    ${text(52, 250, '按文件名聚合重复项', 13, 700, c.sub)}
    ${pill(52, 272, 92, '开始扫描', '#E8E1FF')}
    ${listItemRow(366, 'IMG_0012.jpg', '照片 · 3 个重复', '清理', '')}
    ${listItemRow(466, 'travel.mov', '视频 · 2 个重复', '清理', '')}
  `;
  return phone({ title: '', body });
}

function renderLargeFiles() {
  const body = `
    ${backButton()}
    ${text(82, 108, '大文件排序', 28, 900)}
    ${listItemRow(180, 'holiday.mov', '视频 · 24.8 MB', '', '删除')}
    ${listItemRow(280, 'report.pdf', '资料 · 8.6 MB', '', '删除')}
    ${listItemRow(380, 'voice.m4a', '录音 · 5.1 MB', '', '删除')}
  `;
  return phone({ title: '', body });
}

function renderCleanTemp() {
  const body = `
    ${backButton()}
    ${text(82, 108, '清理临时文件', 28, 900)}
    ${smallCard(30, 190, 370, 180, '#FFFFFF', r.panel)}
    ${text(215, 250, '临时文件', 18, 900, c.sub, 'middle')}
    ${text(215, 300, '12.5 MB', 40, 900, c.red, 'middle')}
    ${pill(171, 328, 88, '立即清理', '#FFE2D8')}
  `;
  return phone({ title: '', body });
}

function renderFaceId() {
  const body = `
    ${backButton()}
    ${text(82, 108, 'Face ID', 28, 900)}
    ${smallCard(30, 184, 370, 126, '#FFFFFF', r.panel)}
    ${text(52, 224, 'Face ID 解锁', 20, 900)}
    ${text(52, 252, '使用面部识别解锁加密相册', 13, 700, c.sub)}
    ${sketchRect(320, 214, 52, 30, r.pill, c.green, 1.5, '')}
    <circle cx="356" cy="229" r="10" fill="#FFF"/>
    ${smallCard(30, 336, 370, 126, '#FFFFFF', r.panel)}
    ${text(52, 376, '文件夹 Face ID 访问', 20, 900)}
    ${text(52, 404, '使用 Face ID 访问特定文件夹', 13, 700, c.sub)}
    ${sketchRect(320, 366, 52, 30, r.pill, '#E9DCCC', 1.5, '')}
    <circle cx="336" cy="381" r="10" fill="#FFF"/>
  `;
  return phone({ title: '', body });
}

function renderIntruderPhoto() {
  const body = `
    ${backButton()}
    ${text(82, 108, '闯入者拍摄', 28, 900)}
    ${smallCard(30, 184, 370, 92, '#FFFFFF', r.panel)}
    ${text(52, 224, '启用闯入者拍摄', 18, 900)}
    ${sketchRect(320, 206, 52, 30, r.pill, c.green, 1.5, '')}
    <circle cx="356" cy="221" r="10" fill="#FFF"/>
    ${card(30, 320, 370, 220, '#FFFDF7')}
    ${text(215, 406, '📸', 60, 900, c.ink, 'middle')}
    ${text(215, 446, '暂无闯入记录', 20, 900, c.ink, 'middle')}
    ${text(215, 478, '开启后，输入错误密码时将自动拍摄', 13, 700, c.sub, 'middle')}
  `;
  return phone({ title: '', body });
}

function renderPasswordSecurity() {
  const body = `
    ${backButton()}
    ${text(82, 108, '密码与密保', 28, 900)}
    ${smallCard(30, 184, 370, 220, '#FFFFFF', r.panel)}
    ${sketchRect(52, 220, 326, 44, r.input, c.bg, 1.6, '')}
    ${text(72, 248, '当前密码', 14, 700, c.sub)}
    ${sketchRect(52, 282, 326, 44, r.input, c.bg, 1.6, '')}
    ${text(72, 310, '新密码', 14, 700, c.sub)}
    ${pill(52, 348, 88, '修改密码', '#E8E1FF')}
  `;
  return phone({ title: '', body });
}

function renderBackupData() {
  const body = `
    ${backButton()}
    ${text(82, 108, '备份数据', 28, 900)}
    ${smallCard(30, 184, 370, 180, '#FFFFFF', r.panel)}
    ${text(215, 248, '💾', 52, 900, c.ink, 'middle')}
    ${text(215, 288, '上次备份: 2026-04-22 08:17', 14, 700, c.sub, 'middle')}
    ${pill(171, 316, 88, '立即备份', '#DDF7EA')}
  `;
  return phone({ title: '', body });
}

function renderPhoneTransfer() {
  const body = `
    ${backButton()}
    ${text(82, 108, '手机互传', 28, 900)}
    ${smallCard(30, 184, 370, 220, '#FFFFFF', r.panel)}
    ${text(215, 228, '本机传输码', 14, 800, c.sub, 'middle')}
    ${text(215, 290, 'AB23KD', 42, 900, c.blue, 'middle')}
    ${text(215, 326, '在另一台设备上输入此代码以建立连接', 13, 700, c.sub, 'middle')}
    ${pill(163, 352, 104, '搜索附近设备', '#FFF2C8')}
  `;
  return phone({ title: '', body });
}

function renderAppSettings() {
  const body = `
    ${backButton()}
    ${text(82, 108, 'App设置', 28, 900)}
    ${smallCard(30, 184, 370, 180, '#FFFFFF', r.panel)}
    ${text(52, 224, '自动锁定', 16, 900)}
    ${sketchRect(320, 206, 52, 30, r.pill, c.green, 1.5, '')}
    <circle cx="356" cy="221" r="10" fill="#FFF"/>
    ${text(52, 276, '锁定延迟', 16, 900)}
    ${text(372, 276, '3分钟', 16, 800, c.blue, 'end')}
    ${text(52, 328, '自动备份', 16, 900)}
    ${sketchRect(320, 310, 52, 30, r.pill, '#E9DCCC', 1.5, '')}
    <circle cx="336" cy="325" r="10" fill="#FFF"/>
  `;
  return phone({ title: '', body });
}

function renderLanguageSettings() {
  const body = `
    ${backButton()}
    ${text(82, 108, '语言设置', 28, 900)}
    ${smallCard(30, 184, 370, 240, '#FFFFFF', r.panel)}
    ${text(52, 226, '简体中文', 16, 900)}
    ${text(372, 226, '✓', 18, 900, c.blue, 'end')}
    ${text(52, 274, '繁體中文', 16, 900)}
    ${text(52, 322, 'English', 16, 900)}
    ${text(52, 370, '日本語', 16, 900)}
    ${text(52, 418, '한국어', 16, 900)}
  `;
  return phone({ title: '', body });
}

function renderOverview() {
  const files = [
    ['01-unlock.svg', '01 密码解锁'],
    ['02-main.svg', '02 首页宫格'],
    ['03-photos.svg', '03 照片目录'],
    ['04-videos.svg', '04 视频目录'],
    ['05-gifs.svg', '05 动图目录'],
    ['06-docs.svg', '06 资料目录'],
    ['07-records.svg', '07 录音&文件'],
    ['08-folder-detail.svg', '08 目录详情'],
    ['09-import.svg', '09 导入照片'],
    ['10-settings.svg', '10 设置分组'],
    ['11-preview.svg', '11 内容详情'],
    ['12-recycle-bin.svg', '12 回收站'],
    ['13-duplicate-files.svg', '13 查看重复文件'],
    ['14-large-files.svg', '14 大文件排序'],
    ['15-clean-temp.svg', '15 清理临时文件'],
    ['16-face-id.svg', '16 Face ID'],
    ['17-intruder-photo.svg', '17 闯入者拍摄'],
    ['18-password-security.svg', '18 密码与密保'],
    ['19-backup-data.svg', '19 备份数据'],
    ['20-phone-transfer.svg', '20 手机互传'],
    ['21-app-settings.svg', '21 App设置'],
    ['22-language-settings.svg', '22 语言设置']
  ];
  const cols = 3;
  const rowCount = Math.ceil(files.length / cols);
  const canvasH = 360 + rowCount * 1140;
  const containerH = canvasH - 160;
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg width="2960" height="${canvasH}" viewBox="0 0 2960 ${canvasH}" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect width="2960" height="${canvasH}" fill="${c.bg}"/>
  <defs>${defs()}</defs>
  ${sketchRect(80, 80, 2800, containerH, 28, '#FFFDF7', 3, 'url(#softShadow)')}
  ${text(160, 190, '私密相册', 68, 900)}
  ${files.map(([file, label], i) => {
    const col = i % 3;
    const row = Math.floor(i / 3);
    const x = 180 + col * 880;
    const y = 360 + row * 1120;
    return `
      <g transform="translate(${x} ${y})">
        ${sketchRect(-20, -20, 470, 972, 22, c.bg, 2.4, '')}
        <image href="./${file}" x="0" y="0" width="430" height="932"/>
        ${text(0, 996, label, 30, 900)}
      </g>
    `;
  }).join('')}
</svg>`;
}

await loadEmbeddedFonts();
const screens = new Map([
  ['01-unlock.svg', renderUnlock()],
  ['02-main.svg', renderMain()],
  ['03-photos.svg', renderPhotos()],
  ['04-videos.svg', renderVideos()],
  ['05-gifs.svg', renderGifs()],
  ['06-docs.svg', renderDocs()],
  ['07-records.svg', renderRecords()],
  ['08-folder-detail.svg', renderFolderDetail()],
  ['09-import.svg', renderImport()],
  ['10-settings.svg', renderSettings()],
  ['11-preview.svg', renderPreview()],
  ['12-recycle-bin.svg', renderRecycleBin()],
  ['13-duplicate-files.svg', renderDuplicateFiles()],
  ['14-large-files.svg', renderLargeFiles()],
  ['15-clean-temp.svg', renderCleanTemp()],
  ['16-face-id.svg', renderFaceId()],
  ['17-intruder-photo.svg', renderIntruderPhoto()],
  ['18-password-security.svg', renderPasswordSecurity()],
  ['19-backup-data.svg', renderBackupData()],
  ['20-phone-transfer.svg', renderPhoneTransfer()],
  ['21-app-settings.svg', renderAppSettings()],
  ['22-language-settings.svg', renderLanguageSettings()],
  ['00-overview.svg', renderOverview()]
]);

await fs.mkdir(svgDir, { recursive: true });
for (const [name, content] of screens) {
  await fs.writeFile(path.join(svgDir.pathname, name), content, 'utf8');
}

console.log(`Generated ${screens.size} feature-complete cartoon SVG files in ${svgDir.pathname}`);
