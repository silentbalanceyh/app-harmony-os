@Entry
@Component
struct Index {
  @State message: string = 'Hello World';

  build() {
    Column() {
      Text(this.message)
        .fontSize(50)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 100 })
      Button('Click Me')
        .fontSize(30)
        .margin({ top: 40 })
        .onClick(() => {
          this.message = 'Hello HarmonyOS!';
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#F5F5F5')
  }
}
