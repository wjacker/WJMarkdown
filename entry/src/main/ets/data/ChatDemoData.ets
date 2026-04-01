import { ChatMessage } from '../models/ChatModels';

export class ChatDemoData {
  static seedMessages(): Array<ChatMessage> {
    const assistantReply: string = [
      '## AI Chat Markdown Demo',
      '',
      'This assistant bubble renders **headings**, *emphasis*, `inline code`, [links](https://developer.huawei.com) and multi-line paragraphs while the content streams in.',
      '',
      '> The message re-parses on every tick, so partially delivered markdown remains readable during the typing effect.',
      '',
      '### Checklist',
      '',
      '- Paragraphs and headings',
      '- Quotes, dividers and lists',
      '- Task lists and image blocks',
      '- Fenced code blocks',
      '- Lightweight markdown tables',
      '',
      '### Task list',
      '',
      '- [x] Render markdown while streaming',
      '- [x] Support code block highlighting',
      '- [ ] Plug into a real model response',
      '',
      '### Image block',
      '',
      '![Markdown preview image](https://dummyimage.com/1200x600/e2e8f0/1e293b&text=HarmonyOS+Markdown+Image)',
      '',
      '### Sample code',
      '',
      '```ts',
      'function streamMarkdown(chunk: string): string {',
      '  return chunk;',
      '}',
      '```',
      '',
      '| Layer | Status | Notes |',
      '| --- | --- | --- |',
      '| UI | In progress | Chat screen and bubbles |',
      '| Parser | In progress | Block and inline markdown support |',
      '| Stream | Ready | Character-by-character typing |',
      '',
      '---',
      '',
      'Next step: connect this local demo to a real model endpoint and replace the timer with streaming callbacks.'
    ].join('\n');

    const messages: Array<ChatMessage> = [];
    messages.push(ChatMessage.user('seed-user', 'Build a markdown-capable AI chat view with a typing effect.'));
    messages.push(ChatMessage.assistant('seed-assistant', assistantReply, '', true));
    return messages;
  }

  static buildAssistantReply(prompt: string): string {
    const normalizedPrompt: string = prompt.trim().length > 0 ? prompt.trim() : 'the latest request';

    return [
      '## Reply Preview',
      '',
      `You asked for: **${normalizedPrompt}**`,
      '',
      'Here is a streaming-friendly markdown answer:',
      '',
      '1. Parse incoming text into markdown blocks.',
      '2. Re-render the bubble whenever new content arrives.',
      '3. Keep code blocks and tables stable while text is still streaming.',
      '',
      '- [x] Task list support',
      '- [x] Image block support',
      '- [x] Basic code highlighting',
      '',
      '> This local demo uses a timer to mimic token streaming. In production, feed real chunks from your model callback into the same state update path.',
      '',
      '![Generated preview](https://dummyimage.com/1200x520/dbeafe/1e3a8a&text=AI+Chat+Markdown+Bubble)',
      '',
      '```json',
      '{',
      '  "mode": "demo-stream",',
      '  "supportsMarkdown": true,',
      '  "supportsTyping": true',
      '}',
      '```',
      '',
      '| Capability | Value |',
      '| --- | --- |',
      '| Prompt source | local input box |',
      '| Output style | markdown |',
      '',
      'Use the parser, message model, and bubble components from this project as the starting point for your production AI chat module.'
    ].join('\n');
  }
}
