/**
 * 生成提示音 - 短促"滴"声（100ms）
 * 用法: node generate-beep.js
 */

const fs = require('fs');
const path = require('path');

// WAV 文件参数
const sampleRate = 16000;  // 16kHz
const duration = 0.1;      // 100ms
const frequency = 880;     // A5 音符（滴声）
const volume = 0.9;        // 音量 90%（更响亮）

// 计算样本数
const numSamples = Math.floor(sampleRate * duration);

// 创建 WAV 文件头
function createWavHeader(dataLength) {
  const header = Buffer.alloc(44);

  // RIFF chunk
  header.write('RIFF', 0);
  header.writeUInt32LE(36 + dataLength, 4);
  header.write('WAVE', 8);

  // fmt chunk
  header.write('fmt ', 12);
  header.writeUInt32LE(16, 16);        // chunk size
  header.writeUInt16LE(1, 20);         // audio format (PCM)
  header.writeUInt16LE(1, 22);         // num channels (mono)
  header.writeUInt32LE(sampleRate, 24);
  header.writeUInt32LE(sampleRate * 2, 28);  // byte rate
  header.writeUInt16LE(2, 32);         // block align
  header.writeUInt16LE(16, 34);        // bits per sample

  // data chunk
  header.write('data', 36);
  header.writeUInt32LE(dataLength, 40);

  return header;
}

// 生成正弦波音频数据
function generateBeep() {
  const samples = Buffer.alloc(numSamples * 2);  // 16-bit samples

  for (let i = 0; i < numSamples; i++) {
    const t = i / sampleRate;

    // 正弦波 + 淡入淡出（避免爆音）
    let sample = Math.sin(2 * Math.PI * frequency * t);

    // 淡入淡出（前 10ms 淡入，后 10ms 淡出）
    const fadeInSamples = Math.floor(sampleRate * 0.01);
    const fadeOutSamples = Math.floor(sampleRate * 0.01);

    if (i < fadeInSamples) {
      sample *= i / fadeInSamples;
    } else if (i > numSamples - fadeOutSamples) {
      sample *= (numSamples - i) / fadeOutSamples;
    }

    // 应用音量并转换为 16-bit 整数
    const value = Math.floor(sample * volume * 32767);
    samples.writeInt16LE(value, i * 2);
  }

  return samples;
}

// 生成并保存
const outputDir = path.join(__dirname, '../entry/src/main/resources/rawfile');
const outputPath = path.join(outputDir, 'beep.wav');

const audioData = generateBeep();
const header = createWavHeader(audioData.length);
const wavFile = Buffer.concat([header, audioData]);

fs.writeFileSync(outputPath, wavFile);

console.log('Generated beep.wav:');
console.log('  Duration:', (duration * 1000).toFixed(0), 'ms');
console.log('  Sample rate:', sampleRate, 'Hz');
console.log('  Frequency:', frequency, 'Hz');
console.log('  Output:', outputPath);