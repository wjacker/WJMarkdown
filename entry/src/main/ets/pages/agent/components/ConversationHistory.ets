import { AgentConversationHelper, AgentConversationItem, AgentConversationSection } from '../models/ConversationModels';
import { ConversationDrawerActionDispatcher, ConversationDrawerActionType } from './ConversationDrawerActionDispatcher';

export class ConversationHistoryHelper {
  static buildSections(items: Array<AgentConversationItem>): Array<AgentConversationSection> {
    const sections: Array<AgentConversationSection> = [];
    const pinnedItems: Array<AgentConversationItem> = [];
    const sectionMap: Map<string, Array<AgentConversationItem>> = new Map();
    const orderedTitles: Array<string> = [];

    for (let index: number = 0; index < items.length; index++) {
      const item: AgentConversationItem = items[index];
      if (item.isPinned) {
        pinnedItems.push(item);
        continue;
      }
      const title: string = AgentConversationHelper.buildGroupTitle(item.createdAt);
      const existingItems: Array<AgentConversationItem> | undefined = sectionMap.get(title);
      if (existingItems === undefined) {
        sectionMap.set(title, [item]);
        orderedTitles.push(title);
      } else {
        existingItems.push(item);
      }
    }

    if (pinnedItems.length > 0) {
      sections.push(new AgentConversationSection('置顶', pinnedItems));
    }
    for (let index: number = 0; index < orderedTitles.length; index++) {
      const title: string = orderedTitles[index];
      const groupedItems: Array<AgentConversationItem> | undefined = sectionMap.get(title);
      if (groupedItems !== undefined) {
        sections.push(new AgentConversationSection(title, groupedItems));
      }
    }
    return sections;
  }

  static buildConversationItemKey(item: AgentConversationItem): string {
    return `${item.appConversationId}:${item.title}:${item.isPinned ? '1' : '0'}:${item.createdAt}`;
  }

  static buildConversationSectionKey(section: AgentConversationSection): string {
    let key: string = `${section.title}:${section.items.length}`;
    for (let index: number = 0; index < section.items.length; index++) {
      key += `|${ConversationHistoryHelper.buildConversationItemKey(section.items[index])}`;
    }
    return key;
  }
}

@Component
export struct ConversationHistory {
  @Prop conversationItems: Array<AgentConversationItem> = [];
  @Prop selectedConversationId: string = '';
  @Prop activeConversationMenuId: string = '';
  @Prop activeConversationMenuTop: number = 88;
  @Prop renameDraft: string = '';
  @Prop isRenameDialogVisible: boolean = false;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack({ alignContent: Alignment.TopStart }) {
        Row() {
          Blank()
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#400F172A')
        .onClick(() => {
          ConversationDrawerActionDispatcher.dispatch(ConversationDrawerActionType.Close);
        })

        Row() {
          Column({ space: 14 }) {
            Row() {
              Text('对话历史')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#111827')

              Blank()

              Button('新建')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor('#0F3D91')
                .backgroundColor('#DBEAFE')
                .borderRadius(16)
                .padding({ left: 12, right: 12 })
                .onClick(() => {
                  ConversationDrawerActionDispatcher.dispatch(ConversationDrawerActionType.NewConversation);
                })
            }
            .width('100%')

            if (this.conversationItems.length === 0) {
              Column({ space: 8 }) {
                Text('还没有会话')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#334155')

                Text('发送第一条消息后，这里会自动保存会话记录。')
                  .fontSize(12)
                  .fontColor('#64748B')
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding({ top: 10, right: 8, bottom: 10, left: 8 })
            } else {
              Stack({ alignContent: Alignment.TopStart }) {
                List({ space: 12 }) {
                  ForEach(ConversationHistoryHelper.buildSections(this.conversationItems),
                    (section: AgentConversationSection) => {
                      ListItem() {
                        Column({ space: 10 }) {
                          Text(section.title)
                            .fontSize(13)
                            .fontWeight(FontWeight.Bold)
                            .fontColor('#6B7280')
                            .width('100%')
                            .textAlign(TextAlign.Start)

                          Column({ space: 12 }) {
                            ForEach(section.items, (item: AgentConversationItem) => {
                              this.ConversationItemBuilder(item)
                            }, (item: AgentConversationItem) => ConversationHistoryHelper.buildConversationItemKey(item))
                          }
                          .width('100%')
                        }
                        .width('100%')
                      }
                    }, (section: AgentConversationSection) => ConversationHistoryHelper.buildConversationSectionKey(section))
                }
                .width('100%')
                .layoutWeight(1)
                .scrollBar(BarState.Off)

                if (this.activeConversationMenuId.length > 0) {
                  this.ConversationFloatingMenuBuilder()
                }
              }
              .width('100%')
              .layoutWeight(1)
            }
          }
          .width('78%')
          .height('100%')
          .padding({ top: 52, right: 14, bottom: 20, left: 14 })
          .backgroundColor('#FFFFFF')
          .borderRadius({ topRight: 26, bottomRight: 26 })
          .shadow({
            radius: 28,
            color: '#1F0F172A',
            offsetX: 6,
            offsetY: 0
          })

          Blank()
            .layoutWeight(1)
            .onClick(() => {
              ConversationDrawerActionDispatcher.dispatch(ConversationDrawerActionType.Close);
            })
        }
        .width('100%')
        .height('100%')

        if (this.isRenameDialogVisible) {
          this.RenameConversationDialogBuilder();
        }
      }
      .width('100%')
      .height('100%')
    }
  }

