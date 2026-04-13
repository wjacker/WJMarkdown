import { AgentChantInputViewActionDispatcher, AgentChantInputViewActionType } from './AgentChantInputViewActionDispatcher';

@Component
export struct AgentChantInputView {
  @Link draft: string;
  @Link isComposerExpanded: boolean;
  @Link isComposerFocused: boolean;
  @Prop isSending: boolean = false;

  build() {
    Column({ space: 8 }) {
      Row() {
        Column({ space: 10 }) {
          if (this.shouldShowExpandedComposer()) {
            TextArea({ text: this.draft, placeholder: '发消息...' })
              .width('100%')
              .id('agent-composer-expanded-input')
              .backgroundColor(Color.Transparent)
              .borderRadius(0)
              .fontSize(16)
              .fontColor('#0F172A')
              .placeholderColor('#C0C8D4')
              .maxLines(8)
              .barState(BarState.Auto)
              .defaultFocus(true)
              .padding({ top: 0, right: 0, bottom: 0, left: 0 })
              .onFocus(() => {
                this.isComposerExpanded = true;
                this.isComposerFocused = true;
              })
              .onBlur(() => {
                this.isComposerFocused = false;
                if (this.draft.trim().length === 0 && !this.isSending) {
                  this.isComposerExpanded = false;
                }
              })
              .onChange((value: string) => {
                this.draft = value;
                if (value.trim().length > 0) {
                  this.isComposerExpanded = true;
                }
              })

            Row() {
              Button() {
                Image($r('app.media.icon_ai_voice'))
                  .width(22)
                  .height(22)
                  .objectFit(ImageFit.Contain)
              }
              .width(28)
              .height(28)
              .backgroundColor(Color.Transparent)
              .borderRadius(14)
              .onClick(() => {
                AgentChantInputViewActionDispatcher.dispatch(AgentChantInputViewActionType.Voice);
              })

              Blank()

              Button() {
                Image(this.isSending ? $r('app.media.icon_ai_stop') : $r('app.media.icon_send'))
                  .width(22)
                  .height(22)
                  .objectFit(ImageFit.Contain)
                  .opacity(this.isSending || this.hasDraftContent() ? 1 : 0.35)
              }
              .width(28)
              .height(28)
              .backgroundColor(Color.Transparent)
              .borderRadius(14)
              .enabled(this.isSending || this.hasDraftContent())
              .onClick(() => {
                if (!this.isSending && !this.hasDraftContent()) {
                  return;
                }
                AgentChantInputViewActionDispatcher.dispatch(AgentChantInputViewActionType.SubmitOrStop);
              })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
          } else {
            Row({ space: 10 }) {
              Button() {
                Image($r('app.media.icon_ai_voice'))
                  .width(22)
                  .height(22)
                  .objectFit(ImageFit.Contain)
              }
              .width(28)
              .height(28)
              .backgroundColor(Color.Transparent)
              .borderRadius(14)
              .onClick(() => {
                AgentChantInputViewActionDispatcher.dispatch(AgentChantInputViewActionType.Voice);
              })

              Text('发消息...')
                .layoutWeight(1)
                .fontSize(16)
                .fontColor('#C0C8D4')
                .textAlign(TextAlign.Start)

              Button() {
                Image($r('app.media.icon_send'))
                  .width(22)
                  .height(22)
                  .objectFit(ImageFit.Contain)
                  .opacity(0.35)
              }
              .width(28)
              .height(28)
              .backgroundColor(Color.Transparent)
              .borderRadius(14)
              .enabled(false)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .onClick(() => {
              this.isComposerExpanded = true;
              this.isComposerFocused = true;
              setTimeout(() => {
                focusControl.requestFocus('agent-composer-expanded-input');
              }, 50);
            })
          }
        }
        .width('100%')
        .padding({ top: 14, right: 14, bottom: this.shouldShowExpandedComposer() ? 10 : 12, left: 14 })
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius(18)
      .shadow({
        radius: 20,
        color: '#220F172A',
        offsetX: 0,
        offsetY: 8
      })

      if (!this.isComposerFocused) {
        Text('内容由 AI 生成')
          .fontSize(11)
          .fontColor('#FFFFFF')
          .textAlign(TextAlign.Center)
          .width('100%')
      }
    }
    .width('100%')
    .padding({ top: 12, right: 16, bottom: this.shouldShowExpandedComposer() ? 8 : 20, left: 16 })
    .backgroundColor('#FFFFFF')
  }

  private hasDraftContent(): boolean {
    return this.draft.trim().length > 0;
  }

  private shouldShowExpandedComposer(): boolean {
    return this.isComposerExpanded || this.hasDraftContent() || this.isSending;
  }
}
