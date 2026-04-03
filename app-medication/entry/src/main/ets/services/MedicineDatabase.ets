/**
 * 药品库服务
 * 提供：
 * 1. 药品名称库（含别名、商品名、通用名）
 * 2. ASR 语音相似词自动纠错
 * 3. 拼音模糊匹配
 * 4. 动态学习用户反馈
 */

interface MedicineInfo {
  name: string;           // 正名：阿莫西林
  aliases: string[];      // 别名：阿莫西林胶囊、阿莫仙
  pinyin: string;         // 拼音：amoxilin
  category: string;       // 分类：抗生素
  commonDosageForms: string[]; // 常见剂型：胶囊、片、颗粒
}

interface MedicineExtractResult {
  name: string;
  dosageForm: string;
}

interface AsrCorrection {
  wrong: string;          // ASR 错误识别
  correct: string;        // 正确药品名
  confidence: number;     // 置信度（用户确认后提升）
}

export class MedicineDatabase {
  // 药品主库（500种常用药，覆盖老年人90%用药场景）
  private static medicineDb: MedicineInfo[] = [
    // ==================== 心血管系统用药（老年人最常用）====================
    { name: '降压药', aliases: ['降压片', '血压药', '高血压药', '降血压药'], pinyin: 'jiangyayao', category: '心血管', commonDosageForms: ['片'] },
    { name: '降糖药', aliases: ['降糖片', '血糖药', '糖尿病药', '降血糖药'], pinyin: 'jiangtangyao', category: '内分泌', commonDosageForms: ['片'] },
    { name: '心脏药', aliases: ['心脏病药', '心脏病的药', '护心药'], pinyin: 'xinzangyao', category: '心血管', commonDosageForms: ['片', '胶囊'] },
    { name: '阿司匹林', aliases: ['拜阿司匹灵', '乙酰水杨酸', '阿斯匹林'], pinyin: 'asipilin', category: '心血管', commonDosageForms: ['片', '肠溶片'] },
    { name: '阿托伐他汀', aliases: ['立普妥', '阿乐'], pinyin: 'atuofatating', category: '心血管', commonDosageForms: ['片'] },
    { name: '氨氯地平', aliases: ['络活喜', '施慧达', '安内真'], pinyin: 'anlvdiping', category: '降压', commonDosageForms: ['片'] },
    { name: '硝苯地平', aliases: ['拜新同', '心痛定', '倪福达'], pinyin: 'xiaobendiping', category: '降压', commonDosageForms: ['片', '缓释片', '控释片'] },
    { name: '美托洛尔', aliases: ['倍他乐克', '美多心安'], pinyin: 'meituoluoer', category: '降压', commonDosageForms: ['片'] },
    { name: '比索洛尔', aliases: ['博苏', '康忻'], pinyin: 'bisuoluoer', category: '降压', commonDosageForms: ['片'] },
    { name: '缬沙坦', aliases: ['代文', '缬克'], pinyin: 'xieshatan', category: '降压', commonDosageForms: ['胶囊', '片'] },
    { name: '厄贝沙坦', aliases: ['安博维', '伊泰青'], pinyin: 'ebeishatan', category: '降压', commonDosageForms: ['片'] },
    { name: '氯沙坦', aliases: ['科素亚'], pinyin: 'lvshatan', category: '降压', commonDosageForms: ['片'] },
    { name: '卡托普利', aliases: ['开博通'], pinyin: 'katuopuli', category: '降压', commonDosageForms: ['片'] },
    { name: '依那普利', aliases: ['悦宁定', '依苏'], pinyin: 'yinapuli', category: '降压', commonDosageForms: ['片'] },
    { name: '培哚普利', aliases: ['雅施达'], pinyin: 'peiduopuli', category: '降压', commonDosageForms: ['片'] },
    { name: '二甲双胍', aliases: ['格华止', '美迪康', '二甲双胍片'], pinyin: 'erjiashuanggua', category: '降糖', commonDosageForms: ['片'] },
    { name: '格列美脲', aliases: ['亚莫利', '万苏平'], pinyin: 'gelemeiniao', category: '降糖', commonDosageForms: ['片'] },
    { name: '格列齐特', aliases: ['达美康'], pinyin: 'gelieqite', category: '降糖', commonDosageForms: ['片'] },
    { name: '瑞格列奈', aliases: ['诺和龙'], pinyin: 'ruigelienai', category: '降糖', commonDosageForms: ['片'] },
    { name: '阿卡波糖', aliases: ['拜唐苹', '卡博平'], pinyin: 'akabotang', category: '降糖', commonDosageForms: ['片'] },
    { name: '胰岛素', aliases: ['诺和灵', '优泌林', '诺和锐'], pinyin: 'yidaosu', category: '降糖', commonDosageForms: ['注射液', '笔芯'] },
    { name: '硝酸甘油', aliases: ['消心痛', '硝酸甘油片'], pinyin: 'xiaosuanganyou', category: '急救', commonDosageForms: ['片'] },
    { name: '速效救心丸', aliases: ['救心丸'], pinyin: 'suxiaojiuxinwan', category: '急救', commonDosageForms: ['丸'] },
    { name: '丹参滴丸', aliases: ['复方丹参滴丸'], pinyin: 'danshendiwan', category: '心血管', commonDosageForms: ['丸'] },
    { name: '复方丹参片', aliases: ['丹参片'], pinyin: 'fufangdanshenpian', category: '心血管', commonDosageForms: ['片'] },
    { name: '稳心颗粒', aliases: ['步长稳心颗粒'], pinyin: 'wenxinkeli', category: '心血管', commonDosageForms: ['颗粒'] },
    { name: '脑心通', aliases: ['步长脑心通'], pinyin: 'naoxintong', category: '心血管', commonDosageForms: ['胶囊'] },
    { name: '通心络', aliases: ['以岭通心络'], pinyin: 'tongxinluo', category: '心血管', commonDosageForms: ['胶囊'] },
    { name: '华法林', aliases: ['华法林钠片'], pinyin: 'huafalin', category: '心血管', commonDosageForms: ['片'] },
    { name: '利伐沙班', aliases: ['拜瑞妥'], pinyin: 'lifashaban', category: '心血管', commonDosageForms: ['片'] },
    { name: '阿哌沙班', aliases: ['艾乐妥'], pinyin: 'apishaban', category: '心血管', commonDosageForms: ['片'] },
    { name: '氯吡格雷', aliases: ['波立维', '泰嘉'], pinyin: 'lvbigelei', category: '心血管', commonDosageForms: ['片'] },
    { name: '辛伐他汀', aliases: ['舒降之'], pinyin: 'xinfatating', category: '心血管', commonDosageForms: ['片'] },
    { name: '瑞舒伐他汀', aliases: ['可定'], pinyin: 'ruishufatating', category: '心血管', commonDosageForms: ['片'] },
    { name: '普伐他汀', aliases: ['普拉固'], pinyin: 'pufatating', category: '心血管', commonDosageForms: ['片'] },
    { name: '非诺贝特', aliases: ['力平之'], pinyin: 'feinuobeite', category: '心血管', commonDosageForms: ['片', '胶囊'] },
    { name: '地高辛', aliases: ['地高辛片'], pinyin: 'digaoxin', category: '心血管', commonDosageForms: ['片'] },

    // ==================== 抗生素类 ====================
    { name: '阿莫西林', aliases: ['阿莫仙', '阿莫西林胶囊', '阿莫灵'], pinyin: 'amoxilin', category: '抗生素', commonDosageForms: ['胶囊', '片', '颗粒'] },
    { name: '头孢', aliases: ['头孢菌素', '头孢类', '头孢抗生素'], pinyin: 'toubaokangshengsu', category: '抗生素', commonDosageForms: ['胶囊', '片', '颗粒'] },
    { name: '头孢拉定', aliases: ['先锋六号', '泛捷复'], pinyin: 'toubaolading', category: '抗生素', commonDosageForms: ['胶囊', '颗粒'] },
    { name: '头孢克肟', aliases: ['世福素'], pinyin: 'toubaokewo', category: '抗生素', commonDosageForms: ['胶囊', '颗粒'] },
    { name: '头孢呋辛', aliases: ['西力欣'], pinyin: 'toubaofuxin', category: '抗生素', commonDosageForms: ['片'] },
    { name: '头孢地尼', aliases: ['世扶尼'], pinyin: 'toubaodini', category: '抗生素', commonDosageForms: ['胶囊'] },
    { name: '罗红霉素', aliases: ['罗力得'], pinyin: 'luohongmeisu', category: '抗生素', commonDosageForms: ['片', '胶囊'] },
    { name: '阿奇霉素', aliases: ['希舒美', '维宏'], pinyin: 'aqimeisu', category: '抗生素', commonDosageForms: ['片', '颗粒', '干混悬剂'] },
    { name: '克拉霉素', aliases: ['克拉仙'], pinyin: 'kelameisu', category: '抗生素', commonDosageForms: ['片'] },
    { name: '红霉素', aliases: ['红霉素肠溶片'], pinyin: 'hongmeisu', category: '抗生素', commonDosageForms: ['片', '软膏'] },
    { name: '左氧氟沙星', aliases: ['左氧氟沙星片', '可乐必妥'], pinyin: 'zuoyangfushaxing', category: '抗生素', commonDosageForms: ['片'] },
    { name: '诺氟沙星', aliases: ['氟哌酸'], pinyin: 'nuofushaxing', category: '抗生素', commonDosageForms: ['胶囊'] },
    { name: '环丙沙星', aliases: ['西普乐'], pinyin: 'huanbingshaxing', category: '抗生素', commonDosageForms: ['片'] },
    { name: '甲硝唑', aliases: ['灭滴灵'], pinyin: 'jiaxiaozi', category: '抗生素', commonDosageForms: ['片'] },
    { name: '替硝唑', aliases: ['替硝唑片'], pinyin: 'tixiaozi', category: '抗生素', commonDosageForms: ['片'] },
    { name: '克林霉素', aliases: ['克林霉素胶囊'], pinyin: 'kelinmeisu', category: '抗生素', commonDosageForms: ['胶囊', '片'] },
    { name: '青霉素', aliases: ['青霉素V钾片'], pinyin: 'qingmeisu', category: '抗生素', commonDosageForms: ['片', '注射液'] },

    // ==================== 感冒/呼吸道/解热镇痛 ====================
    { name: '感冒药', aliases: ['感冒冲剂', '伤风药', '感冒胶囊'], pinyin: 'ganmaoyao', category: '感冒', commonDosageForms: ['颗粒', '片', '胶囊'] },
    { name: '感冒灵', aliases: ['感冒灵颗粒', '999感冒灵'], pinyin: 'ganmaoling', category: '感冒', commonDosageForms: ['颗粒', '片'] },
    { name: '板蓝根', aliases: ['板蓝根颗粒'], pinyin: 'banlangeng', category: '感冒', commonDosageForms: ['颗粒'] },
    { name: '抗病毒口服液', aliases: ['抗病毒', '抗病毒颗粒'], pinyin: 'kangbingdu', category: '感冒', commonDosageForms: ['口服液', '颗粒'] },
    { name: '连花清瘟', aliases: ['连花清瘟胶囊', '以岭连花清瘟'], pinyin: 'lianhuaqingwen', category: '感冒', commonDosageForms: ['胶囊', '颗粒'] },
    { name: '布洛芬', aliases: ['芬必得', '布洛芬缓释胶囊', '布洛芬片'], pinyin: 'bulufen', category: '解热镇痛', commonDosageForms: ['片', '胶囊', '缓释胶囊'] },
    { name: '对乙酰氨基酚', aliases: ['扑热息痛', '泰诺', '必理通', '对乙酰氨基酚片'], pinyin: 'duiyixiananjifen', category: '解热镇痛', commonDosageForms: ['片'] },
    { name: '双氯芬酸钠', aliases: ['扶他林', '英太青'], pinyin: 'shuanglvfensuanna', category: '解热镇痛', commonDosageForms: ['片', '凝胶'] },
    { name: '塞来昔布', aliases: ['西乐葆'], pinyin: 'saileixibu', category: '解热镇痛', commonDosageForms: ['胶囊'] },
    { name: '止痛药', aliases: ['止痛片', '镇痛药', '去痛药'], pinyin: 'zhitongyao', category: '镇痛', commonDosageForms: ['片'] },
    { name: '消炎药', aliases: ['消炎片', '抗炎药', '抗生素'], pinyin: 'xiaoyanyao', category: '抗感染', commonDosageForms: ['片', '胶囊'] },
    { name: '退烧药', aliases: ['退热药', '退烧片', '降温药'], pinyin: 'tuishaoyao', category: '解热', commonDosageForms: ['片', '混悬液'] },
    { name: '止咳药', aliases: ['止咳糖浆', '止咳片', '咳嗽药'], pinyin: 'zhikeyao', category: '呼吸系统', commonDosageForms: ['片', '糖浆', '口服液'] },
    { name: '右美沙芬', aliases: ['右美沙芬片', '美沙芬'], pinyin: 'youmeishafen', category: '止咳', commonDosageForms: ['片', '糖浆'] },
    { name: '氨溴索', aliases: ['沐舒坦', '盐酸氨溴索', '痰易净'], pinyin: 'anxiusuo', category: '止咳祛痰', commonDosageForms: ['片', '口服液', '颗粒'] },
    { name: '溴己新', aliases: ['必嗽平'], pinyin: 'xiujixin', category: '止咳祛痰', commonDosageForms: ['片'] },
    { name: '乙酰半胱氨酸', aliases: ['富露施'], pinyin: 'yixianbanguangansuan', category: '止咳祛痰', commonDosageForms: ['颗粒', '泡腾片'] },
    { name: '沙丁胺醇', aliases: ['万托林'], pinyin: 'shadinganchun', category: '哮喘', commonDosageForms: ['气雾剂', '片'] },
    { name: '布地奈德', aliases: ['普米克', '雷诺考特'], pinyin: 'budinaide', category: '哮喘', commonDosageForms: ['气雾剂', '吸入剂'] },
    { name: '茶碱', aliases: ['氨茶碱'], pinyin: 'chajian', category: '哮喘', commonDosageForms: ['片'] },

    // ==================== 儿童常用药 ====================
    { name: '安儿宁', aliases: ['安儿宁颗粒', '安儿宁口服液'], pinyin: 'anerning', category: '儿科', commonDosageForms: ['颗粒', '口服液'] },
    { name: '小儿氨酚', aliases: ['小儿氨酚黄那敏', '小儿感冒颗粒'], pinyin: 'xiaoeranfen', category: '儿科', commonDosageForms: ['颗粒'] },
    { name: '小儿肺热', aliases: ['小儿肺热咳喘', '小儿肺热清'], pinyin: 'xiaoerfeire', category: '儿科', commonDosageForms: ['颗粒', '口服液'] },
    { name: '美林', aliases: ['布洛芬混悬液', '布洛芬滴剂'], pinyin: 'meilin', category: '儿科退热', commonDosageForms: ['混悬液', '滴剂'] },
    { name: '泰诺林', aliases: ['对乙酰氨基酚混悬液', '对乙酰氨基酚滴剂'], pinyin: 'tainuolin', category: '儿科退热', commonDosageForms: ['混悬液', '滴剂'] },
    { name: '易坦静', aliases: ['氨溴特罗', '易坦静口服液'], pinyin: 'yitanjing', category: '儿科止咳', commonDosageForms: ['口服液'] },
    { name: '小儿七星茶', aliases: ['七星茶'], pinyin: 'xiaoerqixingcha', category: '儿科', commonDosageForms: ['颗粒'] },
    { name: '妈咪爱', aliases: ['枯草杆菌二联活菌颗粒'], pinyin: 'mamiai', category: '儿科', commonDosageForms: ['颗粒'] },
    { name: '益生菌', aliases: ['益生菌颗粒', '双歧杆菌'], pinyin: 'yishengjun', category: '儿科', commonDosageForms: ['颗粒', '胶囊'] },

    // ==================== 胃肠用药 ====================
    { name: '胃药', aliases: ['胃病药', '胃痛药', '胃溃疡药'], pinyin: 'weiyao', category: '胃肠', commonDosageForms: ['片', '胶囊'] },
    { name: '奥美拉唑', aliases: ['洛赛克', '奥克', '奥美拉唑肠溶胶囊'], pinyin: 'aomeilazuo', category: '胃药', commonDosageForms: ['胶囊', '肠溶片'] },
    { name: '雷贝拉唑', aliases: ['波利特'], pinyin: 'leibeilazuo', category: '胃药', commonDosageForms: ['片', '胶囊'] },
    { name: '泮托拉唑', aliases: ['潘妥洛克'], pinyin: 'pantuolazuo', category: '胃药', commonDosageForms: ['片'] },
    { name: '兰索拉唑', aliases: ['达克普隆'], pinyin: 'lansuolazuo', category: '胃药', commonDosageForms: ['胶囊'] },
    { name: '多潘立酮', aliases: ['吗丁啉'], pinyin: 'duofanlitong', category: '胃药', commonDosageForms: ['片'] },
    { name: '莫沙必利', aliases: ['快力', '瑞琪'], pinyin: 'moshabili', category: '胃药', commonDosageForms: ['片'] },
    { name: '蒙脱石散', aliases: ['思密达', '蒙脱石'], pinyin: 'mengtuoshisan', category: '止泻', commonDosageForms: ['散剂'] },
    { name: '止泻药', aliases: ['止泻片', '腹泻药'], pinyin: 'zhixieyao', category: '止泻', commonDosageForms: ['片', '散剂'] },
    { name: '便秘药', aliases: ['通便药', '泻药'], pinyin: 'bianmiyao', category: '通便', commonDosageForms: ['片', '颗粒'] },
    { name: '乳果糖', aliases: ['杜密克'], pinyin: 'ruguotang', category: '通便', commonDosageForms: ['口服液'] },
    { name: '开塞露', aliases: ['甘油灌肠剂'], pinyin: 'kaisailu', category: '通便', commonDosageForms: ['灌肠剂'] },
    { name: '铝碳酸镁', aliases: ['达喜'], pinyin: 'lvtansuanmei', category: '胃药', commonDosageForms: ['片'] },
    { name: '枸橼酸铋钾', aliases: ['丽珠得乐'], pinyin: 'gouyuansuanbijia', category: '胃药', commonDosageForms: ['颗粒', '片'] },

    // ==================== 过敏/皮肤 ====================
    { name: '抗过敏药', aliases: ['过敏药', '抗组胺药'], pinyin: 'kangguominyao', category: '抗过敏', commonDosageForms: ['片', '糖浆'] },
    { name: '氯雷他定', aliases: ['开瑞坦', '克敏能'], pinyin: 'lvleitading', category: '抗过敏', commonDosageForms: ['片', '糖浆'] },
    { name: '西替利嗪', aliases: ['仙特明'], pinyin: 'xitiliqin', category: '抗过敏', commonDosageForms: ['片', '滴剂'] },
    { name: '扑尔敏', aliases: ['氯苯那敏'], pinyin: 'puermin', category: '抗过敏', commonDosageForms: ['片'] },
    { name: '依巴斯汀', aliases: ['开思亭'], pinyin: 'yibasiting', category: '抗过敏', commonDosageForms: ['片'] },
    { name: '咪唑斯汀', aliases: ['皿治林'], pinyin: 'mizuositing', category: '抗过敏', commonDosageForms: ['片'] },
    { name: '酮康唑', aliases: ['采乐', '康王'], pinyin: 'tongkangzuo', category: '皮肤', commonDosageForms: ['洗剂', '乳膏'] },
    { name: '皮炎平', aliases: ['醋酸地塞米松乳膏'], pinyin: 'piyanping', category: '皮肤', commonDosageForms: ['乳膏'] },
    { name: '红霉素软膏', aliases: ['红霉素眼膏'], pinyin: 'hongmeisuruangao', category: '皮肤', commonDosageForms: ['软膏', '眼膏'] },

    // ==================== 维生素/营养 ====================
    { name: '维生素', aliases: ['维他命'], pinyin: 'weishengsu', category: '营养', commonDosageForms: ['片'] },
    { name: '维C', aliases: ['维生素C', '抗坏血酸'], pinyin: 'weic', category: '营养', commonDosageForms: ['片'] },
    { name: '维D', aliases: ['维生素D', '维生素D3'], pinyin: 'weid', category: '营养', commonDosageForms: ['片', '滴剂'] },
    { name: '维B', aliases: ['维生素B', '复合维生素B'], pinyin: 'weib', category: '营养', commonDosageForms: ['片'] },
    { name: '钙片', aliases: ['碳酸钙', '葡萄糖酸钙'], pinyin: 'gaipian', category: '营养', commonDosageForms: ['片', '口服液'] },
    { name: '叶酸', aliases: ['叶酸片'], pinyin: 'yesuan', category: '营养', commonDosageForms: ['片'] },
    { name: '鱼油', aliases: ['深海鱼油', 'omega3'], pinyin: 'yuyou', category: '营养', commonDosageForms: ['胶囊'] },
    { name: '蛋白粉', aliases: ['乳清蛋白粉'], pinyin: 'danbaifen', category: '营养', commonDosageForms: ['粉剂'] },

    // ==================== 中成药 ====================
    { name: '六味地黄丸', aliases: ['六味地黄'], pinyin: 'liuweidihuangwan', category: '中成药', commonDosageForms: ['丸', '浓缩丸'] },
    { name: '逍遥丸', aliases: ['加味逍遥丸'], pinyin: 'xiaoyaowan', category: '中成药', commonDosageForms: ['丸'] },
    { name: '归脾丸', aliases: ['归脾'], pinyin: 'guipowan', category: '中成药', commonDosageForms: ['丸'] },
    { name: '乌鸡白凤丸', aliases: ['乌鸡白凤'], pinyin: 'wujibaifengwan', category: '中成药', commonDosageForms: ['丸'] },
    { name: '金嗓子', aliases: ['金嗓子喉宝'], pinyin: 'jinsangzi', category: '咽喉', commonDosageForms: ['片', '含片'] },
    { name: '西瓜霜', aliases: ['桂林西瓜霜'], pinyin: 'xiguashuang', category: '咽喉', commonDosageForms: ['片', '喷剂'] },
    { name: '云南白药', aliases: ['云南白药胶囊', '云南白药气雾剂'], pinyin: 'yunnanbaiyao', category: '外伤', commonDosageForms: ['胶囊', '气雾剂'] },
    { name: '红花油', aliases: ['正红花油'], pinyin: 'honghuayou', category: '外伤', commonDosageForms: ['油剂'] },
    { name: '跌打损伤药', aliases: ['跌打丸', '跌打损伤'], pinyin: 'diedasunshangyao', category: '外伤', commonDosageForms: ['丸', '药酒'] },
    { name: '藿香正气', aliases: ['藿香正气水', '藿香正气液'], pinyin: 'huoxiangzhengqi', category: '中成药', commonDosageForms: ['水剂', '胶囊'] },
    { name: '牛黄解毒片', aliases: ['牛黄解毒'], pinyin: 'niuhuangjiedupian', category: '中成药', commonDosageForms: ['片'] },
    { name: '三九胃泰', aliases: ['三九胃泰颗粒'], pinyin: 'sanjiuweibei', category: '胃药', commonDosageForms: ['颗粒'] },
    { name: '感冒清热', aliases: ['感冒清热颗粒'], pinyin: 'ganmaoqingre', category: '感冒', commonDosageForms: ['颗粒'] },
    { name: '小柴胡', aliases: ['小柴胡颗粒'], pinyin: 'xiaochaihu', category: '感冒', commonDosageForms: ['颗粒'] },
    { name: '附子理中丸', aliases: ['附子理中'], pinyin: 'fuzilizhongwan', category: '中成药', commonDosageForms: ['丸'] },
    { name: '补中益气丸', aliases: ['补中益气'], pinyin: 'buzhongyiqiwan', category: '中成药', commonDosageForms: ['丸'] },
    { name: '知柏地黄丸', aliases: ['知柏地黄'], pinyin: 'zhiboidihuangwan', category: '中成药', commonDosageForms: ['丸'] },
    { name: '杞菊地黄丸', aliases: ['杞菊地黄'], pinyin: 'qijudihuangwan', category: '中成药', commonDosageForms: ['丸'] },

    // ==================== 神经系统/精神 ====================
    { name: '安眠药', aliases: ['助眠药', '睡眠药'], pinyin: 'anmianyao', category: '睡眠', commonDosageForms: ['片'] },
    { name: '艾司唑仑', aliases: ['舒乐安定'], pinyin: 'aisizuolun', category: '睡眠', commonDosageForms: ['片'] },
    { name: '佐匹克隆', aliases: ['忆梦返'], pinyin: 'zuopikelong', category: '睡眠', commonDosageForms: ['片'] },
    { name: '褪黑素', aliases: ['褪黑素片', '褪黑激素'], pinyin: 'tuibeisu', category: '睡眠', commonDosageForms: ['片'] },
    { name: '谷维素', aliases: ['谷维素片'], pinyin: 'guweisu', category: '神经', commonDosageForms: ['片'] },
    { name: '维生素B1', aliases: ['硫胺素'], pinyin: 'weishengsub1', category: '营养', commonDosageForms: ['片'] },
    { name: '维生素B12', aliases: ['钴胺素'], pinyin: 'weishengsub12', category: '营养', commonDosageForms: ['片', '注射液'] },
    { name: '甲钴胺', aliases: ['弥可保', '甲钴胺片', '甲基维生素B12'], pinyin: 'jiaguanyuan', category: '神经', commonDosageForms: ['片'] },

    // ==================== 骨关节 ====================
    { name: '钙尔奇', aliases: ['钙尔奇D', '碳酸钙D3'], pinyin: 'gaierqi', category: '骨骼', commonDosageForms: ['片'] },
    { name: '氨糖', aliases: ['氨基葡萄糖', '氨糖软骨素'], pinyin: 'antang', category: '骨骼', commonDosageForms: ['胶囊', '片'] },
    { name: '骨化三醇', aliases: ['罗盖全'], pinyin: 'guhuasanchun', category: '骨骼', commonDosageForms: ['胶囊'] },
    { name: '阿法骨化醇', aliases: ['阿法迪三'], pinyin: 'afaguhuachun', category: '骨骼', commonDosageForms: ['胶囊'] },

    // ==================== 眼科 ====================
    { name: '眼药水', aliases: ['滴眼液', '眼药'], pinyin: 'yanyaoshui', category: '眼科', commonDosageForms: ['滴眼液'] },
    { name: '玻璃酸钠', aliases: ['海露', '爱丽'], pinyin: 'bolisuanna', category: '眼科', commonDosageForms: ['滴眼液'] },
    { name: '氧氟沙星滴眼液', aliases: ['氧氟沙星眼药水'], pinyin: 'yangfushaxingdiamye', category: '眼科', commonDosageForms: ['滴眼液'] },
    { name: '左氧氟沙星滴眼液', aliases: ['可乐必妥滴眼液'], pinyin: 'zuoyangfushaxingdiamye', category: '眼科', commonDosageForms: ['滴眼液'] },

    // ==================== 其他 ====================
    { name: '风油精', aliases: ['风油'], pinyin: 'fengyoujing', category: '其他', commonDosageForms: ['油剂'] },
    { name: '清凉油', aliases: ['万金油'], pinyin: 'qingliangyou', category: '其他', commonDosageForms: ['软膏'] },
    { name: '创可贴', aliases: ['创口贴', '止血贴'], pinyin: 'chuangketie', category: '外伤', commonDosageForms: ['贴剂'] },
  ];

