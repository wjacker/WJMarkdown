import { InlineToken, InlineTokenStyle, MarkdownBlock, MarkdownBlockType } from '../models/MarkdownModels';
import { CodeLine, CodeSegment, CodeTokenKind } from '../models/CodeHighlightModels';
import { CodeHighlighter } from '../utils/CodeHighlighter';
import { MarkdownParser } from '../utils/MarkdownParser';

@Component
export struct MarkdownMessage {
  @Prop content: string = '';
  @Prop isStreaming: boolean = false;
  @Prop isAssistant: boolean = true;

  build() {
    Column({ space: 12 }) {
      ForEach(MarkdownParser.parse(this.content), (block: MarkdownBlock) => {
        this.BlockBuilder(block);
      }, (block: MarkdownBlock) => block.id)

      if (this.isStreaming) {
        Row({ space: 6 }) {
          Text('|')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getAccentColor())
          Text('Streaming...')
            .fontSize(12)
            .fontColor(this.getSecondaryTextColor())
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private BlockBuilder(block: MarkdownBlock) {
    if (block.type === MarkdownBlockType.Heading) {
      this.HeadingBuilder(block);
    } else if (block.type === MarkdownBlockType.Code) {
      this.CodeBlockBuilder(block);
    } else if (block.type === MarkdownBlockType.Quote) {
      this.QuoteBuilder(block);
    } else if (block.type === MarkdownBlockType.TaskList) {
      this.TaskListBuilder(block);
    } else if (block.type === MarkdownBlockType.UnorderedList) {
      this.BulletListBuilder(block);
    } else if (block.type === MarkdownBlockType.OrderedList) {
      this.NumberedListBuilder(block);
    } else if (block.type === MarkdownBlockType.Divider) {
      Divider()
        .color(this.getDividerColor())
        .strokeWidth(1)
    } else if (block.type === MarkdownBlockType.Table) {
      this.TableBuilder(block);
    } else if (block.type === MarkdownBlockType.Image) {
      this.ImageBuilder(block);
    } else {
      this.InlineTextBuilder(block.tokens, 15, 24, false);
    }
  }

  @Builder
  private HeadingBuilder(block: MarkdownBlock) {
    this.InlineTextBuilder(block.tokens, this.getHeadingSize(block.level), this.getHeadingSize(block.level) + 8, true);
  }

  @Builder
  private QuoteBuilder(block: MarkdownBlock) {
    Row({ space: 12 }) {
      Column()
        .width(4)
        .height('100%')
        .borderRadius(4)
        .backgroundColor(this.getAccentColor())

      Column({ space: 8 }) {
        ForEach(block.items, (itemTokens: Array<InlineToken>, index: number) => {
          this.InlineTextBuilder(itemTokens, 14, 22, false);
        }, (_itemTokens: Array<InlineToken>, index: number) => `quote-${index}`)
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
  private BulletListBuilder(block: MarkdownBlock) {
    Column({ space: 8 }) {
      ForEach(block.items, (itemTokens: Array<InlineToken>, index: number) => {
        Row({ space: 10 }) {
          Text('-')
            .fontSize(16)
            .fontColor(this.getAccentColor())
            .padding({ top: 1 })

          Column() {
            this.InlineTextBuilder(itemTokens, 15, 24, false);
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }, (_itemTokens: Array<InlineToken>, index: number) => `ul-${index}`)
    }
    .width('100%')
  }

  @Builder
  private TaskListBuilder(block: MarkdownBlock) {
    Column({ space: 8 }) {
      ForEach(block.items, (itemTokens: Array<InlineToken>, index: number) => {
        Row({ space: 10 }) {
          Text(block.taskStates[index] ? 'x' : '')
            .width(18)
            .height(18)
            .textAlign(TextAlign.Center)
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(block.taskStates[index] ? '#FFFFFF' : this.getAccentColor())
            .backgroundColor(block.taskStates[index] ? this.getAccentColor() : '#00000000')
            .border({
              width: 1.2,
              color: this.getAccentColor()
            })
            .borderRadius(6)

          Column() {
            this.InlineTextBuilder(itemTokens, 15, 24, false);
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }, (_itemTokens: Array<InlineToken>, index: number) => `task-${index}`)
    }
    .width('100%')
  }

  @Builder
  private NumberedListBuilder(block: MarkdownBlock) {
    Column({ space: 8 }) {
      ForEach(block.items, (itemTokens: Array<InlineToken>, index: number) => {
        Row({ space: 10 }) {
          Text(`${block.startNumber + index}.`)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.getAccentColor())
            .width(28)

          Column() {
            this.InlineTextBuilder(itemTokens, 15, 24, false);
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }, (_itemTokens: Array<InlineToken>, index: number) => `ol-${index}`)
    }
    .width('100%')
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
      .layoutWeight(1)
      .lineHeight(20)
      .textAlign(TextAlign.Start)
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
            this.InlineTextBuilder(headerTokens, 13, 20, true);
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
              this.InlineTextBuilder(cellTokens, 13, 20, false);
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

      Text(block.imageUrl)
        .width('100%')
        .fontSize(11)
        .lineHeight(16)
        .fontColor(this.getSecondaryTextColor())
    }
    .width('100%')
    .padding(12)
    .borderRadius(18)
    .backgroundColor(this.getSubtleBlockColor())
  }

  @Builder
  private InlineTextBuilder(tokens: Array<InlineToken>, fontSize: number, lineHeight: number, isHeading: boolean) {
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
    .textAlign(TextAlign.Start)
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
    if ((token.style & InlineTokenStyle.Code) !== 0) {
      return 'monospace';
    }
    return 'HarmonyOS Sans';
  }

  private getTokenColor(token: InlineToken): string {
    if (token.href.length > 0) {
      return this.getAccentColor();
    }
    if ((token.style & InlineTokenStyle.Code) !== 0) {
      return this.isAssistant ? '#7C3AED' : '#BFDBFE';
    }
    return this.isAssistant ? '#1E293B' : '#F8FAFC';
  }

  private getTokenBackground(token: InlineToken): string {
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
