import http from '@ohos.net.http';
import util from '@ohos.util';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  HiAgentAppConfigPreview,
  HiAgentChatQueryRequest,
  HiAgentConfig,
  HiAgentConversation,
  HiAgentCreateConversationRequest,
  HiAgentDeleteConversationRequest,
  HiAgentDeleteMessageRequest,
  HiAgentFeedbackRequest,
  HiAgentGetAppConfigPreviewRequest,
  HiAgentGetConversationListRequest,
  HiAgentGetConversationMessagesRequest,
  HiAgentHistoryMessage,
  HiAgentMessageAnswerInfo,
  HiAgentQueryAgainRequest,
  HiAgentSetConversationTopRequest,
  HiAgentSetMessageAnswerUsedRequest,
  HiAgentStopMessageRequest,
  HiAgentStreamEvent,
  HiAgentUpdateConversationRequest
} from '../models/HiAgentModels';
import { HiAgentSseParser } from '../utils/HiAgentSseParser';

const HIAGENT_LOG_DOMAIN: number = 0x3201;
const HIAGENT_LOG_TAG: string = 'HiAgentService';

export class HiAgentStreamSession {
  messageId: string = '';
  taskId: string = '';
  conversationId: string = '';

  private request: http.HttpRequest;
  private closed: boolean = false;

  constructor(request: http.HttpRequest) {
    this.request = request;
  }

  applyEvent(event: HiAgentStreamEvent): void {
    const normalizedEventName: string = event.event.trim().toLowerCase();
    if (event.taskId.length > 0) {
      this.taskId = event.taskId;
    }
    if (event.messageId.length > 0 && (
      normalizedEventName === 'message_start' ||
      normalizedEventName === 'message_end' ||
      normalizedEventName === 'message_failed' ||
      normalizedEventName === 'interrupted'
    )) {
      this.messageId = event.messageId;
    }
    if (event.conversationId.length > 0) {
      this.conversationId = event.conversationId;
    }
  }

  close(): void {
    if (this.closed) {
      return;
    }
    this.closed = true;
    this.request.off('headersReceive');
    this.request.off('dataReceive');
    this.request.off('dataEnd');
    this.request.destroy();
  }
}

export class HiAgentService {
  private static readonly API_PREFIX: string = '/api/proxy/api/v1';

  static async createConversation(config: HiAgentConfig): Promise<HiAgentConversation> {
    const payload: ESObject = await HiAgentService.requestJson(
      config,
      '/create_conversation',
      new HiAgentCreateConversationRequest(config.resolvedAppKey(), config.userId)
    );

    const conversationObject: ESObject = HiAgentService.readObject(payload, 'Conversation');
    const appConversationId: string = HiAgentService.readString(conversationObject, 'AppConversationID');
    if (appConversationId.length === 0) {
      throw new Error('HiAgent create_conversation 未返回 AppConversationID。');
    }

    return new HiAgentConversation(
      appConversationId,
      HiAgentService.readString(conversationObject, 'ConversationName'),
      HiAgentService.readString(conversationObject, 'CreateTime'),
      HiAgentService.readString(conversationObject, 'LastChatTime'),
      HiAgentService.readBoolean(conversationObject, 'EmptyConversation'),
      HiAgentService.readNumber(conversationObject, 'CreateTimestamp'),
      HiAgentService.readBoolean(conversationObject, 'IsPinned')
    );
  }

  static async getAppConfigPreview(config: HiAgentConfig): Promise<HiAgentAppConfigPreview> {
    const payload: ESObject = await HiAgentService.requestJson(
      config,
      '/get_app_config_preview',
      new HiAgentGetAppConfigPreviewRequest(config.resolvedAppKey(), config.userId)
    );

    return new HiAgentAppConfigPreview(
      HiAgentService.readString(payload, 'Name'),
      HiAgentService.readString(payload, 'Image'),
      HiAgentService.readString(payload, 'OpenMessage'),
      HiAgentService.readStringArray(payload, 'OpenQuery')
    );
  }

