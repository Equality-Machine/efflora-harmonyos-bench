import { describe, it } from '@ohos/hypium';
import { Driver } from '@kit.TestKit';
import {
  A_HIT,
  A_LOG,
  A_MISS,
  A_SETTLE,
  T_HOME,
  T_PENDING,
  T_SETTLED,
  T_STATS_TITLE,
  backTo,
  cardTexts,
  detailRows,
  ensureDetail,
  exact,
  fillAndSave,
  findName,
  homeHasCard,
  homePendingCount,
  launch,
  listHas,
  log,
  must,
  onPage,
  openCreate,
  openDetailFromList,
  openLogFromHome,
  present,
  rand5,
  rowsSettled,
  selectFilter,
  settleHere,
  statsEntry,
  summaryHitRate,
  summaryPending,
  waitHomeReady,
  waitRowsSettled
} from './Helpers';

/** 新建两条结算日为今天（已到期）的待结算预测 <prefix>Ra / <prefix>Rb。 */
async function setupTwo(driver: Driver, prefix: string): Promise<void> {
  await launch(driver);
  await openLogFromHome(driver);
  const r = rand5();
  for (const s of ['a', 'b']) {
    const name = `${prefix}${r}${s}`;
    await openCreate(driver);
    await fillAndSave(driver, {
      target: name,
      judgment: `${name} 本周睡眠不少于 7 小时`,
      reason: '用于结算',
      dueToday: true
    });
    await must(driver, `setup_listed ${name}`, await listHas(driver, name));
    log(`setup card ${name}: ${await cardTexts(driver, name)}`);
  }
  await must(driver, 'setup_pending_2', (await summaryPending(driver)) === 2);
}

async function nameOf(driver: Driver, prefix: string, suffix: string): Promise<string> {
  const name = await findName(driver, prefix, new RegExp(`^${prefix}\\d{5}${suffix}$`));
  await must(driver, `find_name ${prefix}*${suffix}`, name.length > 0);
  return name;
}

function actualOf(name: string): string {
  return `${name}实际`;
}

/** 首页读数稳定后返回「N 条待结算|命中率数值|命中率标签」。 */
async function homeNumbers(driver: Driver, want: string): Promise<string> {
  let got = '';
  for (let i = 0; i < 10; i++) {
    await waitHomeReady(driver);
    got = `${await homePendingCount(driver)}|${await summaryHitRate(driver)}`;
    if (got === want) {
      return got;
    }
    await driver.delayMs(500);
  }
  return got;
}

