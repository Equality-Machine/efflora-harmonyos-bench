// 暖爪之家 · 专属第二页：领养申请表单
// 全案例唯一的"输入型"页面：TextInput + RadioGroup + Select + 必填校验 + Toast 提交反馈（假提交）。
import { Pet, PETS, adoptPetId } from '../model/PetData';

const ACCENT = '#E86A92';
const EXP_OPTIONS: SelectOption[] = [
  { value: '没养过' },
  { value: '1-2 年' },
  { value: '3-5 年' },
  { value: '5 年以上' }
];

@Component
export struct AdoptForm {
  @State petOptions: SelectOption[] = [];
  @State petIdx: number = 0;          // 意向宠物 Select 选中索引
  @State name: string = '';
  @State phone: string = '';
  @State house: string = 'own';       // own | rent | share
  @State expIdx: number = 0;          // 养宠经验 Select 选中索引
  @Consume pathStack: NavPathStack;

  aboutToAppear(): void {
    this.petOptions = PETS.map((p: Pet): SelectOption => ({ value: p.name }));
    if (adoptPetId !== '') {
      for (let i = 0; i < PETS.length; i++) {
        if (PETS[i].id === adoptPetId) {
          this.petIdx = i;
          break;
        }
      }
    }
  }

  toast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1500 });
    } catch (e) {
    }
  }

  submit(): void {
    if (this.name.trim() === '') {
      this.toast('请先填写姓名');
      return;
    }
    if (this.phone.trim() === '') {
      this.toast('请填写手机号');
      return;
    }
    if (this.phone.trim().length !== 11) {
      this.toast('手机号需为 11 位数字');
      return;
    }
    this.toast('申请已提交，暖爪之家将回访你 📞');
    // 假提交：返回列表页，不落地数据
    this.pathStack.pop();
  }

  @Builder
  labelLine(label: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor('#5A514C')
        .width(86)
      Blank()
    }
    .width('100%')
  }

  build() {
    NavDestination() {
      Column() {
        Scroll() {
          Column({ space: 12 }) {
            // 顶部说明
            Column({ space: 6 }) {
              Text('领养申请表')
                .fontSize(26)
                .fontWeight(FontWeight.Bold)
                .fontColor('#26201C')
              Text('我们会与意向宠物主人确认基本信息，请如实填写')
                .fontSize(12)
                .fontColor('#8C8078')
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')

            // 意向宠物
            Row() {
              Text('意向宠物')
                .fontSize(14)
                .fontColor('#5A514C')
                .width(86)
              Select(this.petOptions)
                .selected(this.petIdx)
                .font({ size: 14 })
                .onSelect((index: number, value: string) => {
                  this.petIdx = index
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .backgroundColor(Color.White)
            .borderRadius(12)

            // 姓名
            Row() {
              Text('姓名')
                .fontSize(14)
                .fontColor('#5A514C')
                .width(86)
              TextInput({ placeholder: '你的称呼', text: this.name })
                .fontSize(14)
                .layoutWeight(1)
                .onChange((v: string) => {
                  this.name = v
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .backgroundColor(Color.White)
            .borderRadius(12)

            // 手机号
            Row() {
              Text('手机号')
                .fontSize(14)
                .fontColor('#5A514C')
                .width(86)
              TextInput({ placeholder: '11 位手机号', text: this.phone })
                .fontSize(14)
                .layoutWeight(1)
                .type(InputType.PhoneNumber)
                .onChange((v: string) => {
                  this.phone = v
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .backgroundColor(Color.White)
            .borderRadius(12)

            // 居住情况：Radio 单选（group 参数自身管理互斥，API24 无 RadioGroup 容器）
            Column({ space: 10 }) {
              this.labelLine('居住情况')
              Column({ space: 8 }) {
                Row({ space: 8 }) {
                  Radio({ value: 'own', group: 'house' })
                    .checked(this.house === 'own')
                    .onChange((c: boolean) => {
                      if (c) {
                        this.house = 'own'
                      }
                    })
                  Text('自有住房（有阳台/院子更好）')
                    .fontSize(13)
                    .fontColor('#5A514C')
                }
                Row({ space: 8 }) {
                  Radio({ value: 'rent', group: 'house' })
                    .checked(this.house === 'rent')
                    .onChange((c: boolean) => {
                      if (c) {
                        this.house = 'rent'
                      }
                    })
                  Text('租房（房东同意养宠）')
                    .fontSize(13)
                    .fontColor('#5A514C')
                }
                Row({ space: 8 }) {
                  Radio({ value: 'share', group: 'house' })
                    .checked(this.house === 'share')
                    .onChange((c: boolean) => {
                      if (c) {
                        this.house = 'share'
                      }
                    })
                  Text('合租 / 宿舍')
                    .fontSize(13)
                    .fontColor('#5A514C')
                }
              }
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .backgroundColor(Color.White)
            .borderRadius(12)

            // 养宠经验
            Row() {
              Text('养宠经验')
                .fontSize(14)
                .fontColor('#5A514C')
                .width(86)
              Select(EXP_OPTIONS as SelectOption[])
                .selected(this.expIdx)
                .font({ size: 14 })
                .onSelect((index: number, value: string) => {
                  this.expIdx = index
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .backgroundColor(Color.White)
            .borderRadius(12)

            // 提交
            Text('提交申请')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .textAlign(TextAlign.Center)
              .width('100%')
              .padding({ top: 14, bottom: 14 })
              .backgroundColor(ACCENT)
              .borderRadius(999)
              .onClick(() => this.submit())

            Text('提交即代表同意暖爪之家回访问卷 · 全部信息仅用于领养审核')
              .fontSize(11)
              .fontColor('#B5A9A0')
              .textAlign(TextAlign.Center)
              .width('100%')
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 24 })
          .alignItems(HorizontalAlign.Start)
        }
        .scrollBar(BarState.Off)
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F7F6F3')
    }
    .title('领养申请')
    .hideTitleBar(true)
    .onBackPressed(() => {
      this.pathStack.pop();
      return true;
    })
  }
}