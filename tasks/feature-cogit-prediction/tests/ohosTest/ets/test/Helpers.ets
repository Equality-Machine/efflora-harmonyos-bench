import { expect } from '@ohos/hypium';
import { abilityDelegatorRegistry, Component, Driver, MatchPattern, ON, On } from '@kit.TestKit';

export const BUNDLE = 'com.harmonybench.cogit.nf8';
// verify_config.json 的 test_log_tag：失败时 verify.py 把含它的 hilog 行存到 fpoint-<id>.log
export const TAG = 'NF8Cogit';

// 题面锚点
export const A_LOG = '预测日志';          // 列表页标题（base 已有）
export const A_PLUS = '＋';               // 列表页右上角入口
export const A_CREATE = '新建预测';       // 新建页
export const A_DETAIL = '预测详情';       // 详情页标题（base 已有）
export const A_SETTLE = '结算这条预测';   // 详情页结算入口
export const A_HIT = '命中';
export const A_MISS = '未命中';
// base 已有文案
export const T_HOME = '模块入口';         // 首页
export const T_MODULE = '预测';           // 首页「预测」模块卡片标题
export const T_STATS = '统计';            // 列表页右上角原有入口
export const T_STATS_TITLE = '预测统计';
export const T_PENDING = '待结算';        // 汇总卡片标签 / 筛选
export const T_SETTLED = '已结算';        // 筛选
export const T_HOME_PENDING_SUFFIX = '条待结算';  // 首页右上角「N 条待结算」
export const T_HIT_RATE = '命中率';       // 汇总卡片命中率标签前缀（「命中率」或「命中率 · N 条」）

export interface Box {
  left: number;
  top: number;
  right: number;
  bottom: number;
}

export interface PredictionInput {
  target: string;
  judgment: string;
  reason: string;
  /** 结算日填今天（结算用的预测要已到期）；否则保留新建页的默认值，空着才填今天 */
  dueToday: boolean;
}

export function cut(txt: string, n: number): string {
  const cps = Array.from(txt);
  return cps.length <= n ? txt : cps.slice(0, n).join('');
}

export function log(msg: string): void {
  const cps = Array.from(msg);
  for (let i = 0; i < cps.length || i === 0; i += 300) {
    console.info(`${TAG} ${cps.slice(i, i + 300).join('')}`);
  }
}

export function rand5(): string {
  return String(10000 + Math.floor(Math.random() * 90000));
}

function pad2(v: number): string {
  return v < 10 ? `0${v}` : `${v}`;
}

/** 设备本地日期 YYYY-MM-DD（base 的结算日格式），offsetDays 天后。 */
export function todayStr(offsetDays: number = 0): string {
  const d = new Date(Date.now() + offsetDays * 86400000);
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
}

/** 新建页实际填进去的值；null 表示该字段不是文本输入框（实现自定，例如滑块/日期选择器），未填写。 */
export interface FilledValues {
  confidence: string | null;
  dueDate: string | null;
}

/** 新建时填写的置信度（有文本输入框时）。 */
export const FILL_CONFIDENCE = '65';
/** FP1 新建时填写的结算日：7 天后。 */
export const FILL_DUE_OFFSET = 7;

export async function boundsOf(c: Component): Promise<Box> {
  const r = await c.getBounds();
  return { left: r.left, top: r.top, right: r.right, bottom: r.bottom };
}

export async function findAll(driver: Driver, on: On): Promise<Component[]> {
  try {
    const r = await driver.findComponents(on);
    return r === null || r === undefined ? [] : r;
  } catch (e) {
    return [];
  }
}

export async function textOf(c: Component): Promise<string> {
  try {
    const t = await c.getText();
    return t === null || t === undefined ? '' : t.trim();
  } catch (e) {
    return '';
  }
}

async function hintOf(c: Component): Promise<string> {
  try {
    const t = await c.getHint();
    return t === null || t === undefined ? '' : t.trim();
  } catch (e) {
    return '';
  }
}

async function clickableOf(c: Component): Promise<boolean> {
  try {
    return await c.isClickable();
  } catch (e) {
    return false;
  }
}

/** 文字自身可点击，或落在一个较小的可点击容器内（如 base 的 NoteSaveBar：Row.onClick 包 Text）。 */
async function tappable(driver: Driver, c: Component): Promise<boolean> {
  if (await clickableOf(c)) {
    return true;
  }
  const b = await boundsOf(c);
  const cx = (b.left + b.right) / 2;
  const cy = (b.top + b.bottom) / 2;
  for (const p of await findAll(driver, ON.clickable(true))) {
    const pb = await boundsOf(p);
    // 限定容器大小，排除整页可点击的根容器
    if (cx >= pb.left && cx <= pb.right && cy >= pb.top && cy <= pb.bottom &&
      pb.bottom - pb.top <= 200 && pb.right - pb.left <= 1300) {
      return true;
    }
  }
  return false;
}