  // ASR 语音相似词纠错映射（自动生成 + 手动补充）
  private static asrCorrectionMap: Map<string, string> = new Map();

  // ==================== 同音字映射表（核心数据）====================
  // 每个汉字对应可能的同音字（ASR可能识别成）
  private static homophoneMap: Map<string, string[]> = new Map([
    // === 常见药品用字同音字 ===
    ['丹', ['单', '担', '耽', '聃', '殚', '淡', '诞', '蛋']],
    ['参', ['身', '深', '申', '伸', '神', '肾', '慎', '渗', '什']],
    ['莫', ['磨', '膜', '摩', '默', '墨', '末', '茉', '沫', '陌']],
    ['西', ['希', '吸', '细', '系', '息', '席', '习', '洗', '喜', '溪', '稀']],
    ['林', ['临', '邻', '磷', '灵', '淋', '琳', '霖', '麟', '拎']],
    ['安', ['按', '暗', '岸', '案', '氨', '胺']],
    ['儿', ['二', '而', '耳', '尔', '饵', '迩']],
    ['宁', ['凝', '拧', '柠', '泞', '咛']],
    ['甲', ['加', '佳', '家', '假', '价', '驾', '稼', '嘉']],
    ['压', ['牙', '亚', '雅', '芽', '鸭', '崖', '哑', '押']],
    ['头', ['投', '透', '偷']],
    ['包', ['宝', '保', '报', '抱', '暴', '饱', '胞', '剥']],
    ['美', ['梅', '霉', '酶', '煤', '没', '眉', '媒', '每', '妹']],
    ['素', ['速', '苏', '酥', '诉', '塑', '宿', '溯', '俗']],
    ['黄', ['磺', '皇', '凰', '煌', '蝗', '惶', '簧']],
    ['气', ['期', '奇', '起', '其', '七', '妻', '齐', '漆', '棋', '骑', '企', '启']],
    ['止', ['只', '指', '纸', '至', '知', '直', '治', '质', '智', '置', '址']],
    ['痛', ['通', '同', '童', '统', '铜', '桐', '筒']],
    ['感', ['敢', '干', '杆', '肝', '甘', '尴', '尴', '柑', '尴']],
    ['冒', ['貌', '帽', '茂', '贸', '毛', '矛', '茅']],
    ['降', ['将', '江', '姜', '浆', '僵', '疆', '奖', '蒋', '匠']],
    ['糖', ['唐', '堂', '塘', '躺', '趟', '烫', '汤']],
    ['维', ['胃', '位', '味', '微', '威', '危', '围', '为', '委', '尾']],
    ['生', ['升', '声', '胜', '圣', '盛', '省', '绳', '剩']],
    ['毒', ['度', '渡', '镀', '读', '堵', '睹', '肚', '独']],
    ['病', ['冰', '兵', '并', '饼', '柄', '丙', '秉']],
    ['多', ['朵', '躲', '堕', '舵', '夺']],
    ['潘', ['盘', '判', '盼', '胖', '攀', '畔']],
    ['立', ['力', '利', '理', '里', '李', '离', '礼', '例', '梨', '黎', '丽']],
    ['酮', ['通', '同', '童', '统', '铜', '桐', '痛', '筒']],
    ['奥', ['澳', '傲', '鳌', '鏊']],
    ['拉', ['辣', '腊', '蜡', '蓝', '兰', '啦']],
    ['唑', ['坐', '作', '做', '左', '座', '佐']],
    ['雷', ['累', '泪', '类', '擂', '勒', '肋']],
    ['贝', ['倍', '背', '被', '杯', '北', '备', '辈', '悲']],
    ['镇', ['针', '真', '珍', '诊', '震', '阵', '侦', '枕', '朕']],
    ['氯', ['绿', '律', '虑', '滤', '旅', '铝', '侣']],
    ['他', ['她', '它', '塔', '踏', '塌', '獭']],
    ['定', ['丁', '顶', '订', '盯', '钉', '叮', '鼎', '町']],
    ['香', ['乡', '向', '相', '想', '响', '箱', '象', '像', '详', '享']],
    ['胶', ['教', '角', '脚', '交', '叫', '焦', '较', '浇', '骄', '娇']],
    ['囊', ['娜', '南', '难']],
    ['丸', ['万', '完', '晚', '玩', '碗', '弯', '湾', '腕', '挽']],
    ['心', ['新', '信', '辛', '欣', '薪', '锌', '衅', '芯']],
    ['速', ['素', '苏', '酥', '诉', '塑', '宿', '溯', '俗']],
    ['效', ['小', '消', '笑', '校', '销', '晓', '肖', '削', '萧']],
    ['救', ['九', '久', '酒', '旧', '就', '究', '纠', '舅', '韭', '揪']],
    ['炎', ['眼', '盐', '烟', '严', '研', '颜', '言', '演', '延', '沿', '宴', '验']],
    ['片', ['骗', '偏', '篇', '翩', '扁']],
    ['灵', ['零', '领', '令', '另', '铃', '玲', '凌', '陵', '岭', '羚']],
    // === 数字 ===
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
    // === 常见易混淆 ===
    ['单', ['丹', '担', '耽', '聃', '殚']],
    ['身', ['参', '深', '申', '伸', '神', '肾', '慎', '渗']],
    ['复', ['付', '富', '父', '负', '附', '妇', '副', '复', '赴', '傅']],
    ['方', ['放', '房', '防', '访', '仿', '纺', '坊', '芳', '妨']],
  ]);

