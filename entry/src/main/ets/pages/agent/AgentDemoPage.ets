import { ChatBubble } from './components/ChatBubble';
import { AgentHeaderView } from './components/AgentHeaderView';
import { AgentChantInputView } from './components/AgentChantInputView';
import { ChatBubbleActionDispatcher, ChatBubbleActionType } from './components/ChatBubbleActionDispatcher';
import { ConversationHistory, ConversationHistoryHelper } from './components/ConversationHistory';
import { ConversationDrawerActionDispatcher, ConversationDrawerActionType } from './components/ConversationDrawerActionDispatcher';
import pasteboard from '@ohos.pasteboard';
import promptAction from '@ohos.promptAction';
import preferences from '@ohos.data.preferences';
import dataSharePredicates from '@ohos.data.dataSharePredicates';
import fs from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import textToSpeech from '@hms.ai.textToSpeech';
import { KeyboardAvoidMode } from '@ohos.arkui.UIContext';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { AgentImageAttachment } from './models/AgentAttachmentModels';
import { AgentAnswer, ChatMessage, MessageFeedback } from './models/ChatModels';
import { AgentConversationHelper, AgentConversationItem } from './models/ConversationModels';
import { HiAgentAppConfigPreview, HiAgentConfig, HiAgentConversation } from './models/HiAgentModels';
import { AgentConfigStore, AgentStoredConfig } from './services/AgentConfigStore';
import { HiAgentService, HiAgentStreamSession } from './services/HiAgentService';
import { AgentMessageManager } from './services/AgentMessageManager';
import { AgentSpeechManager } from './services/AgentSpeechManager';
import { AgentTextUtils } from './utils/AgentTextUtils';

@Builder
export function AgentDemoPageBuilder() {
  AgentDemoPage()
}

@Component
struct AgentDemoPage {
  @State messages: Array<ChatMessage> = [];
  @State draft: string = '请生成一段包含任务列表、代码块和表格的 Markdown 回复。';
  @State private apiUrl: string = '';
  @State private apiKey: string = '';
  @State private userId: string = 'demo-user';
  @State conversationId: string = '';
  @State private isConfigExpanded: boolean = true;
  @State statusText: string = '请先填写 HiAgent 的 Api URL、ApiKey 和 UserID。';
  @State isSending: boolean = false;
  @State speakingMessageId: string = '';
  @State shouldAutoScrollToBottom: boolean = true;
  @State private conversationItems: Array<AgentConversationItem> = [];
  @State private appConfigPreview: HiAgentAppConfigPreview = new HiAgentAppConfigPreview();
  @State private isConversationDrawerVisible: boolean = false;
  @State private activeConversationMenuId: string = '';
  @State private activeConversationMenuTop: number = 88;
  @State private renameConversationId: string = '';
  @State private renameDraft: string = '';
  @State private isRenameDialogVisible: boolean = false;
  @State private isComposerExpanded: boolean = false;
  @State private isComposerFocused: boolean = false;
  @State attachments: Array<AgentImageAttachment> = [];

  messageScroller: Scroller = new Scroller();
  private configStore: preferences.Preferences | null = null;
  private configSaveTimer: number = -1;
  revealTimer: number = -1;
  revealChunkSize: number = 5;
  revealIntervalMs: number = 24;
  activeRevealMessageId: string = '';
  activeAssistantMessageId: string = '';
  activeStreamSession: HiAgentStreamSession | null = null;
  serviceConversationId: string = '';
  ttsEngine: textToSpeech.TextToSpeechEngine | null = null;
  answersByMessageId: Map<string, Array<AgentAnswer>> = new Map();
  pendingConversationTitleByMessageId: Map<string, string> = new Map();

  aboutToAppear(): void {
    this.applyKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    ChatBubbleActionDispatcher.register((messageId: string, action: ChatBubbleActionType) => {
      this.handleChatBubbleAction(messageId, action);
    });
    ConversationDrawerActionDispatcher.register((action: ConversationDrawerActionType, conversationId: string,
      payload: string) => {
      this.handleConversationDrawerAction(action, conversationId, payload);
    });
    this.resetConversation();
    this.restoreSavedConfig();
  }

