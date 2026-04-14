/**
 * 药品库服务 - 重构版
 * 包含: 药品数据 + ASR纠错 + 同音字识别 + 拼音匹配
 *
 * 架构说明：
 * - 内置数据作为初始化数据源
 * - MedicineLoader 负责数据管理和查询
 * - MedicineSyncService 负责增量更新
 */

import common from '@ohos.app.ability.common';
import { MedicineLoader, MedicineInfo as LoaderMedicineInfo } from './MedicineLoader';

// 导出 MedicineInfo 接口
export interface MedicineInfo {
  name: string;
  aliases: string[];
  pinyin: string;
  pinyinInitials?: string;  // 拼音首字母，初始化时自动生成
  category: string;
  commonDosageForms: string[];
}

interface MedicineExtractResult {
  name: string;
  dosageForm: string;
}

// 多候选匹配结果
interface MedicineMatchResult {
  medicineName: string;
  confidence: number;  // 1-5，数字越小优先级越高
}

// 编辑距离匹配中间结果
interface LevenshteinMatch {
  name: string;
  distance: number;
}

// 拼音匹配中间结果
interface PinyinMatch {
  name: string;
  score: number;
}

export class MedicineDatabase {

  // 药品数据已迁移到 rawfile/medicine_base.json，此数组仅作为 fallback 占位
  private static medicineDb: MedicineInfo[] = [];

  private static asrCorrectionMap: Map<string, string> = new Map([
    // 手动添加的 ASR 误识别纠错（蒙脱石散的严重误识别）
    ['猛拖死伞', '蒙脱石散'],
    ['猛拖死闪', '蒙脱石散'],
    ['猛拖十闪', '蒙脱石散'],  // 新增：ASR把"石"识别成"十"，"散"识别成"闪"
    ['猛拖十散', '蒙脱石散'],
    ['猛脱石散', '蒙脱石散'],
    ['蒙拖石散', '蒙脱石散'],
    ['蒙脱死散', '蒙脱石散'],
    ['猛脱死伞', '蒙脱石散'],
    ['猛托石散', '蒙脱石散'],
    ['猛托石', '蒙脱石'],
    ['蒙托石散', '蒙脱石散'],
    ['梦拖石散', '蒙脱石散'],
    ['梦脱石散', '蒙脱石散'],
    ['松石散', '蒙脱石散'],
  ]);

