/**
 * extract-medicine-data.js - 从 MedicineDatabase.ets 提取数据生成 JSON
 * 用法: node extract-medicine-data.js
 */

const fs = require('fs');
const path = require('path');

const sourceFile = path.join(__dirname, '../entry/src/main/ets/services/MedicineDatabase.ets');
const outputDir = path.join(__dirname, '../entry/src/main/resources/rawfile');

console.log('Reading:', sourceFile);
const content = fs.readFileSync(sourceFile, 'utf-8');
console.log('File size:', content.length, 'chars');

// 提取 medicineDb 数组
const medicineDbMatch = content.match(/private static medicineDb: MedicineInfo\[\] = \[([\s\S]*?)\];/);
if (!medicineDbMatch) {
  console.error('ERROR: Cannot find medicineDb');
  process.exit(1);
}
const medicineDbContent = medicineDbMatch[1];
console.log('MedicineDb content length:', medicineDbContent.length);

// 解析药品数据
const medicines = [];
const medicinePattern = /\{ name: '([^']+)', aliases: \[([^\]]*)\], pinyin: '([^']+)', category: '([^']+)', commonDosageForms: \[([^\]]*)\] \}/g;
let match;
while ((match = medicinePattern.exec(medicineDbContent)) !== null) {
  const name = match[1];
  const aliasesStr = match[2];
  const pinyin = match[3];
  const category = match[4];
  const dosageFormsStr = match[5];

  // 解析别名
  const aliases = aliasesStr.trim()
    ? aliasesStr.split("'").filter(s => s.trim() && s !== ',' && s !== '')
    : [];

  // 解析剂型
  const dosageForms = dosageFormsStr.trim()
    ? dosageFormsStr.split("'").filter(s => s.trim() && s !== ',' && s !== '')
    : [];

  medicines.push({
    name,
    aliases,
    pinyin,
    category,
    commonDosageForms: dosageForms
  });
}
console.log('Extracted', medicines.length, 'medicines');

// 提取 asrCorrectionMap
const asrCorrectionMap = {};
const asrMatch = content.match(/private static asrCorrectionMap: Map<string, string> = new Map\(\[([\s\S]*?)\]\);/);
if (asrMatch) {
  const asrPattern = /\['([^']+)', '([^']+)'\]/g;
  let asrM;
  while ((asrM = asrPattern.exec(asrMatch[1])) !== null) {
    asrCorrectionMap[asrM[1]] = asrM[2];
  }
}
console.log('Extracted', Object.keys(asrCorrectionMap).length, 'ASR corrections');

// 提取 charToInitial
const charToInitial = {};
const charMatch = content.match(/private static charToInitial: Map<string, string> = new Map\(\[([\s\S]*?)\]\);/);
if (charMatch) {
  const charPattern = /\['([^']+)', '([^']+)'\]/g;
  let charM;
  while ((charM = charPattern.exec(charMatch[1])) !== null) {
    charToInitial[charM[1]] = charM[2];
  }
}
console.log('Extracted', Object.keys(charToInitial).length, 'char-to-initial mappings');

// 提取 homophoneMap
const homophoneMap = {};
const homoMatch = content.match(/private static homophoneMap: Map<string, string\[\]> = new Map\(\[([\s\S]*?)\]\);/);
if (homoMatch) {
  const homoPattern = /\['([^']+)', \[([^\]]+)\]\]/g;
  let homoM;
  while ((homoM = homoPattern.exec(homoMatch[1])) !== null) {
    const key = homoM[1];
    const valuesStr = homoM[2];
    const values = valuesStr.split("'").filter(s => s.trim() && s !== ',' && s !== '');
    homophoneMap[key] = values;
  }
}
console.log('Extracted', Object.keys(homophoneMap).length, 'homophone mappings');

// 生成 medicine_base.json
const medicineJson = {
  version: '2026.04.05',
  totalCount: medicines.length,
  medicines: medicines,
  asrCorrections: asrCorrectionMap,
  charToInitial: charToInitial,
  homophoneMap: homophoneMap
};

const outputPath = path.join(outputDir, 'medicine_base.json');
fs.writeFileSync(outputPath, JSON.stringify(medicineJson, null, 2), 'utf-8');
console.log('Generated:', outputPath);

// 生成 medicine_version.json
const versionJson = {
  version: '2026.04.05',
  incrementalUrl: '',
  checksum: ''
};
fs.writeFileSync(path.join(outputDir, 'medicine_version.json'), JSON.stringify(versionJson, null, 2), 'utf-8');
console.log('Generated:', path.join(outputDir, 'medicine_version.json'));

console.log('\n=== Summary ===');
console.log('Medicines:', medicines.length);
console.log('ASR corrections:', Object.keys(asrCorrectionMap).length);
console.log('Char-to-initial:', Object.keys(charToInitial).length);
console.log('Homophones:', Object.keys(homophoneMap).length);
console.log('Phase 1 complete!');