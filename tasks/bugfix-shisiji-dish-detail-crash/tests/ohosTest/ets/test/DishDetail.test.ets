import { describe, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry, Component, Driver, ON } from '@kit.TestKit';

const BUNDLE = 'com.harmonybench.bf.shisijisheet';
// 详情弹层里才有的文字：门店营业信息行
const SHEET_ANCHOR = '鲜小馆 · 11:00 - 22:00';

// 菜品列表里的菜名（不是顶部招牌轮播里的同名标题，取纵坐标最靠下的那个）
async function dishInList(driver: Driver, name: string): Promise<Component> {
  let best: Component | null = null;
  let bestTop = -1;
  for (const c of await driver.findComponents(ON.text(name))) {
    const b = await c.getBounds();
    if (b.top > bestTop) {
      best = c;
      bestTop = b.top;
    }
  }
  expect(best !== null).assertTrue();
  return best as Component;
}

// 打开菜品详情：弹层出现、显示该菜名，且应用没有崩溃
// 测试与应用同进程：应用崩溃时本用例随之终止，aa test 报 "App died"，评分器判失败。
async function openAndCheck(driver: Driver, name: string, price: string, spec: string[]): Promise<void> {
  await (await dishInList(driver, name)).click();
  await driver.delayMs(2500);
  expect((await driver.waitForComponent(ON.text(SHEET_ANCHOR), 5000)) !== null).assertTrue();
  expect((await driver.findComponents(ON.text(name))).length >= 2).assertTrue();
  // 弹层价格行显示该菜的价格（与列表一致），防止"吞掉异常、价格显示为空或 0"的修法
  expect((await driver.findComponents(ON.text(price))).length >= 2).assertTrue();
  // 弹层显示规格选项：第一组规格的组名与默认选项（只在弹层里出现）
  for (const t of spec) {
    expect((await driver.findComponent(ON.text(t))) !== null).assertTrue();
  }
}

export default function dishDetailTest() {
  describe('BF_DishDetail', () => {
    it('FP1_open_dish_detail_twice', 0, async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      await delegator.executeShellCommand(`aa start -b ${BUNDLE} -a EntryAbility`);
      const driver = Driver.create();
      const card = await driver.waitForComponent(ON.text('餐厅点餐'), 8000);
      expect(card !== null).assertTrue();
      await card.click();
      expect((await driver.waitForComponent(ON.text('鲜小馆'), 8000)) !== null).assertTrue();
      await driver.delayMs(1500);

      await openAndCheck(driver, '过桥米线', '28', ['吃法', '配好端出']);
      // 关闭弹层后再打开另一道菜
      await driver.pressBack();
      await driver.delayMs(1500);
      expect((await driver.findComponent(ON.text(SHEET_ANCHOR))) === null).assertTrue();
      await openAndCheck(driver, '汽锅鸡', '68', ['辣度', '原汤原味']);
      await driver.delayMs(2000);
      expect((await driver.findComponent(ON.text(SHEET_ANCHOR))) !== null).assertTrue();
    });
  });
}