export async function screenTexts(driver: Driver): Promise<string> {
  const parts: string[] = [];
  for (const type of ['Text', 'Button', 'TextInput', 'TextArea']) {
    for (const c of await findAll(driver, ON.type(type))) {
      const t = await textOf(c);
      if (t.length === 0) {
        continue;
      }
      try {
        const b = await boundsOf(c);
        parts.push(`${type}[${cut(t, 40)}]@${b.left},${b.top}`);
      } catch (e) {
        parts.push(`${type}[${cut(t, 40)}]@?`);
      }
    }
  }
  return cut(parts.join('|'), 2500);
}

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

/** 检查点：失败时断言信息与日志里带上实际屏幕文字和 App 错误日志。 */
export async function must(driver: Driver, step: string, ok: boolean, detail: string = ''): Promise<void> {
  if (ok) {
    log(`ok ${step} ${detail}`);
    return;
  }
  const screen = await screenTexts(driver);
  log(`FAIL ${step} ${detail}`);
  log(`FAIL ${step} SCREEN=${screen}`);
  for (const l of await appErrors()) {
    log(`FAIL ${step} APPERR ${cut(l, 400)}`);
  }
  expect(`${step}:false ${detail} SCREEN=${screen}`).assertEqual(`${step}:true`);
}

/** 任意类型、文字完全等于 s 的控件。 */
export async function exact(driver: Driver, s: string): Promise<Component[]> {
  const r: Component[] = [];
  for (const c of await findAll(driver, ON.text(s))) {
    if ((await textOf(c)) === s) {
      r.push(c);
    }
  }
  return r;
}

export async function textsContaining(driver: Driver, s: string, type: string = 'Text'): Promise<Component[]> {
  const on = type.length > 0 ? ON.type(type).text(s, MatchPattern.CONTAINS) : ON.text(s, MatchPattern.CONTAINS);
  const r: Component[] = [];
  for (const c of await findAll(driver, on)) {
    if ((await textOf(c)).includes(s)) {
      r.push(c);
    }
  }
  return r;
}

export async function present(driver: Driver, s: string): Promise<boolean> {
  return (await textsContaining(driver, s, '')).length > 0;
}

export async function waitPresent(driver: Driver, s: string, ms: number): Promise<boolean> {
  for (let t = 0; t <= ms; t += 500) {
    if (await present(driver, s)) {
      return true;
    }
    await driver.delayMs(500);
  }
  return false;
}

/** 系统输入法首次使用声明、通知/权限授权弹窗：设备环境的一部分，出现就同意/允许。 */
export async function dismissSystemDialogs(driver: Driver): Promise<boolean> {
  let acted = false;
  if ((await textsContaining(driver, '小艺输入法')).length > 0) {
    const agree = await driver.findComponent(ON.type('Button').text('同意'));
    if (agree !== null) {
      log('dismiss IME first-use dialog');
      await agree.click();
      await driver.delayMs(1500);
      acted = true;
    }
  }
  for (const w of ['允许', '仅使用期间允许']) {
    const allow = await driver.findComponent(ON.type('Button').text(w));
    if (allow !== null) {
      log(`permission dialog: ${w}`);
      await allow.click();
      await driver.delayMs(1500);
      acted = true;
      break;
    }
  }
  return acted;
}

// ---------------------------------------------------------------- 页面判断与导航

export async function onHome(driver: Driver): Promise<boolean> {
  return (await exact(driver, T_HOME)).length > 0;
}

export async function onPage(driver: Driver, title: string): Promise<boolean> {
  return (await exact(driver, title)).length > 0 && !(await onHome(driver));
}

export async function launch(driver: Driver): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  await delegator.executeShellCommand(`aa start -b ${BUNDLE} -a EntryAbility`);
  await driver.delayMs(2500);
  let ok = false;
  for (let i = 0; i < 30 && !ok; i++) {
    const acted = await dismissSystemDialogs(driver);
    if (!acted && (await onHome(driver)) && (await homePendingCount(driver)) >= 0) {
      ok = true;
      break;
    }
    await driver.delayMs(1000);
  }
  await must(driver, 'launch_home', ok);
}

/** 输入法窗口是否弹出。 */
async function imeShown(driver: Driver): Promise<boolean> {
  try {
    const w = await driver.findWindow({ bundleName: 'com.huawei.hmos.inputmethod' });
    if (w === null || w === undefined) {
      return false;
    }
    const b = await w.getBounds();
    return b.bottom - b.top > 50;
  } catch (e) {
    return false;
  }
}

/** 收起软键盘（只在输入法窗口确实弹出时按返回键，避免误触页面返回）。 */
export async function hideIme(driver: Driver): Promise<void> {
  for (let i = 0; i < 2; i++) {
    if (!(await imeShown(driver))) {
      return;
    }
    log('hide IME by back');
    await driver.pressBack();
    // 收起动画期间输入法窗口仍在，等它真正消失，避免第二次返回把页面退掉
    let gone = false;
    for (let j = 0; j < 12 && !gone; j++) {
      await driver.delayMs(250);
      gone = !(await imeShown(driver));
    }
    if (gone) {
      return;
    }
  }
}