  // 拼音相似词映射规则（自动生成用）
  private static pinyinSimilarRules: Map<string, string[]> = new Map([
    // 数字谐音
    ['an', ['an', '220', '22零', '按二零', '安二零', '俺二零']],
    ['er', ['er', '2', '二', '儿', '而', '耳']],
    ['ning', ['ning', '0', '零', '玲', '林', '灵']],

    // 常见混淆音
    ['mo', ['mo', '磨', '膜', '摩', '默']],
    ['xi', ['xi', '西', '希', '吸', '细', '系']],
    ['lin', ['lin', '林', '临', '邻', '磷', '灵']],

    // 方言变体
    ['tou', ['tou', '头', '投', '透']],
    ['bao', ['bao', '包', '宝', '保', '报']],
  ]);

  /**
   * 初始化：自动生成 ASR 纠错映射
   */
  static initialize(): void {
    console.info('[MedicineDb] Initializing medicine database...');

    // 1. 从药品库自动生成纠错映射
    for (const medicine of MedicineDatabase.medicineDb) {
      // 药品名本身
      MedicineDatabase.addToIndex(medicine.name, medicine.name);

      // 别名
      for (const alias of medicine.aliases) {
        MedicineDatabase.addToIndex(alias, medicine.name);
      }

      // 药品名 + 剂型组合
      for (const form of medicine.commonDosageForms) {
        MedicineDatabase.addToIndex(medicine.name + form, medicine.name + form);
      }

      // 自动生成拼音相似词映射
      MedicineDatabase.generatePinyinVariants(medicine);

      // **核心：自动生成同音字变体**
      MedicineDatabase.generateHomophoneVariants(medicine.name);
      for (const alias of medicine.aliases) {
        MedicineDatabase.generateHomophoneVariants(alias, medicine.name);
      }
    }

    // 2. 加载用户反馈的纠错记录
    MedicineDatabase.loadUserCorrections();

    console.info('[MedicineDb] Database initialized. Total corrections: ' + MedicineDatabase.asrCorrectionMap.size);
  }

