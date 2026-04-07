import { describe, it, expect } from '@ohos/hypium';
import {
  InlineTokenStyle,
  MarkdownBlockType,
  MarkdownTableAlignment
} from '../main/ets/models/MarkdownModels';
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
        '![Preview](/image.png)',
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
      expect(blocks[2].imageUrl).assertEqual('https://hia.volcenginepaas.com/image.png');
    });

    it('shouldParseNestedMarkdownBlocks', 0, () => {
      const markdown: string = [
        '###Sub heading',
        '',
        '> quoted intro',
        '>',
        '> - first item',
        '>   - nested item',
        '',
        '1. first step',
        '   - child bullet',
        '2. second step',
        '',
        '| Name | Status | Score |',
        '| :--- | :-: | ---: |',
        '| Parser | Ready | 100 |'
      ].join('\n');

      const blocks = MarkdownParser.parse(markdown);
      expect(blocks.length).assertEqual(4);
      expect(blocks[0].type).assertEqual(MarkdownBlockType.Heading);
      expect(blocks[0].level).assertEqual(3);
      expect(blocks[1].type).assertEqual(MarkdownBlockType.Quote);
      expect(blocks[1].children.length).assertEqual(2);
      expect(blocks[1].children[1].type).assertEqual(MarkdownBlockType.UnorderedList);
      expect(blocks[1].children[1].listItems[0].blocks[1].type).assertEqual(MarkdownBlockType.UnorderedList);
      expect(blocks[2].type).assertEqual(MarkdownBlockType.OrderedList);
      expect(blocks[2].listItems[0].blocks[1].type).assertEqual(MarkdownBlockType.UnorderedList);
      expect(blocks[3].type).assertEqual(MarkdownBlockType.Table);
      expect(blocks[3].tableAlignments[0]).assertEqual(MarkdownTableAlignment.Left);
      expect(blocks[3].tableAlignments[1]).assertEqual(MarkdownTableAlignment.Center);
      expect(blocks[3].tableAlignments[2]).assertEqual(MarkdownTableAlignment.Right);
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

    it('shouldParseNestedInlineAndEscapedTokens', 0, () => {
      const mixedTokens = MarkdownParser.parseInline('**bold _mix_** and \\*literal\\* https://example.com');
      expect(mixedTokens.length).assertEqual(4);
      expect(mixedTokens[0].style).assertEqual(InlineTokenStyle.Bold);
      expect(mixedTokens[1].style).assertEqual(InlineTokenStyle.Bold | InlineTokenStyle.Italic);
      expect(mixedTokens[2].text).assertEqual(' and *literal* ');
      expect(mixedTokens[3].href).assertEqual('https://example.com');

      const strikeTokens = MarkdownParser.parseInline('~~gone~~');
      expect(strikeTokens.length).assertEqual(1);
      expect(strikeTokens[0].style).assertEqual(InlineTokenStyle.Strike);
    });

    it('shouldParseHtmlAndBareImageLines', 0, () => {
      const markdown: string = [
        '<img src="/assets/demo.png" alt="demo" title="preview" />',
        '',
        'https://hia.volcenginepaas.com/assets/cover.jpg'
      ].join('\n');

      const blocks = MarkdownParser.parse(markdown);
      expect(blocks.length).assertEqual(2);
      expect(blocks[0].type).assertEqual(MarkdownBlockType.Image);
      expect(blocks[0].imageUrl).assertEqual('https://hia.volcenginepaas.com/assets/demo.png');
      expect(blocks[0].imageAlt).assertEqual('demo');
      expect(blocks[1].type).assertEqual(MarkdownBlockType.Image);
      expect(blocks[1].imageUrl).assertEqual('https://hia.volcenginepaas.com/assets/cover.jpg');
    });

    it('shouldParseMathBlocksAndInlineMath', 0, () => {
      const markdown: string = [
        '这里有行内公式 \\(a^2 + b^2 = c^2\\) 和 $E=mc^2$。',
        '',
        '\\[',
        '\\frac{-r}{na0}',
        '\\cdot \\left(\\frac{2r}{na0}\\right)',
        '\\]',
        '',
        '$$',
        '\\int_0^1 x^2 dx',
        '$$'
      ].join('\n');

      const blocks = MarkdownParser.parse(markdown);
      expect(blocks.length).assertEqual(3);
      expect(blocks[0].type).assertEqual(MarkdownBlockType.Paragraph);
      expect(blocks[0].tokens[1].style).assertEqual(InlineTokenStyle.Math);
      expect(blocks[0].tokens[1].text).assertEqual('a^2 + b^2 = c^2');
      expect(blocks[0].tokens[3].style).assertEqual(InlineTokenStyle.Math);
      expect(blocks[1].type).assertEqual(MarkdownBlockType.Math);
      expect(blocks[1].math.includes('\\frac{-r}{na0}')).assertTrue();
      expect(blocks[2].type).assertEqual(MarkdownBlockType.Math);
      expect(blocks[2].math).assertEqual('\\int_0^1 x^2 dx');
    });
  });
}