/** 按系统返回键直到出现标题 title（最多 n 次）。 */
export async function backTo(driver: Driver, title: string, n: number = 3): Promise<boolean> {
  await hideIme(driver);
  for (let i = 0; i < n; i++) {
    if (title === T_HOME ? await onHome(driver) : await onPage(driver, title)) {
      return true;
    }
    await driver.pressBack();
    await driver.delayMs(1500);
    await dismissLeaveDialog(driver);
  }
  return title === T_HOME ? await onHome(driver) : await onPage(driver, title);
}

/** 返回时若弹出「放弃编辑」一类确认框（实现自定），选离开。只在测试主动离开表单时用。 */
async function dismissLeaveDialog(driver: Driver): Promise<void> {
  for (const w of ['放弃', '离开', '不保存']) {
    for (const c of await findAll(driver, ON.type('Button').text(w, MatchPattern.CONTAINS))) {
      log(`leave dialog: ${await textOf(c)}`);
      await c.click();
      await driver.delayMs(1000);
      return;
    }
  }
}

/** 首页 →「预测」模块 → 预测日志。 */
export async function openLogFromHome(driver: Driver): Promise<void> {
  const tiles = await exact(driver, T_MODULE);
  await must(driver, 'home_prediction_tile', tiles.length > 0);
  await tiles[0].click();
  let ok = false;
  for (let i = 0; i < 12 && !ok; i++) {
    await driver.delayMs(500);
    ok = await onPage(driver, A_LOG);
  }
  await must(driver, 'open_prediction_log', ok);
  await driver.delayMs(1000);
}

// ---------------------------------------------------------------- 读数

/** 汇总卡片里「标签」正上方的数字/百分比文字（base 的首页和列表页都是「数值在上、标签在下」）。 */
async function valueAbove(driver: Driver, labelPrefix: string, exactLabel: boolean): Promise<string | null> {
  const labels: Component[] = exactLabel ? await exact(driver, labelPrefix) : await textsContaining(driver, labelPrefix);
  const texts = await findAll(driver, ON.type('Text'));
  for (const l of labels) {
    const lt = await textOf(l);
    if (!lt.startsWith(labelPrefix)) {
      continue;
    }
    const lb = await boundsOf(l);
    const lcx = (lb.left + lb.right) / 2;
    let best: string | null = null;
    let bestDy = 1e9;
    for (const c of texts) {
      const b = await boundsOf(c);
      const cx = (b.left + b.right) / 2;
      const dy = lb.top - b.bottom;
      if (dy < -5 || dy > 120 || Math.abs(cx - lcx) > 120) {
        continue;
      }
      const t = await textOf(c);
      if (!/^(\d+(\.\d+)?%?|—|-|--)$/.test(t)) {
        continue;
      }
      if (dy < bestDy) {
        bestDy = dy;
        best = t;
      }
    }
    if (best !== null) {
      return best;
    }
  }
  return null;
}

/** 汇总卡片「待结算」上方的数字；读不到返回 -1。 */
export async function summaryPending(driver: Driver): Promise<number> {
  const v = await valueAbove(driver, T_PENDING, true);
  if (v === null || !/^\d+$/.test(v)) {
    return -1;
  }
  return Number(v);
}

/** 汇总卡片命中率：返回「<数值>|<标签>」，例如「50%|命中率 · 2 条」。 */
export async function summaryHitRate(driver: Driver): Promise<string> {
  const labels = await textsContaining(driver, T_HIT_RATE);
  let label = '';
  for (const l of labels) {
    const t = await textOf(l);
    if (t.startsWith(T_HIT_RATE) && t.length <= 12) {
      label = t;
      break;
    }
  }
  const v = await valueAbove(driver, T_HIT_RATE, false);
  return `${v ?? '?'}|${label}`;
}

/** 首页右上角「N 条待结算」的 N；读不到返回 -1。 */
export async function homePendingCount(driver: Driver): Promise<number> {
  for (const c of await textsContaining(driver, T_HOME_PENDING_SUFFIX)) {
    const m = (await textOf(c)).match(/^(\d+)\s*条待结算$/);
    if (m !== null) {
      return Number(m[1]);
    }
  }
  return -1;
}

/** 首页数据是否处于加载完毕状态（首页 refresh 时整块显示加载中）。 */
export async function waitHomeReady(driver: Driver): Promise<void> {
  for (let i = 0; i < 16; i++) {
    if ((await onHome(driver)) && (await summaryPending(driver)) >= 0) {
      return;
    }
    await driver.delayMs(500);
  }
}

/** 首页滚动区里是否有文字等于 name 的控件（「今日待结算」卡片列表在首页下方，需要滚动）。滚完回到顶部。 */
export async function homeHasCard(driver: Driver, name: string): Promise<boolean> {
  let found = (await exact(driver, name)).length > 0;
  const scroll = await driver.findComponent(ON.type('Scroll'));
  if (!found && scroll !== null) {
    try {
      found = (await scroll.scrollSearch(ON.text(name))) !== null;
    } catch (e) {
      found = false;
    }
  }
  if (scroll !== null) {
    try {
      await scroll.scrollToTop();
    } catch (e) {
    }
    await driver.delayMs(800);
  }
  return found;
}

