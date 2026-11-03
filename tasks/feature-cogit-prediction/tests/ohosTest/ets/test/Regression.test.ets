import { describe, it } from '@ohos/hypium';
import { Component, Driver, MatchPattern, ON } from '@kit.TestKit';
import { T_HOME, exact, findAll, launch, must, onHome, rand5, textOf, textsContaining, typeIntoFirst } from './Helpers';

const T_QUICK_NOTE = '＋ 速记';  // base 首页悬浮入口
const T_SAVE = '保存';            // base 速记页保存

/** R_note（base 行为回归）：首页「＋ 速记」记一条速记并保存，冷启动后首页「最近速记」里有它。 */
export default function regressionTest() {
  describe('R_Note', () => {
    it('R_note_save', 0, async (done: Function) => {
      const driver = Driver.create();
      await launch(driver);
      const entry = await exact(driver, T_QUICK_NOTE);
      await must(driver, 'r_quick_note_entry', entry.length > 0);
      await entry[0].click();
      await driver.delayMs(2000);
      const content = `zn${rand5()} 回归速记`;
      await must(driver, 'r_note_input', await typeIntoFirst(driver, 'TextArea', content));
      let save: Component | null = null;
      for (const c of await exact(driver, T_SAVE)) {
        save = c;
      }
      await must(driver, 'r_note_save_button', save !== null);
      await save!.click();
      let home = false;
      for (let i = 0; i < 12 && !home; i++) {
        await driver.delayMs(500);
        home = await onHome(driver);
      }
      await must(driver, 'r_note_saved_back_home', home);
      done();
    });

    it('R_note_restart', 0, async (done: Function) => {
      const driver = Driver.create();
      await launch(driver);
      let found = '';
      const scroll = await driver.findComponent(ON.type('Scroll'));
      if (scroll !== null) {
        await scroll.scrollSearch(ON.text('zn', MatchPattern.CONTAINS));
      }
      for (const c of await textsContaining(driver, 'zn')) {
        const t = await textOf(c);
        if (/zn\d{5}/.test(t)) {
          found = t;
        }
      }
      await must(driver, 'r_note_listed_after_restart', found.length > 0);
      await must(driver, 'r_home', (await findAll(driver, ON.text(T_HOME))).length > 0);
      done();
    });
  });
}
