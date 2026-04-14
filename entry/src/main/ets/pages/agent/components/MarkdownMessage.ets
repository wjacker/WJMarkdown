import {
  InlineToken,
  InlineTokenStyle,
  MarkdownBlock,
  MarkdownBlockType,
  MarkdownListItem,
  MarkdownTableAlignment
} from '../models/MarkdownModels';
import { CodeLine, CodeSegment, CodeTokenKind } from '../models/CodeHighlightModels';
import { CodeHighlighter } from '../utils/CodeHighlighter';
import { MarkdownParser } from '../utils/MarkdownParser';
import { MathMarkdownWeb } from './MathMarkdownWeb';

@Component
export struct MarkdownMessage {
  @Prop content: string = '';
  @Prop isStreaming: boolean = false;
  @Prop isAssistant: boolean = true;
  @Prop streamingLabel: string = 'Streaming...';

  build() {
    Column({ space: 12 }) {
      if (this.shouldUseWebMathRenderer()) {
        ForEach([this.buildMathRendererToken()], (_token: string) => {
          MathMarkdownWeb({
            content: this.content,
            isAssistant: this.isAssistant
          })
        }, (token: string) => token)
      } else {
        this.BlocksBuilder(MarkdownParser.parse(this.content), 0)

        if (this.isStreaming && this.streamingLabel.length > 0) {
          Row({ space: 6 }) {
            Text('|')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.getAccentColor())
            Text(this.streamingLabel.length > 0 ? this.streamingLabel : 'Streaming...')
              .fontSize(12)
              .fontColor(this.getSecondaryTextColor())
          }
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  private buildMathRendererToken(): string {
    return `${this.content.length}:${this.isStreaming ? '1' : '0'}:${this.content}`;
  }

  private shouldUseWebMathRenderer(): boolean {
    const containsMathLikeContent: boolean = this.content.includes('\\(') ||
      this.content.includes('\\[') ||
      this.content.includes('$$') ||
      /(^|[^\\])\$[^$]/.test(this.content) ||
      this.content.includes('\\frac') ||
      this.content.includes('\\left') ||
      this.content.includes('\\right') ||
      this.content.includes('\\cdot') ||
      this.content.includes('\\times') ||
      this.content.includes('\\sqrt') ||
      this.content.includes('\\int') ||
      this.content.includes('\\sum') ||
      this.content.includes('^{') ||
      this.content.includes('_{') ||
      /\([A-Za-z][A-Za-z0-9_^{}]*\)/.test(this.content);

    if (!containsMathLikeContent) {
      return false;
    }

    if (!this.isStreaming) {
      return true;
    }

    return this.hasClosedMathSyntax(this.content);
  }

  private hasClosedMathSyntax(content: string): boolean {
    return this.hasEvenUnescapedDelimiter(content, '$') &&
      this.hasEvenUnescapedDoubleDollar(content) &&
      this.hasBalancedPair(content, '\\(', '\\)') &&
      this.hasBalancedPair(content, '\\[', '\\]');
  }

  private hasBalancedPair(content: string, openToken: string, closeToken: string): boolean {
    let balance: number = 0;
    let cursor: number = 0;

    while (cursor < content.length) {
      if (content.startsWith(openToken, cursor)) {
        balance++;
        cursor += openToken.length;
        continue;
      }
      if (content.startsWith(closeToken, cursor)) {
        if (balance <= 0) {
          return false;
        }
        balance--;
        cursor += closeToken.length;
        continue;
      }
      cursor++;
    }

    return balance === 0;
  }

  private hasEvenUnescapedDelimiter(content: string, delimiter: string): boolean {
    let count: number = 0;
    for (let index: number = 0; index < content.length; index++) {
      if (content[index] !== delimiter) {
        continue;
      }
      if (index > 0 && content[index - 1] === '\\') {
        continue;
      }
      if ((index > 0 && content[index - 1] === '$') || (index + 1 < content.length && content[index + 1] === '$')) {
        continue;
      }
      count++;
    }
    return count % 2 === 0;
  }

  private hasEvenUnescapedDoubleDollar(content: string): boolean {
    let count: number = 0;
    let index: number = 0;
    while (index < content.length - 1) {
      if (content[index] === '\\') {
        index += 2;
        continue;
      }
      if (content[index] === '$' && content[index + 1] === '$') {
        count++;
        index += 2;
        continue;
      }
      index++;
    }
    return count % 2 === 0;
  }

  @Builder
  private BlocksBuilder(blocks: Array<MarkdownBlock>, nestingLevel: number) {
    Column({ space: 12 }) {
      ForEach(blocks, (block: MarkdownBlock) => {
        this.BlockBuilder(block, nestingLevel);
      }, (block: MarkdownBlock) => block.id)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private BlockBuilder(block: MarkdownBlock, nestingLevel: number) {
    if (block.type === MarkdownBlockType.Heading) {
      this.HeadingBuilder(block);
    } else if (block.type === MarkdownBlockType.Math) {
      this.MathBlockBuilder(block);
    } else if (block.type === MarkdownBlockType.Code) {
      this.CodeBlockBuilder(block);
    } else if (block.type === MarkdownBlockType.Quote) {
      this.QuoteBuilder(block, nestingLevel);
    } else if (block.type === MarkdownBlockType.TaskList ||
      block.type === MarkdownBlockType.UnorderedList ||
      block.type === MarkdownBlockType.OrderedList) {
      this.ListBuilder(block, nestingLevel);
    } else if (block.type === MarkdownBlockType.Divider) {
      Divider()
        .color(this.getDividerColor())
        .strokeWidth(1)
    } else if (block.type === MarkdownBlockType.Table) {
      this.TableBuilder(block);
    } else if (block.type === MarkdownBlockType.Image) {
      this.ImageBuilder(block);
    } else {
      this.InlineTextBuilder(block.tokens, 15, 24, false, TextAlign.Start);
    }
  }

  @Builder
  private HeadingBuilder(block: MarkdownBlock) {
    this.InlineTextBuilder(block.tokens, this.getHeadingSize(block.level), this.getHeadingSize(block.level) + 8,
      true, TextAlign.Start);
  }

  @Builder
  private QuoteBuilder(block: MarkdownBlock, nestingLevel: number) {
    Row({ space: 12 }) {
      Column()
        .width(4)
        .height('100%')
        .borderRadius(4)
        .backgroundColor(this.getAccentColor())

      Column({ space: 8 }) {
        if (block.children.length > 0) {
          this.BlocksBuilder(block.children, nestingLevel + 1);
        } else {
          ForEach(block.items, (itemTokens: Array<InlineToken>, index: number) => {
            this.InlineTextBuilder(itemTokens, 14, 22, false, TextAlign.Start);
          }, (_itemTokens: Array<InlineToken>, index: number) => `quote-${index}`)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: 12, right: 12, bottom: 12, left: 12 })
    .borderRadius(18)
    .backgroundColor(this.getSubtleBlockColor())
  }

  @Builder
  private ListBuilder(block: MarkdownBlock, nestingLevel: number) {
    Column({ space: 8 }) {
      ForEach(block.listItems, (item: MarkdownListItem, index: number) => {
        Row({ space: 10 }) {
          this.ListMarkerBuilder(block, item, index, nestingLevel)

          Column({ space: 8 }) {
            if (item.blocks.length > 0) {
              this.BlocksBuilder(item.blocks, nestingLevel + 1);
            } else {
              this.InlineTextBuilder(block.items[index], 15, 24, false, TextAlign.Start);
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }, (item: MarkdownListItem) => item.id)
    }
    .width('100%')
    .padding({ left: nestingLevel > 0 ? 6 : 0 })
  }

  @Builder
  private ListMarkerBuilder(block: MarkdownBlock, item: MarkdownListItem, index: number, nestingLevel: number) {
    if (block.type === MarkdownBlockType.TaskList) {
      Text(item.checked ? 'x' : '')
        .width(18)
        .height(18)
        .textAlign(TextAlign.Center)
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor(item.checked ? '#FFFFFF' : this.getAccentColor())
        .backgroundColor(item.checked ? this.getAccentColor() : '#00000000')
        .border({
          width: 1.2,
          color: this.getAccentColor()
        })
        .borderRadius(6)
    } else if (block.type === MarkdownBlockType.OrderedList) {
      Text(`${block.startNumber + index}.`)
        .width(30)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.getAccentColor())
    } else {
      Text(nestingLevel % 2 === 0 ? '-' : 'o')
        .width(18)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getAccentColor())
    }
  }

  @Builder
  private CodeBlockBuilder(block: MarkdownBlock) {
    Column({ space: 8 }) {
      Row() {
        Text(block.language.length > 0 ? block.language.toUpperCase() : 'CODE')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor('#8CB4FF')

        Blank()

        Text('highlighted')
          .fontSize(11)
          .fontColor('#6EE7B7')
      }
      .width('100%')

      Column({ space: 4 }) {
        ForEach(CodeHighlighter.highlight(block.code, block.language), (codeLine: CodeLine) => {
          this.CodeLineBuilder(codeLine);
        }, (codeLine: CodeLine) => codeLine.id)
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .borderRadius(18)
    .backgroundColor('#111827')
  }

  @Builder
  private MathBlockBuilder(block: MarkdownBlock) {
    Column({ space: 8 }) {
      Text('MATH')
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.isAssistant ? '#2563EB' : '#DBEAFE')

      Text(block.math)
        .width('100%')
        .fontSize(16)
        .lineHeight(26)
        .fontFamily('monospace')
        .fontColor(this.isAssistant ? '#0F172A' : '#EFF6FF')
        .textAlign(TextAlign.Center)
        .wordBreak(WordBreak.BREAK_WORD)
    }
    .width('100%')
    .padding({ top: 14, right: 16, bottom: 14, left: 16 })
    .borderRadius(18)
    .backgroundColor(this.isAssistant ? '#F8FAFF' : '#4C8FE8')
    .border({
      width: 1,
      color: this.isAssistant ? '#DBEAFE' : '#7FB2F6'
    })
  }

  @Builder
  private CodeLineBuilder(codeLine: CodeLine) {
    Row({ space: 12 }) {
      Text(`${codeLine.lineNumber}`)
        .width(24)
        .fontSize(11)
        .fontColor('#5B708B')
        .textAlign(TextAlign.End)

      Text() {
        ForEach(codeLine.segments, (segment: CodeSegment) => {
          Span(segment.text)
            .fontSize(13)
            .fontFamily('monospace')
            .fontColor(this.getCodeSegmentColor(segment))
        }, (segment: CodeSegment) => segment.id)
      }
      .width('100%')
      .layoutWeight(1)
      .lineHeight(20)
      .textAlign(TextAlign.Start)
      .wordBreak(WordBreak.BREAK_ALL)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private TableBuilder(block: MarkdownBlock) {
    Column({ space: 0 }) {
      Row() {
        ForEach(block.headers, (headerTokens: Array<InlineToken>, index: number) => {
          Column() {
            this.InlineTextBuilder(headerTokens, 13, 20, true, this.getTableCellAlign(block, index));
          }
          .layoutWeight(1)
          .padding(12)
          .alignItems(HorizontalAlign.Start)
        }, (_headerTokens: Array<InlineToken>, index: number) => `th-${index}`)
      }
      .width('100%')
      .backgroundColor(this.getTableHeaderColor())

      ForEach(block.rows, (rowTokens: Array<Array<InlineToken>>, rowIndex: number) => {
        Row() {
          ForEach(rowTokens, (cellTokens: Array<InlineToken>, cellIndex: number) => {
            Column() {
              this.InlineTextBuilder(cellTokens, 13, 20, false, this.getTableCellAlign(block, cellIndex));
            }
            .layoutWeight(1)
            .padding(12)
            .alignItems(HorizontalAlign.Start)
          }, (_cellTokens: Array<InlineToken>, cellIndex: number) => `td-${rowIndex}-${cellIndex}`)
        }
        .width('100%')
        .backgroundColor(rowIndex % 2 === 0 ? this.getTableRowPrimaryColor() : this.getTableRowSecondaryColor())
      }, (_rowTokens: Array<Array<InlineToken>>, rowIndex: number) => `tr-${rowIndex}`)
    }
    .width('100%')
    .borderRadius(18)
    .clip(true)
  }

  @Builder
  private ImageBuilder(block: MarkdownBlock) {
    Column({ space: 10 }) {
      Image(block.imageUrl)
        .width('100%')
        .height(180)
        .borderRadius(16)
        .objectFit(ImageFit.Cover)

      if (block.imageAlt.length > 0) {
        Text(block.imageAlt)
          .width('100%')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isAssistant ? '#334155' : '#E2E8F0')
      }

      if (block.imageTitle.length > 0) {
        Text(block.imageTitle)
          .width('100%')
          .fontSize(12)
          .lineHeight(18)
          .fontColor(this.getSecondaryTextColor())
      }

      if (this.shouldShowImageUrl(block.imageUrl)) {
        Text(block.imageUrl)
          .width('100%')
          .fontSize(11)
          .lineHeight(16)
          .fontColor(this.getSecondaryTextColor())
          .wordBreak(WordBreak.BREAK_ALL)
      }
    }
    .width('100%')
    .padding(12)
    .borderRadius(18)
    .backgroundColor(this.getSubtleBlockColor())
  }

  @Builder
  private InlineTextBuilder(tokens: Array<InlineToken>, fontSize: number, lineHeight: number,
    isHeading: boolean, textAlign: TextAlign) {
    Text() {
      ForEach(tokens, (token: InlineToken) => {
        Span(token.text)
          .fontWeight(this.getTokenWeight(token, isHeading))
          .fontStyle(this.getTokenFontStyle(token))
          .fontColor(this.getTokenColor(token))
          .fontSize(fontSize)
          .fontFamily(this.getTokenFontFamily(token))
          .backgroundColor(this.getTokenBackground(token))
          .decoration({
            type: this.getTokenDecoration(token),
            color: this.getTokenDecorationColor(token)
          })
      }, (token: InlineToken) => token.id)
    }
    .width('100%')
    .lineHeight(lineHeight)
    .textAlign(textAlign)
    .wordBreak(WordBreak.BREAK_WORD)
  }

  private getHeadingSize(level: number): number {
    if (level <= 1) {
      return 24;
    }
    if (level === 2) {
      return 21;
    }
    if (level === 3) {
      return 18;
    }
    return 16;
  }

  private shouldShowImageUrl(imageUrl: string): boolean {
    const normalizedUrl: string = imageUrl.trim().toLowerCase();
    return normalizedUrl.length > 0 &&
      !normalizedUrl.startsWith('file://') &&
      !normalizedUrl.startsWith('datashare://') &&
      !normalizedUrl.startsWith('content://');
  }

  private getTableCellAlign(block: MarkdownBlock, columnIndex: number): TextAlign {
    if (columnIndex >= block.tableAlignments.length) {
      return TextAlign.Start;
    }
    const alignment: MarkdownTableAlignment = block.tableAlignments[columnIndex];
    if (alignment === MarkdownTableAlignment.Center) {
      return TextAlign.Center;
    }
    if (alignment === MarkdownTableAlignment.Right) {
      return TextAlign.End;
    }
    return TextAlign.Start;
  }

  private getTokenWeight(token: InlineToken, isHeading: boolean): FontWeight {
    if ((token.style & InlineTokenStyle.Bold) !== 0 || isHeading) {
      return FontWeight.Bold;
    }
    return FontWeight.Regular;
  }

  private getTokenFontStyle(token: InlineToken): FontStyle {
    if ((token.style & InlineTokenStyle.Italic) !== 0) {
      return FontStyle.Italic;
    }
    return FontStyle.Normal;
  }

  private getTokenFontFamily(token: InlineToken): string {
    if ((token.style & InlineTokenStyle.Code) !== 0 || (token.style & InlineTokenStyle.Math) !== 0) {
      return 'monospace';
    }
    return 'HarmonyOS Sans';
  }

  private getTokenColor(token: InlineToken): string {
    if ((token.style & InlineTokenStyle.Math) !== 0) {
      return this.isAssistant ? '#1D4ED8' : '#EFF6FF';
    }
    if (token.href.length > 0) {
      return this.getAccentColor();
    }
    if ((token.style & InlineTokenStyle.Code) !== 0) {
      return this.isAssistant ? '#7C3AED' : '#BFDBFE';
    }
    return this.isAssistant ? '#1E293B' : '#F8FAFC';
  }

  private getTokenBackground(token: InlineToken): string {
    if ((token.style & InlineTokenStyle.Math) !== 0) {
      return this.isAssistant ? '#EEF4FF' : '#6FA7F3';
    }
    if ((token.style & InlineTokenStyle.Code) !== 0) {
      return this.isAssistant ? '#EEF2FF' : '#1E3A5F';
    }
    return '#00000000';
  }

  private getTokenDecoration(token: InlineToken): TextDecorationType {
    if ((token.style & InlineTokenStyle.Strike) !== 0) {
      return TextDecorationType.LineThrough;
    }
    if (token.href.length > 0) {
      return TextDecorationType.Underline;
    }
    return TextDecorationType.None;
  }

  private getTokenDecorationColor(token: InlineToken): string {
    if (token.href.length > 0) {
      return this.getAccentColor();
    }
    return this.getSecondaryTextColor();
  }

  private getCodeSegmentColor(segment: CodeSegment): string {
    if (segment.kind === CodeTokenKind.Keyword) {
      return '#C084FC';
    }
    if (segment.kind === CodeTokenKind.String) {
      return '#F9A8D4';
    }
    if (segment.kind === CodeTokenKind.Number) {
      return '#FCD34D';
    }
    if (segment.kind === CodeTokenKind.Comment) {
      return '#6B7280';
    }
    if (segment.kind === CodeTokenKind.Operator) {
      return '#93C5FD';
    }
    if (segment.kind === CodeTokenKind.Type) {
      return '#67E8F9';
    }
    if (segment.kind === CodeTokenKind.Literal) {
      return '#FCA5A5';
    }
    return '#E5EEF8';
  }

  private getAccentColor(): string {
    return this.isAssistant ? '#2563EB' : '#93C5FD';
  }

  private getDividerColor(): string {
    return this.isAssistant ? '#D6DEE8' : '#4B617D';
  }

  private getSecondaryTextColor(): string {
    return this.isAssistant ? '#64748B' : '#CBD5E1';
  }

  private getSubtleBlockColor(): string {
    return this.isAssistant ? '#F8FAFC' : '#15324D';
  }

  private getTableHeaderColor(): string {
    return this.isAssistant ? '#E2E8F0' : '#16324A';
  }

  private getTableRowPrimaryColor(): string {
    return this.isAssistant ? '#FFFFFF' : '#0F2C44';
  }

  private getTableRowSecondaryColor(): string {
    return this.isAssistant ? '#F8FAFC' : '#133350';
  }
}
