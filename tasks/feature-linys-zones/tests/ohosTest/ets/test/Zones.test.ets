import { describe, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry, Component, Driver, MatchPattern, ON, On } from '@kit.TestKit';
import { UIAbility } from '@kit.AbilityKit';

const BUNDLE = 'com.harmonybench.linys.browser';
// 所有测试日志的统一前缀（verify_config.json 的 test_log_tag）：失败时 verify.py 把含它的 hilog 行存到 fpoint-<id>.log
const TAG = 'ZonesTest';
// 不引入 @kit.InputKit，直接使用 KeyCode 数值
const KEY_ALT_LEFT = 2045;
const KEY_Z = 2042;
const KEY_ENTER = 2054;
const KEY_CTRL_LEFT = 2072;
const KEY_SHIFT_LEFT = 2047;
const KEY_A = 2017;
const KEY_T = 2036;
const KEY_N = 2030;

// 题面锚点：入口「设为工作区」，面板标题「工作区」，卡片操作「打开」「移除」；反向操作只写了"可以再取消"
const A_ENZONE = '设为工作区';
const A_PANEL = '工作区';
const A_OPEN = '打开';
const A_REMOVE = '移除';
// 反向操作（取消）控件可能用的词：取消 / 移出 / 解除 / 不再 / 退出（按行为判定，见 cancelZone）
const CANCEL_WORDS = ['取消', '移出', '解除', '不再', '退出'];
// 确认类按钮（实现可以在设为/取消/移除时弹确认框）
const CONFIRM_WORDS = ['确定', '确认'];
const REMOVE_CONFIRM_WORDS = ['移除', '删除', '确定', '确认'];

// 阶段 1 生成的随机名称只存在于 App 自己的界面/持久化中；后续阶段通过界面上唯一的
// 「前缀 + 6 位数字」名称把它认出来，测试本身不保存任何中间状态。
// 名称 = 前缀 + 5 位随机数 R + 1 位 K：阶段 1 在该窗口新建 K 个有网址的标签页，标题依次为 tb + R + 1..K。
const ZONE_PREFIX = 'zq';     // 阶段 1 第一个窗口存成的工作区 A
const ZONE_PREFIX_B = 'zp';   // 阶段 1 第二个窗口存成的工作区 B
const ZONE_PREFIX_C = 'zc';   // 阶段 1 设为工作区后又取消的名称（之后任何时候都不应再列出）
const ZONE_RE = /z[pqc][0-9]{6}/;
const TAB_PREFIX = 'tb';
const RENAME_PREFIX = 'zr';
const RENAME_RE = /zr[0-9]{6}/;
// base 里「更多」面板显示窗口名称时带的图标字形（MeowWindowInfoBar：`󰁫  ${windowAlias}`）
const WINDOW_NAME_GLYPH = '\u{F006B}';

interface Box {
  left: number;
  top: number;
  right: number;
  bottom: number;
}

/** 按码点截断，不会把代理对（图标字形等 U+10000 以上字符）切开。 */
function cut(txt: string, n: number): string {
  const cps = Array.from(txt);
  return cps.length <= n ? txt : cps.slice(0, n).join('');
}

/**
 * 写一条带 TAG 的日志。长消息按码点切成多行（每行不超过 160 个字符），避免 hilog 按字节截断单行时
 * 把多字节字符切成非法 UTF-8。
 */
function log(msg: string): void {
  const cps = Array.from(msg);
  for (let i = 0; i < cps.length || i === 0; i += 160) {
    console.info(`${TAG} ${cps.slice(i, i + 160).join('')}`);
  }
}

function randomName(prefix: string): string {
  return prefix + String(100000 + Math.floor(Math.random() * 900000));
}

async function boundsOf(c: Component): Promise<Box> {
  const r = await c.getBounds();
  return { left: r.left, top: r.top, right: r.right, bottom: r.bottom };
}

function centerIn(b: Box, r: Box): boolean {
  const cx = (b.left + b.right) / 2;
  const cy = (b.top + b.bottom) / 2;
  return cx >= r.left && cx <= r.right && cy >= r.top && cy < r.bottom;
}

async function findAll(driver: Driver, on: On): Promise<Component[]> {
  const r = await driver.findComponents(on);
  return r === null || r === undefined ? [] : r;
}

async function textOf(c: Component): Promise<string> {
  const t = await c.getText();
  return t === null || t === undefined ? '' : t.trim();
}

/** 控件是否仍在界面上（已被移除的控件取属性会抛错）。 */
async function alive(c: Component): Promise<boolean> {
  try {
    await c.getBounds();
    return true;
  } catch (e) {
    return false;
  }
}

/** 屏幕上所有可读文字（类型[文字]@左,上），失败证据用。 */
async function screenTexts(driver: Driver): Promise<string> {
  const parts: string[] = [];
  for (const type of ['Text', 'Button', 'TextInput']) {
    for (const c of await findAll(driver, ON.type(type))) {
      const t = await textOf(c);
      if (t.length === 0 && type !== 'TextInput') {
        continue;
      }
      const b = await boundsOf(c);
      parts.push(`${type}[${cut(t, 40)}]@${b.left},${b.top}`);
    }
  }
  return cut(parts.join('|'), 2500);
}

/** App 最近的错误日志（hilog E 级 JS 日志），失败证据用；取不到时返回空串。 */
async function appErrors(): Promise<string[]> {
  try {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator();
    const r = await delegator.executeShellCommand('hilog -x -L E');
    const lines = (r.stdResult ?? '').split('\n').filter((l: string) => l.includes('JSAPP') && !l.includes(TAG));
    return lines.slice(-15);
  } catch (e) {
    return [];
  }
}

/**
 * 检查点：失败时断言信息里带上 detail 和屏幕上实际读到的文字，同时把它们和 App 错误日志写进带 TAG 的 hilog。
 */
async function must(driver: Driver, step: string, ok: boolean, detail: string = ''): Promise<void> {
  if (ok) {
    log(`ok ${step}`);
    return;
  }
  const screen = await screenTexts(driver);
  log(`FAIL ${step} ${detail}`);
  log(`FAIL ${step} SCREEN=${screen}`);
  for (const l of await appErrors()) {
    log(`FAIL ${step} APPERR ${cut(l, 300)}`);
  }
  expect(`${step}:false ${detail} SCREEN=${cut(screen, 600)}`).assertEqual(`${step}:true`);
}

/** 文字（trim 后）包含 s 的控件；type 为空时不限类型。 */
async function textsContaining(driver: Driver, s: string, type: string = ''): Promise<Component[]> {
  const on = type.length > 0 ? ON.type(type).text(s, MatchPattern.CONTAINS) : ON.text(s, MatchPattern.CONTAINS);
  const r: Component[] = [];
  for (const c of await findAll(driver, on)) {
    if ((await textOf(c)).includes(s)) {
      r.push(c);
    }
  }
  return r;
}

/** 控件的位置键，用于"点击前 / 点击后"对比。 */
async function keyOf(c: Component): Promise<string> {
  const b = await boundsOf(c);
  return `${await textOf(c)}@${b.left},${b.top}`;
}

async function keysOf(cs: Component[]): Promise<string[]> {
  const r: string[] = [];
  for (const c of cs) {
    r.push(await keyOf(c));
  }
  return r;
}

/** 两个位置键是否是"同一处的同一段文字"（允许 40px 以内的布局抖动）。 */
function sameSpot(a: string, b: string): boolean {
  const ia = a.lastIndexOf('@');
  const ib = b.lastIndexOf('@');
  if (a.substring(0, ia) !== b.substring(0, ib)) {
    return false;
  }
  const pa = a.substring(ia + 1).split(',');
  const pb = b.substring(ib + 1).split(',');
  return Math.abs(Number(pa[0]) - Number(pb[0])) <= 40 && Math.abs(Number(pa[1]) - Number(pb[1])) <= 40;
}

/** 屏幕上所有 Text/Button 的位置键（判断"点了之后有没有新东西出现"）。 */
async function screenKeys(driver: Driver): Promise<string[]> {
  const r: string[] = [];
  for (const type of ['Text', 'Button']) {
    for (const c of await findAll(driver, ON.type(type))) {
      r.push(await keyOf(c));
    }
  }
  return r;
}

/**
 * 系统输入法（小艺输入法）首次使用时弹出的声明对话框：设备环境的一部分，与被测应用无关，出现就点「同意」。
 */
async function dismissImeGuide(driver: Driver): Promise<void> {
  for (let i = 0; i < 2; i++) {
    if ((await textsContaining(driver, '小艺输入法', 'Text')).length === 0) {
      return;
    }
    const agree = await driver.findComponent(ON.type('Button').text('同意'));
    if (agree === null) {
      return;
    }
    log('dismiss IME first-use dialog');
    await agree.click();
    await driver.delayMs(1500);
  }
}

async function launch(driver: Driver): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  await delegator.executeShellCommand(`aa start -b ${BUNDLE} -a EntryAbility`);
  // 主界面的地址栏输入框（base 已有）
  const input = await driver.waitForComponent(ON.type('TextInput'), 15000);
  await must(driver, 'launch', input !== null);
  await driver.delayMs(1500);
}

/**
 * 当前窗口的地址栏：宽 TextInput 中最靠上的一个（base 布局：工具栏在底部，「更多」面板展开在地址栏下方，
 * 面板里的改名输入框总在地址栏之下）。宽度下限按屏幕宽度的比例取。
 */
async function addressInputComp(driver: Driver): Promise<Component | null> {
  const size = await driver.getDisplaySize();
  let best: Component | null = null;
  let bestTop = 1e9;
  for (const c of await findAll(driver, ON.type('TextInput'))) {
    const b = await boundsOf(c);
    if (b.right - b.left < size.x * 0.25) {
      continue;
    }
    if (b.top < bestTop) {
      bestTop = b.top;
      best = c;
    }
  }
  return best;
}

