import { describe, it, expect } from '@ohos/hypium';
import { InlineTokenStyle, MarkdownBlockType } from '../main/ets/models/MarkdownModels';
import { MarkdownParser } from '../main/ets/utils/MarkdownParser';

export default function markdownParserTest() {
  describe('markdownParserTest', () => {
    it('shouldParseCommonBlocks', 0, () => {
      const markdown: string = [
        '## Title',
        '',
        '- [x] completed task',
        '- [ ] pending task',
        '',
        '![Preview](https://example.com/image.png)',
        '',
        '- first item',
        '- second item',
        '',
        '```ts',
        'const value = 1;',
        '```',
        '',
        '| Name | Status |',
        '| --- | --- |',
        '| Parser | Ready |'
      ].join('\n');

      const blocks = MarkdownParser.parse(markdown);
      expect(blocks.length).assertEqual(6);
      expect(blocks[0].type).assertEqual(MarkdownBlockType.Heading);
      expect(blocks[1].type).assertEqual(MarkdownBlockType.TaskList);
      expect(blocks[2].type).assertEqual(MarkdownBlockType.Image);
      expect(blocks[3].type).assertEqual(MarkdownBlockType.UnorderedList);
      expect(blocks[4].type).assertEqual(MarkdownBlockType.Code);
      expect(blocks[5].type).assertEqual(MarkdownBlockType.Table);
      expect(blocks[1].taskStates[0]).assertTrue();
      expect(blocks[1].taskStates[1]).assertFalse();
      expect(blocks[2].imageUrl).assertEqual('https://example.com/image.png');
    });

    it('shouldParseInlineStyles', 0, () => {
      const boldTokens = MarkdownParser.parseInline('**bold**');
      expect(boldTokens.length).assertEqual(1);
      expect(boldTokens[0].text).assertEqual('bold');
      expect(boldTokens[0].style).assertEqual(InlineTokenStyle.Bold);

      const codeTokens = MarkdownParser.parseInline('`code`');
      expect(codeTokens.length).assertEqual(1);
      expect(codeTokens[0].style).assertEqual(InlineTokenStyle.Code);

      const linkTokens = MarkdownParser.parseInline('[docs](https://example.com)');
      expect(linkTokens.length).assertEqual(1);
      expect(linkTokens[0].href).assertEqual('https://example.com');
    });
  });
}
