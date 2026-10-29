// 四时集 · 首页（@Entry · Navigation 栈根）
// 4 宫格入口 → 四个生活场景；PageMap 集中路由表（新增模块只加一个分支）
import { ModuleTheme, LAUNCHERS } from '../common/Theme';
import { DiningList } from './modules/DiningList';
import { HotelList } from './modules/HotelList';
import { PetList } from './modules/PetList';
import { BookList } from './modules/BookList';
import { StoreDisplay } from '../scenes/StoreDisplay';
import { RoomTour } from '../scenes/RoomTour';
import { AdoptForm } from '../scenes/AdoptForm';
import { DailyPick } from '../scenes/DailyPick';

@Entry
@Component
struct Index {
  @Provide pathStack: NavPathStack = new NavPathStack();

  openLauncher(l: ModuleTheme): void {
    if (l.ready) {
      this.pathStack.pushPathByName(l.route, null);
    } else {
      try {
        this.getUIContext().getPromptAction().showToast({
          message: '「' + l.title + '」正在装修中，敬请期待',
          duration: 1500
        });
      } catch (e) {
        // 占位 Toast 失败不影响使用，静默忽略
      }
    }
  }

  @Builder
  launcherCard(l: ModuleTheme) {
    Column() {
      Row() {
        // 左侧 emoji 图标块
        Text(l.emoji)
          .fontSize(30)
          .width(56)
          .height(56)
          .textAlign(TextAlign.Center)
          .backgroundColor(l.accentSoft)
          .borderRadius(14)
        Blank()
        if (l.ready) {
          Text('GO ›')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(l.accent)
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor(l.accentSoft)
            .borderRadius(999)
        } else {
          Text('建设中')
            .fontSize(11)
            .fontColor('#A39B93')
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor('#F1EEE9')
            .borderRadius(999)
        }
      }
      .width('100%')

      Blank()

      // 下沿：模块名 + 副标（品牌色左条）
      Row() {
        Column({ space: 3 }) {
          Text(l.title)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#211E1A')
          Text(l.slogan)
            .fontSize(11)
            .fontColor('#8A837C')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 10 })
      .border({ width: { left: 3 }, color: l.accent })
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .onClick(() => this.openLauncher(l))
  }

  // 页面映射表：新增模块只加一个分支
  @Builder
  PageMap(name: string) {
    if (name === 'DiningList') {
      DiningList()
    }
    if (name === 'StoreDisplay') {
      StoreDisplay()
    }
    if (name === 'HotelList') {
      HotelList()
    }
    if (name === 'RoomTour') {
      RoomTour()
    }
    if (name === 'PetList') {
      PetList()
    }
    if (name === 'AdoptForm') {
      AdoptForm()
    }
    if (name === 'BookList') {
      BookList()
    }
    if (name === 'DailyPick') {
      DailyPick()
    }
  }

  build() {
    Navigation(this.pathStack) {
      Column() {
        // 头部：四时集 + 标语
        Column({ space: 4 }) {
          Text('四时集')
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor('#211E1A')
          Text('点餐 · 看房 · 领养 · 读书')
            .fontSize(13)
            .fontColor('#8A837C')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ left: 16, right: 16, top: 24, bottom: 18 })

        Text('一个元服务 · 四个生活场景')
          .fontSize(11)
          .fontColor('#8A837C')
          .padding({ left: 12, right: 12, top: 5, bottom: 5 })
          .backgroundColor('#F1EEE9')
          .borderRadius(999)
          .alignSelf(ItemAlign.Start)
          .margin({ left: 16, bottom: 18 })

        // 2×2 宫格：四张场景卡
        Grid() {
          ForEach(LAUNCHERS, (l: ModuleTheme) => {
            GridItem() {
              this.launcherCard(l)
            }
          }, (l: ModuleTheme) => l.key)
        }
        .columnsTemplate('1fr 1fr')
        .rowsTemplate('1fr 1fr')
        .columnsGap(14)
        .rowsGap(14)
        .width('100%')
        .height(360)
        .padding({ left: 16, right: 16 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F7F6F3')
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .backgroundColor('#F7F6F3')
    .navDestination(this.PageMap)
  }
}