async function addressInput(driver: Driver): Promise<Box | null> {
  const c = await addressInputComp(driver);
  return c === null ? null : await boundsOf(c);
}

/**
 * 「更多」面板中的窗口名称（base 已有：地址栏下方可点击的文字，带图标 󰁫，点击后出现改名输入框）。
 * 优先认带 󰁫 的那个；没有时退回"地址栏下方第一个可点击文字"。
 */
async function windowNameText(driver: Driver): Promise<Component | null> {
  const addr = await addressInput(driver);
  if (addr === null) {
    return null;
  }
  let fallback: Component | null = null;
  for (const t of await findAll(driver, ON.type('Text').clickable(true))) {
    const b = await boundsOf(t);
    const txt = await textOf(t);
    if (b.top < addr.bottom || txt.length === 0) {
      continue;
    }
    if (txt.includes(WINDOW_NAME_GLYPH)) {
      return t;
    }
    if (fallback === null) {
      fallback = t;
    }
  }
  return fallback;
}

/**
 * 地址栏上方那一排工具栏图标（base 自己的界面，按从左到右排序）。先在地址栏上方一定高度（屏幕高度的 10%）内
 * 找最靠下的图标作为这一排的基准，再只保留与它同一行的图标，避免把标签栏底部的按钮算进来。
 */
async function toolbarGlyphs(driver: Driver): Promise<Component[]> {
  let addr = await addressInput(driver);
  for (let i = 0; i < 40 && addr === null; i++) {
    await driver.delayMs(500);
    addr = await addressInput(driver);
  }
  await must(driver, 'toolbar_addr', addr !== null);
  const size = await driver.getDisplaySize();
  const cand: Box[] = [];
  const candG: Component[] = [];
  let rowCy = -1;
  for (const g of await findAll(driver, ON.type('SymbolGlyph'))) {
    const b = await boundsOf(g);
    const cy = (b.top + b.bottom) / 2;
    if (cy < addr!.top && cy > addr!.top - size.y * 0.1) {
      cand.push(b);
      candG.push(g);
      rowCy = Math.max(rowCy, cy);
    }
  }
  const row: Box[] = [];
  const glyphs: Component[] = [];
  for (let i = 0; i < cand.length; i++) {
    const b = cand[i];
    if (Math.abs((b.top + b.bottom) / 2 - rowCy) <= (b.bottom - b.top) / 2) {
      row.push(b);
      glyphs.push(candG[i]);
    }
  }
  const idx: number[] = row.map((_b: Box, i: number) => i);
  idx.sort((a: number, b: number) => row[a].left - row[b].left);
  return idx.map((i: number) => glyphs[i]);
}

/**
 * 点错了工具栏图标之后的收尾：只有点出了新东西（面板、对话框）或地址栏不见了，才按返回键收起；
 * 什么都没出现就不按（返回键会让网页后退、改掉标签页内容）。
 */
async function undoStrayOpen(driver: Driver, before: string[]): Promise<void> {
  for (let i = 0; i < 3; i++) {
    const now = await screenKeys(driver);
    const appeared = now.some((k: string) => !before.some((b: string) => sameSpot(k, b)));
    if (!appeared && (await addressInput(driver)) !== null) {
      return;
    }
    log('undo stray open: back');
    await driver.pressBack();
    await driver.delayMs(1000);
  }
  if ((await addressInput(driver)) === null) {
    await backToWindow(driver, 'stray');
  }
}

/**
 * 点开底部工具栏的「更多」按钮（base 已有：工具栏只有图标没有文字，默认布局下是地址栏上方一排图标的第 5 个）。
 * 以「面板里出现窗口名称」为打开成功的标志。如果实现在工具栏里加了按钮，「更多」会右移：依次尝试第 6 个及以后的图标；
 * 前 4 个（后退、前进、刷新、主页）点了会改变网页，从不尝试。
 */
async function openMorePanel(driver: Driver): Promise<void> {
  const first = await toolbarGlyphs(driver);
  await must(driver, 'more_toolbar', first.length >= 5, `glyphs=${first.length}`);
  let shown: Component | null = null;
  for (let k = 4; k < first.length && shown === null; k++) {
    const glyphs = await toolbarGlyphs(driver);
    if (k >= glyphs.length) {
      break;
    }
    const before = await screenKeys(driver);
    await glyphs[k].click();
    for (let i = 0; i < 6 && shown === null; i++) {
      await driver.delayMs(500);
      shown = await windowNameText(driver);
    }
    if (shown === null) {
      log(`more: glyph ${k} is not 更多`);
      await undoStrayOpen(driver, before);
    }
  }
  await must(driver, 'more_name', shown !== null);
  await driver.delayMs(500);
}

/** 确保「更多」面板处于打开状态（已打开就不再点工具栏，避免把它关掉）。 */
async function ensureMorePanel(driver: Driver): Promise<void> {
  if ((await windowNameText(driver)) === null) {
    await openMorePanel(driver);
  }
}

/** 收起「更多」面板（base：按返回键；输入框有焦点时第一下可能只收起键盘；不能多按，否则会退出应用）。 */
async function closeMorePanel(driver: Driver): Promise<void> {
  for (let i = 0; i < 3 && (await windowNameText(driver)) !== null; i++) {
    await driver.pressBack();
    await driver.delayMs(1000);
  }
  if ((await addressInput(driver)) === null) {
    await backToWindow(driver, 'more_close');
  }
}

/**
 * 离线可加载、带标题的网址：data URL（base 地址栏把它当作带协议的网址直接打开，不走搜索；
 * 标签栏显示网页标题）。只用百分号编码，满足 base 地址栏的合法字符校验。网页正文不含标记，
 * 这样屏幕上出现的标记只能来自标签标题。
 */
function markerUrl(marker: string): string {
  return `data:text/html,%3Ctitle%3E${marker}%3C%2Ftitle%3E-`;
}

/**
 * 是否有 Text 显示网页标题 marker（包含匹配，允许实现给标签加图标、序号等修饰）；
 * 排除地址栏/联想等显示网址本身的文字（含 data: 或 %3C），避免把"输入的网址"当作"已打开的网页"。
 */
async function markerShown(driver: Driver, marker: string): Promise<boolean> {
  for (const t of await textsContaining(driver, marker, 'Text')) {
    const txt = await textOf(t);
    if (!txt.includes('data:') && !txt.includes('%3C')) {
      return true;
    }
  }
  return false;
}

async function countMarkers(driver: Driver, markers: string[]): Promise<number> {
  let n = 0;
  for (const m of markers) {
    if (await markerShown(driver, m)) {
      n++;
    }
  }
  return n;
}

/** 屏幕左侧竖向标签栏（base 已有）里的标签项边界；按屏幕宽度比例判定"在左侧"。 */
async function sideTabItems(driver: Driver): Promise<Box[]> {
  const size = await driver.getDisplaySize();
  const r: Box[] = [];
  for (const it of await findAll(driver, ON.type('ListItem'))) {
    const b = await boundsOf(it);
    if (b.left < size.x * 0.2 && b.bottom > b.top) {
      r.push(b);
    }
  }
  return r;
}

/**
 * 让标签栏显示网页标题（只用于找到标题，不按标签项计数）。base 的竖向标签栏可以隐藏（Ctrl+Shift+A 显示/隐藏），
 * 也可以收窄成只有图标的一列（窄屏默认收窄，此时不显示标题）：隐藏就按 Ctrl+Shift+A；收窄就点标签列表下方
 * 那个展开按钮（base 已有的图标按钮）。宽窄都按屏幕宽度的比例判断：收窄 = 标签项宽度都小于屏幕宽度的 20%。
 */
async function showTabTitles(driver: Driver): Promise<void> {
  const size = await driver.getDisplaySize();
  let items = await sideTabItems(driver);
  if (items.length === 0) {
    await driver.triggerCombineKeys(KEY_CTRL_LEFT, KEY_SHIFT_LEFT, KEY_A);
    await driver.delayMs(2000);
    items = await sideTabItems(driver);
    log(`showTabTitles: toggled tab bar, items=${items.length}`);
  }
  if (items.length === 0 || items.some((b: Box) => b.right - b.left >= size.x * 0.2)) {
    return;
  }
  let lowest = 0;
  for (const b of items) {
    lowest = Math.max(lowest, b.bottom);
  }
  const bar = await toolbarGlyphs(driver);
  const limit = bar.length === 0 ? size.y : (await boundsOf(bar[0])).top;
  let best: Component | null = null;
  let bestTop = 1e9;
  for (const g of await findAll(driver, ON.type('SymbolGlyph').clickable(true))) {
    const b = await boundsOf(g);
    if (b.left < size.x * 0.2 && b.top >= lowest && b.bottom <= limit && b.top < bestTop) {
      best = g;
      bestTop = b.top;
    }
  }
  if (best === null) {
    log('showTabTitles: narrow tab bar but no expand button');
    return;
  }
  await best.click();
  await driver.delayMs(1500);
  const after = await sideTabItems(driver);
  log(`showTabTitles: expanded, widths=${after.map((b: Box) => b.right - b.left).join(',')}`);
}

/** 等 markers（标签栏里的网页标题）全部出现，返回找到的数量；没找齐时让标签栏显示标题后再找。 */
async function seekMarkers(driver: Driver, markers: string[], rounds: number): Promise<number> {
  let found = 0;
  for (let i = 0; i < rounds; i++) {
    found = await countMarkers(driver, markers);
    if (found === markers.length) {
      return found;
    }
    if (i === 0) {
      await showTabTitles(driver);
    } else {
      await driver.delayMs(1000);
    }
  }
  return await countMarkers(driver, markers);
}