// ---------------------------------------------------------------- 列表页

/** 列表页上文字等于 name 的卡片标题是否可见。 */
export async function listHas(driver: Driver, name: string): Promise<boolean> {
  if ((await exact(driver, name)).length > 0) {
    return true;
  }
  const list = await driver.findComponent(ON.type('List'));
  if (list === null) {
    return false;
  }
  try {
    const r = (await list.scrollSearch(ON.text(name))) !== null;
    await list.scrollToTop();
    await driver.delayMs(500);
    return r;
  } catch (e) {
    return false;
  }
}

/** 列表卡片：name 所在卡片的标签文字（卡片纵向范围内的所有文字，用 | 连接）。 */
export async function cardTexts(driver: Driver, name: string): Promise<string> {
  const titles = await exact(driver, name);
  if (titles.length === 0) {
    return '';
  }
  const tb = await boundsOf(titles[0]);
  const parts: string[] = [];
  for (const c of await findAll(driver, ON.type('Text'))) {
    const b = await boundsOf(c);
    const cy = (b.top + b.bottom) / 2;
    if (cy >= tb.top - 80 && cy <= tb.bottom + 220) {
      const t = await textOf(c);
      if (t.length > 0) {
        parts.push(t);
      }
    }
  }
  return parts.join('|');
}

/** 列表页筛选：点可点击的、文字等于 label 的筛选项。 */
export async function selectFilter(driver: Driver, label: string): Promise<void> {
  let chip: Component | null = null;
  for (const c of await exact(driver, label)) {
    if (await clickableOf(c)) {
      chip = c;
      break;
    }
  }
  await must(driver, `filter_chip ${label}`, chip !== null);
  await chip!.click();
  await driver.delayMs(1800);
}

/** 预测日志标题栏里的控件：中心纵坐标落在标题行内、在标题右侧。 */
async function titleBarItems(driver: Driver): Promise<Component[]> {
  const titles = await exact(driver, A_LOG);
  if (titles.length === 0) {
    return [];
  }
  const tb = await boundsOf(titles[0]);
  const r: Component[] = [];
  for (const c of await findAll(driver, ON.clickable(true))) {
    const b = await boundsOf(c);
    const cy = (b.top + b.bottom) / 2;
    if (cy >= tb.top - 60 && cy <= tb.bottom + 60 && b.left >= tb.right - 5 && b.right - b.left < 400) {
      r.push(c);
    }
  }
  return r;
}

/** 预测日志右上角的「统计」入口仍在（标题栏中文字为「统计」的控件）。 */
export async function statsEntry(driver: Driver): Promise<Component | null> {
  for (const c of await exact(driver, T_STATS)) {
    return c;
  }
  return null;
}

/** 预测日志右上角的「＋」入口：文字为「＋」/「+」的控件；没有文字时取标题栏里最靠右、不是「统计」的可点击控件。 */
export async function plusEntry(driver: Driver): Promise<Component | null> {
  for (const s of [A_PLUS, '+']) {
    const cs = await exact(driver, s);
    if (cs.length > 0) {
      return cs[0];
    }
  }
  let best: Component | null = null;
  let bestRight = -1;
  for (const c of await titleBarItems(driver)) {
    const t = await textOf(c);
    if (t.includes(T_STATS)) {
      continue;
    }
    const b = await boundsOf(c);
    if (b.right > bestRight) {
      bestRight = b.right;
      best = c;
    }
  }
  return best;
}

export async function openDetailFromList(driver: Driver, name: string): Promise<void> {
  const ok = await listHas(driver, name);
  await must(driver, `list_has ${name}`, ok);
  const t = await exact(driver, name);
  await t[0].click();
  let shown = false;
  for (let i = 0; i < 12 && !shown; i++) {
    await driver.delayMs(500);
    shown = (await onPage(driver, A_DETAIL)) && (await exact(driver, name)).length > 0;
  }
  await must(driver, `open_detail ${name}`, shown);
  await driver.delayMs(1000);
}

// ---------------------------------------------------------------- 表单

interface Field {
  c: Component;
  b: Box;
  type: string;
  hint: string;
  used: boolean;
}

async function formInputs(driver: Driver): Promise<Field[]> {
  const r: Field[] = [];
  for (const type of ['TextInput', 'TextArea']) {
    for (const c of await findAll(driver, ON.type(type))) {
      r.push({ c: c, b: await boundsOf(c), type: type, hint: await hintOf(c), used: false });
    }
  }
  r.sort((x: Field, y: Field) => x.b.top - y.b.top);
  return r;
}

function normLabel(t: string): string {
  return t.replace(/[*＊:：\s]/g, '').replace(/[（(][^）)]*[）)]/g, '');
}

/** 标签文字匹配 re 的短文字（字段标签，不是说明文字）。 */
async function labelsMatching(driver: Driver, re: RegExp): Promise<Box[]> {
  const r: Box[] = [];
  for (const c of await findAll(driver, ON.type('Text'))) {
    const t = normLabel(await textOf(c));
    if (t.length > 0 && t.length <= 6 && re.test(t) && t !== A_CREATE) {
      r.push(await boundsOf(c));
    }
  }
  return r;
}

