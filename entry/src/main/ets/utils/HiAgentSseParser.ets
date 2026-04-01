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
      const parsedEvent: string = HiAgentSseParser.readString(data, 'event');
      nextEvent.event = parsedEvent.length > 0 ? parsedEvent : nextEvent.event;
      nextEvent.answer = HiAgentSseParser.readString(data, 'answer');
      nextEvent.taskId = HiAgentSseParser.readString(data, 'task_id');
      nextEvent.messageId = HiAgentSseParser.readString(data, 'id');
      nextEvent.conversationId = HiAgentSseParser.readString(data, 'conversation_id');
      nextEvent.createdAt = HiAgentSseParser.readNumber(data, 'created_at');
      nextEvent.inputTokens = HiAgentSseParser.readNumber(data, 'input_tokens');
      nextEvent.outputTokens = HiAgentSseParser.readNumber(data, 'output_tokens');
      nextEvent.latency = HiAgentSseParser.readNumber(data, 'latency');
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

  private static readString(source: ESObject, key: string): string {
    const value: Object = source[key];
    return typeof value === 'string' ? value : '';
  }

  private static readNumber(source: ESObject, key: string): number {
    const value: Object = source[key];
    return typeof value === 'number' ? value : 0;
  }
}