/** 在当前标签页的地址栏输入网址并回车（base 已有流程），等屏幕上出现该网页标题。 */
async function loadMarkerInCurrentTab(driver: Driver, marker: string): Promise<boolean> {
  // 前置：输入前不应已有该标题（随机值）
  if (await markerShown(driver, marker)) {
    return false;
  }
  for (let attempt = 0; attempt < 3; attempt++) {
    const addr = await addressInputComp(driver);
    if (addr === null) {
      await driver.delayMs(1000);
      continue;
    }
    await addr.click();
    await driver.delayMs(800);
    await dismissImeGuide(driver);
    let editor: Component | null = await driver.findComponent(ON.type('TextInput').focused(true));
    if (editor === null) {
      editor = await addressInputComp(driver);
    }
    if (editor === null) {
      continue;
    }
    await editor.clearText();
    await editor.inputText(markerUrl(marker));
    await driver.delayMs(500);
    await driver.triggerKey(KEY_ENTER);
    for (let i = 0; i < 12; i++) {
      await driver.delayMs(500);
      if (await markerShown(driver, marker)) {
        return true;
      }
    }
    if ((await seekMarkers(driver, [marker], 3)) === 1) {
      return true;
    }
  }
  return false;
}

function markersOf(token: string, k: number): string[] {
  const r: string[] = [];
  for (let i = 1; i <= k; i++) {
    r.push(TAB_PREFIX + token + String(i));
  }
  return r;
}

/** 改名输入框：地址栏以外、内容是当前窗口名称（shown 以它结尾）的 TextInput。 */
async function renameEditor(driver: Driver, shown: string): Promise<Component | null> {
  const addr = await addressInput(driver);
  for (const c of await findAll(driver, ON.type('TextInput'))) {
    const b = await boundsOf(c);
    const txt = await textOf(c);
    if (addr !== null && b.top <= addr.top) {
      continue;
    }
    if (txt.length > 0 && shown.endsWith(txt)) {
      return c;
    }
  }
  return null;
}

/** 在「更多」面板里把当前窗口改名为 name（base 已有流程：点窗口名称 → 输入 → 回车）。改名框已经开着就直接用。 */
async function renameWindow(driver: Driver, name: string): Promise<void> {
  const nameText = await windowNameText(driver);
  await must(driver, 'rename_text', nameText !== null);
  const shown = await textOf(nameText!);
  // 前置：新名称（随机）此前不在屏幕上
  await must(driver, 'rename_pre', (await textsContaining(driver, name)).length === 0, `name=${name}`);
  let editor = await renameEditor(driver, shown);
  if (editor === null) {
    await nameText!.click();
    await driver.delayMs(1000);
    await dismissImeGuide(driver);
    editor = await renameEditor(driver, shown);
  }
  await must(driver, 'rename_editor', editor !== null, `shown=${shown}`);
  await editor!.clearText();
  await editor!.inputText(name);
  await driver.delayMs(500);
  // 回车提交；提交成功的标志是窗口名称（可点击文字）变为新名称
  let renamed = false;
  for (let attempt = 0; attempt < 3 && !renamed; attempt++) {
    await driver.triggerKey(KEY_ENTER);
    for (let i = 0; i < 6 && !renamed; i++) {
      await driver.delayMs(500);
      const t = await windowNameText(driver);
      renamed = t !== null && (await textOf(t)).includes(name);
    }
  }
  await must(driver, 'rename_done', renamed, `name=${name}`);
  await driver.delayMs(1000);
}

/** 去掉实现可能加在文字前后的修饰（空白、图标字形、emoji、冒号等符号）。 */
function stripDecor(txt: string): string {
  return txt.replace(/^[^一-龥A-Za-z0-9]+/u, '').replace(/[^一-龥A-Za-z0-9]+$/u, '').trim();
}

function hasCancelWord(t: string): boolean {
  return CANCEL_WORDS.some((w: string) => t.includes(w));
}

/** 文字含 words 之一、较短（≤ maxLen，去掉修饰后）的可点击控件（按钮、可点击文字）。 */
async function shortClickables(driver: Driver, words: string[], maxLen: number): Promise<Component[]> {
  const r: Component[] = [];
  const keys: string[] = [];
  for (const w of words) {
    for (const c of await findAll(driver, ON.text(w, MatchPattern.CONTAINS).clickable(true))) {
      const t = stripDecor(await textOf(c));
      if (!t.includes(w) || t.length > maxLen || ZONE_RE.test(t)) {
        continue;
      }
      const k = await keyOf(c);
      if (!keys.includes(k)) {
        keys.push(k);
        r.push(c);
      }
    }
  }
  return r;
}

/** 点击某个操作前屏幕上已有的确认类按钮。 */
async function confirmKeys(driver: Driver): Promise<string[]> {
  return await keysOf(await shortClickables(driver, CONFIRM_WORDS, 8));
}

/** 操作后如果弹出了新的「确定/确认」按钮（实现可以要求确认），点它。 */
async function clickNewConfirm(driver: Driver, before: string[], step: string): Promise<void> {
  for (const c of await shortClickables(driver, CONFIRM_WORDS, 8)) {
    if (!before.includes(await keyOf(c))) {
      log(`${step} confirm ${cut(await textOf(c), 20)}`);
      await c.click();
      await driver.delayMs(1500);
      return;
    }
  }
}

/**
 * 题面锚点「设为工作区」的入口控件：文字含「设为工作区」、不含取消类词、较短（排除说明文字）。
 * 如果同一行有 Toggle / Checkbox（开关式实现），返回开关本身。
 */
async function enZoneControl(driver: Driver): Promise<Component | null> {
  for (const c of await textsContaining(driver, A_ENZONE)) {
    const t = stripDecor(await textOf(c));
    if (hasCancelWord(t) || t.length > 12) {
      continue;
    }
    const toggle = await toggleInRow(driver, c);
    return toggle !== null ? toggle : c;
  }
  return null;
}

async function toggleInRow(driver: Driver, label: Component): Promise<Component | null> {
  const pb = await boundsOf(label);
  const cy = (pb.top + pb.bottom) / 2;
  const toggles: Component[] = (await findAll(driver, ON.type('Toggle'))).concat(await findAll(driver, ON.type('Checkbox')));
  for (const tg of toggles) {
    const b = await boundsOf(tg);
    if (b.top <= cy && b.bottom >= cy) {
      return tg;
    }
  }
  return null;
}

/** 改名编辑区是否已展开；没有就点开窗口名称（实现可以把工作区操作放在编辑区里）。 */
async function openNameEditor(driver: Driver, windowName: string): Promise<void> {
  const t = await windowNameText(driver);
  if (t === null) {
    return;
  }
  const shown = await textOf(t);
  if (!shown.includes(windowName) || (await renameEditor(driver, shown)) !== null) {
    return;
  }
  await t.click();
  await driver.delayMs(1500);
  await dismissImeGuide(driver);
}

/** 找「设为工作区」控件：可以常驻在「更多」面板，也可以在点开窗口名称后的编辑区；找不到时点开窗口名称再找。 */
async function findEnZone(driver: Driver, windowName: string): Promise<Component | null> {
  let btn: Component | null = null;
  for (let i = 0; i < 6 && btn === null; i++) {
    btn = await enZoneControl(driver);
    if (btn === null) {
      await driver.delayMs(500);
    }
  }
  if (btn === null) {
    await openNameEditor(driver, windowName);
    for (let i = 0; i < 6 && btn === null; i++) {
      btn = await enZoneControl(driver);
      if (btn === null) {
        await driver.delayMs(500);
      }
    }
  }
  return btn;
}

/** 地址栏下方（「更多」面板里）含取消类词的短控件的位置键：设为工作区之前记下，用来认出之后新出现的取消操作。 */
async function cancelWordKeys(driver: Driver): Promise<string[]> {
  return await keysOf(await cancelWordControls(driver));
}

async function cancelWordControls(driver: Driver): Promise<Component[]> {
  const addr = await addressInput(driver);
  const r: Component[] = [];
  const keys: string[] = [];
  for (const w of CANCEL_WORDS) {
    for (const c of await textsContaining(driver, w)) {
      const type = await c.getType();
      if (type !== 'Text' && type !== 'Button') {
        continue;
      }
      const b = await boundsOf(c);
      const t = stripDecor(await textOf(c));
      if (t.length > 12 || ZONE_RE.test(t) || (addr !== null && b.top < addr.bottom)) {
        continue;
      }
      const k = await keyOf(c);
      if (!keys.includes(k)) {
        keys.push(k);
        r.push(c);
      }
    }
  }
  return r;
}

/**
 * 取消操作的候选，按优先级：
 *   1. 设为工作区之后新出现的、含 取消/移出/解除/不再/退出 的短控件（含「工作区」的优先）；
 *   2. 「设为工作区」那一行的开关；
 *   3. 再点一次「设为工作区」（或带选中态的「已设为工作区」）。
 * 已经试过的（tried，位置键）不再返回。
 */
async function cancelCandidates(driver: Driver, before: string[], tried: string[]): Promise<Component[]> {
  const first: Component[] = [];
  const second: Component[] = [];
  for (const c of await cancelWordControls(driver)) {
    const k = await keyOf(c);
    if (before.some((b: string) => sameSpot(k, b)) || tried.includes(k)) {
      continue;
    }
    (stripDecor(await textOf(c)).includes(A_PANEL) ? first : second).push(c);
  }
  const r = first.concat(second);
  const labels: Component[] = [];
  for (const c of await textsContaining(driver, A_ENZONE)) {
    const t = stripDecor(await textOf(c));
    if (!hasCancelWord(t) && t.length <= 12) {
      labels.push(c);
    }
  }
  for (const c of labels) {
    const tg = await toggleInRow(driver, c);
    if (tg !== null && !tried.includes(await keyOf(tg))) {
      r.push(tg);
    }
  }
  for (const c of labels) {
    if (!tried.includes(await keyOf(c))) {
      r.push(c);
    }
  }
  return r;
}

