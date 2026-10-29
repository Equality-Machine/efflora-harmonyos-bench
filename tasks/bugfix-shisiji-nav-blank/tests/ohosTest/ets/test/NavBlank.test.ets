import { describe, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit';

const BUNDLE = 'com.harmonybench.bf.shisijinav';

// 应用冷启动后（评分器在每个阶段前 force-stop），进入 card 对应的模块，probes 中的文字都要出现
async function firstEntryShows(card: string, probes: string[]): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  await delegator.executeShellCommand(`aa start -b ${BUNDLE} -a EntryAbility`);
  const driver = Driver.create();
  const entry = await driver.waitForComponent(ON.text(card), 8000);
  expect(entry !== null).assertTrue();
  await entry.click();
  for (const p of probes) {
    expect((await driver.waitForComponent(ON.text(p), 6000)) !== null).assertTrue();
  }
}

export default function navBlankTest() {
  describe('BF_NavBlank', () => {
    // 测试与应用同进程，用例里的第一次跳转就是"启动后第一次进入"。三个用例分属三个冷启动阶段
    it('FP1_first_entry_pet', 0, async () => {
      await firstEntryShows('宠物领养', ['暖爪之家', '猫咪', '小黄']);
    });
    it('FP1_first_entry_book', 0, async () => {
      await firstEntryShows('书单书架', ['拾光书局', '历史', '三体']);
    });
    // 回归：题面说明「餐厅点餐」能正常进入，修复不能把它改坏
    it('FP1_dining_still_ok', 0, async () => {
      await firstEntryShows('餐厅点餐', ['过桥米线']);
    });
  });
}