  aboutToDisappear(): void {
    this.applyKeyboardAvoidMode(KeyboardAvoidMode.OFFSET);
    ChatBubbleActionDispatcher.clear();
    ConversationDrawerActionDispatcher.clear();
    this.flushConfigIfNeeded();
    AgentMessageManager.stopRevealTimer(this);
    AgentMessageManager.closeActiveSession(this);
    AgentSpeechManager.shutdownSpeechEngine(this);
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        Column({ space: 0 }) {
          this.HeaderBuilder();
          this.ConfigBuilder();

          List({ space: 22, scroller: this.messageScroller }) {
            if (this.shouldShowAgentHeaderView()) {
              ListItem() {
                AgentHeaderView({
                  preview: this.appConfigPreview,
                  onSelectQuery: (query: string): void => {
                    this.handleAgentHeaderQuerySelect(query);
                  }
                })
                .padding({ top: 2, bottom: 6 })
              }
            }

            ForEach(this.messages, (message: ChatMessage) => {
              ListItem() {
                ChatBubble({
                  message: message,
                  isSpeaking: this.speakingMessageId === message.id,
                })
                .padding({ top: 2, bottom: 6 })
              }
            }, (message: ChatMessage) => message.id)
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ top: 14, right: 16, bottom: 20, left: 16 })
          .backgroundColor('#FFFFFF')
          .scrollBar(BarState.Off)
          .onReachEnd(() => {
            this.shouldAutoScrollToBottom = true;
          })
          .onDidScroll((_scrollOffset: number, scrollState: ScrollState) => {
            if (scrollState === ScrollState.Scroll) {
              this.shouldAutoScrollToBottom = AgentMessageManager.safeIsAtEnd(this);
            }
          })
          .onScrollStop(() => {
            this.shouldAutoScrollToBottom = AgentMessageManager.safeIsAtEnd(this);
          })

          AgentChantInputView({
            draft: $draft,
            isComposerExpanded: $isComposerExpanded,
            isComposerFocused: $isComposerFocused,
            isSending: this.isSending,
            attachments: this.attachments,
            onVoice: () => {
              this.handleVoiceInput();
            },
            onUploadImage: () => {
              void this.handleImageUpload();
            },
            onRemoveAttachment: (attachmentId: string): void => {
              this.removeAttachment(attachmentId);
            },
            onSubmitOrStop: () => {
              this.handleSubmitOrStop();
            }
          })
        }
        .height('100%')
        .width('100%')
        .backgroundColor('#FFFFFF')