/**
 * 取消工作区 name（当前窗口）：按行为判定，依次尝试候选（见 cancelCandidates），以"面板不再列出"为准。
 * 某个候选没有让它从面板消失，就当作这次尝试无效：名称仍在面板里（状态未变），界面收回到普通窗口，再试下一个。
 * 第 1 轮在「更多」面板现有内容里找，第 2 轮点开窗口名称（编辑区）再找。返回是否取消成功。
 */
async function cancelZone(driver: Driver, name: string, step: string, before: string[]): Promise<boolean> {
  const tried: string[] = [];
  for (let round = 0; round < 2; round++) {
    for (let guard = 0; guard < 5; guard++) {
      await ensureMorePanel(driver);
      if (round === 1) {
        await openNameEditor(driver, name);
      }
      let cands: Component[] = [];
      for (let i = 0; i < 4 && cands.length === 0; i++) {
        cands = await cancelCandidates(driver, before, tried);
        if (cands.length === 0) {
          await driver.delayMs(500);
        }
      }
      if (cands.length === 0) {
        break;
      }
      const c = cands[0];
      tried.push(await keyOf(c));
      log(`${step} try cancel r${round} [${cut(stripDecor(await textOf(c)), 20)}] ${await c.getType()}`);
      const conf = await confirmKeys(driver);
      await c.click();
      await driver.delayMs(1500);
      await clickNewConfirm(driver, conf, step);
      await driver.delayMs(1000);
      await closeMorePanel(driver);
      if (!(await listedSettled(driver, name, `${step}u`))) {
        return true;
      }
      log(`${step} candidate did not unlist ${name}; still listed`);
    }
  }
  return false;
}

/**
 * 是否像「工作区」面板标题：包含「工作区」（允许图标、空格、冒号、计数等修饰），
 * 但不是「设为工作区」/取消类控件、快捷键条目「查看工作区」或某个工作区名称，且文字较短。
 */
function isPanelTitleText(txt: string): boolean {
  const t = stripDecor(txt);
  return t.includes(A_PANEL) && !t.includes('设为') && !hasCancelWord(t) && !t.includes('查看工作区') &&
    !ZONE_RE.test(t) && t.length <= 12;
}

async function titleKeys(driver: Driver): Promise<string[]> {
  const r: string[] = [];
  for (const c of await textsContaining(driver, A_PANEL, 'Text')) {
    if (isPanelTitleText(await textOf(c))) {
      r.push(await keyOf(c));
    }
  }
  return r;
}

// 面板打开前屏幕上已有的标题样文字（常驻徽标、提示等，位置键）；面板打开时新出现的标题（位置键）就是面板标题。
// 面板"关闭"= 记下的面板标题不在了。卡片 = 打开面板前不存在、且带有自己的「打开」或「移除」按钮的名称文字。
let panelBaselineKeys: string[] = [];
let panelTitleKeys: string[] = [];
let outsideNameTexts: string[] = [];

async function newTitleKeys(driver: Driver): Promise<string[]> {
  return (await titleKeys(driver)).filter((k: string) => !panelBaselineKeys.some((b: string) => sameSpot(k, b)));
}

/**
 * 从这个窗口打开过别的工作区窗口后，回到这个窗口时面板可能还开着（实现可以这样）。只有看到的正是之前打开过的
 * 面板标题（同一处的同一段文字）才按返回键收起；常驻的「工作区」字样不会触发返回键。
 */
async function dismissLeftoverPanel(driver: Driver): Promise<void> {
  for (let i = 0; i < 3; i++) {
    const cur = await titleKeys(driver);
    if (!cur.some((k: string) => panelTitleKeys.some((p: string) => sameTitle(k, p)))) {
      break;
    }
    log('dismiss leftover panel');
    await driver.pressBack();
    await driver.delayMs(1200);
  }
  if ((await addressInput(driver)) === null) {
    await backToWindow(driver, 'leftover');
  }
}

async function tryOpenZonesPanel(driver: Driver): Promise<boolean> {
  await dismissLeftoverPanel(driver);
  panelBaselineKeys = await titleKeys(driver);
  outsideNameTexts = await keysOf(await textsContaining(driver, 'z', 'Text'));
  await driver.triggerCombineKeys(KEY_ALT_LEFT, KEY_Z);
  for (let i = 0; i < 10; i++) {
    await driver.delayMs(500);
    if ((await newTitleKeys(driver)).length > 0) {
      await driver.delayMs(2000);
      const settled = await newTitleKeys(driver);
      if (settled.length > 0) {
        panelTitleKeys = settled;
        return true;
      }
    }
  }
  return false;
}

async function openZonesPanel(driver: Driver, step: string): Promise<void> {
  const opened = await tryOpenZonesPanel(driver);
  await must(driver, `${step}_panel_open`, opened, `titles_before=${panelBaselineKeys.length}`);
}

/**
 * 是不是同一个面板标题：同一段文字、横向位置相同（40px 以内）。纵向不比：面板内容变少（例如移除了一张卡片）时
 * 居中的面板会变矮，标题随之上下移动。
 */
function sameTitle(k: string, p: string): boolean {
  const ik = k.lastIndexOf('@');
  const ip = p.lastIndexOf('@');
  return k.substring(0, ik) === p.substring(0, ip) &&
    Math.abs(Number(k.substring(ik + 1).split(',')[0]) - Number(p.substring(ip + 1).split(',')[0])) <= 40;
}

/** 面板已关闭：打开时记下的面板标题（同一段文字、同一横向位置）不在了；打开前就有的同位置文字不算。 */
async function panelGone(driver: Driver): Promise<boolean> {
  const cur = await titleKeys(driver);
  return !cur.some((k: string) => !panelBaselineKeys.some((b: string) => sameSpot(k, b)) &&
    panelTitleKeys.some((p: string) => sameTitle(k, p)));
}

async function closeZonesPanel(driver: Driver, step: string): Promise<void> {
  for (let i = 0; i < 4; i++) {
    if (await panelGone(driver)) {
      break;
    }
    await driver.pressBack();
    await driver.delayMs(1000);
  }
  await must(driver, `${step}_panel_closed`, await panelGone(driver));
}

/** 面板里文字为题面锚点 word 的可点击控件（去掉图标等修饰后以 word 开头、较短，且不含工作区名称）。 */
async function anchorButtons(driver: Driver, word: string): Promise<Component[]> {
  const r: Component[] = [];
  for (const b of await findAll(driver, ON.text(word, MatchPattern.CONTAINS).clickable(true))) {
    const t = stripDecor(await textOf(b));
    if (t.startsWith(word) && t.length <= 8 && !ZONE_RE.test(t)) {
      r.push(b);
    }
  }
  return r;
}

interface Card {
  title: Component;
  text: string;
  region: Box;
  open: Component | null;
  remove: Component | null;
}

interface Named {
  c: Component;
  txt: string;
  box: Box;
}

/**
 * 面板里的卡片：打开面板前不存在、含名称的文字（name 为 null 时匹配 ZONE_RE），且在它自己的范围里有「打开」或「移除」。
 * 卡片范围：横向夹在左右相邻的其他名称文字之间（兼容多列网格），纵向从本名称到同一列下一个名称为止。
 * 名称文字可以带图标（包括窗口名称的 󰁫）；面板顶部"当前窗口：xxx"之类没有自己按钮的文字不算卡片。
 */
async function scanCards(driver: Driver, name: string | null): Promise<Card[]> {
  const size = await driver.getDisplaySize();
  const named: Named[] = [];
  for (const t of await textsContaining(driver, 'z', 'Text')) {
    const txt = await textOf(t);
    if (!ZONE_RE.test(txt) && !(name !== null && txt.includes(name))) {
      continue;
    }
    if (outsideNameTexts.includes(await keyOf(t))) {
      continue;
    }
    named.push({ c: t, txt: txt, box: await boundsOf(t) });
  }
  if (named.length === 0) {
    return [];
  }
  const opens: Component[] = await anchorButtons(driver, A_OPEN);
  const removes: Component[] = await anchorButtons(driver, A_REMOVE);
  const openBoxes: Box[] = [];
  for (const o of opens) {
    openBoxes.push(await boundsOf(o));
  }
  const removeBoxes: Box[] = [];
  for (const o of removes) {
    removeBoxes.push(await boundsOf(o));
  }
  const cards: Card[] = [];
  for (const a of named) {
    if (name !== null && !a.txt.includes(name)) {
      continue;
    }
    let left = 0;
    let right = size.x;
    for (const o of named) {
      if (o !== a && o.box.right <= a.box.left) {
        left = Math.max(left, o.box.right);
      }
      if (o !== a && o.box.left >= a.box.right) {
        right = Math.min(right, o.box.left);
      }
    }
    const h = a.box.bottom - a.box.top;
    let bottom = size.y;
    for (const o of named) {
      if (o !== a && o.box.left < right && o.box.right > left && o.box.top > a.box.top + h / 2) {
        bottom = Math.min(bottom, o.box.top);
      }
    }
    const region: Box = { left: left, top: a.box.top - h, right: right, bottom: bottom };
    let open: Component | null = null;
    for (let i = 0; i < opens.length && open === null; i++) {
      if (centerIn(openBoxes[i], region)) {
        open = opens[i];
      }
    }
    let remove: Component | null = null;
    for (let i = 0; i < removes.length && remove === null; i++) {
      if (centerIn(removeBoxes[i], region)) {
        remove = removes[i];
      }
    }
    if (open !== null || remove !== null) {
      cards.push({ title: a.c, text: a.txt, region: region, open: open, remove: remove });
    }
  }
  return cards;
}

/** 面板里名称含 name（为 null 时任意 ZONE_RE 名称）的卡片，带轮询。 */
async function findCard(driver: Driver, name: string | null, waitMs: number): Promise<Card | null> {
  for (let waited = 0; ; waited += 500) {
    const cards = await scanCards(driver, name);
    if (cards.length > 0) {
      return cards[0];
    }
    if (waited >= waitMs) {
      return null;
    }
    await driver.delayMs(500);
  }
}