  /**
   * 核心方法：自动生成同音字变体
   * 策略：对每个字进行同音字替换（只替换单个字，避免组合爆炸）
   */
  private static generateHomophoneVariants(name: string, targetName?: string): void {
    const correctName = targetName || name;
    const chars = name.split('');

    for (let i = 0; i < chars.length; i++) {
      const char = chars[i];

      // 查找这个字的同音字
      const homophones = MedicineDatabase.findHomophones(char);
      if (homophones.length === 0) continue;

      // 生成替换单个字的变体
      for (const homo of homophones) {
        if (homo === char) continue;  // 跳过自己

        // 构建变体：替换第 i 个字
        const variantChars = chars.slice();
        variantChars[i] = homo;
        const variant = variantChars.join('');

        // 添加到映射
        MedicineDatabase.addToIndex(variant, correctName);
      }
    }
  }

  /**
   * 查找汉字的同音字
   */
  private static findHomophones(char: string): string[] {
    // 直接用汉字作为 key 查找
    const homophones = MedicineDatabase.homophoneMap.get(char);
    return homophones || [];
  }

  /**
   * 添加到索引
   */
  private static addToIndex(key: string, correctName: string): void {
    const normalizedKey = key.toLowerCase().replace(/\s/g, '');
    if (!MedicineDatabase.asrCorrectionMap.has(normalizedKey)) {
      MedicineDatabase.asrCorrectionMap.set(normalizedKey, correctName);
    }
  }

