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
  });
}