  static async getConversationList(config: HiAgentConfig): Promise<Array<HiAgentConversation>> {
    const payload: ESObject = await HiAgentService.requestJson(
      config,
      '/get_conversation_list',
      new HiAgentGetConversationListRequest(config.resolvedAppKey(), config.userId)
    );

    const conversationObjects: Array<ESObject> = HiAgentService.readObjectArray(payload, 'ConversationList');
    const conversations: Array<HiAgentConversation> = [];
    for (let index: number = 0; index < conversationObjects.length; index++) {
      const item: ESObject = conversationObjects[index];
      conversations.push(new HiAgentConversation(
        HiAgentService.readString(item, 'AppConversationID'),
        HiAgentService.readString(item, 'ConversationName'),
        HiAgentService.readString(item, 'CreateTime'),
        HiAgentService.readString(item, 'LastChatTime'),
        HiAgentService.readBoolean(item, 'EmptyConversation'),
        HiAgentService.readNumber(item, 'CreateTimestamp'),
        HiAgentService.readBoolean(item, 'IsPinned')
      ));
    }
    return conversations;
  }

  static async getConversationMessages(
    config: HiAgentConfig,
    appConversationId: string,
    limit: number = 100
  ): Promise<Array<HiAgentHistoryMessage>> {
    const payload: ESObject = await HiAgentService.requestJson(
      config,
      '/get_conversation_messages',
      new HiAgentGetConversationMessagesRequest(config.resolvedAppKey(), appConversationId, limit, config.userId)
    );

    const messageItems: Array<ESObject> = HiAgentService.readObjectArray(payload, 'Messages');
    const messages: Array<HiAgentHistoryMessage> = [];
    for (let index: number = 0; index < messageItems.length; index++) {
      const item: ESObject = messageItems[index];
      const answerInfoObject: ESObject = HiAgentService.readObject(item, 'AnswerInfo');
      const answerInfo: HiAgentMessageAnswerInfo = HiAgentService.buildMessageAnswerInfo(answerInfoObject);
      const otherAnswerObjects: Array<ESObject> = HiAgentService.readObjectArray(item, 'OtherAnswers');
      const otherAnswers: Array<HiAgentMessageAnswerInfo> = [];
      for (let answerIndex: number = 0; answerIndex < otherAnswerObjects.length; answerIndex++) {
        otherAnswers.push(HiAgentService.buildMessageAnswerInfo(otherAnswerObjects[answerIndex]));
      }
      messages.push(new HiAgentHistoryMessage(
        HiAgentService.readString(item, 'ConversationID'),
        HiAgentService.readString(item, 'QueryID'),
        HiAgentService.readString(item, 'Query'),
        HiAgentService.buildUserMessageContent(item),
        HiAgentService.buildUserMessageParts(item),
        answerInfo.answer,
        answerInfo.messageId,
        answerInfo.taskId,
        answerInfo.createdTime,
        answerInfo,
        otherAnswers
      ));
    }

    messages.sort((left: HiAgentHistoryMessage, right: HiAgentHistoryMessage) => left.createdTime - right.createdTime);
    return messages;
  }

  static async stopMessage(config: HiAgentConfig, messageId: string = '', taskId: string = ''): Promise<void> {
    if (messageId.trim().length === 0 && taskId.trim().length === 0) {
      return;
    }
    await HiAgentService.requestJson(
      config,
      '/stop_message',
      new HiAgentStopMessageRequest(config.resolvedAppKey(), config.userId, messageId.trim(), taskId.trim())
    );
  }

  static async deleteMessage(config: HiAgentConfig, messageId: string): Promise<void> {
    const normalizedMessageId: string = messageId.trim();
    await HiAgentService.requestJson(
      config,
      '/delete_message',
      new HiAgentDeleteMessageRequest(config.resolvedAppKey(), normalizedMessageId, '', config.userId)
    );
  }

  static async updateConversation(config: HiAgentConfig, appConversationId: string, conversationName: string): Promise<void> {
    await HiAgentService.requestJson(
      config,
      '/update_conversation',
      new HiAgentUpdateConversationRequest(config.resolvedAppKey(), appConversationId.trim(), conversationName, config.userId)
    );
  }