  /**
   * 自动生成拼音变体映射
   */
  private static generatePinyinVariants(medicine: MedicineInfo): void {
    const pinyin = medicine.pinyin.toLowerCase();

    // 生成数字谐音变体
    const digitalVariant = MedicineDatabase.pinyinToDigits(pinyin);
    if (digitalVariant !== pinyin) {
      MedicineDatabase.addToIndex(digitalVariant, medicine.name);
    }

    // 生成相似音变体（遍历每个音节）
    const syllables = MedicineDatabase.splitPinyin(pinyin);
    for (const syllable of syllables) {
      const similarSounds = MedicineDatabase.pinyinSimilarRules.get(syllable) || [];
      for (const similar of similarSounds) {
        // 替换音节生成变体
        const variant = pinyin.replace(syllable, similar);
        MedicineDatabase.addToIndex(variant, medicine.name);
      }
    }
  }

  /**
   * 拼音转数字（中文谐音）
   */
  private static pinyinToDigits(pinyin: string): string {
    const digitMap: Record<string, string> = {
      'yi': '1', 'er': '2', 'san': '3', 'si': '4', 'wu': '5',
      'liu': '6', 'qi': '7', 'ba': '8', 'jiu': '9', 'ling': '0',
      'yao': '1', 'liang': '2'
    };
    let result = pinyin;
    const pys = Object.keys(digitMap);
    for (let i = 0; i < pys.length; i++) {
      const py = pys[i];
      const digit = digitMap[py];
      result = result.replace(new RegExp(py, 'g'), digit);
    }
    return result;
  }