  // 汉字到拼音首字母的映射（基于药品库常用字）
  private static charToInitial: Map<string, string> = new Map([
    // f - 复方丹参片相关
    ['复', 'f'], ['傅', 'f'], ['付', 'f'], ['富', 'f'], ['负', 'f'], ['服', 'f'], ['福', 'f'], ['扶', 'f'], ['浮', 'f'], ['符', 'f'],
    ['方', 'f'], ['放', 'f'], ['房', 'f'], ['防', 'f'], ['访', 'f'], ['纺', 'f'], ['仿', 'f'], ['芳', 'f'], ['坊', 'f'], ['非', 'f'],
    // m
    ['蒙', 'm'], ['猛', 'm'], ['梦', 'm'], ['孟', 'm'], ['萌', 'm'], ['盟', 'm'], ['檬', 'm'], ['朦', 'm'],
    // t
    ['脱', 't'], ['拖', 't'], ['托', 't'], ['妥', 't'], ['陀', 't'], ['驼', 't'], ['拓', 't'],
    ['头', 't'], ['透', 't'], ['痛', 't'], ['通', 't'], ['同', 't'], ['童', 't'], ['统', 't'], ['铜', 't'], ['筒', 't'], ['酮', 't'],
    // s
    ['石', 's'], ['十', 's'], ['时', 's'], ['事', 's'], ['实', 's'], ['食', 's'], ['史', 's'], ['使', 's'], ['始', 's'], ['式', 's'], ['示', 's'], ['士', 's'], ['市', 's'], ['师', 's'], ['湿', 's'], ['死', 's'], ['散', 's'], ['三', 's'], ['速', 's'], ['素', 's'], ['苏', 's'], ['酥', 's'], ['诉', 's'], ['塑', 's'], ['宿', 's'],
    // d
    ['丹', 'd'], ['单', 'd'], ['担', 'd'], ['淡', 'd'], ['诞', 'd'], ['定', 'd'], ['丁', 'd'], ['顶', 'd'], ['订', 'd'], ['盯', 'd'], ['钉', 'd'], ['叮', 'd'], ['鼎', 'd'],
    // c
    ['参', 'c'], ['深', 'c'], ['申', 'c'], ['神', 'c'], ['肾', 'c'], ['春', 'c'], ['纯', 'c'], ['存', 'c'], ['寸', 'c'],
    // s - 身是shen，首字母是s
    ['身', 's'], ['生', 's'], ['升', 's'], ['声', 's'], ['胜', 's'], ['圣', 's'], ['盛', 's'], ['省', 's'], ['绳', 's'],
    ['莫', 'm'], ['磨', 'm'], ['膜', 'm'], ['摩', 'm'], ['默', 'm'], ['末', 'm'],
    // x
    ['西', 'x'], ['希', 'x'], ['吸', 'x'], ['细', 'x'], ['系', 'x'], ['息', 'x'], ['席', 'x'], ['习', 'x'], ['洗', 'x'], ['喜', 'x'],
    // l
    ['林', 'l'], ['临', 'l'], ['邻', 'l'], ['磷', 'l'], ['灵', 'l'], ['淋', 'l'], ['琳', 'l'],
    ['立', 'l'], ['力', 'l'], ['利', 'l'], ['理', 'l'], ['里', 'l'], ['李', 'l'], ['离', 'l'], ['礼', 'l'], ['例', 'l'], ['梨', 'l'], ['黎', 'l'], ['丽', 'l'],
    // a
    ['安', 'a'], ['按', 'a'], ['暗', 'a'], ['岸', 'a'], ['案', 'a'], ['氨', 'a'],
    // e
    ['儿', 'e'], ['二', 'e'], ['而', 'e'], ['耳', 'e'], ['尔', 'e'],
    // n
    ['宁', 'n'], ['凝', 'n'], ['拧', 'n'], ['柠', 'n'], ['咛', 'n'], ['囊', 'n'], ['娜', 'n'], ['南', 'n'], ['难', 'n'],
    // j
    ['甲', 'j'], ['加', 'j'], ['佳', 'j'], ['家', 'j'], ['假', 'j'], ['价', 'j'], ['嘉', 'j'],
    // y
    ['压', 'y'], ['牙', 'y'], ['亚', 'y'], ['雅', 'y'], ['芽', 'y'], ['鸭', 'y'], ['哑', 'y'],
    // b
    ['包', 'b'], ['宝', 'b'], ['保', 'b'], ['报', 'b'], ['抱', 'b'], ['暴', 'b'], ['饱', 'b'],
    ['贝', 'b'], ['倍', 'b'], ['背', 'b'], ['被', 'b'], ['杯', 'b'], ['北', 'b'], ['备', 'b'], ['辈', 'b'], ['悲', 'b'],
    // m
    ['美', 'm'], ['梅', 'm'], ['霉', 'm'], ['酶', 'm'], ['煤', 'm'], ['没', 'm'], ['眉', 'm'], ['妹', 'm'],
    // h
    ['黄', 'h'], ['磺', 'h'], ['皇', 'h'], ['凰', 'h'], ['煌', 'h'], ['蝗', 'h'], ['簧', 'h'],
    // q
    ['气', 'q'], ['期', 'q'], ['奇', 'q'], ['起', 'q'], ['其', 'q'], ['七', 'q'], ['妻', 'q'], ['齐', 'q'], ['漆', 'q'], ['棋', 'q'], ['骑', 'q'],
    // z
    ['止', 'z'], ['只', 'z'], ['指', 'z'], ['纸', 'z'], ['至', 'z'], ['知', 'z'], ['直', 'z'], ['治', 'z'], ['质', 'z'], ['智', 'z'],
    ['镇', 'z'], ['针', 'z'], ['真', 'z'], ['珍', 'z'], ['诊', 'z'], ['震', 'z'], ['阵', 'z'], ['侦', 'z'], ['枕', 'z'],
    // g
    ['感', 'g'], ['敢', 'g'], ['干', 'g'], ['杆', 'g'], ['肝', 'g'], ['甘', 'g'], ['柑', 'g'],
    // m
    ['冒', 'm'], ['貌', 'm'], ['帽', 'm'], ['茂', 'm'], ['贸', 'm'], ['毛', 'm'], ['矛', 'm'],
    // j
    ['降', 'j'], ['将', 'j'], ['江', 'j'], ['姜', 'j'], ['浆', 'j'], ['僵', 'j'], ['奖', 'j'], ['匠', 'j'],
    // t
    ['糖', 't'], ['唐', 't'], ['堂', 't'], ['塘', 't'], ['躺', 't'], ['趟', 't'], ['烫', 't'], ['汤', 't'],
    // w
    ['维', 'w'], ['胃', 'w'], ['位', 'w'], ['味', 'w'], ['微', 'w'], ['威', 'w'], ['危', 'w'], ['围', 'w'], ['为', 'w'], ['委', 'w'],
    // d
    ['毒', 'd'], ['度', 'd'], ['渡', 'd'], ['镀', 'd'], ['读', 'd'], ['堵', 'd'], ['睹', 'd'], ['肚', 'd'], ['独', 'd'],
    // b
    ['病', 'b'], ['冰', 'b'], ['兵', 'b'], ['并', 'b'], ['饼', 'b'], ['柄', 'b'], ['丙', 'b'],
    // d
    ['多', 'd'], ['朵', 'd'], ['躲', 'd'], ['堕', 'd'], ['舵', 'd'], ['夺', 'd'],
    // p
    ['潘', 'p'], ['盘', 'p'], ['判', 'p'], ['盼', 'p'], ['胖', 'p'], ['攀', 'p'], ['畔', 'p'],
    // p
    ['片', 'p'], ['骗', 'p'], ['偏', 'p'], ['篇', 'p'], ['翩', 'p'], ['扁', 'p'],
    // a
    ['奥', 'a'], ['澳', 'a'], ['傲', 'a'], ['鳌', 'a'],
    // l
    ['拉', 'l'], ['辣', 'l'], ['腊', 'l'], ['蜡', 'l'], ['蓝', 'l'], ['兰', 'l'], ['啦', 'l'],
    // z
    ['唑', 'z'], ['坐', 'z'], ['作', 'z'], ['做', 'z'], ['左', 'z'], ['座', 'z'], ['佐', 'z'],
    // l
    ['雷', 'l'], ['累', 'l'], ['泪', 'l'], ['类', 'l'], ['擂', 'l'], ['勒', 'l'], ['肋', 'l'],
    // l
    ['氯', 'l'], ['绿', 'l'], ['律', 'l'], ['虑', 'l'], ['滤', 'l'], ['旅', 'l'], ['铝', 'l'], ['侣', 'l'],
    // t
    ['他', 't'], ['她', 't'], ['它', 't'], ['塔', 't'], ['踏', 't'], ['塌', 't'],
    // x
    ['香', 'x'], ['乡', 'x'], ['向', 'x'], ['相', 'x'], ['想', 'x'], ['响', 'x'], ['箱', 'x'], ['象', 'x'], ['像', 'x'], ['详', 'x'], ['享', 'x'],
    // j
    ['胶', 'j'], ['教', 'j'], ['角', 'j'], ['脚', 'j'], ['交', 'j'], ['叫', 'j'], ['焦', 'j'], ['较', 'j'], ['浇', 'j'], ['骄', 'j'], ['娇', 'j'],
    // w
    ['丸', 'w'], ['万', 'w'], ['完', 'w'], ['晚', 'w'], ['玩', 'w'], ['碗', 'w'], ['弯', 'w'], ['湾', 'w'], ['腕', 'w'], ['挽', 'w'],
    // x
    ['心', 'x'], ['新', 'x'], ['信', 'x'], ['辛', 'x'], ['欣', 'x'], ['薪', 'x'], ['锌', 'x'], ['衅', 'x'], ['芯', 'x'],
    // x
    ['效', 'x'], ['小', 'x'], ['消', 'x'], ['笑', 'x'], ['校', 'x'], ['销', 'x'], ['晓', 'x'], ['肖', 'x'], ['削', 'x'], ['萧', 'x'],
    // j
    ['救', 'j'], ['九', 'j'], ['久', 'j'], ['酒', 'j'], ['旧', 'j'], ['就', 'j'], ['究', 'j'], ['纠', 'j'], ['舅', 'j'], ['韭', 'j'],
    // y
    ['炎', 'y'], ['眼', 'y'], ['盐', 'y'], ['烟', 'y'], ['严', 'y'], ['研', 'y'], ['颜', 'y'], ['言', 'y'], ['演', 'y'], ['延', 'y'], ['沿', 'y'], ['宴', 'y'], ['验', 'y'],
    // l
    ['灵', 'l'], ['零', 'l'], ['领', 'l'], ['令', 'l'], ['另', 'l'], ['铃', 'l'], ['玲', 'l'], ['凌', 'l'], ['陵', 'l'], ['岭', 'l'], ['羚', 'l'],
    // y
    ['一', 'y'], ['医', 'y'], ['衣', 'y'], ['依', 'y'], ['伊', 'y'], ['宜', 'y'], ['姨', 'y'], ['移', 'y'], ['仪', 'y'], ['疑', 'y'], ['乙', 'y'], ['已', 'y'], ['以', 'y'],
    // 闪
    ['闪', 's'], ['山', 's'], ['善', 's'], ['扇', 's'], ['衫', 's'], ['杉', 's'],
  ]);