function cardName(txt: string): string {
  const m = txt.match(ZONE_RE);
  return m === null ? txt.trim() : m[0];
}

/** 面板里所有卡片的名称（ZONE_RE）。 */
async function listedNames(driver: Driver): Promise<string[]> {
  const r: string[] = [];
  for (const c of await scanCards(driver, null)) {
    const n = cardName(c.text);
    if (!r.includes(n)) {
      r.push(n);
    }
  }
  return r;
}

/**
 * 等面板内容稳定后再读卡片名称（否定检查用）：至少观察 4 秒，且最近连续 3 次（约 1.5 秒以上）读到的名称集合相同；
 * 最多 12 秒。面板异步加载慢的实现不会因为"还没加载出来"而被当成"不再列出"。
 */
async function settledNames(driver: Driver): Promise<string[]> {
  const t0 = Date.now();
  let last = '#';
  let same = 0;
  let names: string[] = [];
  while (true) {
    names = await listedNames(driver);
    const sig = names.slice().sort().join(',');
    same = sig === last ? same + 1 : 0;
    last = sig;
    const el = Date.now() - t0;
    if ((el >= 4000 && same >= 2) || el >= 12000) {
      return names;
    }
    await driver.delayMs(500);
  }
}

/** 打开面板，等内容稳定后看 name 是否列出，再关掉面板（结果可能是"否"的检查都用它）。 */
async function listedSettled(driver: Driver, name: string, step: string): Promise<boolean> {
  await openZonesPanel(driver, step);
  const names = await settledNames(driver);
  const listed = (await findCard(driver, name, 0)) !== null;
  log(`${step} settled listed(${name})=${listed} names=${names.join(',')}`);
  if (!listed) {
    log(`${step} panel SCREEN=${await screenTexts(driver)}`);
  }
  await closeZonesPanel(driver, step);
  return listed;
}

/** 打开面板，等到 name 出现（最多 waitMs），再关掉面板（肯定检查）。 */
async function isListed(driver: Driver, name: string, step: string, waitMs: number): Promise<boolean> {
  await openZonesPanel(driver, step);
  const listed = (await findCard(driver, name, waitMs)) !== null;
  log(`${step} listed(${name})=${listed}`);
  if (!listed) {
    log(`${step} panel SCREEN=${await screenTexts(driver)}`);
  }
  await closeZonesPanel(driver, step);
  return listed;
}

function union(a: Box, b: Box): Box {
  return { left: Math.min(a.left, b.left), top: Math.min(a.top, b.top), right: Math.max(a.right, b.right),
    bottom: Math.max(a.bottom, b.bottom) };
}

/**
 * 点卡片自己的「移除」。兼容需要确认的实现：点击后比较前后差异（同一处 40px 以内算同一个），只点新出现的
 * 移除/删除/确定/确认：先点不在本卡片（名称 + 自己的按钮）范围内的（弹窗，弹窗可以盖在别的卡片上），
 * 其次点本卡片范围内新出现的；别的卡片自己的按钮永远不点。都没有、且本卡片的「移除」还在，就再点一次（连点两次确认）。
 * 需要的位置信息都在点击前算好，保证第二下落在连点确认的时限（常见 2 秒）内。
 */
async function clickRemove(driver: Driver, card: Card, name: string, step: string): Promise<void> {
  await must(driver, `${step}_remove_button`, card.remove !== null, `card=${card.text}`);
  const titleKey = await keyOf(card.title);
  const otherButtons: string[] = [];
  for (const c of await scanCards(driver, null)) {
    if ((await keyOf(c.title)) === titleKey) {
      continue;
    }
    for (const b of [c.open, c.remove]) {
      if (b !== null) {
        otherButtons.push(await keyOf(b));
      }
    }
  }
  let tight = await boundsOf(card.title);
  for (const b of [card.open, card.remove]) {
    if (b !== null) {
      tight = union(tight, await boundsOf(b));
    }
  }
  const before = await keysOf(await shortClickables(driver, REMOVE_CONFIRM_WORDS, 8));
  await card.remove!.click();
  await driver.delayMs(600);
  if (await alive(card.title) && await alive(card.remove!)) {
    const outside: Component[] = [];
    const inside: Component[] = [];
    for (const c of await shortClickables(driver, REMOVE_CONFIRM_WORDS, 8)) {
      const k = await keyOf(c);
      if (before.some((x: string) => sameSpot(k, x)) || otherButtons.some((x: string) => sameSpot(k, x))) {
        continue;
      }
      const b = await boundsOf(c);
      (centerIn(b, tight) ? inside : outside).push(c);
    }
    const next: Component | null = outside.length > 0 ? outside[0] : (inside.length > 0 ? inside[0] : null);
    if (next !== null) {
      log(`${step} remove confirm [${cut(stripDecor(await textOf(next)), 20)}]`);
      await next.click();
    } else if (await alive(card.remove!)) {
      await card.remove!.click();
    }
  }
  await driver.delayMs(1500);
}

/** 点「设为工作区」（可以要求确认），并以"面板里列出该名称"判定成功。 */
async function setAsZone(driver: Driver, name: string, step: string): Promise<void> {
  await ensureMorePanel(driver);
  const en = await findEnZone(driver, name);
  await must(driver, `${step}_enzone_control`, en !== null);
  const conf = await confirmKeys(driver);
  await en!.click();
  await driver.delayMs(1500);
  await clickNewConfirm(driver, conf, step);
  await driver.delayMs(1000);
  const listed = await isListed(driver, name, step, 5000);
  await must(driver, `${step}_listed`, listed, `设为工作区后面板里没有列出 ${name}`);
}

/** 工作区名称 → 阶段 1 在那个窗口里打开的网页标题。 */
function markersOfName(name: string): string[] {
  const k = Number.parseInt(name.charAt(name.length - 1));
  return markersOf(name.substring(2, name.length - 1), k);
}

/** 屏幕上显示网页标题 marker 的文字控件个数（规则同 markerShown）。 */
async function markerCount(driver: Driver, marker: string): Promise<number> {
  let n = 0;
  for (const t of await textsContaining(driver, marker, 'Text')) {
    const txt = await textOf(t);
    if (!txt.includes('data:') && !txt.includes('%3C')) {
      n++;
    }
  }
  return n;
}

async function markerCounts(driver: Driver, markers: string[]): Promise<number[]> {
  const r: number[] = [];
  for (const m of markers) {
    r.push(await markerCount(driver, m));
  }
  return r;
}

/** 回到某个浏览器窗口（有地址栏）；当前没有就用 aa start 把应用拉到前台。 */
async function backToWindow(driver: Driver, step: string): Promise<void> {
  for (let i = 0; i < 6 && (await addressInput(driver)) === null; i++) {
    await driver.delayMs(500);
  }
  if ((await addressInput(driver)) === null) {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator();
    await delegator.executeShellCommand(`aa start -b ${BUNDLE} -a EntryAbility`);
    await driver.waitForComponent(ON.type('TextInput'), 10000);
    await driver.delayMs(1500);
  }
  await must(driver, `${step}_window`, (await addressInput(driver)) !== null);
}

// 最近一次来到前台的浏览器窗口（EntryAbility 实例），以及已经销毁（或窗口已销毁）的实例。
// 用系统的 AbilityMonitor 记录，不依赖应用实现。
let lastForeground: UIAbility | null = null;
const destroyed: UIAbility[] = [];
let monitorAdded = false;

function watchForeground(): void {
  if (monitorAdded) {
    return;
  }
  const monitor: abilityDelegatorRegistry.AbilityMonitor = {
    abilityName: 'EntryAbility',
    moduleName: 'entry',
    onAbilityForeground: (a: UIAbility) => {
      lastForeground = a;
    },
    onWindowStageDestroy: (a: UIAbility) => {
      destroyed.push(a);
    },
    onAbilityDestroy: (a: UIAbility) => {
      destroyed.push(a);
    }
  };
  abilityDelegatorRegistry.getAbilityDelegator().addAbilityMonitor(monitor);
  monitorAdded = true;
}

/**
 * 正常关闭当前窗口（最近一次来到前台的那个）：走系统的 Ability 正常销毁流程（等同用户在多任务里关掉这个窗口），
 * 不是杀进程。关闭后回到应用的其他窗口。
 */
async function closeTopWindow(driver: Driver, step: string): Promise<void> {
  const top = lastForeground;
  await must(driver, `${step}_top_ability`, top !== null);
  lastForeground = null;
  await top!.context.terminateSelf();
  await driver.delayMs(3000);
  await backToWindow(driver, step);
}

/** 当前窗口在「更多」面板里显示的名称。 */
async function currentWindowName(driver: Driver): Promise<string> {
  await ensureMorePanel(driver);
  const t = await windowNameText(driver);
  const txt = t === null ? '' : await textOf(t);
  await closeMorePanel(driver);
  return txt;
}

/**
 * Alt+Z →「打开」名为 name 的工作区；等面板消失、回到一个浏览器窗口。按钮只在这张卡片自己的范围里找。
 * allowNoOpen：已打开的工作区可以不提供「打开」（例如显示"当前窗口"），这时什么都不点。
 */
async function openZoneByName(driver: Driver, name: string, step: string, mustLeavePanel: boolean,
  allowNoOpen: boolean = false): Promise<void> {
  await openZonesPanel(driver, step);
  const card = await findCard(driver, name, 8000);
  await must(driver, `${step}_listed`, card !== null, `面板里没有 ${name}`);
  if (card!.open === null && allowNoOpen) {
    log(`${step} card ${name} has no 打开 (already open); skip`);
    await closeZonesPanel(driver, step);
    return;
  }
  await must(driver, `${step}_open_button`, card!.open !== null, `card=${card!.text}`);
  await card!.open!.click();
  for (let i = 0; i < 30; i++) {
    await driver.delayMs(500);
    if (await panelGone(driver)) {
      break;
    }
  }
  if (mustLeavePanel) {
    await must(driver, `${step}_opened`, await panelGone(driver), '点「打开」后面板没有消失');
  } else if (!(await panelGone(driver))) {
    await closeZonesPanel(driver, step);
  }
  await driver.waitForComponent(ON.type('TextInput'), 10000);
  await driver.delayMs(2000);
  await backToWindow(driver, step);
}

