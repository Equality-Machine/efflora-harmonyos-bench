import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'DiningOrder', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(0x0000, 'DiningOrder', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 整窗暖色打底：杜绝列表弹性越界 / 页面切换瞬时透出的白底闪屏
    windowStage.getMainWindow().then((win: window.Window) => {
      win.setWindowBackgroundColor('#FFF7F0');
    }).catch((err: Error) => {
      hilog.error(0x0000, 'DiningOrder', 'setWindowBackgroundColor failed: %{public}s',
        JSON.stringify(err));
    });
    // 元服务入口：首页即菜单页，秒开直达内容
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'DiningOrder', 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(0x0000, 'DiningOrder', '%{public}s', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, 'DiningOrder', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(0x0000, 'DiningOrder', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(0x0000, 'DiningOrder', '%{public}s', 'Ability onBackground');
  }
}