  // 同音字映射表
  private static homophoneMap: Map<string, string[]> = new Map([
    ['蒙', ['猛', '梦', '孟', '萌', '盟', '檬', '朦']],
    ['脱', ['拖', '托', '妥', '陀', '驼', '拓']],
    ['石', ['十', '时', '事', '实', '食', '史', '使', '始', '式', '示', '士', '市', '师', '湿', '死']],
    ['丹', ['单', '担', '淡', '诞']],
    ['参', ['身', '深', '申', '神', '肾']],
    ['莫', ['磨', '膜', '摩', '默', '末']],
    ['西', ['希', '吸', '细', '系', '息', '席', '习', '洗', '喜']],
    ['林', ['临', '邻', '磷', '灵', '淋', '琳']],
    ['安', ['按', '暗', '岸', '案', '氨']],
    ['儿', ['二', '而', '耳', '尔']],
    ['宁', ['凝', '拧', '柠', '咛']],
    ['甲', ['加', '佳', '家', '假', '价', '嘉']],
    ['压', ['牙', '亚', '雅', '芽', '鸭', '哑']],
    ['头', ['投', '透', '偷']],
    ['包', ['宝', '保', '报', '抱', '暴', '饱']],
    ['美', ['梅', '霉', '酶', '煤', '没', '眉', '妹']],
    ['素', ['速', '苏', '酥', '诉', '塑', '宿']],
    ['黄', ['磺', '皇', '凰', '煌', '蝗', '簧']],
    ['气', ['期', '奇', '起', '其', '七', '妻', '齐', '漆', '棋', '骑']],
    ['止', ['只', '指', '纸', '至', '知', '直', '治', '质', '智']],
    ['痛', ['通', '同', '童', '统', '铜', '筒']],
    ['感', ['敢', '干', '杆', '肝', '甘', '柑']],
    ['冒', ['貌', '帽', '茂', '贸', '毛', '矛']],
    ['降', ['将', '江', '姜', '浆', '僵', '奖', '匠']],
    ['糖', ['唐', '堂', '塘', '躺', '趟', '烫', '汤']],
    ['维', ['胃', '位', '味', '微', '威', '危', '围', '为', '委']],
    ['生', ['升', '声', '胜', '圣', '盛', '省', '绳']],
    ['毒', ['度', '渡', '镀', '读', '堵', '睹', '肚', '独']],
    ['病', ['冰', '兵', '并', '饼', '柄', '丙']],
    ['多', ['朵', '躲', '堕', '舵', '夺']],
    ['潘', ['盘', '判', '盼', '胖', '攀', '畔']],
    ['立', ['力', '利', '理', '里', '李', '离', '礼', '例', '梨', '黎', '丽']],
    ['酮', ['通', '同', '童', '统', '铜', '痛']],
    ['奥', ['澳', '傲', '鳌']],
    ['拉', ['辣', '腊', '蜡', '蓝', '兰', '啦']],
    ['唑', ['坐', '作', '做', '左', '座', '佐']],
    ['雷', ['累', '泪', '类', '擂', '勒', '肋']],
    ['贝', ['倍', '背', '被', '杯', '北', '备', '辈', '悲']],
    ['镇', ['针', '真', '珍', '诊', '震', '阵', '侦', '枕']],
    ['氯', ['绿', '律', '虑', '滤', '旅', '铝', '侣']],
    ['他', ['她', '它', '塔', '踏', '塌']],
    ['定', ['丁', '顶', '订', '盯', '钉', '叮', '鼎']],
    ['香', ['乡', '向', '相', '想', '响', '箱', '象', '像', '详', '享']],
    ['胶', ['教', '角', '脚', '交', '叫', '焦', '较', '浇', '骄', '娇']],
    ['囊', ['娜', '南', '难']],
    ['丸', ['万', '完', '晚', '玩', '碗', '弯', '湾', '腕', '挽']],
    ['心', ['新', '信', '辛', '欣', '薪', '锌', '衅', '芯']],
    ['速', ['素', '苏', '酥', '诉', '塑', '宿']],
    ['效', ['小', '消', '笑', '校', '销', '晓', '肖', '削', '萧']],
    ['救', ['九', '久', '酒', '旧', '就', '究', '纠', '舅', '韭']],
    ['炎', ['眼', '盐', '烟', '严', '研', '颜', '言', '演', '延', '沿', '宴', '验']],
    ['片', ['骗', '偏', '篇', '翩', '扁']],
    ['灵', ['零', '领', '令', '另', '铃', '玲', '凌', '陵', '岭', '羚']],
    ['一', ['医', '衣', '依', '伊', '宜', '姨', '移', '仪', '疑', '乙', '已', '以']],
    ['两', ['亮', '良', '凉', '梁', '粮', '量', '辆']],
    ['三', ['散', '伞', '丧']],
    ['四', ['死', '丝', '思', '司', '私', '斯', '撕', '似']],
    ['五', ['无', '舞', '武', '物', '午', '务', '雾', '误', '悟', '捂']],
    ['六', ['流', '留', '刘', '柳', '溜', '瘤', '硫']],
    ['七', ['气', '期', '起', '其', '奇', '妻', '齐', '棋', '骑', '漆', '企', '启']],
    ['八', ['巴', '吧', '爸', '拔', '把', '霸', '罢', '坝']],
    ['九', ['久', '酒', '旧', '救', '就', '究', '纠']],
    ['十', ['时', '事', '实', '石', '食', '史', '使', '始', '式', '示', '士', '市', '师', '湿']],
  ]);