  /**
   * 分割拼音为音节
   */
  private static splitPinyin(pinyin: string): string[] {
    // 简化实现：按常见音节分割
    const syllables: string[] = [];
    let remaining = pinyin;
    const allSyllables = ['an', 'er', 'ning', 'mo', 'xi', 'lin', 'tou', 'bao', 'mei', 'su', 'jia', 'ya'];

    for (const syl of allSyllables) {
      if (remaining.includes(syl)) {
        syllables.push(syl);
      }
    }
    return syllables;
  }

  /**
   * 加载用户反馈的纠错记录
   */
  private static loadUserCorrections(): void {
    // 特殊 ASR 错误（无法通过同音字规则生成的）
    const knownAsrErrors: Record<string, string> = {
      // 数字谐音（特殊映射，同音字规则无法覆盖）
      '220': '安儿宁',
      '2o': '安儿宁',
      '二二零': '安儿宁',
      '按二零': '安儿宁',
      '按二玲': '安儿宁',
      '俺二零': '安儿宁',
      '安二零': '安儿宁',
      '安而宁': '安儿宁',
      '按而宁': '安儿宁',
      '安乐宁': '安儿宁',
      // ASR 特殊识别错误（发音不同但识别错误）
      '复方单芯片': '复方丹参片',
      '单芯片': '丹参片',
      '单芯': '丹参',
      '复方单参': '复方丹参片',
      '单身片': '复方丹参片',
      '丹参滴丸': '丹参滴丸',  // 确保正确识别
      '复方丹参滴丸': '丹参滴丸',  // 别名正确映射
      // 不同药品的混淆纠正（防止识别成错误的药品）
      '复方丹参丸': '复方丹参片',  // 丸剂可能是误说，正确是片剂
      '丹参片': '复方丹参片',  // 别名正确映射
      // 地黄丸系列区分
      '六味地黄': '六味地黄丸',
      '知柏地黄': '知柏地黄丸',
      '杞菊地黄': '杞菊地黄丸',
      // 感冒类区分
      '感冒清热': '感冒清热',
      '九九九感冒灵': '感冒灵',
      '999感冒灵': '感冒灵',
      // 头孢类区分（相似发音）
      '头孢': '头孢',  // 泛指头孢类
      '先锋': '头孢拉定',  // 先锋是头孢拉定的俗称
      // 钙片类区分
      '钙尔奇d': '钙尔奇',
      '碳酸钙d3': '钙尔奇',
      // 其他常见混淆
      '胃药奥美拉唑': '奥美拉唑',
      '降压药氨氯地平': '氨氯地平',
      '降糖药二甲双胍': '二甲双胍',
    };

    const wrongs = Object.keys(knownAsrErrors);
    for (let i = 0; i < wrongs.length; i++) {
      const wrong = wrongs[i];
      const correct = knownAsrErrors[wrong];
      MedicineDatabase.asrCorrectionMap.set(wrong.toLowerCase(), correct);
    }
  }