        if (this.isConversationDrawerVisible || this.isRenameDialogVisible) {
          ConversationHistory({
            conversationItems: this.conversationItems,
            selectedConversationId: this.conversationId,
            activeConversationMenuId: this.activeConversationMenuId,
            activeConversationMenuTop: this.activeConversationMenuTop,
            renameDraft: this.renameDraft,
            isRenameDialogVisible: this.isRenameDialogVisible
          })
        }
      }
      .height('100%')
      .width('100%')
    }
    .hideTitleBar(true)
  }

  @Builder
  private HeaderBuilder() {
    Stack({ alignContent: Alignment.TopStart }) {
      Image($r('app.media.img_ai_header_bg'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      Column({ space: 16 }) {
        Row({ space: 12 }) {
          Button() {
            Image($r('app.media.icon_ai_more'))
              .width(18)
              .height(18)
              .fillColor('#0F3D91')
          }
          .width(38)
          .height(38)
          .backgroundColor('#FFFFFF')
          .borderRadius(19)
          .onClick(() => {
            this.isConversationDrawerVisible = true;
            this.activeConversationMenuId = '';
          })

          Column({ space: 6 }) {
            Text('HiAgent Markdown Chat')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0F172A')

            Text('HarmonyOS SSE chat demo with real HiAgent streaming markdown rendering.')
              .fontSize(13)
              .fontColor('#526174')
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Button('New chat')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#0F3D91')
            .backgroundColor('#DBEAFE')
            .borderRadius(18)
            .padding({ left: 14, right: 14 })
            .onClick(() => {
              void this.startNewConversation();
            })
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding({ top: 18, right: 16, bottom: 12, left: 16 })
    .height(112)
  }

  @Builder
  private ConfigBuilder() {
    Column({ space: this.isConfigExpanded ? 10 : 0 }) {
      Row({ space: 8 }) {
        Column({ space: 2 }) {
          Text(this.isConfigExpanded ? 'HiAgent Config' : 'Config Hidden')
            .fontSize(this.isConfigExpanded ? 15 : 14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')

          Text(this.isConfigExpanded ? '接口配置会自动保存，下次启动继续可用。' : this.statusText)
            .fontSize(11)
            .fontColor('#64748B')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.conversationId.length > 0) {
          Text(this.shortenId(this.conversationId))
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.getStatusTextColor())
            .padding({ top: 6, right: 10, bottom: 6, left: 10 })
            .backgroundColor(this.getStatusBackgroundColor())
            .borderRadius(14)
        }

        Button('Sync')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#166534')
          .backgroundColor('#DCFCE7')
          .borderRadius(16)
          .padding({ left: 12, right: 12 })
          .onClick(() => {
            this.syncHistory();
          })

        Button(this.isConfigExpanded ? 'Hide' : 'Show')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F3D91')
          .backgroundColor('#DBEAFE')
          .borderRadius(16)
          .padding({ left: 12, right: 12 })
          .onClick(() => {
            this.toggleConfigPanel();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.isConfigExpanded) {
        TextInput({ text: this.apiUrl, placeholder: 'Api URL，例如 http://host:32300' })
          .height(46)
          .fontSize(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .padding({ left: 14, right: 14 })
          .onChange((value: string) => {
            this.apiUrl = value;
            this.scheduleConfigSave();
          })

        TextInput({ text: this.apiKey, placeholder: 'ApiKey，body.AppKey 默认复用同一值' })
          .height(46)
          .fontSize(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .padding({ left: 14, right: 14 })
          .onChange((value: string) => {
            this.apiKey = value;
            this.scheduleConfigSave();
          })

        TextInput({ text: this.userId, placeholder: 'UserID' })
          .height(46)
          .fontSize(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .padding({ left: 14, right: 14 })
          .onChange((value: string) => {
            this.userId = value;
            this.scheduleConfigSave();
          })

        Row({ space: 8 }) {
          Text(this.statusText)
            .fontSize(12)
            .fontColor(this.getStatusTextColor())
            .layoutWeight(1)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (this.conversationId.length === 0) {
            Text('No conversation')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getStatusTextColor())
              .padding({ top: 6, right: 10, bottom: 6, left: 10 })
              .backgroundColor(this.getStatusBackgroundColor())
              .borderRadius(14)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .padding({ top: 10, right: 16, bottom: this.isConfigExpanded ? 12 : 8, left: 16 })
    .backgroundColor('#F8FAFC')
  }

  private hasDraftContent(): boolean {
    return this.draft.trim().length > 0 || this.attachments.length > 0;
  }

  private applyKeyboardAvoidMode(mode: KeyboardAvoidMode): void {
    try {
      this.getUIContext().setKeyboardAvoidMode(mode);
    } catch (_error) {
    }
  }

  private handleVoiceInput(): void {
    this.showToast('暂不支持语音输入');
  }

  private handleSubmitOrStop(): void {
    if (this.isSending) {
      void AgentMessageManager.stopActiveResponse(this);
      return;
    }
    if (!this.hasDraftContent()) {
      return;
    }
    void AgentMessageManager.sendPrompt(this);
  }

  private async handleImageUpload(): Promise<void> {
    try {
      const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      });
      if (result.photoUris.length === 0) {
        return;
      }
      const attachment: AgentImageAttachment | null = await this.buildImageAttachment(result.photoUris[0]);
      if (attachment === null) {
        this.showToast('图片读取失败，请重试');
        return;
      }
      this.attachments = [attachment];
      this.isComposerExpanded = true;
      this.isComposerFocused = false;
      this.statusText = '图片已添加，当前仅做本地渲染。';
      this.showToast('图片已添加');
    } catch (error) {
      this.statusText = `图片选择失败：${this.stringifyError(error as Object)}`;
      this.showToast(`图片选择失败：${this.stringifyError(error as Object)}`);
    }
  }

  private removeAttachment(attachmentId: string): void {
    this.attachments = this.attachments.filter((attachment: AgentImageAttachment) => attachment.id !== attachmentId);
    if (this.draft.trim().length === 0 && this.attachments.length === 0 && !this.isSending && !this.isComposerFocused) {
      this.isComposerExpanded = false;
    }
  }

  private handleChatBubbleAction(messageId: string, action: ChatBubbleActionType): void {
    if (action === ChatBubbleActionType.Copy) {
      void this.copyMessageText(messageId);
      return;
    }
    if (action === ChatBubbleActionType.Regenerate) {
      void AgentMessageManager.queryAgainAssistantMessage(this, messageId);
      return;
    }
    if (action === ChatBubbleActionType.Delete) {
      void AgentMessageManager.deleteAssistantMessage(this, messageId);
      return;
    }
    if (action === ChatBubbleActionType.Like) {
      void AgentMessageManager.toggleFeedback(this, messageId, MessageFeedback.Like);
      return;
    }
    if (action === ChatBubbleActionType.Dislike) {
      void AgentMessageManager.toggleFeedback(this, messageId, MessageFeedback.Dislike);
      return;
    }
    if (action === ChatBubbleActionType.Sound) {
      void AgentSpeechManager.toggleSpeakMessage(this, messageId);
      return;
    }
    if (action === ChatBubbleActionType.Previous) {
      void AgentMessageManager.switchAnswer(this, messageId, -1);
      return;
    }
    if (action === ChatBubbleActionType.Next) {
      void AgentMessageManager.switchAnswer(this, messageId, 1);
    }
  }

  private handleConversationDrawerAction(action: ConversationDrawerActionType, conversationId: string,
    payload: string): void {
    if (action === ConversationDrawerActionType.Close) {
      this.isConversationDrawerVisible = false;
      this.activeConversationMenuId = '';
      return;
    }
    if (action === ConversationDrawerActionType.NewConversation) {
      this.isConversationDrawerVisible = false;
      this.activeConversationMenuId = '';
      void this.startNewConversation();
      return;
    }
    if (action === ConversationDrawerActionType.SelectConversation) {
      void this.selectConversation(conversationId);
      return;
    }
    if (action === ConversationDrawerActionType.ToggleMenu) {
      if (this.activeConversationMenuId === conversationId) {
        this.activeConversationMenuId = '';
        return;
      }
      this.activeConversationMenuTop = this.resolveConversationMenuTopFor(conversationId);
      this.activeConversationMenuId = conversationId;
      return;
    }
    if (action === ConversationDrawerActionType.TogglePinned) {
      void this.toggleConversationPinned(conversationId);
      return;
    }
    if (action === ConversationDrawerActionType.OpenRename) {
      this.openRenameConversation(conversationId);
      return;
    }
    if (action === ConversationDrawerActionType.UpdateRenameDraft) {
      this.renameDraft = this.sanitizeConversationTitle(payload, false);
      return;
    }
    if (action === ConversationDrawerActionType.ConfirmRename) {
      void this.confirmRenameConversation();
      return;
    }
    if (action === ConversationDrawerActionType.CancelRename) {
      this.isRenameDialogVisible = false;
      return;
    }
    if (action === ConversationDrawerActionType.DeleteConversation) {
      void this.deleteConversationItem(conversationId);
    }
  }

  private resetConversation(showGuideMessage: boolean = true): void {
    AgentMessageManager.stopRevealTimer(this);
    AgentMessageManager.closeActiveSession(this);
    AgentSpeechManager.stopSpeakingMessage(this, false);
    this.answersByMessageId.clear();
    this.attachments = [];
    this.conversationId = '';
    this.serviceConversationId = '';
    this.isSending = false;
    this.shouldAutoScrollToBottom = true;
    this.statusText = '请先填写 HiAgent 的 Api URL、ApiKey 和 UserID。';
    this.messages = showGuideMessage ? AgentMessageManager.buildGuideMessages((prefix: string): string => {
      return this.createMessageId(prefix);
    }) : [];
    AgentMessageManager.scrollToBottom(this, true);
  }

  async startNewConversation(): Promise<void> {
    if (this.isSending) {
      this.showToast('当前仍在生成中，请稍后再新建会话');
      return;
    }
    this.isConversationDrawerVisible = false;
    this.activeConversationMenuId = '';
    this.isRenameDialogVisible = false;
    this.resetConversation(false);
    const config: HiAgentConfig = this.buildConfig();
    if (!config.isReady()) {
      this.statusText = '请先填写 Api URL、ApiKey 和 UserID。';
      this.scheduleConfigSave();
      return;
    }

    this.statusText = '正在创建新会话...';
    try {
      const conversation: HiAgentConversation = await HiAgentService.createConversation(config);
      this.conversationId = conversation.appConversationId;
      this.upsertConversationItem(conversation.appConversationId, conversation.conversationName, '', Date.now());
      void this.refreshConversationList(false);
      this.statusText = `新会话 ${this.shortenId(conversation.appConversationId)} 已创建。`;
      this.scheduleConfigSave();
    } catch (error) {
      this.statusText = `创建新会话失败：${this.stringifyError(error)}`;
    }
  }

  private restoreSavedConfig(): void {
    try {
      const context: Context = getContext(this);
      const store: preferences.Preferences = AgentConfigStore.open(context);
      this.configStore = store;
      const storedConfig: AgentStoredConfig = AgentConfigStore.load(store);
      this.conversationItems = AgentConversationHelper.sort(AgentConfigStore.loadConversations(store));
      this.apiUrl = storedConfig.apiUrl;
      this.apiKey = storedConfig.apiKey;
      this.userId = storedConfig.userId;
      this.conversationId = storedConfig.conversationId;
      this.isConfigExpanded = storedConfig.isConfigExpanded;
      if (this.buildConfig().isReady()) {
        void this.refreshAppConfigPreview(false);
        void this.refreshConversationList(false);
      }
      if (this.buildConfig().isReady() && this.conversationId.trim().length > 0) {
        this.statusText = `已恢复上次会话 ${this.shortenId(this.conversationId)}，正在同步历史...`;
        void AgentMessageManager.syncHistory(this);
      } else if (this.buildConfig().isReady()) {
        this.statusText = '已恢复上次配置，可以直接发送。';
      }
    } catch (_error) {
      this.statusText = '配置读取失败，请重新填写接口参数。';
    }
  }

  private async buildImageAttachment(sourceUri: string): Promise<AgentImageAttachment | null> {
    const context: Context = getContext(this);
    const photoHelper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
    const predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();
    predicates.equalTo(String(photoAccessHelper.PhotoKeys.URI), sourceUri);
    const fetchResult: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> = await photoHelper.getAssets({
      fetchColumns: [String(photoAccessHelper.PhotoKeys.URI), String(photoAccessHelper.PhotoKeys.DISPLAY_NAME)],
      predicates: predicates
    });
    try {
      const assets: Array<photoAccessHelper.PhotoAsset> = await fetchResult.getAllObjects();
      if (assets.length === 0) {
        return null;
      }
      const asset: photoAccessHelper.PhotoAsset = assets[0];
      const imageData: ArrayBuffer = await this.readImageData(context, asset);
      const fileName: string = this.resolveAttachmentFileName(sourceUri, asset);
      const attachmentPath: string = this.writeAttachmentToSandbox(context, fileName, imageData);
      const attachmentUri: string = fileUri.getUriFromPath(attachmentPath);
      return new AgentImageAttachment(
        this.createMessageId('attachment'),
        fileName,
        attachmentUri,
        attachmentPath,
        sourceUri
      );
    } finally {
      fetchResult.close();
    }
  }

  private readImageData(context: Context, asset: photoAccessHelper.PhotoAsset): Promise<ArrayBuffer> {
    return new Promise((resolve: (value: ArrayBuffer) => void, reject: (reason?: Object) => void) => {
      let settled: boolean = false;
      void photoAccessHelper.MediaAssetManager.requestImageData(context, asset, {
        deliveryMode: photoAccessHelper.DeliveryMode.HIGH_QUALITY_MODE
      }, {
        onDataPrepared: (data: ArrayBuffer): void => {
          if (settled) {
            return;
          }
          settled = true;
          resolve(data);
        }
      }).catch((error: Object) => {
        if (settled) {
          return;
        }
        settled = true;
        reject(error);
      });
    });
  }

  private writeAttachmentToSandbox(context: Context, fileName: string, imageData: ArrayBuffer): string {
    const attachmentDir: string = `${context.tempDir}/chat-attachments`;
    let attachmentDirExists: boolean = false;
    try {
      attachmentDirExists = fs.accessSync(attachmentDir);
    } catch (_error) {
      attachmentDirExists = false;
    }
    if (!attachmentDirExists) {
      fs.mkdirSync(attachmentDir, true);
    }
    const attachmentPath: string = `${attachmentDir}/${Date.now()}-${fileName}`;
    const file: fs.File = fs.openSync(attachmentPath,
      fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.WRITE_ONLY);
    try {
      fs.writeSync(file.fd, imageData);
    } finally {
      fs.closeSync(file);
    }
    return attachmentPath;
  }

  private resolveAttachmentFileName(sourceUri: string, asset: photoAccessHelper.PhotoAsset): string {
    const displayName: string = `${asset.get(photoAccessHelper.PhotoKeys.DISPLAY_NAME) ?? ''}`.trim();
    if (displayName.length > 0) {
      return displayName;
    }
    try {
      return new fileUri.FileUri(sourceUri).name;
    } catch (_error) {
      return `image-${Date.now()}.jpg`;
    }
  }

  private shouldShowAgentHeaderView(): boolean {
    return this.appConfigPreview.name.trim().length > 0 ||
      this.appConfigPreview.image.trim().length > 0 ||
      this.appConfigPreview.openMessage.trim().length > 0 ||
      this.appConfigPreview.openQuery.length > 0;
  }

  private handleAgentHeaderQuerySelect(queryValue: string): void {
    const query: string = queryValue.trim();
    if (query.length === 0) {
      return;
    }
    if (this.isSending) {
      this.draft = query;
      return;
    }
    this.draft = query;
    void AgentMessageManager.sendPrompt(this);
  }

  private toggleConfigPanel(): void {
    this.isConfigExpanded = !this.isConfigExpanded;
    this.scheduleConfigSave();
  }

  scheduleConfigSave(): void {
    if (this.configSaveTimer >= 0) {
      clearTimeout(this.configSaveTimer);
      this.configSaveTimer = -1;
    }
    this.configSaveTimer = setTimeout(() => {
      this.persistConfig();
    }, 250);
  }

  private flushConfigIfNeeded(): void {
    if (this.configSaveTimer >= 0) {
      clearTimeout(this.configSaveTimer);
      this.configSaveTimer = -1;
    }
    this.persistConfig();
  }

  private persistConfig(): void {
    try {
      if (this.configStore === null) {
        const context: Context = getContext(this);
        this.configStore = AgentConfigStore.open(context);
      }
      if (this.configStore === null) {
        return;
      }
      AgentConfigStore.save(this.configStore, new AgentStoredConfig(
        this.apiUrl,
        this.apiKey,
        this.userId,
        this.conversationId,
        this.isConfigExpanded
      ));
      AgentConfigStore.saveConversations(this.configStore, this.conversationItems);
    } catch (_error) {
      // Ignore local persistence errors so chat features remain available.
    }
  }

  private persistConversationList(): void {
    this.scheduleConfigSave();
  }

  private async refreshAppConfigPreview(showErrorToast: boolean = true): Promise<void> {
    const config: HiAgentConfig = this.buildConfig();
    if (!config.isReady()) {
      this.appConfigPreview = new HiAgentAppConfigPreview();
      return;
    }

    try {
      this.appConfigPreview = await HiAgentService.getAppConfigPreview(config);
    } catch (error) {
      if (showErrorToast) {
        this.showToast(`智能体预览获取失败：${this.stringifyError(error)}`);
      }
    }
  }

  async refreshConversationList(showErrorToast: boolean = true): Promise<void> {
    const config: HiAgentConfig = this.buildConfig();
    if (!config.isReady()) {
      return;
    }

    try {
      const remoteConversations: Array<HiAgentConversation> = await HiAgentService.getConversationList(config);
      const nextItems: Array<AgentConversationItem> = [];
      for (let index: number = 0; index < remoteConversations.length; index++) {
        const remoteConversation: HiAgentConversation = remoteConversations[index];
        const localIndex: number = this.getConversationItemIndex(remoteConversation.appConversationId);
        const localItem: AgentConversationItem | null = localIndex >= 0 ? this.conversationItems[localIndex] : null;
        const createdAt: number = remoteConversation.createTimestamp > 0
          ? remoteConversation.createTimestamp * 1000
          : (localItem !== null ? localItem.createdAt : Date.now());
        nextItems.push(new AgentConversationItem(
          remoteConversation.appConversationId,
          remoteConversation.conversationName.trim().length > 0 ? remoteConversation.conversationName : (localItem !== null ? localItem.title : ''),
          createdAt,
          remoteConversation.isPinned || (localItem !== null ? localItem.isPinned : false)
        ));
      }
      this.conversationItems = AgentConversationHelper.sort(nextItems);
      this.persistConversationList();
    } catch (error) {
      if (showErrorToast) {
        this.showToast(`会话列表获取失败：${this.stringifyError(error)}`);
      }
    }
  }

  upsertConversationItem(appConversationId: string, title: string = '', _preview: string = '', updatedAt: number = 0,
    forceTitleUpdate: boolean = false): void {
    const normalizedId: string = appConversationId.trim();
    if (normalizedId.length === 0) {
      return;
    }

    const normalizedUpdatedAt: number = updatedAt > 0 ? updatedAt : Date.now();
    const nextItems: Array<AgentConversationItem> = [];
    let updated: boolean = false;
    for (let index: number = 0; index < this.conversationItems.length; index++) {
      const nextItem: AgentConversationItem = this.conversationItems[index].copy();
      if (nextItem.appConversationId === normalizedId) {
        if (title.trim().length > 0 && (forceTitleUpdate || nextItem.title.trim().length === 0)) {
          nextItem.title = title.trim();
        }
        nextItem.createdAt = normalizedUpdatedAt;
        nextItems.push(nextItem);
        updated = true;
      } else {
        nextItems.push(nextItem);
      }
    }

    if (!updated) {
      nextItems.push(new AgentConversationItem(
        normalizedId,
        title.trim(),
        normalizedUpdatedAt,
        false
      ));
    }

    this.conversationItems = AgentConversationHelper.sort(nextItems);
    this.persistConversationList();
  }

  private getConversationItemIndex(appConversationId: string): number {
    for (let index: number = 0; index < this.conversationItems.length; index++) {
      if (this.conversationItems[index].appConversationId === appConversationId) {
        return index;
      }
    }
    return -1;
  }

  private cloneConversationItems(): Array<AgentConversationItem> {
    const nextItems: Array<AgentConversationItem> = [];
    for (let index: number = 0; index < this.conversationItems.length; index++) {
      nextItems.push(this.conversationItems[index].copy());
    }
    return nextItems;
  }

  private resolveConversationMenuTopFor(appConversationId: string): number {
    if (appConversationId.length === 0) {
      return 88;
    }
    let itemOffset: number = 0;
    const sections = ConversationHistoryHelper.buildSections(this.conversationItems);
    for (let sectionIndex: number = 0; sectionIndex < sections.length; sectionIndex++) {
      itemOffset += 26;
      for (let itemIndex: number = 0; itemIndex < sections[sectionIndex].items.length; itemIndex++) {
        if (sections[sectionIndex].items[itemIndex].appConversationId === appConversationId) {
          const nextTop: number = 60 + itemOffset;
          return nextTop > 500 ? 500 : nextTop;
        }
        itemOffset += 60;
      }
      itemOffset += 12;
    }
    return 88;
  }

  private async selectConversation(appConversationId: string): Promise<void> {
    if (this.isSending) {
      this.showToast('当前仍在生成中，请稍后再切换会话');
      return;
    }
    if (appConversationId.trim().length === 0) {
      return;
    }
    this.activeConversationMenuId = '';
    this.isConversationDrawerVisible = false;
    this.isRenameDialogVisible = false;
    if (this.conversationId === appConversationId) {
      return;
    }
    this.answersByMessageId.clear();
    this.messages = AgentMessageManager.buildGuideMessages((prefix: string): string => {
      return this.createMessageId(prefix);
    });
    this.conversationId = appConversationId;
    this.scheduleConfigSave();
    this.statusText = `会话 ${this.shortenId(appConversationId)} 已连接，正在同步历史...`;
    await AgentMessageManager.syncHistory(this);
  }

  private async toggleConversationPinned(appConversationId: string): Promise<void> {
    const itemIndex: number = this.getConversationItemIndex(appConversationId);
    if (itemIndex < 0) {
      return;
    }
    const config: HiAgentConfig = this.buildConfig();
    if (!config.isReady()) {
      this.showToast('请先填写接口配置');
      return;
    }
    const previousItems: Array<AgentConversationItem> = this.cloneConversationItems();
    const nextItems: Array<AgentConversationItem> = [];
    let nextPinnedState: boolean = false;
    for (let index: number = 0; index < this.conversationItems.length; index++) {
      const nextItem: AgentConversationItem = this.conversationItems[index].copy();
      if (index === itemIndex) {
        nextItem.isPinned = !nextItem.isPinned;
        nextPinnedState = nextItem.isPinned;
      }
      nextItems.push(nextItem);
    }
    this.conversationItems = AgentConversationHelper.sort(nextItems);
    this.activeConversationMenuId = '';
    this.persistConversationList();
    try {
      if (nextPinnedState) {
        await HiAgentService.setConversationTop(config, appConversationId);
      } else {
        await HiAgentService.cancelConversationTop(config, appConversationId);
      }
    } catch (error) {
      this.conversationItems = previousItems;
      this.persistConversationList();
      this.showToast(this.stringifyError(error));
    }
  }

  private openRenameConversation(appConversationId: string): void {
    const itemIndex: number = this.getConversationItemIndex(appConversationId);
    if (itemIndex < 0) {
      return;
    }
    this.renameConversationId = appConversationId;
    this.renameDraft = this.conversationItems[itemIndex].title;
    this.isRenameDialogVisible = true;
    this.activeConversationMenuId = '';
  }

  private async confirmRenameConversation(): Promise<void> {
    const normalizedTitle: string = this.sanitizeConversationTitle(this.renameDraft, false);
    if (normalizedTitle.length === 0) {
      this.showToast('会话名称不能为空');
      return;
    }
    const targetConversationId: string = this.renameConversationId;
    const itemIndex: number = this.getConversationItemIndex(targetConversationId);
    if (itemIndex < 0) {
      this.isRenameDialogVisible = false;
      return;
    }
    const config: HiAgentConfig = this.buildConfig();
    if (!config.isReady()) {
      this.showToast('请先填写接口配置');
      return;
    }
    const previousItems: Array<AgentConversationItem> = this.cloneConversationItems();
    const nextItems: Array<AgentConversationItem> = [];
    for (let index: number = 0; index < this.conversationItems.length; index++) {
      const nextItem: AgentConversationItem = this.conversationItems[index].copy();
      if (index === itemIndex) {
        nextItem.title = normalizedTitle;
      }
      nextItems.push(nextItem);
    }
    this.conversationItems = AgentConversationHelper.sort(nextItems);
    this.isRenameDialogVisible = false;
    this.renameConversationId = '';
    this.renameDraft = '';
    this.persistConversationList();
    try {
      await HiAgentService.updateConversation(config, targetConversationId, normalizedTitle);
    } catch (error) {
      this.conversationItems = previousItems;
      this.persistConversationList();
      this.showToast(this.stringifyError(error));
    }
  }

  private async deleteConversationItem(appConversationId: string): Promise<void> {
    const config: HiAgentConfig = this.buildConfig();
    if (!config.isReady()) {
      this.showToast('请先填写接口配置');
      return;
    }
    try {
      await HiAgentService.deleteConversation(config, appConversationId);
    } catch (error) {
      this.showToast(this.stringifyError(error));
      return;
    }
    const nextItems: Array<AgentConversationItem> = [];
    for (let index: number = 0; index < this.conversationItems.length; index++) {
      if (this.conversationItems[index].appConversationId !== appConversationId) {
        nextItems.push(this.conversationItems[index].copy());
      }
    }
    this.conversationItems = nextItems;
    this.activeConversationMenuId = '';
    this.persistConversationList();
    if (this.conversationId === appConversationId) {
      this.startNewConversation();
    }
  }

  async syncHistory(): Promise<void> {
    await AgentMessageManager.syncHistory(this);
  }

  getMessageById(messageId: string): ChatMessage | null {
    return AgentMessageManager.getMessageById(this, messageId);
  }

  sanitizeConversationTitle(title: string, stripControlChars: boolean): string {
    let nextTitle: string = stripControlChars ? title.replace(/[\n\r\t]/g, '') : title;
    nextTitle = nextTitle.trim();
    if (nextTitle.length > 100) {
      nextTitle = nextTitle.substring(0, 100);
    }
    return nextTitle;
  }

  buildConfig(): HiAgentConfig {
    return new HiAgentConfig(this.apiUrl, this.apiKey, this.userId);
  }

  shortenId(value: string): string {
    return AgentTextUtils.shortenId(value);
  }

  stringifyError(error: Object): string {
    return AgentTextUtils.stringifyError(error);
  }

  private getStatusBackgroundColor(): string {
    if (this.isSending) {
      return '#DBEAFE';
    }
    if (this.conversationId.length > 0) {
      return '#DCFCE7';
    }
    return '#FEF3C7';
  }

  private getStatusTextColor(): string {
    if (this.isSending) {
      return '#1D4ED8';
    }
    if (this.conversationId.length > 0) {
      return '#166534';
    }
    return '#92400E';
  }

  private async copyMessageText(messageId: string): Promise<void> {
    const message: ChatMessage | null = this.getMessageById(messageId);
    if (message === null) {
      return;
    }

    const plainText: string = message.rawContent.length > 0 ? message.rawContent : message.visibleContent;
    if (plainText.trim().length === 0) {
      this.showToast('当前回复还没有内容可复制');
      return;
    }

    try {
      const systemPasteboard = pasteboard.getSystemPasteboard();
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, plainText);
      await systemPasteboard.setData(data);
      this.showToast('已复制回复内容');
    } catch (_error) {
      this.showToast('复制失败，请稍后重试');
    }
  }

  showToast(message: string): void {
    promptAction.showToast({
      message: message,
      duration: 1800
    });
  }

  stopSpeakingMessage(showToast: boolean): void {
    AgentSpeechManager.stopSpeakingMessage(this, showToast);
  }

  createMessageId(prefix: string): string {
    return `${prefix}-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
  }
}