  /**
   * 初始化药品库
   * 从 rawfile 加载外部数据源（medicine_base.json）
   */
  static async initialize(context?: common.Context): Promise<void> {
    console.info('[MedicineDb] Initializing...');

    const loader = MedicineLoader.getInstance();

    // 如果提供了 context，尝试从 rawfile 加载
    if (context) {
      await loader.load(context);
    }

    // 如果 MedicineLoader 已加载数据，使用外部数据源
    if (loader.isLoaded()) {
      console.info('[MedicineDb] Using external data source from rawfile');
      MedicineDatabase.buildIndexesFromLoader(loader);
      return;
    }

    // 回退：使用内置数据（仅当 rawfile 加载失败时）
    console.info('[MedicineDb] Fallback to built-in data');
    for (const m of MedicineDatabase.medicineDb) {
      m.pinyinInitials = MedicineDatabase.generatePinyinInitials(m.pinyin);
    }

    // 构建索引
    for (const m of MedicineDatabase.medicineDb) {
      MedicineDatabase.addToIndex(m.name, m.name);
      if (m.pinyinInitials && m.pinyinInitials.length >= 2) {
        MedicineDatabase.addToIndex(m.pinyinInitials, m.name);
      }
      for (const a of m.aliases) {
        MedicineDatabase.addToIndex(a, m.name);
      }
      for (const f of m.commonDosageForms) {
        MedicineDatabase.addToIndex(m.name + f, m.name + f);
      }
    }

    // 生成同音字变体
    for (const m of MedicineDatabase.medicineDb) {
      MedicineDatabase.generateHomophoneVariants(m.name);
      for (const a of m.aliases) {
        MedicineDatabase.generateHomophoneVariants(a, m.name);
      }
    }

    // 将数据传递给 MedicineLoader
    loader.setData(
      MedicineDatabase.medicineDb as LoaderMedicineInfo[],
      MedicineDatabase.asrCorrectionMap,
      MedicineDatabase.charToInitial,
      MedicineDatabase.homophoneMap
    );

    console.info('[MedicineDb] Initialized with built-in data: ' + MedicineDatabase.medicineDb.length + ' medicines');
  }

