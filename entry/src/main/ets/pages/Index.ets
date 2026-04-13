@Entry
@Component
struct Index {
  private pageStack: NavPathStack = new NavPathStack();
  @State private didPushAgentPage: boolean = false;

  build() {
    Navigation(this.pageStack) {
    }
    .hideNavBar(true)
    .width('100%')
    .height('100%')
    .onAppear(() => {
      if (this.didPushAgentPage) {
        return;
      }
      this.didPushAgentPage = true;
      this.pageStack.pushPathByName('AgentIndexPage', undefined, false);
    })
  }
}
