import http from '@ohos.net.http';
import util from '@ohos.util';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  HiAgentChatQueryRequest,
  HiAgentConfig,
  HiAgentConversation,
  HiAgentCreateConversationRequest,
  HiAgentDeleteMessageRequest,
  HiAgentFeedbackRequest,
  HiAgentGetConversationMessagesRequest,
  HiAgentHistoryMessage,
  HiAgentGetMessageInfoRequest,
  HiAgentMessageAnswerInfo,
  HiAgentMessageInfo,
  HiAgentQueryAgainRequest,
  HiAgentSetMessageAnswerUsedRequest,
  HiAgentStopMessageRequest,
  HiAgentStreamEvent
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
      this.messageId = event.taskId;
    } else if (event.messageId.length > 0 && (
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
      HiAgentService.readString(conversationObject, 'ConversationName')
    );
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
      const answerInfo: ESObject = HiAgentService.readObject(item, 'AnswerInfo');
      messages.push(new HiAgentHistoryMessage(
        HiAgentService.readString(item, 'ConversationID'),
        HiAgentService.readString(item, 'QueryID'),
        HiAgentService.readString(item, 'Query'),
        HiAgentService.readString(answerInfo, 'Answer'),
        HiAgentService.readString(answerInfo, 'MessageID'),
        HiAgentService.readString(answerInfo, 'TaskID'),
        HiAgentService.readNumber(answerInfo, 'CreatedTime')
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

  static async getMessageInfo(config: HiAgentConfig, messageId: string): Promise<HiAgentMessageInfo> {
    const payload: ESObject = await HiAgentService.requestJson(
      config,
      '/get_message_info',
      new HiAgentGetMessageInfoRequest(config.resolvedAppKey(), messageId.trim(), config.userId)
    );

    const messageInfoObject: ESObject = HiAgentService.readObject(payload, 'MessageInfo');
    const answerInfoObject: ESObject = HiAgentService.readObject(messageInfoObject, 'AnswerInfo');
    const otherAnswerObjects: Array<ESObject> = HiAgentService.readObjectArray(messageInfoObject, 'OtherAnswers');
    const otherAnswers: Array<HiAgentMessageAnswerInfo> = [];
    for (let index: number = 0; index < otherAnswerObjects.length; index++) {
      otherAnswers.push(HiAgentService.buildMessageAnswerInfo(otherAnswerObjects[index]));
    }

    return new HiAgentMessageInfo(
      HiAgentService.readString(messageInfoObject, 'ConversationID'),
      HiAgentService.readString(messageInfoObject, 'QueryID'),
      HiAgentService.readString(messageInfoObject, 'Query'),
      HiAgentService.buildMessageAnswerInfo(answerInfoObject),
      otherAnswers
    );
  }

  static async deleteMessage(config: HiAgentConfig, messageId: string, queryId: string): Promise<void> {
    await HiAgentService.requestJson(
      config,
      '/delete_message',
      new HiAgentDeleteMessageRequest(config.resolvedAppKey(), messageId.trim(), queryId.trim(), config.userId)
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
    let finished: boolean = false;

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

    request.on('dataReceive', (chunk: ArrayBuffer) => {
      if (finished) {
        return;
      }
      const chunkText: string = decoder.decodeToString(new Uint8Array(chunk), { stream: true });
      HiAgentService.logInfo(`stream raw chunk path=${path} chunk=${HiAgentService.redactSensitiveText(chunkText)}`);
      const parsed = HiAgentSseParser.parseChunk(chunkText, sseBuffer);
      sseBuffer = parsed.remaining;
      emitEvents(parsed.events);
    });

    request.on('dataEnd', () => {
      if (finished) {
        return;
      }

      const tailText: string = decoder.decodeToString(new Uint8Array(0), { stream: false });
      const parsed = HiAgentSseParser.parseChunk(tailText, sseBuffer);
      sseBuffer = parsed.remaining;
      emitEvents(parsed.events);
      emitEvents(HiAgentSseParser.flushRemaining(sseBuffer));
      sseBuffer = '';

      finished = true;
      cleanup();
      HiAgentService.logInfo(`stream completed path=${path}`);
      onComplete();
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

    void request.requestInStream(streamUrl, options).then((responseCode: number) => {
      if (finished) {
        return;
      }
      HiAgentService.logInfo(`stream response code path=${path} code=${responseCode}`);
      if (responseCode < 200 || responseCode >= 300) {
        fail(`HiAgent chat_query 返回异常状态码 ${responseCode}。`);
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
      if (responseCode < 200 || responseCode >= 300) {
        throw new Error(`HiAgent 请求失败，HTTP ${responseCode}：${responseText}`);
      }
      if (responseText.trim().length === 0) {
        return {};
      }
      return JSON.parse(responseText) as ESObject;
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
