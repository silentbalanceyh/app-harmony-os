export interface AlbumAccent {
  key: string;
  tint: ResourceColor;
  solid: ResourceColor;
  soft: ResourceColor;
  icon: string;
  emptyIcon: string;
  importLabel: string;
}

export interface AlbumSettingsItem {
  title: string;
  icon: string;
  route: string;
}

export interface AlbumListAction {
  label: string;
  tone?: 'lavender' | 'peach' | 'mint' | 'sand';
  onClick: () => void;
}

export interface AlbumThemeShape {
  fontFamily: string;
  pageBg: ResourceColor;
  paper: ResourceColor;
  line: ResourceColor;
  grid: ResourceColor;
  shadow: ResourceColor;
  text: ResourceColor;
  subText: ResourceColor;
  paleBlue: ResourceColor;
  paleYellow: ResourceColor;
  palePeach: ResourceColor;
  paleMint: ResourceColor;
  paleLavender: ResourceColor;
  success: ResourceColor;
  disabled: ResourceColor;
  danger: ResourceColor;
  borderWidth: number;
  screenPadding: number;
  titleTop: number;
  cardRadius: number;
  tileRadius: number;
  pillRadius: number;
  inputRadius: number;
  iconCircle: number;
  listIcon: number;
}

export const AlbumTheme: AlbumThemeShape = {
  fontFamily: 'AlbumHannotateTC',
  pageBg: '#F8F6F0',
  paper: '#FFFDF7',
  line: '#2E3137',
  grid: '#ECE3D7',
  shadow: '#DED5C8',
  text: '#23262B',
  subText: '#6D6A64',
  paleBlue: '#E7F0FF',
  paleYellow: '#FFF2C8',
  palePeach: '#FFE4D6',
  paleMint: '#DFF4E4',
  paleLavender: '#E8E1FF',
  success: '#B8EDBC',
  disabled: '#E7DECF',
  danger: '#FFA8A8',
  borderWidth: 2,
  screenPadding: 18,
  titleTop: 18,
  cardRadius: 18,
  tileRadius: 20,
  pillRadius: 14,
  inputRadius: 12,
  iconCircle: 66,
  listIcon: 26
};

export interface AlbumSettingsGroup {
  title: string;
  items: AlbumSettingsItem[];
}

export const AlbumAccents: Map<string, AlbumAccent> = new Map<string, AlbumAccent>([
  ['photo', {
    key: 'photo',
    tint: '#E9F2FF',
    solid: '#8EC8FF',
    soft: '#D9ECFF',
    icon: '照',
    emptyIcon: '🖼',
    importLabel: '导入照片'
  }],
  ['video', {
    key: 'video',
    tint: '#FFE9F0',
    solid: '#FFB8C5',
    soft: '#FFD9E2',
    icon: '影',
    emptyIcon: '🎬',
    importLabel: '导入视频'
  }],
  ['gif', {
    key: 'gif',
    tint: '#FFF5D5',
    solid: '#FFD95A',
    soft: '#FFF0BA',
    icon: '动',
    emptyIcon: '🎭',
    importLabel: '导入动图'
  }],
  ['doc', {
    key: 'doc',
    tint: '#E6F7EB',
    solid: '#9BE7AA',
    soft: '#D9F3DF',
    icon: '文',
    emptyIcon: '📄',
    importLabel: '导入资料'
  }],
  ['record', {
    key: 'record',
    tint: '#F7EBD9',
    solid: '#FFD39F',
    soft: '#FCE9CF',
    icon: '录',
    emptyIcon: '🎙',
    importLabel: '导入文件'
  }],
  ['settings', {
    key: 'settings',
    tint: '#EFE8FF',
    solid: '#C9B8FF',
    soft: '#E8E0FF',
    icon: '设',
    emptyIcon: '⚙',
    importLabel: ''
  }]
]);

export const SettingsGroups: AlbumSettingsGroup[] = [
  {
    title: '文件管理',
    items: [
      { title: '回收站', icon: '🗑', route: 'pages/settings/RecycleBinPage' },
      { title: '查看重复文件', icon: '📄', route: 'pages/settings/DuplicateFilesPage' },
      { title: '大文件排序', icon: '📊', route: 'pages/settings/LargeFilesPage' },
      { title: '清理临时文件', icon: '🧹', route: 'pages/settings/CleanTempPage' }
    ]
  },
  {
    title: '数据安全',
    items: [
      { title: '备份数据', icon: '💾', route: 'pages/settings/BackupDataPage' },
      { title: '闯入者拍摄', icon: '📸', route: 'pages/settings/IntruderPhotoPage' },
      { title: '手机互传', icon: '📱', route: 'pages/settings/PhoneTransferPage' }
    ]
  },
  {
    title: '密码相关',
    items: [
      { title: '密码与密保', icon: '🔐', route: 'pages/settings/PasswordSecurityPage' },
      { title: 'Face ID登录', icon: '👤', route: 'pages/settings/FaceIdPage' }
    ]
  },
  {
    title: '配置',
    items: [
      { title: 'App设置', icon: '⚙', route: 'pages/settings/AppSettingsPage' },
      { title: '语言设置', icon: '🌐', route: 'pages/settings/LanguageSettingsPage' }
    ]
  }
];

export function albumAccentByType(contentType: string): AlbumAccent {
  return AlbumAccents.get(contentType) ?? (AlbumAccents.get('photo') as AlbumAccent);
}

export function albumTypeLabel(contentType: string): string {
  switch (contentType) {
    case 'video':
      return '视频';
    case 'gif':
      return '动图';
    case 'doc':
      return '资料';
    case 'record':
      return '录音&文件';
    default:
      return '照片';
  }
}

export function albumImportTitle(contentType: string): string {
  switch (contentType) {
    case 'video':
      return '导入视频';
    case 'gif':
      return '导入动图';
    case 'doc':
      return '导入资料';
    case 'record':
      return '导入文件';
    default:
      return '导入照片';
  }
}

export function albumToneColor(tone: 'lavender' | 'peach' | 'mint' | 'sand' = 'lavender'): ResourceColor {
  switch (tone) {
    case 'peach':
      return AlbumTheme.palePeach;
    case 'mint':
      return AlbumTheme.paleMint;
    case 'sand':
      return AlbumTheme.paleYellow;
    default:
      return AlbumTheme.paleLavender;
  }
}