/**
 * 标签对应的输入框：同一行在右侧的优先（标签在左、输入框在右的布局）；同一行没有，再取下方 300px 以内最近的
 * （标签在上、输入框在下的布局）。
 */
async function inputForLabel(driver: Driver, fields: Field[], re: RegExp): Promise<Field | null> {
  let best: Field | null = null;
  let bestD = 1e9;
  for (const lb of await labelsMatching(driver, re)) {
    const lcy = (lb.top + lb.bottom) / 2;
    for (const f of fields) {
      if (f.used) {
        continue;
      }
      let d = 1e9;
      if (lcy >= f.b.top - 10 && lcy <= f.b.bottom + 10 && f.b.left >= lb.right - 10) {
        d = f.b.left - lb.right;
      } else if (f.b.top >= lb.top && f.b.top - lb.bottom <= 300) {
        d = 100000 + (f.b.top - lb.bottom) + Math.abs(f.b.left - lb.left) / 4;
      }
      if (d < bestD) {
        bestD = d;
        best = f;
      }
    }
  }
  return best;
}

async function typeInto(driver: Driver, f: Field, text: string): Promise<void> {
  await f.c.click();
  await driver.delayMs(600);
  await dismissSystemDialogs(driver);
  try {
    await f.c.clearText();
  } catch (e) {
  }
  await f.c.inputText(text);
  await driver.delayMs(600);
  await hideIme(driver);
}

const RE_TARGET = /对象/;
const RE_JUDGMENT = /^判断|判断$/;
const RE_CONFIDENCE = /置信/;
const RE_REASON = /理由/;
const RE_DATE = /结算日|到期|日期/;

/** 新建页的保存按钮：可点击、文字含保存一类词（实现自定），排除标题。 */
async function saveButton(driver: Driver): Promise<Component | null> {
  for (const w of ['保存', '落盘', '提交', '创建', '确定', '完成', '添加']) {
    for (const type of ['Button', 'Text']) {
      for (const c of await findAll(driver, ON.type(type).text(w, MatchPattern.CONTAINS))) {
        const t = await textOf(c);
        if (t === A_CREATE || Array.from(t).length > 8) {
          continue;
        }
        if (type === 'Button' || (await tappable(driver, c))) {
          return c;
        }
      }
    }
  }
  return null;
}

async function dismissInfoDialog(driver: Driver): Promise<void> {
  for (const w of ['知道了', '我知道了', '好的', '确定']) {
    for (const c of await findAll(driver, ON.type('Button').text(w))) {
      log(`info dialog: ${w}`);
      await c.click();
      await driver.delayMs(800);
      return;
    }
  }
}

/** 在预测日志页点「＋」打开新建页。 */
export async function openCreate(driver: Driver): Promise<void> {
  const plus = await plusEntry(driver);
  await must(driver, 'plus_entry', plus !== null);
  await plus!.click();
  let ok = false;
  for (let i = 0; i < 12 && !ok; i++) {
    await driver.delayMs(500);
    ok = await onPage(driver, A_CREATE);
  }
  await must(driver, 'open_create_page', ok);
  await driver.delayMs(1000);
}

/** 空表单点保存：不能产生新预测（仍在新建页，或回到列表时待结算数不变）。返回时仍停在新建页。 */
export async function trySaveEmpty(driver: Driver, pendingBefore: number): Promise<void> {
  const save = await saveButton(driver);
  await must(driver, 'create_save_button', save !== null);
  await save!.click();
  await driver.delayMs(1800);
  await dismissInfoDialog(driver);
  if (await onPage(driver, A_CREATE)) {
    log('ok empty_save_stays_on_create');
    return;
  }
  // 实现选择了离开新建页：此时不能多出一条预测
  await backTo(driver, A_LOG);
  const now = await summaryPending(driver);
  await must(driver, 'empty_save_no_new_prediction', now === pendingBefore, `before=${pendingBefore} now=${now}`);
  await openCreate(driver);
}