  /**
   * 从 MedicineLoader 构建索引（使用外部数据源）
   */
  private static buildIndexesFromLoader(loader: MedicineLoader): void {
    const medicines = loader.getAllMedicines();

    for (const m of medicines) {
      // 构建名称索引
      MedicineDatabase.addToIndex(m.name, m.name);

      // 拼音首字母索引
      if (m.pinyinInitials && m.pinyinInitials.length >= 2) {
        MedicineDatabase.addToIndex(m.pinyinInitials, m.name);
      }

      // 别名索引
      for (const a of (m.aliases || [])) {
        MedicineDatabase.addToIndex(a, m.name);
      }

      // 剂型索引
      for (const f of (m.commonDosageForms || [])) {
        MedicineDatabase.addToIndex(m.name + f, m.name + f);
      }
    }

    // ASR 纠错映射
    for (let i = 0; i < loader.getAsrCorrectionSize(); i++) {
      // MedicineLoader 已加载
    }

    console.info('[MedicineDb] Built indexes for ' + medicines.length + ' medicines');
  }

  private static addToIndex(key: string, correctName: string): void {
    const normalizedKey = key.toLowerCase().replace(/\s/g, '');
    if (!MedicineDatabase.asrCorrectionMap.has(normalizedKey)) {
      MedicineDatabase.asrCorrectionMap.set(normalizedKey, correctName);
    }
  }

  private static generateHomophoneVariants(name: string, targetName?: string): void {
    const correctName = targetName || name;
    const chars = name.split('');

    for (let i = 0; i < chars.length; i++) {
      const char = chars[i];
      const homophones = MedicineDatabase.homophoneMap.get(char);
      if (!homophones || homophones.length === 0) continue;

      for (const homo of homophones) {
        if (homo === char) continue;
        const variantChars = chars.slice();
        variantChars[i] = homo;
        const variant = variantChars.join('');
        MedicineDatabase.addToIndex(variant, correctName);
      }
    }
  }