/**
 * 当前窗口就是工作区 name：带回它的全部有网址的标签页（按标题判断，空白标签页留不留都可以），
 * 没有混进另一个工作区 other 的标签页，窗口名称就是工作区名称。
 */
async function checkZoneWindow(driver: Driver, name: string, other: string, step: string): Promise<void> {
  const markers = markersOfName(name);
  const found = await seekMarkers(driver, markers, 12);
  await must(driver, `${step}_tabs_restored`, found === markers.length, `${found}/${markers.length} markers=${markers.join(',')}`);
  const foreign = await countMarkers(driver, markersOfName(other));
  await must(driver, `${step}_no_foreign_tabs`, foreign === 0, `${name} 的窗口里出现了 ${other} 的标签页 ${foreign} 个`);
  const winName = await currentWindowName(driver);
  await must(driver, `${step}_window_name`, winName.includes(name), `window=${winName} zone=${name}`);
}

/** 在当前窗口新建 K 个有网址的标签页（Ctrl+T + 地址栏输入，base 已有），返回网页标题。 */
async function addMarkerTabs(driver: Driver, token: string, k: number, step: string): Promise<string[]> {
  const markers = markersOf(token, k);
  log(`${step} k=${k} markers=${markers.join(',')}`);
  await showTabTitles(driver);
  for (let i = 0; i < k; i++) {
    await driver.triggerCombineKeys(KEY_CTRL_LEFT, KEY_T);
    await driver.delayMs(1500);
    await must(driver, `${step}_tab_loaded_${i + 1}`, await loadMarkerInCurrentTab(driver, markers[i]), markers[i]);
  }
  const shown = await seekMarkers(driver, markers, 5);
  await must(driver, `${step}_markers_shown`, shown === k, `${shown}/${k}`);
  await driver.delayMs(3000);
  return markers;
}

function randomToken(): string {
  return String(10000 + Math.floor(Math.random() * 90000));
}

/** 阶段 2：面板里有阶段 1 的两个工作区（zq… 和 zp…），且没有阶段 1 取消掉的 zc…。 */
async function findTwoZones(driver: Driver, step: string): Promise<string[]> {
  await openZonesPanel(driver, step);
  let names: string[] = [];
  for (let i = 0; i < 16; i++) {
    names = await listedNames(driver);
    if (names.some((n: string) => n.startsWith(ZONE_PREFIX)) && names.some((n: string) => n.startsWith(ZONE_PREFIX_B))) {
      break;
    }
    await driver.delayMs(500);
  }
  names = await settledNames(driver);
  const a = names.find((n: string) => n.startsWith(ZONE_PREFIX));
  const b = names.find((n: string) => n.startsWith(ZONE_PREFIX_B));
  const c = names.find((n: string) => n.startsWith(ZONE_PREFIX_C));
  await must(driver, `${step}_listed`, a !== undefined && b !== undefined, `冷启动后面板里的工作区：${names.join(',')}`);
  await must(driver, `${step}_cancel_gone`, c === undefined, `阶段 1 已取消的 ${c} 冷启动后又出现在面板里`);
  await closeZonesPanel(driver, step);
  log(`${step} zones=${a},${b}`);
  return [a!, b!];
}

/**
 * 把「设置 → 启动 → 启动至页面」选为「恢复上次」（base 已有设置；默认布局下工具栏最右侧的图标打开设置）。
 * 实现改动了工具栏时从右往左试（不试前 4 个：后退、前进、刷新、主页）。
 */
async function setStartUpRestoreLast(driver: Driver): Promise<void> {
  // 「设置」「启动」「恢复上次」「通用」都是 base 自己的界面文案；点击前先确认它们不在屏幕上
  await must(driver, 'settings_pre', (await textsContaining(driver, '恢复上次')).length === 0 &&
    (await driver.findComponent(ON.text('设置'))) === null);
  const first = await toolbarGlyphs(driver);
  await must(driver, 'settings_toolbar', first.length >= 5, `glyphs=${first.length}`);
  let opened = false;
  for (let k = first.length - 1; k >= 4 && !opened; k--) {
    const glyphs = await toolbarGlyphs(driver);
    if (k >= glyphs.length) {
      continue;
    }
    const before = await screenKeys(driver);
    await glyphs[k].click();
    opened = (await driver.waitForComponent(ON.text('设置'), 4000)) !== null;
    if (!opened) {
      await undoStrayOpen(driver, before);
    }
  }
  await must(driver, 'settings_open', opened);
  await driver.delayMs(1000);
  const entries = await findAll(driver, ON.text('启动'));
  await must(driver, 'settings_startup_entry', entries.length > 0);
  await entries[entries.length - 1].click();
  const option = await driver.waitForComponent(ON.text('恢复上次'), 5000);
  await must(driver, 'settings_restore_last', option !== null);
  await option!.click();
  await driver.delayMs(1500);
  // 逐级返回直到设置关闭（「恢复上次」所在页和设置分类列表「通用」都不可见）；不能多按，否则会退出应用
  for (let i = 0; i < 4; i++) {
    if ((await driver.findComponent(ON.text('恢复上次'))) === null && (await driver.findComponent(ON.text('通用'))) === null) {
      break;
    }
    await driver.pressBack();
    await driver.delayMs(1200);
  }
  await must(driver, 'settings_closed', (await driver.findComponent(ON.text('通用'))) === null && (await addressInput(driver)) !== null);
}


/** 竖向标签栏里的标签项个数（先让标签栏显示出来）。 */
async function tabCount(driver: Driver): Promise<number> {
  await showTabTitles(driver);
  await driver.delayMs(500);
  return (await sideTabItems(driver)).length;
}

/** 把「启动至页面」设为 option（base 设置界面）。 */
async function setStartUp(driver: Driver, option: string): Promise<void> {
  const first = await toolbarGlyphs(driver);
  let opened = false;
  for (let k = first.length - 1; k >= 4 && !opened; k--) {
    const glyphs = await toolbarGlyphs(driver);
    const before = await screenKeys(driver);
    await glyphs[k].click();
    opened = (await driver.waitForComponent(ON.text('设置'), 4000)) !== null;
    if (!opened) {
      await undoStrayOpen(driver, before);
    }
  }
  await must(driver, 'pset_open', opened);
  await driver.delayMs(1000);
  const entries = await findAll(driver, ON.text('启动'));
  await must(driver, 'pset_entry', entries.length > 0);
  await entries[entries.length - 1].click();
  const opt = await driver.waitForComponent(ON.text(option), 5000);
  await must(driver, 'pset_option', opt !== null, option);
  await opt!.click();
  await driver.delayMs(1500);
  for (let i = 0; i < 4; i++) {
    if ((await driver.findComponent(ON.text('恢复上次'))) === null && (await driver.findComponent(ON.text('通用'))) === null) {
      break;
    }
    await driver.pressBack();
    await driver.delayMs(1200);
  }
  await must(driver, 'pset_closed', (await addressInput(driver)) !== null);
}

/** 屏幕上第一个形如 zq + 6 位数字的窗口名（「更多」面板里）。 */
async function currentZoneLikeName(driver: Driver): Promise<string> {
  const t = await currentWindowName(driver);
  const m = t.match(/zq[0-9]{6}/);
  return m === null ? '' : m[0];
}

/** 点标签栏里标题为 marker 的标签项，等地址栏显示含 marker 的网址（data URL 里含标题）；返回地址栏内容是否含 marker。 */
async function tabLoads(driver: Driver, marker: string): Promise<string> {
  const size = await driver.getDisplaySize();
  let item: Component | null = null;
  for (const t of await textsContaining(driver, marker, 'Text')) {
    const b = await boundsOf(t);
    const txt = await textOf(t);
    if (b.left < size.x * 0.2 && !txt.includes('data:') && !txt.includes('%3C')) {
      item = t;
      break;
    }
  }
  if (item === null) {
    return 'no-tab-item';
  }
  await item.click();
  let addr = '';
  for (let i = 0; i < 16; i++) {
    await driver.delayMs(500);
    const c = await addressInputComp(driver);
    addr = c === null ? '' : await textOf(c);
    if (addr.includes(marker)) {
      return 'ok';
    }
  }
  return `addr=[${cut(addr, 60)}]`;
}

/** 标签栏（屏幕左侧）里标题为 base 空白页标题「Meow」的标签项个数。 */
async function blankTabRows(driver: Driver): Promise<number> {
  await showTabTitles(driver);
  await driver.delayMs(500);
  const size = await driver.getDisplaySize();
  let n = 0;
  for (const t of await textsContaining(driver, 'Meow', 'Text')) {
    const b = await boundsOf(t);
    if (b.left < size.x * 0.2 && stripDecor(await textOf(t)) === 'Meow') {
      n++;
    }
  }
  return n;
}