  static async deleteConversation(config: HiAgentConfig, appConversationId: string): Promise<void> {
    await HiAgentService.requestJson(
      config,
      '/delete_conversation',
      new HiAgentDeleteConversationRequest(config.resolvedAppKey(), appConversationId.trim(), config.userId)
    );
  }

  static async setConversationTop(config: HiAgentConfig, appConversationId: string): Promise<void> {
    await HiAgentService.requestJson(
      config,
      '/set_conversation_top',
      new HiAgentSetConversationTopRequest(config.resolvedAppKey(), config.userId, appConversationId.trim())
    );
  }

  static async cancelConversationTop(config: HiAgentConfig, appConversationId: string): Promise<void> {
    await HiAgentService.requestJson(
      config,
      '/cancel_conversation_top',
      new HiAgentSetConversationTopRequest(config.resolvedAppKey(), config.userId, appConversationId.trim())
    );
  }

  static async feedback(config: HiAgentConfig, messageId: string, likeType: number): Promise<void> {
    await HiAgentService.requestJson(
      config,
      '/feedback',
      new HiAgentFeedbackRequest(config.resolvedAppKey(), messageId.trim(), likeType, config.userId)
    );
  }

  static async setMessageAnswerUsed(config: HiAgentConfig, messageId: string): Promise<void> {
    await HiAgentService.requestJson(
      config,
      '/set_message_answer_used',
      new HiAgentSetMessageAnswerUsedRequest(config.resolvedAppKey(), messageId.trim(), config.userId)
    );
  }

  static startChatStream(
    config: HiAgentConfig,
    appConversationId: string,
    query: string,
    onEvent: (event: HiAgentStreamEvent) => void,
    onComplete: () => void,
    onError: (errorMessage: string) => void
  ): HiAgentStreamSession {
    return HiAgentService.startStreamRequest(
      config,
      '/chat_query',
      new HiAgentChatQueryRequest(config.resolvedAppKey(), appConversationId, query, config.userId),
      onEvent,
      onComplete,
      onError
    );
  }

  static startQueryAgainStream(
    config: HiAgentConfig,
    appConversationId: string,
    messageId: string,
    onEvent: (event: HiAgentStreamEvent) => void,
    onComplete: () => void,
    onError: (errorMessage: string) => void
  ): HiAgentStreamSession {
    return HiAgentService.startStreamRequest(
      config,
      '/query_again',
      new HiAgentQueryAgainRequest(config.resolvedAppKey(), appConversationId, messageId, config.userId),
      onEvent,
      onComplete,
      onError
    );
  }

