import { describe, it } from '@ohos/hypium';
import { Driver } from '@kit.TestKit';
import {
  A_CREATE,
  A_LOG,
  T_HOME,
  T_PENDING,
  backTo,
  cardTexts,
  checkCreatedDetail,
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
  openLogFromHome,
  plusAtTopRight,
  plusEntry,
  rand5,
  statsEntry,
  summaryPending,
  trySaveEmpty,
  waitHomeReady
} from './Helpers';

const REASON = '最近作息稳定';

function judgmentOf(name: string): string {
  return `${name} 本周至少跑步 3 次`;
}

/**
 * FP1_create：「预测日志」右上角「＋」→「新建预测」→ 保存后列表、首页更新，冷启动后仍在。
 * 预测名称 zc<5 位随机数>a，p2 冷启动后从屏幕上找回。
 */
export default function createTest() {
  describe('NF8_Create', () => {
    it('FP1_p1_create', 0, async (done: Function) => {
      const driver = Driver.create();
      await launch(driver);
      await waitHomeReady(driver);
      const homeBefore = await homePendingCount(driver);
      const homeSumBefore = await summaryPending(driver);
      log(`home before: pending=${homeBefore} summary=${homeSumBefore}`);

      await openLogFromHome(driver);
      // #15 加「＋」后原有「统计」入口仍在
      await must(driver, 'p1_stats_entry_kept', (await statsEntry(driver)) !== null);
      const plus = await plusEntry(driver);
      await must(driver, 'p1_plus_entry', plus !== null);
      // 题面：「预测日志」页右上角的「＋」
      const pos = await plusAtTopRight(driver, plus!);
      await must(driver, 'p1_plus_top_right', pos === 'ok', pos);
      const listBefore = await summaryPending(driver);
      await must(driver, 'p1_list_pending_readable', listBefore >= 0, `pending=${listBefore}`);

      await openCreate(driver);
      // #9 预测对象、判断为空不能保存
      await trySaveEmpty(driver, listBefore);
      await must(driver, 'p1_still_on_create', await onPage(driver, A_CREATE));

      const name = `zc${rand5()}a`;
      const filled = await fillAndSave(driver, {
        target: name,
        judgment: judgmentOf(name),
        reason: REASON,
        dueToday: false
      });
      // #1 回到预测日志：列表出现新预测，待结算计数 +1
      await must(driver, 'p1_list_has_new', await listHas(driver, name), name);
      const card = await cardTexts(driver, name);
      await must(driver, 'p1_new_is_pending', card.includes(T_PENDING), card);
      const listAfter = await summaryPending(driver);
      await must(driver, 'p1_list_pending_plus1', listAfter === listBefore + 1, `before=${listBefore} after=${listAfter}`);
      // 题面：新建时填写的判断、置信度、理由、结算日都保存下来，详情页能看到
      await checkCreatedDetail(driver, 'p1', name, judgmentOf(name), REASON, filled);

      // #2 系统返回首页：待结算数与待结算卡片列表包含新预测
      await must(driver, 'p1_back_home', await backTo(driver, T_HOME));
      let homeAfter = -1;
      let sumAfter = -1;
      for (let i = 0; i < 10; i++) {
        await waitHomeReady(driver);
        homeAfter = await homePendingCount(driver);
        sumAfter = await summaryPending(driver);
        if (homeAfter === homeBefore + 1 && sumAfter === homeSumBefore + 1) {
          break;
        }
        await driver.delayMs(500);
      }
      await must(driver, 'p1_home_pending_count', homeAfter === homeBefore + 1, `before=${homeBefore} after=${homeAfter}`);
      await must(driver, 'p1_home_summary_pending', sumAfter === homeSumBefore + 1,
        `before=${homeSumBefore} after=${sumAfter}`);
      await must(driver, 'p1_home_card_listed', await homeHasCard(driver, name), name);
      done();
    });

    it('FP1_p2_restart', 0, async (done: Function) => {
      const driver = Driver.create();
      await launch(driver);
      await waitHomeReady(driver);
      // #7 冷启动后仍在
      await must(driver, 'p2_home_pending_count', (await homePendingCount(driver)) === 1);
      await openLogFromHome(driver);
      const name = await findName(driver, 'zc', /^zc\d{5}a$/);
      await must(driver, 'p2_list_has_created', name.length > 0);
      const card = await cardTexts(driver, name);
      await must(driver, 'p2_created_pending', card.includes(T_PENDING), card);
      await checkCreatedDetail(driver, 'p2', name, judgmentOf(name), REASON, { confidence: null, dueDate: null });
      await must(driver, 'p2_list_pending_1', (await summaryPending(driver)) === 1);
      await must(driver, 'p2_title', await onPage(driver, A_LOG));
      done();
    });
  });
}