/** 填写新建页并保存，回到预测日志。 */
export async function fillAndSave(driver: Driver, p: PredictionInput): Promise<FilledValues> {
  const filled: FilledValues = { confidence: null, dueDate: null };
  const fields = await formInputs(driver);
  const target = await inputForLabel(driver, fields, RE_TARGET);
  await must(driver, 'create_target_input', target !== null, `inputs=${fields.length}`);
  target!.used = true;
  await typeInto(driver, target!, p.target);

  const judgment = await inputForLabel(driver, fields, RE_JUDGMENT);
  await must(driver, 'create_judgment_input', judgment !== null);
  judgment!.used = true;
  await typeInto(driver, judgment!, p.judgment);

  const conf = await inputForLabel(driver, fields, RE_CONFIDENCE);
  if (conf !== null) {
    conf.used = true;
    await typeInto(driver, conf, FILL_CONFIDENCE);
    filled.confidence = FILL_CONFIDENCE;
  } else {
    log('no confidence text input; keep implementation default');
  }

  const reason = await inputForLabel(driver, fields, RE_REASON);
  if (reason !== null) {
    reason.used = true;
    await typeInto(driver, reason, p.reason);
  }

  const date = await inputForLabel(driver, fields, RE_DATE);
  if (date !== null) {
    date.used = true;
    const v = await textOf(date.c);
    const due = todayStr(p.dueToday ? 0 : FILL_DUE_OFFSET);
    await typeInto(driver, date, due);
    filled.dueDate = due;
    log(`date field before=${v} filled=${due}`);
  } else {
    log('no date text input; keep implementation default');
  }

  const save = await saveButton(driver);
  await must(driver, 'create_save_button', save !== null);
  await save!.click();
  let left = false;
  for (let i = 0; i < 16 && !left; i++) {
    await driver.delayMs(500);
    left = !(await onPage(driver, A_CREATE));
  }
  await must(driver, `create_saved ${p.target}`, left);
  await driver.delayMs(1000);
  // 保存后可能停在新预测的详情页（实现自定）：回到预测日志
  await must(driver, `create_back_to_log ${p.target}`, await backTo(driver, A_LOG));
  await driver.delayMs(1000);
  return filled;
}

/** 当前页面全部文字（不截断），用于核对详情页内容。 */
async function allTexts(driver: Driver): Promise<string[]> {
  const r: string[] = [];
  for (const c of await findAll(driver, ON.type('Text'))) {
    const t = await textOf(c);
    if (t.length > 0) {
      r.push(t);
    }
  }
  return r;
}

/** 日期在界面上的几种写法：2026-11-06 / 2026/11/06 / 2026年11月6日 / 11月6日 / 11-06。 */
function dateShown(texts: string[], ymd: string): boolean {
  const m = ymd.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (m === null) {
    return false;
  }
  const y = Number(m[1]);
  const mo = Number(m[2]);
  const d = Number(m[3]);
  for (const t of texts) {
    const re = new RegExp('(?:(\\d{4})\\s*[-/.年]\\s*)?(\\d{1,2})\\s*[-/.月]\\s*(\\d{1,2})', 'g');
    let g = re.exec(t);
    while (g !== null) {
      const gy = g[1];
      if ((gy === undefined || gy === null || gy.length === 0 || Number(gy) === y) &&
        Number(g[2]) === mo && Number(g[3]) === d) {
        return true;
      }
      g = re.exec(t);
    }
  }
  return false;
}

/** 置信度数值单独出现（如「65%」「65 %」「置信度 65%」），不是更长数字的一部分。 */
function confidenceShown(texts: string[], v: string): boolean {
  const re = new RegExp(`(^|[^\\d])${v}(\\s*%|[^\\d]|$)`);
  return texts.some((t: string) => re.test(t));
}

/**
 * 新建预测的详情页显示新建时填写的内容（题面：预测对象、判断、置信度、理由、结算日）。
 * 置信度 / 结算日只在新建页是文本输入框、测试实际填写了时核对。
 */
export async function checkCreatedDetail(driver: Driver, step: string, name: string, judgment: string,
  reason: string, filled: FilledValues): Promise<void> {
  await openDetailFromList(driver, name);
  let texts = await allTexts(driver);
  const need = (ts: string[]): boolean => ts.some((t: string) => t.includes(judgment)) &&
    ts.some((t: string) => t.includes(reason));
  if (!need(texts)) {
    const scroll = await driver.findComponent(ON.type('Scroll'));
    if (scroll !== null) {
      await scroll.scrollToBottom();
      await driver.delayMs(800);
      texts = texts.concat(await allTexts(driver));
      await scroll.scrollToTop();
      await driver.delayMs(500);
    }
  }
  const dump = cut(texts.join('|'), 600);
  await must(driver, `${step}_detail_judgment`, texts.some((t: string) => t.includes(judgment)), dump);
  await must(driver, `${step}_detail_reason`, texts.some((t: string) => t.includes(reason)), dump);
  if (filled.confidence !== null) {
    await must(driver, `${step}_detail_confidence`, confidenceShown(texts, filled.confidence), dump);
  }
  if (filled.dueDate !== null) {
    await must(driver, `${step}_detail_due_date`, dateShown(texts, filled.dueDate), dump);
  }
  log(`${step} detail checked conf=${filled.confidence} due=${filled.dueDate}`);
  await must(driver, `${step}_detail_back_to_log`, await backTo(driver, A_LOG));
  await driver.delayMs(800);
}

/** 「＋」在页面右上角：与「预测日志」标题同一行（标题栏），且在屏幕右半边。 */
export async function plusAtTopRight(driver: Driver, plus: Component): Promise<string> {
  const titles = await exact(driver, A_LOG);
  if (titles.length === 0) {
    return 'no title';
  }
  const tb = await boundsOf(titles[0]);
  const pb = await boundsOf(plus);
  const cy = (pb.top + pb.bottom) / 2;
  const cx = (pb.left + pb.right) / 2;
  const w = (await driver.getDisplaySize()).x;
  const rowOk = cy >= tb.top - 80 && cy <= tb.bottom + 80;
  const rightOk = cx > w / 2;
  return rowOk && rightOk ? 'ok' : `title=${tb.top}-${tb.bottom} plus=${pb.left},${pb.top},${pb.right},${pb.bottom} w=${w}`;
}