  private static startStreamRequest(
    config: HiAgentConfig,
    path: string,
    payload: Object,
    onEvent: (event: HiAgentStreamEvent) => void,
    onComplete: () => void,
    onError: (errorMessage: string) => void
  ): HiAgentStreamSession {
    const request: http.HttpRequest = http.createHttp();
    const session: HiAgentStreamSession = new HiAgentStreamSession(request);
    const decoder: util.TextDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
    let sseBuffer: string = '';
    let rawBodyBuffer: string = '';
    let responseCode: number = 0;
    let responseCodeResolved: boolean = false;
    let finished: boolean = false;
    let pendingStreamEnd: boolean = false;

    const cleanup = (): void => {
      session.close();
    };

    const fail = (errorMessage: string): void => {
      if (finished) {
        return;
      }
      finished = true;
      cleanup();
      HiAgentService.logError(`stream request failed path=${path} error=${errorMessage}`);
      onError(errorMessage);
    };

    const emitEvents = (events: Array<HiAgentStreamEvent>): void => {
      for (let index: number = 0; index < events.length; index++) {
        const event: HiAgentStreamEvent = events[index];
        session.applyEvent(event);
        HiAgentService.logInfo(
          `stream parsed event path=${path}` +
          ` event=${event.event}` +
          ` rawData=${HiAgentService.redactSensitiveText(event.rawData)}` +
          ` answer=${HiAgentService.redactSensitiveText(event.answer)}` +
          ` thought=${HiAgentService.redactSensitiveText(event.thought)}` +
          ` detail=${HiAgentService.redactSensitiveText(event.detailMessage)}` +
          ` error=${HiAgentService.redactSensitiveText(event.errorMessage)}` +
          ` taskId=${event.taskId}` +
          ` messageId=${event.messageId}` +
          ` conversationId=${event.conversationId}` +
          ` createdAt=${event.createdAt}` +
          ` inputTokens=${event.inputTokens}` +
          ` outputTokens=${event.outputTokens}` +
          ` latency=${event.latency}`
        );
        onEvent(event);
      }
    };

    const finalizeStream = (tailText: string = '', waitAttempt: number = 0): void => {
      if (finished) {
        return;
      }
      if (!responseCodeResolved) {
        if (waitAttempt >= 10) {
          fail(HiAgentService.extractApiErrorMessageFromText(
            rawBodyBuffer + tailText,
            'HiAgent 流式请求失败，未获取到有效状态码。'
          ));
          return;
        }
        setTimeout(() => {
          finalizeStream(tailText, waitAttempt + 1);
        }, 30);
        return;
      }

      if (responseCode < 200 || responseCode >= 300) {
        fail(HiAgentService.extractApiErrorMessageFromText(
          rawBodyBuffer + tailText,
          `HiAgent 流式请求失败，HTTP ${responseCode}。`
        ));
        return;
      }

      const parsed = HiAgentSseParser.parseChunk(tailText, sseBuffer);
      sseBuffer = parsed.remaining;
      emitEvents(parsed.events);
      emitEvents(HiAgentSseParser.flushRemaining(sseBuffer));
      sseBuffer = '';

      finished = true;
      cleanup();
      HiAgentService.logInfo(`stream completed path=${path}`);
      onComplete();
    };

    request.on('dataReceive', (chunk: ArrayBuffer) => {
      if (finished) {
        return;
      }
      const chunkText: string = decoder.decodeToString(new Uint8Array(chunk), { stream: true });
      rawBodyBuffer += chunkText;
      HiAgentService.logInfo(`stream raw chunk path=${path} chunk=${HiAgentService.redactSensitiveText(chunkText)}`);
      if (responseCode > 0 && (responseCode < 200 || responseCode >= 300)) {
        return;
      }
      const parsed = HiAgentSseParser.parseChunk(chunkText, sseBuffer);
      sseBuffer = parsed.remaining;
      emitEvents(parsed.events);
    });

    request.on('dataEnd', () => {
      if (finished) {
        return;
      }

      pendingStreamEnd = true;
      const tailText: string = decoder.decodeToString(new Uint8Array(0), { stream: false });
      rawBodyBuffer += tailText;
      finalizeStream(tailText);
    });

    request.on('headersReceive', (headers: Object) => {
      HiAgentService.logInfo(`stream headers path=${path} headers=${HiAgentService.safeStringify(headers)}`);
    });

    const streamUrl: string = HiAgentService.buildUrl(config.apiUrl, path);
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        'Apikey': config.apiKey.trim()
      },
      extraData: JSON.stringify(payload),
      readTimeout: 0,
      connectTimeout: 60000
    };
    HiAgentService.logInfo(`stream request start path=${path} url=${streamUrl} payload=${HiAgentService.safeStringify(payload)}`);

    void request.requestInStream(streamUrl, options).then((streamResponseCode: number) => {
      if (finished) {
        return;
      }
      responseCode = Number(streamResponseCode);
      responseCodeResolved = true;
      HiAgentService.logInfo(`stream response code path=${path} code=${responseCode}`);
      if (pendingStreamEnd) {
        finalizeStream();
      }
    }).catch((error: Object) => {
      fail(HiAgentService.stringifyError(error));
    });

    return session;
  }

  private static async requestJson(config: HiAgentConfig, path: string, payload: ESObject): Promise<ESObject> {
    const request: http.HttpRequest = http.createHttp();
    const requestUrl: string = HiAgentService.buildUrl(config.apiUrl, path);
    HiAgentService.logInfo(`json request start path=${path} url=${requestUrl} payload=${HiAgentService.safeStringify(payload)}`);
    try {
      const response: http.HttpResponse = await request.request(requestUrl, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Apikey': config.apiKey.trim()
        },
        extraData: JSON.stringify(payload),
        expectDataType: http.HttpDataType.STRING,
        readTimeout: 60000,
        connectTimeout: 60000
      });

      const responseText: string = HiAgentService.readResponseText(response.result);
      const responseCode: number = Number(response.responseCode);
      HiAgentService.logInfo(`json response path=${path} code=${responseCode} body=${HiAgentService.redactSensitiveText(responseText)}`);
      const payloadObject: ESObject = responseText.trim().length > 0 ? JSON.parse(responseText) as ESObject : {};
      const responseMetadataErrorMessage: string = HiAgentService.readResponseMetadataErrorMessage(payloadObject);
      if (responseCode < 200 || responseCode >= 300) {
        if (responseMetadataErrorMessage.length > 0) {
          throw new Error(responseMetadataErrorMessage);
        }
        throw new Error(`HiAgent 请求失败，HTTP ${responseCode}：${responseText}`);
      }
      if (responseMetadataErrorMessage.length > 0) {
        throw new Error(responseMetadataErrorMessage);
      }
      if (responseText.trim().length === 0) {
        return {};
      }
      return payloadObject;
    } catch (error) {
      HiAgentService.logError(`json request failed path=${path} error=${HiAgentService.stringifyError(error)}`);
      throw new Error(HiAgentService.stringifyError(error));
    } finally {
      request.destroy();
    }
  }

  private static buildUrl(apiUrl: string, path: string): string {
    let trimmed: string = apiUrl.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }

    if (trimmed.endsWith(HiAgentService.API_PREFIX)) {
      return `${trimmed}${path}`;
    }
    return `${trimmed}${HiAgentService.API_PREFIX}${path}`;
  }

  private static readResponseText(result: string | Object | ArrayBuffer): string {
    if (typeof result === 'string') {
      return result;
    }
    if (result instanceof ArrayBuffer) {
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      return decoder.decodeToString(new Uint8Array(result), { stream: false });
    }
    return JSON.stringify(result);
  }

  private static readString(source: ESObject, key: string): string {
    const value: Object = source[key];
    return typeof value === 'string' ? value : '';
  }

  private static readNumber(source: ESObject, key: string): number {
    const value: Object = source[key];
    return typeof value === 'number' ? value : 0;
  }

  private static readBoolean(source: ESObject, key: string): boolean {
    const value: Object = source[key];
    return typeof value === 'boolean' ? value : false;
  }

  private static readObject(source: ESObject, key: string): ESObject {
    const value: Object = source[key];
    if (typeof value === 'object' && value !== null && !(value instanceof Array)) {
      return value as ESObject;
    }
    return {};
  }

  private static readObjectArray(source: ESObject, key: string): Array<ESObject> {
    const value: Object = source[key];
    if (!(value instanceof Array)) {
      return [];
    }

    const results: Array<ESObject> = [];
    for (let index: number = 0; index < value.length; index++) {
      if (typeof value[index] === 'object' && value[index] !== null) {
        results.push(value[index] as ESObject);
      }
    }
    return results;
  }

  private static readStringArray(source: ESObject, key: string): Array<string> {
    const value: Object = source[key];
    if (!(value instanceof Array)) {
      return [];
    }

    const results: Array<string> = [];
    for (let index: number = 0; index < value.length; index++) {
      if (typeof value[index] === 'string') {
        const item: string = (value[index] as string).trim();
        if (item.length > 0) {
          results.push(item);
        }
      }
    }
    return results;
  }

  private static buildMessageAnswerInfo(source: ESObject): HiAgentMessageAnswerInfo {
    return new HiAgentMessageAnswerInfo(
      HiAgentService.readString(source, 'Answer'),
      HiAgentService.readString(source, 'MessageID'),
      HiAgentService.readNumber(source, 'CreatedTime'),
      HiAgentService.readString(source, 'TaskID'),
      HiAgentService.readNumber(source, 'Like'),
      HiAgentService.readNumber(source, 'TotalTokens'),
      HiAgentService.readNumber(source, 'Latency'),
      HiAgentService.readString(source, 'TracingJsonStr')
    );
  }

  private static buildUserMessageContent(source: ESObject): string {
    return HiAgentService.buildUserMessageParts(source).join('\n\n');
  }

  private static buildUserMessageParts(source: ESObject): Array<string> {
    const userMessageObject: ESObject = HiAgentService.readObject(source, 'UserMessage');
    const userMessageItems: Array<ESObject> = HiAgentService.readObjectArray(userMessageObject, 'Messages');
    if (userMessageItems.length === 0) {
      return [];
    }

    const contentParts: Array<string> = [];
    for (let index: number = 0; index < userMessageItems.length; index++) {
      const item: ESObject = userMessageItems[index];
      const type: string = HiAgentService.readString(item, 'type').trim().toLowerCase();
      if (type === 'text') {
        const text: string = HiAgentService.readString(item, 'text').trim();
        if (text.length > 0) {
          contentParts.push(text);
        }
        continue;
      }
      if (type === 'image') {
        const imageObject: ESObject = HiAgentService.readObject(item, 'image');
        const imageUrl: string = HiAgentService.readString(imageObject, 'url').trim();
        if (imageUrl.length === 0) {
          continue;
        }
        const imageName: string = HiAgentService.readString(imageObject, 'name').trim();
        const altText: string = imageName.length > 0 ? imageName : 'image';
        contentParts.push(`![${altText}](${imageUrl})`);
      }
    }
    return contentParts;
  }

  private static readResponseMetadataErrorMessage(source: ESObject): string {
    const responseMetadata: ESObject = HiAgentService.readObject(source, 'ResponseMetadata');
    const errorObject: ESObject = HiAgentService.readObject(responseMetadata, 'Error');
    return HiAgentService.readString(errorObject, 'Message').trim();
  }

  private static extractApiErrorMessageFromText(responseText: string, fallbackMessage: string): string {
    const normalizedText: string = responseText.trim();
    if (normalizedText.length === 0) {
      return fallbackMessage;
    }

    try {
      const payloadObject: ESObject = JSON.parse(normalizedText) as ESObject;
      const responseMetadataErrorMessage: string = HiAgentService.readResponseMetadataErrorMessage(payloadObject);
      if (responseMetadataErrorMessage.length > 0) {
        return responseMetadataErrorMessage;
      }
    } catch (_error) {
      // Ignore parse failure and fall back to raw text.
    }

    return fallbackMessage.length > 0 ? `${fallbackMessage} ${normalizedText}` : normalizedText;
  }

  private static stringifyError(error: Object): string {
    if (typeof error === 'string') {
      return error;
    }
    if (typeof error === 'object' && error !== null) {
      const message: Object = (error as ESObject)['message'];
      if (typeof message === 'string' && message.length > 0) {
        return message;
      }
    }
    return `${error}`;
  }

  private static logInfo(message: string): void {
    hilog.info(HIAGENT_LOG_DOMAIN, HIAGENT_LOG_TAG, '%{public}s', message);
  }

  private static logError(message: string): void {
    hilog.error(HIAGENT_LOG_DOMAIN, HIAGENT_LOG_TAG, '%{public}s', message);
  }

  private static safeStringify(value: Object): string {
    return HiAgentService.redactSensitiveText(JSON.stringify(value));
  }

  private static redactSensitiveText(value: string): string {
    if (value.length === 0) {
      return value;
    }

    return value
      .replace(/"Apikey"\s*:\s*"([^"]*)"/gi, '"Apikey":"***"')
      .replace(/"apiKey"\s*:\s*"([^"]*)"/gi, '"apiKey":"***"')
      .replace(/"AppKey"\s*:\s*"([^"]*)"/gi, '"AppKey":"***"')
      .replace(/"appKey"\s*:\s*"([^"]*)"/gi, '"appKey":"***"')
      .replace(/Apikey:\s*([^\s,]+)/gi, 'Apikey:***')
      .replace(/AppKey:\s*([^\s,]+)/gi, 'AppKey:***');
  }
}
