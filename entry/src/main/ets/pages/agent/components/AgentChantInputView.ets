import { AgentImageAttachment } from '../models/AgentAttachmentModels';

@Component
export struct AgentChantInputView {
  @Link draft: string;
  @Link isComposerExpanded: boolean;
  @Link isComposerFocused: boolean;
  @Prop isSending: boolean = false;
  @Prop attachments: Array<AgentImageAttachment> = [];
  onVoice?: () => void = undefined;
  onUploadImage?: () => void = undefined;
  onRemoveAttachment?: (attachmentId: string) => void = undefined;
  onSubmitOrStop?: () => void = undefined;

  build() {
    Column({ space: 8 }) {
      Row() {
        Column({ space: 10 }) {
          if (this.shouldShowExpandedComposer()) {
            if (this.attachments.length > 0) {
              this.AttachmentPreviewBuilder()
            }

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
                if (!this.hasSendableContent() && !this.isSending) {
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
                if(this.onVoice) {
                  this.onVoice()
                }
              })

              Button() {
                Image($r('app.media.icon_ai_upload'))
                  .width(22)
                  .height(22)
                  .objectFit(ImageFit.Contain)
              }
              .width(28)
              .height(28)
              .backgroundColor(Color.Transparent)
              .borderRadius(14)
              .onClick(() => {
                if(this.onUploadImage) {
                  this.onUploadImage()
                }
              })

              Blank()

              Button() {
                Image(this.isSending ? $r('app.media.icon_ai_stop') : $r('app.media.icon_send'))
                  .width(22)
                  .height(22)
                  .objectFit(ImageFit.Contain)
                  .opacity(this.isSending || this.hasSendableContent() ? 1 : 0.35)
              }
              .width(28)
              .height(28)
              .backgroundColor(Color.Transparent)
              .borderRadius(14)
              .enabled(this.isSending || this.hasSendableContent())
              .onClick(() => {
                if (!this.isSending && !this.hasSendableContent()) {
                  return;
                }
                if(this.onSubmitOrStop) {
                  this.onSubmitOrStop()
                }
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
                if(this.onVoice) {
                  this.onVoice()
                }
              })

              Button() {
                Image($r('app.media.icon_ai_upload'))
                  .width(22)
                  .height(22)
                  .objectFit(ImageFit.Contain)
              }
              .width(28)
              .height(28)
              .backgroundColor(Color.Transparent)
              .borderRadius(14)
              .onClick(() => {
                if(this.onUploadImage) {
                  this.onUploadImage()
                }
              })

              Text('发消息...')
                .layoutWeight(1)
                .fontSize(16)
                .fontColor('#C0C8D4')
                .textAlign(TextAlign.Start)

              Button() {
                Image(this.isSending ? $r('app.media.icon_ai_stop') : $r('app.media.icon_send'))
                  .width(22)
                  .height(22)
                  .objectFit(ImageFit.Contain)
                  .opacity(this.isSending || this.hasSendableContent() ? 1 : 0.35)
              }
              .width(28)
              .height(28)
              .backgroundColor(Color.Transparent)
              .borderRadius(14)
              .enabled(this.isSending || this.hasSendableContent())
              .onClick(() => {
                if (!this.isSending && !this.hasSendableContent()) {
                  return;
                }

                if(this.onSubmitOrStop) {
                  this.onSubmitOrStop()
                }
              })
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
        Text('内容由AI生成, 仅供参考')
          .fontSize(11)
          .fontColor('#D0D3DF')
          .textAlign(TextAlign.Center)
          .width('100%')
      }
    }
    .width('100%')
    .padding({ top: 12, right: 16, bottom: this.shouldShowExpandedComposer() ? 8 : 20, left: 16 })
    .backgroundColor('#FFFFFF')
  }

  @Builder
  private AttachmentPreviewBuilder() {
    Column({ space: 8 }) {
      ForEach(this.attachments, (attachment: AgentImageAttachment) => {
        Row({ space: 10 }) {
          Image(attachment.fileUri)
            .width(46)
            .height(46)
            .borderRadius(8)
            .objectFit(ImageFit.Cover)

          Text(attachment.name)
            .layoutWeight(1)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#334155')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Button('移除')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor('#DC2626')
            .backgroundColor('#FEE2E2')
            .borderRadius(8)
            .padding({ left: 8, right: 8 })
            .onClick(() => {
              if(this.onRemoveAttachment) {
                this.onRemoveAttachment(attachment.id)
              }
            })
        }
        .width('100%')
        .padding({ top: 8, right: 8, bottom: 8, left: 8 })
        .backgroundColor('#F8FAFC')
        .borderRadius(8)
      }, (attachment: AgentImageAttachment) => attachment.id)
    }
    .width('100%')
  }

  private hasDraftContent(): boolean {
    return this.draft.trim().length > 0;
  }

  private hasAttachment(): boolean {
    return this.attachments.length > 0;
  }

  private hasSendableContent(): boolean {
    return this.hasDraftContent() || this.hasAttachment();
  }

  private shouldShowExpandedComposer(): boolean {
    return this.isComposerExpanded || this.hasSendableContent() || this.isSending;
  }
}