  static correctAsrResult(text: string): string | null {
    const n = text.toLowerCase().replace(/\s/g, '');

    // 优先使用 MedicineLoader 的数据
    const loader = MedicineLoader.getInstance();
    if (loader.isLoaded()) {
      const corrected = loader.correctAsr(n);
      if (corrected) return corrected;
    }

    // 回退到内置索引
    if (MedicineDatabase.asrCorrectionMap.has(n)) {
      return MedicineDatabase.asrCorrectionMap.get(n) || null;
    }

    for (const k of Array.from(MedicineDatabase.asrCorrectionMap.keys())) {
      if (n.includes(k) || k.includes(n)) {
        return MedicineDatabase.asrCorrectionMap.get(k) || null;
      }
    }

    const textPinyin = MedicineDatabase.textToPinyin(n);
    const medicines = loader.isLoaded() ? loader.getAllMedicines() : MedicineDatabase.medicineDb;
    for (const m of medicines) {
      const similarity = MedicineDatabase.calculateSimilarity(textPinyin, m.pinyin);
      if (similarity > 0.7) {
        return m.name;
      }
    }

    return null;
  }

  /**
   * 多候选结果匹配（五级优先级）
   * @param candidates ASR 返回的多候选结果列表
   * @return 匹配结果：MedicineMatchResult 或 null
   */
  static matchMedicineFromCandidates(candidates: string[]): MedicineMatchResult | null {
    if (!candidates || candidates.length === 0) return null;

    // 使用 MedicineLoader 或内置数据
    const loader = MedicineLoader.getInstance();
    const medicines = loader.isLoaded() ? loader.getAllMedicines() : MedicineDatabase.medicineDb;

    console.info('[MedicineDb] Matching from ' + candidates.length + ' candidates');

    // 遍历所有候选结果，按优先级匹配
    for (const candidate of candidates) {
      const cleaned = candidate.toLowerCase().replace(/[，。、！？\s]+/g, '').trim();
      if (!cleaned) continue;

      // 优先级1：精确匹配药品名称
      for (const m of medicines) {
        if (m.name === cleaned) {
          return { medicineName: m.name, confidence: 1 };
        }
      }

      // 优先级2：精确匹配别名
      for (const m of medicines) {
        if (m.aliases && m.aliases.some((a: string) => a === cleaned)) {
          return { medicineName: m.name, confidence: 2 };
        }
      }

      // 优先级3：子串匹配（ASR 结果中包含药品名但前后有噪声）
      // 例："阿莫欺凌阿莫西林" → 滑动窗口提取 → "阿莫西林" 命中
      for (const candidate of candidates) {
        const cleaned = candidate.toLowerCase().replace(/[，。、！？\s]+/g, '').trim();
        if (!cleaned || cleaned.length < 2) continue;

        const subMatch = MedicineDatabase.matchBySubstring(cleaned, medicines);
        if (subMatch) {
          console.info('[MedicineDb] Substring matched: ' + cleaned + ' -> ' + subMatch.medicineName);
          return subMatch;
        }
      }

      // 优先级4：拼音首字母匹配（模糊匹配，支持子串匹配）
      const candidateInitials = MedicineDatabase.getInitialsFromText(cleaned);
      console.info('[MedicineDb] Candidate initials: ' + candidateInitials + ' for ' + cleaned);

      // 收集所有拼音首字母匹配的结果
      const pinyinMatches: PinyinMatch[] = [];
      for (const m of medicines) {
        if (!m.pinyinInitials) continue;

        // 精确匹配
        if (m.pinyinInitials === candidateInitials) {
          const match: PinyinMatch = { name: m.name, score: 0 };
          pinyinMatches.push(match);
        }
        // 药品拼音首字母包含候选（如 fdsp 匹配 ffdsp）
        else if (m.pinyinInitials.includes(candidateInitials)) {
          const match: PinyinMatch = { name: m.name, score: 1 };
          pinyinMatches.push(match);
        }
        // 候选包含药品拼音首字母（如 ffdsp 匹配 fdsp）
        else if (candidateInitials.includes(m.pinyinInitials)) {
          const match: PinyinMatch = { name: m.name, score: 1 };
          pinyinMatches.push(match);
        }
      }

      // 如果有匹配，按剂型优先排序
      if (pinyinMatches.length > 0) {
        pinyinMatches.sort((a: PinyinMatch, b: PinyinMatch) => a.score - b.score);

        // 剂型优先匹配：如果用户输入包含"片"/"丸"等剂型，优先返回相同剂型的药品
        const dosageForms = ['片', '丸', '胶囊', '颗粒', '口服液', '滴丸', '含片', '喷雾剂'];
        let preferredForm = '';
        for (const form of dosageForms) {
          if (cleaned.endsWith(form)) {
            preferredForm = form;
            break;
          }
        }

        if (preferredForm) {
          // 找到相同剂型的药品
          const formMatch = pinyinMatches.find((m: PinyinMatch) => m.name.endsWith(preferredForm));
          if (formMatch) {
            console.info('[MedicineDb] Pinyin matched with dosage form priority: ' + formMatch.name + ' (user input contains: ' + preferredForm + ')');
            return { medicineName: formMatch.name, confidence: 4 };
          }
        }

        console.info('[MedicineDb] Pinyin matched: ' + pinyinMatches[0].name);
        return { medicineName: pinyinMatches[0].name, confidence: 4 };
      }
    }

    // 优先级5：Levenshtein 模糊匹配
    let bestMatch: LevenshteinMatch | null = null;

    for (const candidate of candidates) {
      const cleaned = candidate.toLowerCase().replace(/[，。、！？\s]+/g, '').trim();
      if (!cleaned) continue;

      for (const m of medicines) {
        const distance = MedicineDatabase.levenshteinDistance(cleaned, m.name);
        if (distance <= 2 && (!bestMatch || distance < bestMatch.distance)) {
          bestMatch = { name: m.name, distance };
        }

        if (m.aliases) {
          for (const alias of m.aliases) {
            const aliasDistance = MedicineDatabase.levenshteinDistance(cleaned, alias);
            if (aliasDistance <= 2 && (!bestMatch || aliasDistance < bestMatch.distance)) {
              bestMatch = { name: m.name, distance: aliasDistance };
            }
          }
        }
      }
    }

    if (bestMatch) {
      return { medicineName: bestMatch.name, confidence: 5 };
    }

    // 最后尝试纠错映射
    for (const candidate of candidates) {
      const corrected = MedicineDatabase.correctAsrResult(candidate);
      if (corrected) {
        return { medicineName: corrected, confidence: 5 };
      }
    }

    return null;
  }

