import { HiAgentSseParseResult, HiAgentStreamEvent } from '../models/HiAgentModels';

export class HiAgentSseParser {
  static parseChunk(chunk: string, remaining: string = ''): HiAgentSseParseResult {
    const merged: string = `${remaining}${chunk}`.replace(/\r\n/g, '\n');
    const frames: Array<string> = merged.split('\n\n');
    let nextRemaining: string = '';
    if (!merged.endsWith('\n\n')) {
      nextRemaining = frames.pop() ?? '';
    }

    const events: Array<HiAgentStreamEvent> = [];
    for (let index: number = 0; index < frames.length; index++) {
      const nextEvent: HiAgentStreamEvent | null = HiAgentSseParser.parseFrame(frames[index]);
      if (nextEvent !== null) {
        events.push(nextEvent);
      }
    }
    return new HiAgentSseParseResult(events, nextRemaining);
  }

  static flushRemaining(remaining: string): Array<HiAgentStreamEvent> {
    const trimmed: string = remaining.trim();
    if (trimmed.length === 0) {
      return [];
    }
    const nextEvent: HiAgentStreamEvent | null = HiAgentSseParser.parseFrame(trimmed);
    return nextEvent === null ? [] : [nextEvent];
  }

  private static parseFrame(frame: string): HiAgentStreamEvent | null {
    const lines: Array<string> = frame.split('\n');
    let eventName: string = '';
    const dataLines: Array<string> = [];

    for (let index: number = 0; index < lines.length; index++) {
      const line: string = lines[index].trim();
      if (line.length === 0) {
        continue;
      }
      if (line.startsWith('event:')) {
        eventName = line.substring(6).trim();
        continue;
      }
      if (line.startsWith('data:')) {
        dataLines.push(HiAgentSseParser.normalizeDataPayload(line.substring(5).trim()));
      }
    }

    const payload: string = dataLines.join('\n').trim();
    if (payload.length === 0 || payload === '[DONE]') {
      return null;
    }

    const nextEvent: HiAgentStreamEvent = new HiAgentStreamEvent(payload);
    nextEvent.event = eventName;

    try {
      const data: ESObject = JSON.parse(payload) as ESObject;
      const parsedEvent: string = HiAgentSseParser.readFirstString(data, ['event', 'type']);
      nextEvent.event = parsedEvent.length > 0 ? parsedEvent : nextEvent.event;
      nextEvent.status = HiAgentSseParser.readFirstString(data, ['status']);
      nextEvent.answer = HiAgentSseParser.readFirstString(data, ['answer', 'delta', 'text', 'content']);
      nextEvent.thought = HiAgentSseParser.readFirstString(data, ['thought', 'thinking', 'reasoning']);
      nextEvent.detailMessage = HiAgentSseParser.readFirstString(data, ['message', 'msg', 'detail']);
      nextEvent.errorMessage = HiAgentSseParser.readFirstString(data, ['error', 'error_message', 'errmsg', 'reason']);
      nextEvent.taskId = HiAgentSseParser.readFirstString(data, ['task_id', 'taskId']);
      nextEvent.messageId = HiAgentSseParser.readFirstString(data, ['id', 'message_id', 'messageId']);
      nextEvent.conversationId = HiAgentSseParser.readFirstString(data, ['conversation_id', 'conversationId']);
      nextEvent.createdAt = HiAgentSseParser.readFirstNumber(data, ['created_at', 'createdAt']);
      nextEvent.inputTokens = HiAgentSseParser.readFirstNumber(data, ['input_tokens', 'inputTokens']);
      nextEvent.outputTokens = HiAgentSseParser.readFirstNumber(data, ['output_tokens', 'outputTokens']);
      nextEvent.latency = HiAgentSseParser.readFirstNumber(data, ['latency']);
    } catch (_error) {
      if (nextEvent.event.length === 0) {
        nextEvent.event = 'text';
      }
      nextEvent.answer = payload;
    }

    if (nextEvent.event.length === 0) {
      nextEvent.event = 'message';
    }
    return nextEvent;
  }

  private static normalizeDataPayload(payload: string): string {
    let nextPayload: string = payload;
    if (nextPayload.startsWith('data:')) {
      nextPayload = nextPayload.substring(5).trim();
    }
    return nextPayload;
  }

  private static readFirstString(source: ESObject, keys: Array<string>): string {
    for (let index: number = 0; index < keys.length; index++) {
      const value: Object = source[keys[index]];
      if (typeof value === 'string' && value.length > 0) {
        return value;
      }
    }
    return '';
  }

  private static readFirstNumber(source: ESObject, keys: Array<string>): number {
    for (let index: number = 0; index < keys.length; index++) {
      const value: Object = source[keys[index]];
      if (typeof value === 'number') {
        return value;
      }
    }
    return 0;
  }
}