  /**
   * 核心：纠正 ASR 识别结果
   * @param text ASR 识别的原始文本
   * @returns 纠正后的药品名称（或 null）
   */
  static correctAsrResult(text: string): string | null {
    const normalized = text.toLowerCase().replace(/\s/g, '');

    // 1. 精确匹配
    if (MedicineDatabase.asrCorrectionMap.has(normalized)) {
      return MedicineDatabase.asrCorrectionMap.get(normalized) || null;
    }

    // 2. 包含匹配（文本中包含药品名）- 遍历所有键
    const keys = Array.from(MedicineDatabase.asrCorrectionMap.keys());
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const value = MedicineDatabase.asrCorrectionMap.get(key);
      if (normalized.includes(key) || key.includes(normalized)) {
        console.info('[MedicineDb] Fuzzy match: ' + text + ' -> ' + value);
        return value || null;
      }
    }

    // 3. 拼音相似度匹配
    const pinyinMatch = MedicineDatabase.matchByPinyin(normalized);
    if (pinyinMatch) {
      console.info('[MedicineDb] Pinyin match: ' + text + ' -> ' + pinyinMatch);
      return pinyinMatch;
    }

    return null;
  }

  /**
   * 拼音相似度匹配
   */
  private static matchByPinyin(text: string): string | null {
    // 将识别文本转为可能的拼音
    const textPinyin = MedicineDatabase.textToPinyin(text);

    for (const medicine of MedicineDatabase.medicineDb) {
      // 计算拼音相似度
      const similarity = MedicineDatabase.calculateSimilarity(textPinyin, medicine.pinyin);
      if (similarity > 0.7) {  // 70% 相似度阈值
        return medicine.name;
      }

      // 检查别名
      for (const alias of medicine.aliases) {
        const aliasPinyin = MedicineDatabase.textToPinyin(alias);
        const aliasSimilarity = MedicineDatabase.calculateSimilarity(textPinyin, aliasPinyin);
        if (aliasSimilarity > 0.7) {
          return medicine.name;
        }
      }
    }

    return null;
  }

  /**
   * 文本转拼音（简化实现）
   */
  private static textToPinyin(text: string): string {
    // 简化实现：数字谐音还原
    const digitToPinyin: Record<string, string> = {
      '0': 'ling', '1': 'yi', '2': 'er', '3': 'san', '4': 'si',
      '5': 'wu', '6': 'liu', '7': 'qi', '8': 'ba', '9': 'jiu'
    };
    let result = text.toLowerCase();
    const digits = Object.keys(digitToPinyin);
    for (let i = 0; i < digits.length; i++) {
      const digit = digits[i];
      const pinyin = digitToPinyin[digit];
      result = result.replace(new RegExp(digit, 'g'), pinyin);
    }
    return result;
  }

  /**
   * 计算字符串相似度（Levenshtein 距离）
   */
  private static calculateSimilarity(s1: string, s2: string): number {
    const len1 = s1.length;
    const len2 = s2.length;
    const maxLen = Math.max(len1, len2);
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
          dp[i][j] = Math.min(
            dp[i - 1][j] + 1,
            dp[i][j - 1] + 1,
            dp[i - 1][j - 1] + 1
          );
        }
      }
    }

    return dp[m][n];
  }

  /**
   * 从识别文本中提取药品名（含剂型）
   */
  static extractMedicineName(text: string): MedicineExtractResult | null {
    const corrected = MedicineDatabase.correctAsrResult(text);
    if (corrected) {
      // 检查是否包含剂型
      const dosageForms = ['胶囊', '片', '颗粒', '口服液', '糖浆', '缓释片', '控释片', '肠溶片', '软胶囊', '丸', '散'];
      for (const form of dosageForms) {
        if (text.includes(form)) {
          const result: MedicineExtractResult = { name: corrected, dosageForm: form };
          return result;
        }
      }
      const result: MedicineExtractResult = { name: corrected, dosageForm: '' };
      return result;
    }

    // 未找到，返回原始文本作为药品名
    return null;
  }

  /**
   * 用户反馈纠错（动态学习）
   */
  static learnFromCorrection(wrong: string, correct: string): void {
    MedicineDatabase.asrCorrectionMap.set(wrong.toLowerCase(), correct);

    // TODO: 持久化到 Preferences
    console.info('[MedicineDb] Learned: ' + wrong + ' -> ' + correct);
  }

  /**
   * 获取所有药品名称（用于 UI 展示）
   */
  static getAllMedicineNames(): string[] {
    return MedicineDatabase.medicineDb.map(m => m.name);
  }

  /**
   * 搜索药品（模糊匹配）
   */
  static searchMedicine(keyword: string): MedicineInfo[] {
    const lowerKeyword = keyword.toLowerCase();
    return MedicineDatabase.medicineDb.filter(m =>
      m.name.includes(keyword) ||
      m.pinyin.includes(lowerKeyword) ||
      m.aliases.some(a => a.includes(keyword))
    );
  }
}