  /**
   * 滑动窗口子串匹配（解决 ASR 识别结果前后有噪声的问题）
   * 例："阿莫欺凌阿莫西林" → 提取 "阿莫西林"
   *
   * 策略：从长到短遍历所有子串，优先匹配较长子串
   * - 子串长度从 8 递减到 2
   * - 使用滑动窗口遍历所有可能的子串
   *
   * @param text ASR 识别文本
   * @param medicines 药品列表
   * @return 匹配结果或 null
   */
  private static matchBySubstring(text: string, medicines: MedicineInfo[]): MedicineMatchResult | null {
    if (!text || text.length < 2) return null;

    const maxLen = Math.min(text.length, 10);  // 最长子串 10 字（大多数药品名不超过 10 字）
    const minLen = 2;  // 最短子串 2 字

    // 从长到短遍历子串长度（优先匹配长名称，避免"阿莫"匹配到部分药品）
    for (let len = maxLen; len >= minLen; len--) {
      for (let start = 0; start <= text.length - len; start++) {
        const substr = text.substring(start, start + len);

        // 精确匹配药品名
        for (const m of medicines) {
          if (m.name === substr) {
            return { medicineName: m.name, confidence: 3 };  // confidence 3 = 子串匹配
          }
        }

        // 精确匹配别名
        for (const m of medicines) {
          if (m.aliases && m.aliases.some((a: string) => a === substr)) {
            return { medicineName: m.name, confidence: 3 };
          }
        }
      }
    }

    // 如果没有精确匹配，尝试模糊子串匹配（编辑距离 ≤1）
    // 这可以处理"阿莫西林"被识别成"阿莫西林胶囊"的情况
    for (let len = maxLen; len >= minLen; len--) {
      for (let start = 0; start <= text.length - len; start++) {
        const substr = text.substring(start, start + len);

        for (const m of medicines) {
          // 子串与药品名编辑距离 ≤1
          const distance = MedicineDatabase.levenshteinDistance(substr, m.name);
          if (distance <= 1) {
            console.info('[MedicineDb] Fuzzy substring match: "' + substr + '" -> ' + m.name + ' (dist=' + distance + ')');
            return { medicineName: m.name, confidence: 4 };  // confidence 4 = 模糊子串匹配
          }
        }
      }
    }

    return null;
  }