export default function zonesTest() {
  describe('NF_Zones', () => {
    // 阶段 1（「启动至页面」保持默认）：窗口 1 布置 K 个带标题的标签页 → 改名为 zc… →「设为工作区」→ 面板列出；
    // 取消（按行为判定）→ 面板不再列出，标签页仍在；改名为 zq… → 设为工作区 A → 列出。
    // 然后 Ctrl+N 开窗口 2，同样布置标签页、改名、设为工作区 B，面板同时列出 A 和 B。
    it('FP1_create_zone', 0, async () => {
      const driver = Driver.create();
      await launch(driver);
      const token = randomToken();
      const k = 1 + Math.floor(Math.random() * 3);
      const markers = await addMarkerTabs(driver, token, k, 's1');
      await openMorePanel(driver);
      const nameC = ZONE_PREFIX_C + token + String(k);
      await renameWindow(driver, nameC);

      // 设为工作区之前屏幕上已有的取消类文字，用来识别之后新出现的取消操作
      const cancelBefore = await cancelWordKeys(driver);
      await setAsZone(driver, nameC, 's1');

      // 取消：面板中不再有它（等面板稳定后判断）；窗口和标签页不受影响
      const canceled = await cancelZone(driver, nameC, 's1c', cancelBefore);
      await must(driver, 's1_cancel', canceled, `设为工作区后找不到能让面板不再列出 ${nameC} 的取消操作`);
      const kept = await seekMarkers(driver, markers, 5);
      await must(driver, 's1_cancel_keeps_tabs', kept === k, `取消后标签页 ${kept}/${k}`);

      // 以新名称再设为工作区 A，留给后续阶段
      await ensureMorePanel(driver);
      const name = ZONE_PREFIX + token + String(k);
      await renameWindow(driver, name);
      await setAsZone(driver, name, 's1again');
      await closeMorePanel(driver);

      // 窗口 2（base 已有的 Ctrl+N 新窗口）：另一组标签页，存成工作区 B
      await driver.triggerCombineKeys(KEY_CTRL_LEFT, KEY_N);
      let isNew = false;
      for (let i = 0; i < 20 && !isNew; i++) {
        await driver.delayMs(500);
        isNew = (await addressInput(driver)) !== null && (await countMarkers(driver, markers)) === 0;
      }
      await driver.delayMs(1500);
      isNew = (await addressInput(driver)) !== null && (await countMarkers(driver, markers)) === 0;
      await must(driver, 's1_new_window', isNew, 'Ctrl+N 后没有出现新窗口');
      let tokenB = randomToken();
      while (tokenB === token) {
        tokenB = randomToken();
      }
      const kB = 1 + Math.floor(Math.random() * 2);
      await addMarkerTabs(driver, tokenB, kB, 's1b');
      await openMorePanel(driver);
      const nameB = ZONE_PREFIX_B + tokenB + String(kB);
      await renameWindow(driver, nameB);
      await setAsZone(driver, nameB, 's1b');
      await must(driver, 's1_both_listed', await isListed(driver, name, 's1ab', 3000), `设为工作区 ${nameB} 后面板里没有 ${name}`);
    });

    // 阶段 2（冷启动，「启动至页面」为默认值）：两个工作区都还在，取消掉的不在。打开 A：带回 A 的标签页、没有 B 的、名称为 A；
    // 正常关闭 A 的窗口后再打开：标签页仍在；A 已打开时再点一次「打开」：不能把标签页弄重复；
    // 打开 B：带回 B 的标签页、没有 A 的。最后在 B 打开时点「移除」：面板列表与窗口状态必须一致。
    it('FP1_open_zone', 0, async () => {
      watchForeground();
      const driver = Driver.create();
      await launch(driver);
      const zones = await findTwoZones(driver, 's2');
      const a = zones[0];
      const b = zones[1];

      await openZoneByName(driver, a, 's2a', true);
      await checkZoneWindow(driver, a, b, 's2a');

      // 正常关闭工作区窗口，再从面板打开
      await closeTopWindow(driver, 's2close');
      await openZoneByName(driver, a, 's2reopen', true);
      await checkZoneWindow(driver, a, b, 's2reopen');

      // A 已经打开时再打开一次：可以聚焦已有窗口、提示、不反应或不提供「打开」，但不能让标签页重复或丢失
      const markersA = markersOfName(a);
      await seekMarkers(driver, markersA, 5);
      const before = await markerCounts(driver, markersA);
      await must(driver, 's2dup_before', before.every((n: number) => n >= 1),
        `再次打开前标签栏里的标题个数 ${before.join(',')}（${markersA.join(',')}）`);
      await openZoneByName(driver, a, 's2dup', false, true);
      await seekMarkers(driver, markersA, 8);
      const after = await markerCounts(driver, markersA);
      await must(driver, 's2dup_same_tabs', after.every((n: number, i: number) => n === before[i]),
        `再次打开前 ${before.join(',')}，之后 ${after.join(',')}（${markersA.join(',')}）`);
      const dupName = await currentWindowName(driver);
      await must(driver, 's2dup_window_name', dupName.includes(a), `window=${dupName} zone=${a}`);

      // 打开另一个工作区
      await openZoneByName(driver, b, 's2b', true);
      await checkZoneWindow(driver, b, a, 's2b');

      // 在工作区打开时移除它：实现可以拒绝（仍列出），也可以移除并把窗口变回普通窗口，或者移除并关闭它的窗口；
      // 但不能出现「列表里已经没有、窗口却仍以该工作区自居」的状态
      const bAbility = lastForeground;
      await openZonesPanel(driver, 's2rm');
      const openedCard = await findCard(driver, b, 8000);
      await must(driver, 's2_listed_while_open', openedCard !== null, b);
      await clickRemove(driver, openedCard!, b, 's2');
      for (let i = 0; i < 4; i++) {
        if ((await panelGone(driver)) && (await addressInput(driver)) !== null) {
          break;
        }
        await driver.pressBack();
        await driver.delayMs(1200);
      }
      await backToWindow(driver, 's2_back');
      const listed = await listedSettled(driver, b, 's2chk');
      if (listed) {
        log('s2 open zone removal rejected (still listed)');
        return;
      }
      // 已从面板移除：B 的窗口已经关闭即可
      let closed = false;
      for (let i = 0; i < 10 && !closed; i++) {
        closed = bAbility !== null && destroyed.includes(bAbility);
        if (!closed) {
          await driver.delayMs(500);
        }
      }
      if (closed) {
        log('s2 removed zone window was closed');
        return;
      }
      // B 的窗口还在（就是前台这个）：它不能再以 B 自居——必须能重新「设为工作区」并被面板列出（随后取消）
      const curText = await currentWindowName(driver);
      await must(driver, 's2_remove_window', curText.includes(b), `B 的窗口没有关闭，但前台窗口是 ${curText}`);
      await ensureMorePanel(driver);
      const cancelBefore = await cancelWordKeys(driver);
      const en = await findEnZone(driver, b);
      await must(driver, 's2_remove_consistent_enzone', en !== null,
        `已从面板移除，但当前窗口（${b}）找不到「设为工作区」`);
      const conf = await confirmKeys(driver);
      await en!.click();
      await driver.delayMs(1500);
      await clickNewConfirm(driver, conf, 's2re');
      await driver.delayMs(1000);
      const relisted = await isListed(driver, b, 's2re', 5000);
      await must(driver, 's2_remove_consistent', relisted,
        `已从面板移除，但当前窗口（${b}）再次设为工作区后面板里没有列出`);
      // 清理：取消
      await must(driver, 's2_cleanup_cancel', await cancelZone(driver, b, 's2cu', cancelBefore), b);
    });

    // 阶段 3（冷启动）：经过阶段 2 的关闭、重复打开、打开另一个工作区之后，A 仍然完好
    it('FP1_reopen_after_restart', 0, async () => {
      const driver = Driver.create();
      await launch(driver);
      await openZonesPanel(driver, 's3');
      let names: string[] = [];
      for (let i = 0; i < 16 && !names.some((n: string) => n.startsWith(ZONE_PREFIX)); i++) {
        names = await listedNames(driver);
        await driver.delayMs(500);
      }
      const a = names.find((n: string) => n.startsWith(ZONE_PREFIX));
      await must(driver, 's3_listed', a !== undefined, `面板里的工作区：${names.join(',')}`);
      await closeZonesPanel(driver, 's3');
      // B 在阶段 2 可能已被移除；只用它的名称排除串入的标签页
      const b = ZONE_PREFIX_B + '000000';
      const bLog = names.find((n: string) => n.startsWith(ZONE_PREFIX_B));
      await openZoneByName(driver, a!, 's3a', true);
      await checkZoneWindow(driver, a!, bLog === undefined ? b : bLog, 's3a');
    });

    // 阶段 4（冷启动）：工作区未打开时可以移除；移除 A 不影响 B（B 在阶段 2 被实现拒绝移除时仍在）
    it('FP1_remove_zone', 0, async () => {
      const driver = Driver.create();
      await launch(driver);
      await openZonesPanel(driver, 's4');
      const any = await findCard(driver, null, 8000);
      await must(driver, 's4_has_cards', any !== null, '冷启动后面板里一张工作区卡片都没有');
      const names = await settledNames(driver);
      const a = names.find((n: string) => n.startsWith(ZONE_PREFIX));
      const b = names.find((n: string) => n.startsWith(ZONE_PREFIX_B));
      await must(driver, 's4_listed', a !== undefined, `面板里的工作区：${names.join(',')}`);
      const card = await findCard(driver, a!, 3000);
      await must(driver, 's4_card', card !== null, a!);
      await clickRemove(driver, card!, a!, 's4');
      const left = await settledNames(driver);
      await must(driver, 's4_removed', !left.includes(a!), `移除后仍列出 ${a}：${left.join(',')}`);
      if (b !== undefined) {
        await must(driver, 's4_other_kept', left.includes(b), `移除 ${a} 后 ${b} 也不见了：${left.join(',')}`);
        await closeZonesPanel(driver, 's4');
        await openZoneByName(driver, b, 's4b', true);
        await checkZoneWindow(driver, b, a!, 's4b');
      }
    });

    // 阶段 5（冷启动）：移除后重启也不再出现（取消掉的 zc 也不在）
    it('FP1_removed_after_restart', 0, async () => {
      const driver = Driver.create();
      await launch(driver);
      await openZonesPanel(driver, 's5');
      const names = await settledNames(driver);
      const left = names.filter((n: string) => n.startsWith(ZONE_PREFIX) || n.startsWith(ZONE_PREFIX_C));
      await must(driver, 's5_gone', left.length === 0, left.join(','));
    });
  });

  describe('R_WindowRename', () => {
    // 回归：「更多」面板里给普通窗口改名（本功能修改了改名逻辑），改名后新窗口默认沿用该名称；
    // 普通改名不会让它出现在工作区面板里（Alt+Z 打不开面板的实现上跳过这一项）
    it('R_rename_set', 0, async () => {
      const driver = Driver.create();
      await launch(driver);
      await openMorePanel(driver);
      const name = randomName(RENAME_PREFIX);
      await renameWindow(driver, name);
      if (await tryOpenZonesPanel(driver)) {
        await settledNames(driver);
        await must(driver, 'r1_not_listed', (await findCard(driver, name, 0)) === null, name);
        await closeZonesPanel(driver, 'r1');
      }
    });

    it('R_rename_after_restart', 0, async () => {
      const driver = Driver.create();
      await launch(driver);
      await openMorePanel(driver);
      const nameText = await windowNameText(driver);
      const txt = nameText === null ? '' : await textOf(nameText);
      await must(driver, 'r2_name_kept', RENAME_RE.test(txt), `window=${txt}`);
    });
  });

  describe('R_RestoreLast', () => {
    // 回归：「启动至页面」=「恢复上次」时，普通窗口的标签页在冷启动后恢复（base 已有行为；本功能会改工作目录的
    // 初始化与清理逻辑）。用 base 自带的设置界面设置；与工作区无关，不设任何工作区。
    it('R_restore_set', 0, async () => {
      const driver = Driver.create();
      await launch(driver);
      await setStartUpRestoreLast(driver);
      // 网页标题 tb + 4 位随机数 + K + 序号：K 编进标题，阶段 2 不保存中间状态也能知道要找几个
      const k = 1 + Math.floor(Math.random() * 2);
      const token = String(1000 + Math.floor(Math.random() * 9000)) + String(k);
      await addMarkerTabs(driver, token, k, 'rr1');
    });

    it('R_restore_after_restart', 0, async () => {
      const driver = Driver.create();
      await launch(driver);
      // 从屏幕上认出阶段 1 的第 1 个标题 tbNNNNK1，再要求 K 个标题全部恢复
      let first = '';
      for (let i = 0; i < 12 && first.length === 0; i++) {
        for (const t of await textsContaining(driver, TAB_PREFIX, 'Text')) {
          const txt = await textOf(t);
          const m = txt.match(/tb[0-9]{4}[12]1/);
          if (m !== null && !txt.includes('data:') && !txt.includes('%3C')) {
            first = m[0];
          }
        }
        if (first.length === 0) {
          if (i === 0) {
            await showTabTitles(driver);
          } else {
            await driver.delayMs(1000);
          }
        }
      }
      await must(driver, 'rr2_tabs_restored', first.length > 0, '「恢复上次」下冷启动后没有恢复上次的标签页');
      const token = first.substring(2, 7);
      const markers = markersOf(token, Number.parseInt(token.charAt(4)));
      const n = await seekMarkers(driver, markers, 8);
      await must(driver, 'rr2_all_tabs', n === markers.length, `${n}/${markers.length} ${markers.join(',')}`);
    });
  });

  describe('NF_ZoneTabs', () => {
    // FP2 空白标签页（base 的 newTabBare 会把新建的空白标签页存盘，空白标签页是窗口的一部分）：
    // 当前标签页加载 tb1，Ctrl+T 加载 tb2，再 Ctrl+T 留空白标签页 → 改名 → 设为工作区；冷启动后打开，空白标签页个数不减少
    it('FP2_blank_set', 0, async () => {
      const driver = Driver.create();
      await launch(driver);
      const token = randomToken();
      const markers = markersOf(token, 2);
      log(`pb1 markers=${markers.join(',')}`);
      await showTabTitles(driver);
      await must(driver, 'pb1_tab1', await loadMarkerInCurrentTab(driver, markers[0]), markers[0]);
      await driver.triggerCombineKeys(KEY_CTRL_LEFT, KEY_T);
      await driver.delayMs(1500);
      await must(driver, 'pb1_tab2', await loadMarkerInCurrentTab(driver, markers[1]), markers[1]);
      await driver.triggerCombineKeys(KEY_CTRL_LEFT, KEY_T);
      await driver.delayMs(3000);
      const n0 = await tabCount(driver);
      const blanks = await blankTabRows(driver);
      log(`pb1 tabs=${n0} blank=${blanks}`);
      await must(driver, 'pb1_blanks', blanks >= 2 && blanks <= 9, `tabs=${n0} blank=${blanks}`);
      await must(driver, 'pb1_markers', (await seekMarkers(driver, markers, 3)) === 2);
      await openMorePanel(driver);
      // 名称最后一位 = 保存前的空白标签项个数
      const name = ZONE_PREFIX + token + String(blanks);
      await renameWindow(driver, name);
      await setAsZone(driver, name, 'pb1');
      await closeMorePanel(driver);
      await driver.delayMs(3000);
    });

    it('FP2_blank_open', 0, async () => {
      const driver = Driver.create();
      await launch(driver);
      await openZonesPanel(driver, 'pb2');
      const names = await settledNames(driver);
      const a = names.find((n: string) => n.startsWith(ZONE_PREFIX));
      await must(driver, 'pb2_listed', a !== undefined, names.join(','));
      await closeZonesPanel(driver, 'pb2');
      await openZoneByName(driver, a!, 'pb2o', true);
      const markers = markersOf(a!.substring(2, 7), 2);
      const n0 = Number.parseInt(a!.charAt(7));
      const found = await seekMarkers(driver, markers, 10);
      const n = await tabCount(driver);
      const blanks = await blankTabRows(driver);
      log(`pb2 zone=${a} titled=${found}/2 tabs=${n} blank=${blanks} blankBefore=${n0}`);
      await must(driver, 'pb2_titled', found === 2, `${found}/2`);
      const loads: string[] = [];
      for (const m of markers) {
        loads.push(`${m}:${await tabLoads(driver, m)}`);
      }
      log(`pb2 loads ${loads.join(' ')}`);
      await must(driver, 'pb2_blank_kept', blanks >= n0, `保存前空白标签 ${n0} 个，打开后 ${blanks} 个（标签项共 ${n}）`);
    });

    // FP3 冷启动恢复后尚未激活的标签页（base 恢复时只读标题，网址要等标签页激活才从磁盘读）：
    // 「恢复上次」→ 3 个有标题的标签页 → 改名 → 冷启动
    it('FP3_lazy_prepare', 0, async () => {
      const driver = Driver.create();
      await launch(driver);
      await setStartUp(driver, '恢复上次');
      const token = randomToken();
      const markers = markersOf(token, 3);
      log(`pl1 markers=${markers.join(',')}`);
      await showTabTitles(driver);
      await must(driver, 'pl1_tab1', await loadMarkerInCurrentTab(driver, markers[0]), markers[0]);
      for (let i = 1; i < 3; i++) {
        await driver.triggerCombineKeys(KEY_CTRL_LEFT, KEY_T);
        await driver.delayMs(1500);
        await must(driver, `pl1_tab${i + 1}`, await loadMarkerInCurrentTab(driver, markers[i]), markers[i]);
      }
      await must(driver, 'pl1_markers', (await seekMarkers(driver, markers, 3)) === 3);
      await openMorePanel(driver);
      await renameWindow(driver, ZONE_PREFIX + token + '3');
      await closeMorePanel(driver);
      await driver.delayMs(4000);
    });

    // 冷启动：标签页由 base 恢复（未激活的只有标题）；不点任何标签页，直接设为工作区；再把启动选项改回「新标签页」
    it('FP3_lazy_set', 0, async () => {
      const driver = Driver.create();
      await launch(driver);
      const name = await currentZoneLikeName(driver);
      await must(driver, 'pl2_name', name.length > 0, name);
      const markers = markersOfName(name);
      await must(driver, 'pl2_restored', (await seekMarkers(driver, markers, 6)) === 3, '冷启动后标签页没有恢复');
      await setAsZone(driver, name, 'pl2');
      await closeMorePanel(driver);
      await driver.delayMs(3000);
      await setStartUp(driver, '新标签页');
      await driver.delayMs(2000);
    });

    // 冷启动（新标签页）：先把当前窗口改成普通名称，再从面板打开工作区，3 个标题都要在
    it('FP3_lazy_open', 0, async () => {
      const driver = Driver.create();
      await launch(driver);
      await openZonesPanel(driver, 'pl3');
      const names = await settledNames(driver);
      const a = names.find((n: string) => n.startsWith(ZONE_PREFIX));
      await must(driver, 'pl3_listed', a !== undefined, names.join(','));
      await closeZonesPanel(driver, 'pl3');
      const markers = markersOfName(a!);
      await must(driver, 'pl3_w0_clean', (await countMarkers(driver, markers)) === 0, '冷启动的普通窗口里已经有这些标签页');
      await openMorePanel(driver);
      await renameWindow(driver, randomName(RENAME_PREFIX));
      await closeMorePanel(driver);
      await openZoneByName(driver, a!, 'pl3o', true);
      const found = await seekMarkers(driver, markers, 12);
      log(`pl3 zone=${a} found=${found}/3`);
      await must(driver, 'pl3_tabs_restored', found === 3, `${found}/3 ${markers.join(',')}`);
      const loads: string[] = [];
      for (const m of markers) {
        loads.push(`${m}:${await tabLoads(driver, m)}`);
      }
      log(`pl3 loads ${loads.join(' ')}`);
      await must(driver, 'pl3_pages_loaded', loads.every((x: string) => x.endsWith(':ok')), loads.join(' '));
      const winName = await currentWindowName(driver);
      await must(driver, 'pl3_window_name', winName.includes(a!), winName);
    });
  });
}
