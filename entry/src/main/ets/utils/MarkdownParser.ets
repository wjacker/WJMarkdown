import { InlineToken, InlineTokenStyle, MarkdownBlock, MarkdownBlockType } from '../models/MarkdownModels';

class BlockParseResult {
  block: MarkdownBlock;
  nextIndex: number;

  constructor(block: MarkdownBlock, nextIndex: number) {
    this.block = block;
    this.nextIndex = nextIndex;
  }
}

class DelimitedMatchResult {
  matched: boolean;
  content: string;
  nextIndex: number;
  style: number;

  constructor(matched: boolean, content: string, nextIndex: number, style: number) {
    this.matched = matched;
    this.content = content;
    this.nextIndex = nextIndex;
    this.style = style;
  }
}

class LinkMatchResult {
  matched: boolean;
  content: string;
  href: string;
  nextIndex: number;

  constructor(matched: boolean, content: string, href: string, nextIndex: number) {
    this.matched = matched;
    this.content = content;
    this.href = href;
    this.nextIndex = nextIndex;
  }
}

export class MarkdownParser {
  private static blockCounter: number = 0;
  private static tokenCounter: number = 0;

  static parse(markdown: string): Array<MarkdownBlock> {
    MarkdownParser.blockCounter = 0;
    MarkdownParser.tokenCounter = 0;

    const blocks: Array<MarkdownBlock> = [];
    const normalized: string = markdown.replace(/\r\n/g, '\n');
    const lines: Array<string> = normalized.split('\n');
    let index: number = 0;

    while (index < lines.length) {
      const line: string = lines[index];
      if (MarkdownParser.isBlank(line)) {
        index++;
        continue;
      }

      const fenceMatch: RegExpMatchArray | null = line.match(/^```([\w-]+)?\s*$/);
      if (fenceMatch !== null) {
        let language: string = '';
        if (fenceMatch[1] !== undefined) {
          language = fenceMatch[1];
        }
        const codeBlockResult = MarkdownParser.consumeCodeBlock(lines, index, language);
        blocks.push(codeBlockResult.block);
        index = codeBlockResult.nextIndex;
        continue;
      }

      const headingMatch: RegExpMatchArray | null = line.match(/^(#{1,6})\s+(.*)$/);
      if (headingMatch !== null) {
        const headingBlock: MarkdownBlock = new MarkdownBlock(MarkdownParser.nextBlockId(), MarkdownBlockType.Heading);
        headingBlock.level = headingMatch[1].length;
        headingBlock.tokens = MarkdownParser.parseInline(headingMatch[2]);
        blocks.push(headingBlock);
        index++;
        continue;
      }

      if (MarkdownParser.isDividerLine(line)) {
        blocks.push(new MarkdownBlock(MarkdownParser.nextBlockId(), MarkdownBlockType.Divider));
        index++;
        continue;
      }

      if (MarkdownParser.isImageLine(line)) {
        const imageResult = MarkdownParser.consumeImage(line);
        blocks.push(imageResult.block);
        index = index + 1;
        continue;
      }

      if (index + 1 < lines.length && MarkdownParser.isTableStart(lines[index], lines[index + 1])) {
        const tableResult = MarkdownParser.consumeTable(lines, index);
        blocks.push(tableResult.block);
        index = tableResult.nextIndex;
        continue;
      }

      if (MarkdownParser.isQuoteLine(line)) {
        const quoteResult = MarkdownParser.consumeQuote(lines, index);
        blocks.push(quoteResult.block);
        index = quoteResult.nextIndex;
        continue;
      }

      if (MarkdownParser.isTaskListLine(line)) {
        const taskListResult = MarkdownParser.consumeTaskList(lines, index);
        blocks.push(taskListResult.block);
        index = taskListResult.nextIndex;
        continue;
      }

      if (MarkdownParser.isUnorderedListLine(line)) {
        const unorderedListResult = MarkdownParser.consumeUnorderedList(lines, index);
        blocks.push(unorderedListResult.block);
        index = unorderedListResult.nextIndex;
        continue;
      }

      if (MarkdownParser.isOrderedListLine(line)) {
        const orderedListResult = MarkdownParser.consumeOrderedList(lines, index);
        blocks.push(orderedListResult.block);
        index = orderedListResult.nextIndex;
        continue;
      }

      const paragraphResult = MarkdownParser.consumeParagraph(lines, index);
      blocks.push(paragraphResult.block);
      index = paragraphResult.nextIndex;
    }

    return blocks;
  }

  static parseInline(text: string): Array<InlineToken> {
    const tokens: Array<InlineToken> = [];
    let cursor: number = 0;
    let buffer: string = '';

    const flushBuffer = (): void => {
      if (buffer.length === 0) {
        return;
      }
      tokens.push(MarkdownParser.createToken(buffer));
      buffer = '';
    };

    while (cursor < text.length) {
      const codeResult = MarkdownParser.matchDelimited(text, cursor, '`', InlineTokenStyle.Code);
      if (codeResult.matched) {
        flushBuffer();
        tokens.push(MarkdownParser.createToken(codeResult.content, InlineTokenStyle.Code));
        cursor = codeResult.nextIndex;
        continue;
      }

      const linkResult = MarkdownParser.matchLink(text, cursor);
      if (linkResult.matched) {
        flushBuffer();
        tokens.push(MarkdownParser.createToken(linkResult.content, InlineTokenStyle.Plain, linkResult.href));
        cursor = linkResult.nextIndex;
        continue;
      }

      const strikeResult = MarkdownParser.matchDelimited(text, cursor, '~~', InlineTokenStyle.Strike);
      if (strikeResult.matched) {
        flushBuffer();
        tokens.push(MarkdownParser.createToken(strikeResult.content, InlineTokenStyle.Strike));
        cursor = strikeResult.nextIndex;
        continue;
      }

      const boldItalicAsteriskResult = MarkdownParser.matchDelimited(text, cursor, '***',
        InlineTokenStyle.Bold | InlineTokenStyle.Italic);
      if (boldItalicAsteriskResult.matched) {
        flushBuffer();
        tokens.push(MarkdownParser.createToken(boldItalicAsteriskResult.content,
          InlineTokenStyle.Bold | InlineTokenStyle.Italic));
        cursor = boldItalicAsteriskResult.nextIndex;
        continue;
      }

      const boldItalicUnderlineResult = MarkdownParser.matchDelimited(text, cursor, '___',
        InlineTokenStyle.Bold | InlineTokenStyle.Italic);
      if (boldItalicUnderlineResult.matched) {
        flushBuffer();
        tokens.push(MarkdownParser.createToken(boldItalicUnderlineResult.content,
          InlineTokenStyle.Bold | InlineTokenStyle.Italic));
        cursor = boldItalicUnderlineResult.nextIndex;
        continue;
      }

      const boldAsteriskResult = MarkdownParser.matchDelimited(text, cursor, '**', InlineTokenStyle.Bold);
      if (boldAsteriskResult.matched) {
        flushBuffer();
        tokens.push(MarkdownParser.createToken(boldAsteriskResult.content, InlineTokenStyle.Bold));
        cursor = boldAsteriskResult.nextIndex;
        continue;
      }

      const boldUnderlineResult = MarkdownParser.matchDelimited(text, cursor, '__', InlineTokenStyle.Bold);
      if (boldUnderlineResult.matched) {
        flushBuffer();
        tokens.push(MarkdownParser.createToken(boldUnderlineResult.content, InlineTokenStyle.Bold));
        cursor = boldUnderlineResult.nextIndex;
        continue;
      }

      const italicAsteriskResult = MarkdownParser.matchDelimited(text, cursor, '*', InlineTokenStyle.Italic);
      if (italicAsteriskResult.matched) {
        flushBuffer();
        tokens.push(MarkdownParser.createToken(italicAsteriskResult.content, InlineTokenStyle.Italic));
        cursor = italicAsteriskResult.nextIndex;
        continue;
      }

      const italicUnderlineResult = MarkdownParser.matchDelimited(text, cursor, '_', InlineTokenStyle.Italic);
      if (italicUnderlineResult.matched) {
        flushBuffer();
        tokens.push(MarkdownParser.createToken(italicUnderlineResult.content, InlineTokenStyle.Italic));
        cursor = italicUnderlineResult.nextIndex;
        continue;
      }

      buffer += text[cursor];
      cursor++;
    }

    flushBuffer();
    return tokens;
  }

  private static consumeCodeBlock(lines: Array<string>, startIndex: number, language: string): BlockParseResult {
    const block: MarkdownBlock = new MarkdownBlock(MarkdownParser.nextBlockId(), MarkdownBlockType.Code);
    block.language = language;

    const codeLines: Array<string> = [];
    let index: number = startIndex + 1;
    while (index < lines.length && !lines[index].match(/^```\s*$/)) {
      codeLines.push(lines[index]);
      index++;
    }

    block.code = codeLines.join('\n');
    if (index < lines.length) {
      index++;
    }

    return new BlockParseResult(block, index);
  }

  private static consumeQuote(lines: Array<string>, startIndex: number): BlockParseResult {
    const block: MarkdownBlock = new MarkdownBlock(MarkdownParser.nextBlockId(), MarkdownBlockType.Quote);
    let index: number = startIndex;

    while (index < lines.length && MarkdownParser.isQuoteLine(lines[index])) {
      const strippedLine: string = lines[index].replace(/^\s*>\s?/, '');
      block.items.push(MarkdownParser.parseInline(strippedLine));
      index++;
    }

    return new BlockParseResult(block, index);
  }

  private static consumeUnorderedList(lines: Array<string>, startIndex: number): BlockParseResult {
    const block: MarkdownBlock = new MarkdownBlock(MarkdownParser.nextBlockId(), MarkdownBlockType.UnorderedList);
    let index: number = startIndex;

    while (index < lines.length) {
      const match: RegExpMatchArray | null = lines[index].match(/^\s*[-*+]\s+(.*)$/);
      if (match === null) {
        break;
      }
      block.items.push(MarkdownParser.parseInline(match[1]));
      index++;
    }

    return new BlockParseResult(block, index);
  }

  private static consumeTaskList(lines: Array<string>, startIndex: number): BlockParseResult {
    const block: MarkdownBlock = new MarkdownBlock(MarkdownParser.nextBlockId(), MarkdownBlockType.TaskList);
    let index: number = startIndex;

    while (index < lines.length) {
      const match: RegExpMatchArray | null = lines[index].match(/^\s*[-*+]\s+\[(x|X| )\]\s+(.*)$/);
      if (match === null) {
        break;
      }
      block.taskStates.push(match[1].toLowerCase() === 'x');
      block.items.push(MarkdownParser.parseInline(match[2]));
      index++;
    }

    return new BlockParseResult(block, index);
  }

  private static consumeOrderedList(lines: Array<string>, startIndex: number): BlockParseResult {
    const block: MarkdownBlock = new MarkdownBlock(MarkdownParser.nextBlockId(), MarkdownBlockType.OrderedList);
    let index: number = startIndex;

    const firstLineMatch: RegExpMatchArray | null = lines[startIndex].match(/^\s*(\d+)\.\s+(.*)$/);
    if (firstLineMatch !== null) {
      block.startNumber = Number(firstLineMatch[1]);
    }

    while (index < lines.length) {
      const match: RegExpMatchArray | null = lines[index].match(/^\s*(\d+)\.\s+(.*)$/);
      if (match === null) {
        break;
      }
      block.items.push(MarkdownParser.parseInline(match[2]));
      index++;
    }

    return new BlockParseResult(block, index);
  }

  private static consumeParagraph(lines: Array<string>, startIndex: number): BlockParseResult {
    const block: MarkdownBlock = new MarkdownBlock(MarkdownParser.nextBlockId(), MarkdownBlockType.Paragraph);
    const paragraphLines: Array<string> = [];
    let index: number = startIndex;

    while (index < lines.length) {
      if (MarkdownParser.isBlank(lines[index])) {
        break;
      }
      if (index !== startIndex && MarkdownParser.isBlockStart(lines, index)) {
        break;
      }
      paragraphLines.push(lines[index]);
      index++;
    }

    block.tokens = MarkdownParser.parseInline(paragraphLines.join('\n'));
    return new BlockParseResult(block, index);
  }

  private static consumeTable(lines: Array<string>, startIndex: number): BlockParseResult {
    const block: MarkdownBlock = new MarkdownBlock(MarkdownParser.nextBlockId(), MarkdownBlockType.Table);
    const headers: Array<string> = MarkdownParser.splitTableRow(lines[startIndex]);
    block.headers = MarkdownParser.toTokenMatrix(headers);

    let index: number = startIndex + 2;
    while (index < lines.length && !MarkdownParser.isBlank(lines[index]) && lines[index].includes('|')) {
      const rowCells: Array<string> = MarkdownParser.splitTableRow(lines[index]);
      while (rowCells.length < headers.length) {
        rowCells.push('');
      }
      block.rows.push(MarkdownParser.toTokenMatrix(rowCells));
      index++;
    }

    return new BlockParseResult(block, index);
  }

  private static consumeImage(line: string): BlockParseResult {
    const block: MarkdownBlock = new MarkdownBlock(MarkdownParser.nextBlockId(), MarkdownBlockType.Image);
    const match: RegExpMatchArray | null = line.match(/^\s*!\[(.*)\]\((.+)\)\s*$/);
    if (match !== null) {
      block.imageAlt = match[1];
      block.imageUrl = match[2];
    }
    return new BlockParseResult(block, 0);
  }

  private static isBlockStart(lines: Array<string>, index: number): boolean {
    const line: string = lines[index];
    if (line.match(/^```([\w-]+)?\s*$/) !== null) {
      return true;
    }
    if (line.match(/^(#{1,6})\s+(.*)$/) !== null) {
      return true;
    }
    if (MarkdownParser.isDividerLine(line) || MarkdownParser.isQuoteLine(line) ||
      MarkdownParser.isTaskListLine(line) || MarkdownParser.isUnorderedListLine(line) ||
      MarkdownParser.isOrderedListLine(line) || MarkdownParser.isImageLine(line)) {
      return true;
    }
    if (index + 1 < lines.length && MarkdownParser.isTableStart(lines[index], lines[index + 1])) {
      return true;
    }
    return false;
  }

  private static isBlank(line: string): boolean {
    return line.trim().length === 0;
  }

  private static isDividerLine(line: string): boolean {
    return line.match(/^\s*([-*_])(?:\s*\1){2,}\s*$/) !== null;
  }

  private static isQuoteLine(line: string): boolean {
    return line.match(/^\s*>\s?.*$/) !== null;
  }

  private static isUnorderedListLine(line: string): boolean {
    return line.match(/^\s*[-*+]\s+.+$/) !== null;
  }

  private static isTaskListLine(line: string): boolean {
    return line.match(/^\s*[-*+]\s+\[(x|X| )\]\s+.+$/) !== null;
  }

  private static isOrderedListLine(line: string): boolean {
    return line.match(/^\s*\d+\.\s+.+$/) !== null;
  }

  private static isImageLine(line: string): boolean {
    return line.match(/^\s*!\[(.*)\]\((.+)\)\s*$/) !== null;
  }

  private static isTableStart(headerLine: string, separatorLine: string): boolean {
    if (!headerLine.includes('|') || !separatorLine.includes('|')) {
      return false;
    }
    const separatorCells: Array<string> = MarkdownParser.splitTableRow(separatorLine);
    if (separatorCells.length === 0) {
      return false;
    }

    for (let index: number = 0; index < separatorCells.length; index++) {
      if (separatorCells[index].match(/^:?-{3,}:?$/) === null) {
        return false;
      }
    }
    return true;
  }

  private static splitTableRow(line: string): Array<string> {
    let normalizedLine: string = line.trim();
    if (normalizedLine.startsWith('|')) {
      normalizedLine = normalizedLine.substring(1);
    }
    if (normalizedLine.endsWith('|')) {
      normalizedLine = normalizedLine.substring(0, normalizedLine.length - 1);
    }

    const parts: Array<string> = normalizedLine.split('|');
    const cells: Array<string> = [];
    for (let index: number = 0; index < parts.length; index++) {
      cells.push(parts[index].trim());
    }
    return cells;
  }

  private static toTokenMatrix(texts: Array<string>): Array<Array<InlineToken>> {
    const matrix: Array<Array<InlineToken>> = [];
    for (let index: number = 0; index < texts.length; index++) {
      matrix.push(MarkdownParser.parseInline(texts[index]));
    }
    return matrix;
  }

  private static matchDelimited(
    text: string,
    startIndex: number,
    delimiter: string,
    style: number
  ): DelimitedMatchResult {
    if (!text.startsWith(delimiter, startIndex)) {
      return new DelimitedMatchResult(false, '', startIndex, style);
    }

    const contentStart: number = startIndex + delimiter.length;
    const closingIndex: number = text.indexOf(delimiter, contentStart);
    if (closingIndex <= contentStart) {
      return new DelimitedMatchResult(false, '', startIndex, style);
    }

    return new DelimitedMatchResult(true, text.substring(contentStart, closingIndex), closingIndex + delimiter.length, style);
  }

  private static matchLink(
    text: string,
    startIndex: number
  ): LinkMatchResult {
    if (!text.startsWith('[', startIndex)) {
      return new LinkMatchResult(false, '', '', startIndex);
    }

    const closeBracketIndex: number = text.indexOf(']', startIndex + 1);
    if (closeBracketIndex < 0 || closeBracketIndex + 1 >= text.length || text[closeBracketIndex + 1] !== '(') {
      return new LinkMatchResult(false, '', '', startIndex);
    }

    const closeParenIndex: number = text.indexOf(')', closeBracketIndex + 2);
    if (closeParenIndex < 0) {
      return new LinkMatchResult(false, '', '', startIndex);
    }

    return new LinkMatchResult(
      true,
      text.substring(startIndex + 1, closeBracketIndex),
      text.substring(closeBracketIndex + 2, closeParenIndex),
      closeParenIndex + 1
    );
  }

  private static createToken(text: string, style: number = InlineTokenStyle.Plain, href: string = ''): InlineToken {
    return new InlineToken(MarkdownParser.nextTokenId(), text, style, href);
  }

  private static nextBlockId(): string {
    MarkdownParser.blockCounter++;
    return `block-${MarkdownParser.blockCounter}`;
  }

  private static nextTokenId(): string {
    MarkdownParser.tokenCounter++;
    return `token-${MarkdownParser.tokenCounter}`;
  }
}
