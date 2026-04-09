import { ChatMessagePhase } from './ChatModels';

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
  createTime: string;
  lastChatTime: string;
  emptyConversation: boolean;
  createTimestamp: number;
  isPinned: boolean;

  constructor(
    appConversationId: string = '',
    conversationName: string = '',
    createTime: string = '',
    lastChatTime: string = '',
    emptyConversation: boolean = false,
    createTimestamp: number = 0,
    isPinned: boolean = false
  ) {
    this.appConversationId = appConversationId;
    this.conversationName = conversationName;
    this.createTime = createTime;
    this.lastChatTime = lastChatTime;
    this.emptyConversation = emptyConversation;
    this.createTimestamp = createTimestamp;
    this.isPinned = isPinned;
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

export class HiAgentGetConversationListRequest {
  AppKey: string;
  UserID: string;

  constructor(appKey: string, userId: string) {
    this.AppKey = appKey;
    this.UserID = userId;
  }
}

export class HiAgentUpdateConversationRequest {
  AppKey: string;
  AppConversationID: string;
  ConversationName: string;
  UserID: string;

  constructor(appKey: string, appConversationId: string, conversationName: string, userId: string) {
    this.AppKey = appKey;
    this.AppConversationID = appConversationId;
    this.ConversationName = conversationName;
    this.UserID = userId;
  }
}

export class HiAgentDeleteConversationRequest {
  AppKey: string;
  AppConversationID: string;
  UserID: string;

  constructor(appKey: string, appConversationId: string, userId: string) {
    this.AppKey = appKey;
    this.AppConversationID = appConversationId;
    this.UserID = userId;
  }
}

export class HiAgentSetConversationTopRequest {
  AppKey: string;
  UserID: string;
  AppConversationID: string;

  constructor(appKey: string, userId: string, appConversationId: string) {
    this.AppKey = appKey;
    this.UserID = userId;
    this.AppConversationID = appConversationId;
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
  answerInfo: HiAgentMessageAnswerInfo;
  otherAnswers: Array<HiAgentMessageAnswerInfo>;

  constructor(
    conversationId: string = '',
    queryId: string = '',
    query: string = '',
    answer: string = '',
    messageId: string = '',
    taskId: string = '',
    createdTime: number = 0,
    answerInfo: HiAgentMessageAnswerInfo = new HiAgentMessageAnswerInfo(),
    otherAnswers: Array<HiAgentMessageAnswerInfo> = []
  ) {
    this.conversationId = conversationId;
    this.queryId = queryId;
    this.query = query;
    this.answer = answer;
    this.messageId = messageId;
    this.taskId = taskId;
    this.createdTime = createdTime;
    this.answerInfo = answerInfo;
    this.otherAnswers = otherAnswers;
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

export class HiAgentEventHelper {
  static normalizeEventName(eventName: string): string {
    return eventName.trim().toLowerCase();
  }

  static isRootMessageEvent(eventName: string): boolean {
    return eventName === 'message_start' ||
      eventName === 'message_end' ||
      eventName === 'message_failed' ||
      eventName === 'interrupted';
  }

  static resolveEventLabel(eventName: string, phase: ChatMessagePhase, event: HiAgentStreamEvent): string {
    if (eventName === 'message_start') {
      return '消息开始';
    }
    if (eventName === 'message_output_start') {
      return '开始输出';
    }
    if (eventName === 'message') {
      return '回答中';
    }
    if (eventName === 'message_replace') {
      return '回答修正中';
    }
    if (eventName === 'message_output_end') {
      return '输出结束';
    }
    if (eventName === 'message_end') {
      return '已结束';
    }
    if (eventName === 'message_cost') {
      return '消息消耗统计';
    }
    if (eventName === 'suggestion') {
      return '问题建议中';
    }
    if (eventName === 'suggestion_cost') {
      return '建议消耗统计';
    }
    if (eventName === 'agent_thought' || eventName === 'think_message') {
      return 'AI 正在思考中';
    }
    if (eventName === 'agent_thought_end' || eventName === 'think_message_output_end') {
      return '思考结束';
    }
    if (eventName === 'think_message_output_start') {
      return '思考开始';
    }
    if (eventName === 'knowledge_retrieve') {
      return '知识库检索中';
    }
    if (eventName === 'knowledge_retrieve_end') {
      return '知识库检索结束';
    }
    if (eventName === 'qa_retrieve') {
      return '问答库检索中';
    }
    if (eventName === 'qa_retrieve_end') {
      return '问答库检索结束';
    }
    if (eventName === 'knowledge_graph_retrieve') {
      return '图谱库检索中';
    }
    if (eventName === 'knowledge_graph_retrieve_end') {
      return '图谱库检索结束';
    }
    if (eventName === 'terminology_retrieve') {
      return '术语库检索中';
    }
    if (eventName === 'terminology_retrieve_end') {
      return '术语库检索结束';
    }
    if (eventName === 'agent_jump') {
      return 'Agent 跳转中';
    }
    if (eventName === 'agent_take_over') {
      return 'Agent 接管回答';
    }
    if (eventName === 'intention') {
      return '意图识别中';
    }
    if (eventName === 'tool_message') {
      return '工具处理中';
    }
    if (eventName === 'flow_start') {
      return '流程开始';
    }
    if (eventName === 'flow_end') {
      return '流程结束';
    }
    if (eventName === 'message_failed') {
      return '消息失败';
    }
    if (eventName === 'interrupted') {
      return '已停止';
    }
    if (phase === ChatMessagePhase.Finished) {
      return '已结束';
    }
    return '';
  }

  static isThinkingEvent(eventName: string, status: string, thought: string): boolean {
    const normalizedStatus: string = status.trim().toLowerCase();
    if (thought.trim().length > 0) {
      return true;
    }
    return eventName === 'message_start' ||
      eventName === 'flow_start' ||
      eventName === 'agent_thought' ||
      eventName === 'agent_thought_end' ||
      eventName === 'think_message_output_start' ||
      eventName === 'think_message' ||
      eventName === 'think_message_output_end' ||
      eventName === 'knowledge_retrieve' ||
      eventName === 'knowledge_retrieve_end' ||
      eventName === 'qa_retrieve' ||
      eventName === 'qa_retrieve_end' ||
      eventName === 'knowledge_graph_retrieve' ||
      eventName === 'knowledge_graph_retrieve_end' ||
      eventName === 'terminology_retrieve' ||
      eventName === 'terminology_retrieve_end' ||
      eventName === 'tool_message' ||
      eventName === 'agent_jump' ||
      eventName === 'agent_take_over' ||
      eventName === 'intention' ||
      eventName === 'thinking' ||
      eventName === 'thought' ||
      eventName === 'workflow_started' ||
      normalizedStatus === 'running' ||
      normalizedStatus === 'queued';
  }

  static isErrorEvent(eventName: string, status: string): boolean {
    const normalizedStatus: string = status.trim().toLowerCase();
    return eventName === 'error' || eventName === 'message_error' || eventName === 'message_failed' ||
      normalizedStatus === 'error' ||
      normalizedStatus === 'failed';
  }

  static isStoppedEvent(eventName: string): boolean {
    return eventName === 'interrupted' || eventName === 'stopped';
  }

  static isProgressOnlyEvent(eventName: string): boolean {
    return eventName === 'message_cost' || eventName === 'suggestion' || eventName === 'suggestion_cost';
  }

  static extractEventErrorMessage(event: HiAgentStreamEvent): string {
    if (event.errorMessage.trim().length > 0) {
      return event.errorMessage.trim();
    }
    if (event.detailMessage.trim().length > 0) {
      return event.detailMessage.trim();
    }
    if (event.rawData.trim().length > 0) {
      return event.rawData.trim();
    }
    return '流式接口返回异常。';
  }
}
