import { describe, expect, it } from '@ohos/hypium';
import { HiAgentSseParser } from '../main/ets/utils/HiAgentSseParser';

export default function hiAgentSseParserTest() {
  describe('hiAgentSseParserTest', () => {
    it('shouldParseStreamingFrames', 0, () => {
      const chunk: string = [
        'event:text',
        'data: {"event":"message_start","task_id":"task-1","id":"message-1","conversation_id":"conv-1","answer":"","created_at":1}',
        '',
        'event:text',
        'data: {"event":"message","task_id":"task-1","id":"message-1","conversation_id":"conv-1","answer":"Hello"}',
        '',
        'event:text',
        'data: {"event":"message","task_id":"task-1","id":"message-1","conversation_id":"conv-1","answer":" world"}',
        ''
      ].join('\n');

      const result = HiAgentSseParser.parseChunk(chunk, '');
      expect(result.events.length).assertEqual(3);
      expect(result.events[0].event).assertEqual('message_start');
      expect(result.events[1].answer).assertEqual('Hello');
      expect(result.events[2].answer).assertEqual(' world');
      expect(result.events[2].conversationId).assertEqual('conv-1');
      expect(result.remaining).assertEqual('');
    });

    it('shouldKeepPartialFrameInBuffer', 0, () => {
      const firstChunk: string = [
        'event:text',
        'data: {"event":"message","answer":"Hel'
      ].join('\n');
      const firstResult = HiAgentSseParser.parseChunk(firstChunk, '');
      expect(firstResult.events.length).assertEqual(0);
      expect(firstResult.remaining.length > 0).assertTrue();

      const secondChunk: string = 'lo"}\n\n';
      const secondResult = HiAgentSseParser.parseChunk(secondChunk, firstResult.remaining);
      expect(secondResult.events.length).assertEqual(1);
      expect(secondResult.events[0].answer).assertEqual('Hello');
    });

    it('shouldParseThoughtAndStatusFields', 0, () => {
      const chunk: string = [
        'event:text',
        'data: {"event":"agent_thought","status":"running","thought":"searching docs","message":"thinking","task_id":"task-2"}',
        '',
        'event:text',
        'data: {"event":"error","error":"request failed","message":"bad gateway"}',
        ''
      ].join('\n');

      const result = HiAgentSseParser.parseChunk(chunk, '');
      expect(result.events.length).assertEqual(2);
      expect(result.events[0].event).assertEqual('agent_thought');
      expect(result.events[0].status).assertEqual('running');
      expect(result.events[0].thought).assertEqual('searching docs');
      expect(result.events[0].detailMessage).assertEqual('thinking');
      expect(result.events[1].errorMessage).assertEqual('request failed');
    });
  });
}