// ---------------------------------------------------------------- 结算

async function settleInput(driver: Driver): Promise<Field | null> {
  const fields = await formInputs(driver);
  if (fields.length === 0) {
    return null;
  }
  const byLabel = await inputForLabel(driver, fields, /实际|结果/);
  if (byLabel !== null) {
    return byLabel;
  }
  for (const f of fields) {
    if (/实际|结果|发生/.test(f.hint)) {
      return f;
    }
  }
  return fields[0];
}

/** 命中 / 未命中的选择控件：文字完全相等且可点击（或是按钮），优先在输入框下方的。 */
async function choiceControl(driver: Driver, label: string, below: number): Promise<Component | null> {
  let fallback: Component | null = null;
  for (const c of await exact(driver, label)) {
    const ty = await c.getType();
    if (!(await clickableOf(c)) && ty !== 'Button' && ty !== 'Radio') {
      continue;
    }
    const b = await boundsOf(c);
    if (b.top >= below) {
      return c;
    }
    if (fallback === null) {
      fallback = c;
    }
  }
  if (fallback !== null) {
    return fallback;
  }
  // 单选框 + 文字标签：取文字左侧同一行的 Radio/Checkbox
  for (const l of await exact(driver, label)) {
    const lb = await boundsOf(l);
    for (const type of ['Radio', 'Checkbox', 'Toggle']) {
      for (const r of await findAll(driver, ON.type(type))) {
        const rb = await boundsOf(r);
        const rcy = (rb.top + rb.bottom) / 2;
        if (rcy >= lb.top - 20 && rcy <= lb.bottom + 20 && Math.abs(rb.right - lb.left) < 120) {
          return r;
        }
      }
    }
  }
  return null;
}

/** 结算表单的提交控件：可点击、文字含完成/确认一类词，排除结算入口本身。 */
async function submitControl(driver: Driver): Promise<Component | null> {
  for (const w of ['完成结算', '确认结算', '提交结算', '保存结算', '完成', '确认', '提交', '保存', '确定', '结算']) {
    for (const type of ['Button', 'Text']) {
      for (const c of await findAll(driver, ON.type(type).text(w, MatchPattern.CONTAINS))) {
        const t = await textOf(c);
        if (t === A_SETTLE || t === T_SETTLED || Array.from(t).length > 8) {
          continue;
        }
        if (type === 'Button' || (await tappable(driver, c))) {
          return c;
        }
      }
    }
  }
  return null;
}

/** 结算表单是否还在（有输入框且有命中/未命中选择）。 */
async function settleFormShown(driver: Driver): Promise<boolean> {
  return (await formInputs(driver)).length > 0 && (await exact(driver, A_MISS)).length > 0;
}

/**
 * 在当前「预测详情」页结算：点「结算这条预测」→ 填实际结果 → 选命中/未命中 → 完成。
 * 结束时停在结算完成后应用自己显示的页面（不主动导航）。
 */
export async function settleHere(driver: Driver, actual: string, hit: boolean): Promise<void> {
  const entry = await exact(driver, A_SETTLE);
  await must(driver, 'settle_entry', entry.length > 0);
  await entry[0].click();
  let form = false;
  for (let i = 0; i < 12 && !form; i++) {
    await driver.delayMs(500);
    form = (await formInputs(driver)).length > 0;
  }
  await must(driver, 'settle_form_input', form);
  const input = await settleInput(driver);
  await must(driver, 'settle_actual_input', input !== null);
  await typeInto(driver, input!, actual);
  const ib = await boundsOf(input!.c);
  const choice = await choiceControl(driver, hit ? A_HIT : A_MISS, ib.bottom - 5);
  await must(driver, `settle_choice ${hit ? A_HIT : A_MISS}`, choice !== null);
  await choice!.click();
  await driver.delayMs(800);
  // 选择命中/未命中即完成结算的实现（题面「选择命中或未命中后完成结算」）：表单已关闭就不再找提交按钮
  let oneTap = false;
  for (let i = 0; i < 4 && !oneTap; i++) {
    oneTap = !(await settleFormShown(driver));
    if (!oneTap) {
      await driver.delayMs(500);
    }
  }
  log(`settle one-tap=${oneTap}`);
  if (!oneTap) {
    const submit = await submitControl(driver);
    await must(driver, 'settle_submit', submit !== null);
    await submit!.click();
    await driver.delayMs(1500);
  }
  // 二次确认框（实现自定）：点确认一类按钮
  for (let i = 0; i < 2; i++) {
    let acted = false;
    for (const w of ['确认', '确定', '完成', '结算']) {
      for (const c of await findAll(driver, ON.type('Button').text(w, MatchPattern.CONTAINS))) {
        log(`settle confirm dialog: ${await textOf(c)}`);
        await c.click();
        await driver.delayMs(1500);
        acted = true;
        break;
      }
      if (acted) {
        break;
      }
    }
    if (!acted) {
      break;
    }
  }
  let done = false;
  for (let i = 0; i < 16 && !done; i++) {
    done = !(await settleFormShown(driver));
    if (!done) {
      await driver.delayMs(500);
    }
  }
  log(`settle form closed=${done}`);
  await driver.delayMs(1500);
}