  @Builder
  private ConversationItemBuilder(item: AgentConversationItem) {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Column() {
          Text(AgentConversationHelper.buildDisplayTitle(item))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#0F172A')
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Button() {
          Image($r('app.media.icon_ai_more'))
            .width(16)
            .height(16)
            .fillColor('#64748B')
        }
        .width(28)
        .height(28)
        .backgroundColor(Color.Transparent)
        .borderRadius(14)
        .onClick(() => {
          ConversationDrawerActionDispatcher.dispatch(ConversationDrawerActionType.ToggleMenu, item.appConversationId);
        })
      }
      .width('100%')
      .padding({ top: 12, right: 12, bottom: 12, left: 12 })
      .backgroundColor(this.selectedConversationId === item.appConversationId ? '#EFF6FF' : '#F8FAFC')
      .border({
        width: 1,
        color: this.selectedConversationId === item.appConversationId ? '#93C5FD' : '#E2E8F0'
      })
      .borderRadius(16)
      .onClick(() => {
        ConversationDrawerActionDispatcher.dispatch(ConversationDrawerActionType.SelectConversation, item.appConversationId);
      })
    }
    .width('100%')
  }

  @Builder
  private ConversationFloatingMenuBuilder() {
    Row() {
      Blank()

      Column({ space: 0 }) {
        this.ConversationMenuItemBuilder(
          this.isActiveConversationPinned() ? '取消置顶' : '置顶',
          $r('app.media.icon_ai_pinned'),
          '#0F172A',
          ConversationDrawerActionType.TogglePinned,
          this.activeConversationMenuId
        );
        this.ConversationMenuItemBuilder('重命名', $r('app.media.icon_ai_edit'), '#0F172A',
          ConversationDrawerActionType.OpenRename, this.activeConversationMenuId);
        this.ConversationMenuItemBuilder('删除', $r('app.media.icon_ai_delete'), '#DC2626',
          ConversationDrawerActionType.DeleteConversation, this.activeConversationMenuId);
      }
      .width(196)
      .backgroundColor('#FFFFFF')
      .borderRadius(22)
      .shadow({
        radius: 24,
        color: '#220F172A',
        offsetX: 0,
        offsetY: 10
      })
      .padding({ top: 6, bottom: 6 })
    }
    .width('100%')
    .margin({ top: this.activeConversationMenuTop, right: 20 })
  }

  @Builder
  private ConversationMenuItemBuilder(label: string, icon: Resource, color: string, actionType: ConversationDrawerActionType,
    appConversationId: string) {
    Row({ space: 10 }) {
      Image(icon)
        .width(15)
        .height(15)
        .fillColor(color)

      Text(label)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(color)

      Blank()
    }
    .width('100%')
    .padding({ top: 12, right: 14, bottom: 12, left: 14 })
    .onClick(() => {
      if (actionType === ConversationDrawerActionType.DeleteConversation) {
        AlertDialog.show({
          title: '确定删除对话记录？',
          message: '确定删除对话记录？删除后将无法恢复',
          primaryButton: {
            value: '取消',
            action: () => {
            }
          },
          secondaryButton: {
            value: '删除',
            action: () => {
              ConversationDrawerActionDispatcher.dispatch(actionType, appConversationId);
            }
          }
        });
        return;
      }
      ConversationDrawerActionDispatcher.dispatch(actionType, appConversationId);
    })
  }

  @Builder
  private RenameConversationDialogBuilder() {
    Stack({ alignContent: Alignment.Center }) {
      Row() {
        Blank()
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#500F172A')
      .onClick(() => {
        ConversationDrawerActionDispatcher.dispatch(ConversationDrawerActionType.CancelRename);
      })

      Column({ space: 14 }) {
        Text('重命名会话')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')

        TextInput({ text: this.renameDraft, placeholder: '请输入新的会话名称' })
          .height(46)
          .fontSize(14)
          .backgroundColor('#F8FAFC')
          .borderRadius(14)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            ConversationDrawerActionDispatcher.dispatch(ConversationDrawerActionType.UpdateRenameDraft, '', value);
          })

        Row({ space: 10 }) {
          Button('取消')
            .layoutWeight(1)
            .height(42)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#475569')
            .backgroundColor('#F1F5F9')
            .borderRadius(14)
            .onClick(() => {
              ConversationDrawerActionDispatcher.dispatch(ConversationDrawerActionType.CancelRename);
            })

          Button('确定')
            .layoutWeight(1)
            .height(42)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .backgroundColor('#2563EB')
            .borderRadius(14)
            .onClick(() => {
              ConversationDrawerActionDispatcher.dispatch(ConversationDrawerActionType.ConfirmRename);
            })
        }
        .width('100%')
      }
      .width('78%')
      .padding(18)
      .backgroundColor('#FFFFFF')
      .borderRadius(24)
    }
    .width('100%')
    .height('100%')
  }

  private isActiveConversationPinned(): boolean {
    for (let index: number = 0; index < this.conversationItems.length; index++) {
      const item: AgentConversationItem = this.conversationItems[index];
      if (item.appConversationId === this.activeConversationMenuId) {
        return item.isPinned;
      }
    }
    return false;
  }
}
