export class HiAgentConfig {
  apiUrl: string;
  apiKey: string;
  userId: string;
  appKey: string;

  constructor(apiUrl: string = '', apiKey: string = '', userId: string = '', appKey: string = '') {
    this.apiUrl = apiUrl;
    this.apiKey = apiKey;
    this.userId = userId;
    this.appKey = appKey;
  }

  isReady(): boolean {
    return this.apiUrl.trim().length > 0 && this.apiKey.trim().length > 0 && this.userId.trim().length > 0;
  }

  resolvedAppKey(): string {
    const nextAppKey: string = this.appKey.trim();
    if (nextAppKey.length > 0) {
      return nextAppKey;
    }
    return this.apiKey.trim();
  }
}

export class HiAgentConversation {
  appConversationId: string;
  conversationName: string;

  constructor(appConversationId: string = '', conversationName: string = '') {
    this.appConversationId = appConversationId;
    this.conversationName = conversationName;
  }
}

export class HiAgentCreateConversationRequest {
  AppKey: string;
  UserID: string;

  constructor(appKey: string, userId: string) {
    this.AppKey = appKey;
    this.UserID = userId;
  }
}

export class HiAgentChatQueryRequest {
  AppKey: string;
  AppConversationID: string;
  Query: string;
  ResponseMode: string;
  UserID: string;

  constructor(appKey: string, appConversationId: string, query: string, userId: string) {
    this.AppKey = appKey;
    this.AppConversationID = appConversationId;
    this.Query = query;
    this.ResponseMode = 'streaming';
    this.UserID = userId;
  }
}

export class HiAgentGetConversationMessagesRequest {
  AppKey: string;
  AppConversationID: string;
  Limit: number;
  UserID: string;

  constructor(appKey: string, appConversationId: string, limit: number, userId: string) {
    this.AppKey = appKey;
    this.AppConversationID = appConversationId;
    this.Limit = limit;
    this.UserID = userId;
  }
}

export class HiAgentStopMessageRequest {
  AppKey: string;
  UserID: string;
  MessageID: string;
  TaskID: string;

  constructor(appKey: string, userId: string, messageId: string = '', taskId: string = '') {
    this.AppKey = appKey;
    this.UserID = userId;
    this.MessageID = messageId;
    this.TaskID = taskId;
  }
}

export class HiAgentHistoryMessage {
  conversationId: string;
  queryId: string;
  query: string;
  answer: string;
  messageId: string;
  taskId: string;
  createdTime: number;

  constructor(
    conversationId: string = '',
    queryId: string = '',
    query: string = '',
    answer: string = '',
    messageId: string = '',
    taskId: string = '',
    createdTime: number = 0
  ) {
    this.conversationId = conversationId;
    this.queryId = queryId;
    this.query = query;
    this.answer = answer;
    this.messageId = messageId;
    this.taskId = taskId;
    this.createdTime = createdTime;
  }
}

export class HiAgentStreamEvent {
  event: string;
  rawData: string;
  answer: string;
  taskId: string;
  messageId: string;
  conversationId: string;
  createdAt: number;
  inputTokens: number;
  outputTokens: number;
  latency: number;

  constructor(rawData: string = '') {
    this.event = '';
    this.rawData = rawData;
    this.answer = '';
    this.taskId = '';
    this.messageId = '';
    this.conversationId = '';
    this.createdAt = 0;
    this.inputTokens = 0;
    this.outputTokens = 0;
    this.latency = 0;
  }
}

export class HiAgentSseParseResult {
  events: Array<HiAgentStreamEvent>;
  remaining: string;

  constructor(events: Array<HiAgentStreamEvent> = [], remaining: string = '') {
    this.events = events;
    this.remaining = remaining;
  }
}
