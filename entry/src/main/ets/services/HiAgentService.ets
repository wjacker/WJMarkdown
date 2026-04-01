import http from '@ohos.net.http';
import util from '@ohos.util';
import {
  HiAgentChatQueryRequest,
  HiAgentConfig,
  HiAgentConversation,
  HiAgentCreateConversationRequest,
  HiAgentGetConversationMessagesRequest,
  HiAgentHistoryMessage,
  HiAgentStopMessageRequest,
  HiAgentStreamEvent
} from '../models/HiAgentModels';
import { HiAgentSseParser } from '../utils/HiAgentSseParser';

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
    if (event.messageId.length > 0) {
      this.messageId = event.messageId;
    }
    if (event.taskId.length > 0) {
      this.taskId = event.taskId;
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

  static startChatStream(
    config: HiAgentConfig,
    appConversationId: string,
    query: string,
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
      onError(errorMessage);
    };

    const emitEvents = (events: Array<HiAgentStreamEvent>): void => {
      for (let index: number = 0; index < events.length; index++) {
        const event: HiAgentStreamEvent = events[index];
        session.applyEvent(event);
        onEvent(event);
      }
    };

    request.on('dataReceive', (chunk: ArrayBuffer) => {
      if (finished) {
        return;
      }
      const chunkText: string = decoder.decodeToString(new Uint8Array(chunk), { stream: true });
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
      onComplete();
    });

    request.on('headersReceive', (_headers: Object) => {
      // Header callbacks are registered so the stream can be inspected later if needed.
    });

    const payload: HiAgentChatQueryRequest = new HiAgentChatQueryRequest(
      config.resolvedAppKey(),
      appConversationId,
      query,
      config.userId
    );

    const streamUrl: string = HiAgentService.buildUrl(config.apiUrl, '/chat_query');
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

    void request.requestInStream(streamUrl, options).then((responseCode: number) => {
      if (finished) {
        return;
      }
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
    try {
      const response: http.HttpResponse = await request.request(HiAgentService.buildUrl(config.apiUrl, path), {
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
      if (responseCode < 200 || responseCode >= 300) {
        throw new Error(`HiAgent 请求失败，HTTP ${responseCode}：${responseText}`);
      }
      if (responseText.trim().length === 0) {
        return {};
      }
      return JSON.parse(responseText) as ESObject;
    } catch (error) {
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
}