/** 详情页信息卡里标签 label 同一行右侧最近的文字（base 的「状态 / 命中 / 实际结果」行）。 */
export async function rowValue(driver: Driver, label: string, statusTop: number): Promise<string> {
  const texts = await findAll(driver, ON.type('Text'));
  const values: string[] = [];
  for (const l of await exact(driver, label)) {
    const lb = await boundsOf(l);
    if (statusTop >= 0 && lb.top < statusTop - 5) {
      continue;  // 顶部状态标签行在信息卡上方，不是信息行
    }
    const lcy = (lb.top + lb.bottom) / 2;
    let best = '';
    let bestDx = 1e9;
    for (const c of texts) {
      const b = await boundsOf(c);
      const cy = (b.top + b.bottom) / 2;
      if (Math.abs(cy - lcy) > (lb.bottom - lb.top) && !(lcy >= b.top && lcy <= b.bottom)) {
        continue;
      }
      if (b.left < lb.right - 2) {
        continue;
      }
      const dx = b.left - lb.right;
      if (dx < bestDx) {
        bestDx = dx;
        best = await textOf(c);
      }
    }
    if (best.length > 0) {
      values.push(best);
    }
  }
  return values.join('/');
}

/** 「状态」行的纵坐标（信息卡上沿的参照）；没有返回 -1。 */
export async function statusRowTop(driver: Driver): Promise<number> {
  const s = await exact(driver, '状态');
  if (s.length === 0) {
    return -1;
  }
  return (await boundsOf(s[0])).top;
}

/** 当前详情页的状态 / 命中 / 实际结果三行。 */
export async function detailRows(driver: Driver): Promise<string> {
  const top = await statusRowTop(driver);
  const st = await rowValue(driver, '状态', -1);
  const hit = await rowValue(driver, A_HIT, top);
  const act = await rowValue(driver, '实际结果', -1);
  return `状态=${st};命中=${hit};实际结果=${act}`;
}

/** 三行显示了结算后的新值：状态不是待结算、命中行与选择一致、实际结果行是填写的内容。 */
export function rowsSettled(rows: string, actual: string, hit: boolean): boolean {
  const m = rows.match(/^状态=(.*);命中=(.*);实际结果=(.*)$/);
  if (m === null) {
    return false;
  }
  const st = m[1];
  const hv = m[2];
  const av = m[3];
  const stOk = st.length > 0 && !st.includes(T_PENDING) && !st.includes('未结算');
  const hitOk = hit ? (hv.includes(A_HIT) && !hv.includes(A_MISS)) : hv.includes(A_MISS);
  return stOk && hitOk && av.includes(actual);
}

/** 结算后（不离开详情页）等待三行刷新；返回最后一次读到的值。 */
export async function waitRowsSettled(driver: Driver, actual: string, hit: boolean, ms: number): Promise<string> {
  let rows = '';
  for (let t = 0; t <= ms; t += 500) {
    rows = await detailRows(driver);
    if (rowsSettled(rows, actual, hit)) {
      return rows;
    }
    await driver.delayMs(500);
  }
  return rows;
}

/** 屏幕上第一个文字完全匹配 re 的 Text（用于冷启动后找回上一阶段的随机名称）。 */
export async function findName(driver: Driver, prefix: string, re: RegExp): Promise<string> {
  for (const c of await textsContaining(driver, prefix)) {
    const t = await textOf(c);
    if (re.test(t)) {
      return t;
    }
  }
  return '';
}

/** 回到当前预测的详情页：结算后实现可能停在详情页（期望），也可能离开了，离开了就从列表重新打开。 */
export async function ensureDetail(driver: Driver, name: string): Promise<boolean> {
  if ((await onPage(driver, A_DETAIL)) && (await exact(driver, name)).length > 0) {
    return true;
  }
  log(`not on detail after settle; navigate back to ${name}`);
  if (await backTo(driver, A_DETAIL, 1)) {
    return (await exact(driver, name)).length > 0;
  }
  if (await backTo(driver, A_LOG, 2)) {
    await openDetailFromList(driver, name);
    return true;
  }
  return false;
}

/** 在第一个 type 类型的输入框里输入文字并收起键盘。 */
export async function typeIntoFirst(driver: Driver, type: string, text: string): Promise<boolean> {
  const cs = await findAll(driver, ON.type(type));
  if (cs.length === 0) {
    return false;
  }
  await cs[0].click();
  await driver.delayMs(600);
  await dismissSystemDialogs(driver);
  await cs[0].inputText(text);
  await driver.delayMs(600);
  await hideIme(driver);
  return true;
}
