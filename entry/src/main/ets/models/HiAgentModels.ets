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

export class HiAgentQueryAgainRequest {
  AppKey: string;
  AppConversationID: string;
  MessageID: string;
  ResponseMode: string;
  UserID: string;

  constructor(appKey: string, appConversationId: string, messageId: string, userId: string) {
    this.AppKey = appKey;
    this.AppConversationID = appConversationId;
    this.MessageID = messageId;
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

export class HiAgentGetMessageInfoRequest {
  AppKey: string;
  MessageID: string;
  UserID: string;

  constructor(appKey: string, messageId: string, userId: string) {
    this.AppKey = appKey;
    this.MessageID = messageId;
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

export class HiAgentDeleteMessageRequest {
  AppKey: string;
  MessageID: string;
  QueryID: string;
  UserID: string;

  constructor(appKey: string, messageId: string, queryId: string, userId: string) {
    this.AppKey = appKey;
    this.MessageID = messageId;
    this.QueryID = queryId;
    this.UserID = userId;
  }
}

export class HiAgentFeedbackRequest {
  AppKey: string;
  MessageID: string;
  LikeType: number;
  UserID: string;

  constructor(appKey: string, messageId: string, likeType: number, userId: string) {
    this.AppKey = appKey;
    this.MessageID = messageId;
    this.LikeType = likeType;
    this.UserID = userId;
  }
}

export class HiAgentSetMessageAnswerUsedRequest {
  AppKey: string;
  MessageID: string;
  UserID: string;

  constructor(appKey: string, messageId: string, userId: string) {
    this.AppKey = appKey;
    this.MessageID = messageId;
    this.UserID = userId;
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

export class HiAgentMessageAnswerInfo {
  answer: string;
  messageId: string;
  createdTime: number;
  taskId: string;
  like: number;
  totalTokens: number;
  latency: number;
  tracingJsonStr: string;

  constructor(
    answer: string = '',
    messageId: string = '',
    createdTime: number = 0,
    taskId: string = '',
    like: number = 0,
    totalTokens: number = 0,
    latency: number = 0,
    tracingJsonStr: string = ''
  ) {
    this.answer = answer;
    this.messageId = messageId;
    this.createdTime = createdTime;
    this.taskId = taskId;
    this.like = like;
    this.totalTokens = totalTokens;
    this.latency = latency;
    this.tracingJsonStr = tracingJsonStr;
  }
}

export class HiAgentMessageInfo {
  conversationId: string;
  queryId: string;
  query: string;
  answerInfo: HiAgentMessageAnswerInfo;
  otherAnswers: Array<HiAgentMessageAnswerInfo>;

  constructor(
    conversationId: string = '',
    queryId: string = '',
    query: string = '',
    answerInfo: HiAgentMessageAnswerInfo = new HiAgentMessageAnswerInfo(),
    otherAnswers: Array<HiAgentMessageAnswerInfo> = []
  ) {
    this.conversationId = conversationId;
    this.queryId = queryId;
    this.query = query;
    this.answerInfo = answerInfo;
    this.otherAnswers = otherAnswers;
  }
}

export class HiAgentStreamEvent {
  event: string;
  rawData: string;
  status: string;
  answer: string;
  thought: string;
  detailMessage: string;
  errorMessage: string;
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
    this.status = '';
    this.answer = '';
    this.thought = '';
    this.detailMessage = '';
    this.errorMessage = '';
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