  /**
   * 从拼音字符串生成拼音首字母
   * 例如：mengtuoShisan → mtss，amoxilin → aml
   * 音节结构：(辅音) + (介音) + 元音 + (鼻音n/ng)
   */
  private static generatePinyinInitials(pinyin: string): string {
    const initials: string[] = [];
    const vowels = 'aeiouv';  // v 代表 ü
    const nasals = 'ng';  // 鼻音
    const lower = pinyin.toLowerCase();
    let i = 0;

    while (i < lower.length) {
      // 跳过非字母
      if (!/[a-z]/.test(lower[i])) {
        i++;
        continue;
      }

      // 当前字符是音节开头，记录首字母
      initials.push(lower[i]);

      // 跳过这个音节的剩余部分
      // 音节结构：辅音(可选) + 介音(可选，如j,q,x后的u/v) + 元音 + 鼻音(可选)

      // 1. 跳过辅音（直到遇到元音）
      while (i < lower.length && !vowels.includes(lower[i])) {
        i++;
      }

      // 2. 跳过元音（至少一个）
      while (i < lower.length && vowels.includes(lower[i])) {
        i++;
      }

      // 3. 跳过鼻音结尾（n 或 ng）
      // 注意：鼻音 n 后面如果还是鼻音 g，说明是 ng
      if (i < lower.length && lower[i] === 'n') {
        i++;
        if (i < lower.length && lower[i] === 'g') {
          i++;
        }
      }
    }

    return initials.join('');
  }

  private static textToPinyin(text: string): string {
    const digitMap: Record<string, string> = {
      '0': 'ling', '1': 'yi', '2': 'er', '3': 'san', '4': 'si',
      '5': 'wu', '6': 'liu', '7': 'qi', '8': 'ba', '9': 'jiu'
    };
    let result = text.toLowerCase();
    for (const d of Object.keys(digitMap)) {
      result = result.replace(new RegExp(d, 'g'), digitMap[d]);
    }
    return result;
  }

  private static calculateSimilarity(s1: string, s2: string): number {
    const maxLen = Math.max(s1.length, s2.length);
    if (maxLen === 0) return 1;
    const distance = MedicineDatabase.levenshteinDistance(s1, s2);
    return 1 - distance / maxLen;
  }

  private static levenshteinDistance(s1: string, s2: string): number {
    const m = s1.length;
    const n = s2.length;
    const dp: number[][] = [];

    for (let i = 0; i <= m; i++) {
      dp[i] = [];
      dp[i][0] = i;
    }
    for (let j = 0; j <= n; j++) {
      dp[0][j] = j;
    }

    for (let i = 1; i <= m; i++) {
      for (let j = 1; j <= n; j++) {
        if (s1[i - 1] === s2[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] = Math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + 1);
        }
      }
    }

    return dp[m][n];
  }

  /**
   * 从文本提取拼音首字母
   * 使用汉字到首字母映射表
   */
  private static getInitialsFromText(text: string): string {
    const initials: string[] = [];
    for (const char of text) {
      const initial = MedicineDatabase.charToInitial.get(char);
      if (initial) {
        initials.push(initial);
      }
    }
    return initials.join('');
  }

  static extractMedicineName(text: string): MedicineExtractResult | null {
    const c = MedicineDatabase.correctAsrResult(text);
    if (!c) return null;
    const forms = ['胶囊', '片', '颗粒', '口服液', '丸', '注射液', '缓释片', '控释片', '肠溶片'];
    for (const f of forms) {
      if (text.includes(f)) {
        const result: MedicineExtractResult = { name: c, dosageForm: f };
        return result;
      }
    }
    const result: MedicineExtractResult = { name: c, dosageForm: '' };
    return result;
  }

  static searchMedicine(keyword: string): MedicineInfo[] {
    // 优先使用 MedicineLoader
    const loader = MedicineLoader.getInstance();
    if (loader.isLoaded()) {
      const all = loader.getAllMedicines();
      const k = keyword.toLowerCase();
      return all.filter(m =>
        m.name.includes(keyword) || m.pinyin.includes(k) || (m.aliases && m.aliases.some(a => a.includes(keyword)))
      ) as MedicineInfo[];
    }
    // 回退到内置数据
    const k = keyword.toLowerCase();
    return MedicineDatabase.medicineDb.filter(m =>
      m.name.includes(keyword) || m.pinyin.includes(k) || m.aliases.some(a => a.includes(keyword))
    );
  }

  static getAllMedicineNames(): string[] {
    // 优先使用 MedicineLoader
    const loader = MedicineLoader.getInstance();
    if (loader.isLoaded()) {
      return loader.getAllMedicines().map(m => m.name);
    }
    return MedicineDatabase.medicineDb.map(m => m.name);
  }

  /**
   * 从 JSON 文件加载药品数据
   * 调用此方法会替换内置数据
   */
  static async loadFromJson(context: common.Context): Promise<boolean> {
    const loader = MedicineLoader.getInstance();
    await loader.load(context);
    return loader.isLoaded();
  }

  /**
   * 获取药品数据版本
   */
  static getVersion(): string {
    return MedicineLoader.getInstance().getVersion();
  }
}