export default function settleTest() {
  /**
   * FP2_settle_detail：结算后不离开「预测详情」页，状态 / 命中 / 实际结果三行显示新值（#3），
   * 结算入口消失（#4）；冷启动后仍是结算后的值（#7）。
   */
  describe('NF8_SettleDetail', () => {
    it('FP2_p1_setup', 0, async (done: Function) => {
      const driver = Driver.create();
      await setupTwo(driver, 'zd');
      done();
    });

    it('FP2_p2_settle_detail', 0, async (done: Function) => {
      const driver = Driver.create();
      await launch(driver);
      await openLogFromHome(driver);
      const a = await nameOf(driver, 'zd', 'a');
      const b = await nameOf(driver, 'zd', 'b');

      await openDetailFromList(driver, a);
      const before = await detailRows(driver);
      log(`rows before settle: ${before}`);
      await settleHere(driver, actualOf(a), true);
      await must(driver, 'p2_on_detail_after_settle_a', await ensureDetail(driver, a));
      const rowsA = await waitRowsSettled(driver, actualOf(a), true, 4000);
      await must(driver, 'p2_detail_rows_refreshed_hit', rowsSettled(rowsA, actualOf(a), true), rowsA);
      await must(driver, 'p2_settle_entry_gone_a', (await exact(driver, A_SETTLE)).length === 0);

      await must(driver, 'p2_back_to_log', await backTo(driver, A_LOG));
      await openDetailFromList(driver, b);
      await settleHere(driver, actualOf(b), false);
      await must(driver, 'p2_on_detail_after_settle_b', await ensureDetail(driver, b));
      const rowsB = await waitRowsSettled(driver, actualOf(b), false, 4000);
      await must(driver, 'p2_detail_rows_refreshed_miss', rowsSettled(rowsB, actualOf(b), false), rowsB);
      await must(driver, 'p2_settle_entry_gone_b', (await exact(driver, A_SETTLE)).length === 0);
      done();
    });

    it('FP2_p3_restart', 0, async (done: Function) => {
      const driver = Driver.create();
      await launch(driver);
      await openLogFromHome(driver);
      const a = await nameOf(driver, 'zd', 'a');
      const b = await nameOf(driver, 'zd', 'b');
      await openDetailFromList(driver, a);
      const rowsA = await detailRows(driver);
      await must(driver, 'p3_rows_a_kept', rowsSettled(rowsA, actualOf(a), true), rowsA);
      await must(driver, 'p3_no_settle_entry_a', (await exact(driver, A_SETTLE)).length === 0);
      await must(driver, 'p3_back_to_log', await backTo(driver, A_LOG));
      await openDetailFromList(driver, b);
      const rowsB = await detailRows(driver);
      await must(driver, 'p3_rows_b_kept', rowsSettled(rowsB, actualOf(b), false), rowsB);
      await must(driver, 'p3_no_settle_entry_b', (await exact(driver, A_SETTLE)).length === 0);
      done();
    });
  });

  /**
   * FP3_settle_effects：结算后列表筛选（#6）、首页待结算数 / 命中率 / 待结算卡片（#2）、
   * 命中率分母计入未命中（#8）、统计页（#5）、冷启动保留（#7）。不检查详情页信息行。
   */
  describe('NF8_SettleEffects', () => {
    it('FP3_p1_setup', 0, async (done: Function) => {
      const driver = Driver.create();
      await setupTwo(driver, 'ze');
      done();
    });

    it('FP3_p2_settle_effects', 0, async (done: Function) => {
      const driver = Driver.create();
      await launch(driver);
      await must(driver, 'p2_home_pending_2_at_start', (await homeNumbers(driver, '2|—|命中率')) === '2|—|命中率');
      await openLogFromHome(driver);
      const a = await nameOf(driver, 'ze', 'a');
      const b = await nameOf(driver, 'ze', 'b');

      // 结算 A 为命中
      await openDetailFromList(driver, a);
      await settleHere(driver, actualOf(a), true);
      await must(driver, 'p2_back_to_log_a', await backTo(driver, A_LOG));
      await driver.delayMs(1000);
      // #1/#6 列表计数与筛选
      await must(driver, 'p2_list_pending_1', (await summaryPending(driver)) === 1);
      await selectFilter(driver, T_SETTLED);
      await must(driver, 'p2_settled_filter_has_a', await listHas(driver, a));
      await must(driver, 'p2_settled_filter_no_b', !(await listHas(driver, b)));
      // 不在这里读卡片标签：base 列表 ForEach 以 id 为 key，同一会话里刷新后卡片可能沿用旧 @Param（base 既有缺陷，
      // 是否显示取决于刷新时序）。卡片标签放到 p3 冷启动后检查。
      await selectFilter(driver, T_PENDING);
      await must(driver, 'p2_pending_filter_no_a', !(await listHas(driver, a)));
      await must(driver, 'p2_pending_filter_has_b', await listHas(driver, b));
      await selectFilter(driver, '全部');

      // #2 系统返回首页：待结算数、命中率、待结算卡片随之更新
      await must(driver, 'p2_back_home_a', await backTo(driver, T_HOME));
      const h1 = await homeNumbers(driver, '1|100%|命中率 · 1 条');
      await must(driver, 'p2_home_after_hit', h1 === '1|100%|命中率 · 1 条', h1);
      await must(driver, 'p2_home_card_a_gone', !(await homeHasCard(driver, a)));
      await must(driver, 'p2_home_card_b_kept', await homeHasCard(driver, b));

      // 结算 B 为未命中：#8 命中率分母计入未命中
      await openLogFromHome(driver);
      await openDetailFromList(driver, b);
      await settleHere(driver, actualOf(b), false);
      await must(driver, 'p2_back_home_b', await backTo(driver, T_HOME, 4));
      const h2 = await homeNumbers(driver, '0|50%|命中率 · 2 条');
      await must(driver, 'p2_home_after_miss', h2 === '0|50%|命中率 · 2 条', h2);
      await must(driver, 'p2_home_card_b_gone', !(await homeHasCard(driver, b)));

      // #5 统计页反映新结算（base 统计页文案）
      await openLogFromHome(driver);
      const listRate = await summaryHitRate(driver);
      await must(driver, 'p2_list_hit_rate', listRate === '50%|命中率 · 2 条', listRate);
      const stats = await statsEntry(driver);
      await must(driver, 'p2_stats_entry', stats !== null);
      await stats!.click();
      let shown = false;
      for (let i = 0; i < 12 && !shown; i++) {
        await driver.delayMs(500);
        shown = await onPage(driver, T_STATS_TITLE);
      }
      await must(driver, 'p2_stats_page', shown);
      await driver.delayMs(1500);
      await must(driver, 'p2_stats_settled_2', await present(driver, '已结算 2 条'));
      await must(driver, 'p2_stats_hit_miss', await present(driver, '命中 1 · 未命中 1'));
      done();
    });

    it('FP3_p3_restart', 0, async (done: Function) => {
      const driver = Driver.create();
      await launch(driver);
      const h = await homeNumbers(driver, '0|50%|命中率 · 2 条');
      await must(driver, 'p3_home_numbers', h === '0|50%|命中率 · 2 条', h);
      await openLogFromHome(driver);
      const a = await nameOf(driver, 'ze', 'a');
      const b = await nameOf(driver, 'ze', 'b');
      const cardA = await cardTexts(driver, a);
      const cardB = await cardTexts(driver, b);
      await must(driver, 'p3_card_a_hit', cardA.includes(A_HIT) && !cardA.includes(A_MISS), cardA);
      await must(driver, 'p3_card_b_miss', cardB.includes(A_MISS), cardB);
      await must(driver, 'p3_list_pending_0', (await summaryPending(driver)) === 0);
      await selectFilter(driver, T_SETTLED);
      await must(driver, 'p3_settled_has_both', (await listHas(driver, a)) && (await listHas(driver, b)));
      done();
    });
  });
}
