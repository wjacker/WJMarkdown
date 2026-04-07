import {
  InlineToken,
  InlineTokenStyle,
  MarkdownBlock,
  MarkdownBlockType,
  MarkdownListItem,
  MarkdownTableAlignment
} from '../models/MarkdownModels';

class BlockParseResult {
  block: MarkdownBlock;
  nextIndex: number;

  constructor(block: MarkdownBlock, nextIndex: number) {
    this.block = block;
    this.nextIndex = nextIndex;
  }
}

class FenceMatchResult {
  matched: boolean;
  marker: string;
  markerChar: string;
  markerLength: number;
  language: string;

  constructor(matched: boolean, marker: string = '', markerChar: string = '', markerLength: number = 0,
    language: string = '') {
    this.matched = matched;
    this.marker = marker;
    this.markerChar = markerChar;
    this.markerLength = markerLength;
    this.language = language;
  }
}

class ListMarkerMatch {
  matched: boolean;
  indent: number;
  markerLength: number;
  type: MarkdownBlockType;
  content: string;
  checked: boolean;
  orderNumber: number;

  constructor(matched: boolean, indent: number = 0, markerLength: number = 0,
    type: MarkdownBlockType = MarkdownBlockType.UnorderedList, content: string = '',
    checked: boolean = false, orderNumber: number = 1) {
    this.matched = matched;
    this.indent = indent;
    this.markerLength = markerLength;
    this.type = type;
    this.content = content;
    this.checked = checked;
    this.orderNumber = orderNumber;
  }
}

class InlineMatchResult {
  matched: boolean;
  nextIndex: number;
  tokens: Array<InlineToken>;

  constructor(matched: boolean, nextIndex: number = 0, tokens: Array<InlineToken> = []) {
    this.matched = matched;
    this.nextIndex = nextIndex;
    this.tokens = tokens;
  }
}

class StyledInlineMatchResult {
  matched: boolean;
  nextIndex: number;
  content: string;
  style: number;

  constructor(matched: boolean, nextIndex: number = 0, content: string = '',
    style: number = InlineTokenStyle.Plain) {
    this.matched = matched;
    this.nextIndex = nextIndex;
    this.content = content;
    this.style = style;
  }
}

export class MarkdownParser {
  private static readonly IMAGE_BASE_URL: string = 'https://hia.volcenginepaas.com';
  private static blockCounter: number = 0;
  private static tokenCounter: number = 0;
  private static listItemCounter: number = 0;

  static parse(markdown: string): Array<MarkdownBlock> {
    MarkdownParser.blockCounter = 0;
    MarkdownParser.tokenCounter = 0;
    MarkdownParser.listItemCounter = 0;

    const normalized: string = MarkdownParser.normalizeMathMarkdown(markdown).replace(/\t/g, '    ');
    const lines: Array<string> = normalized.split('\n');
    return MarkdownParser.parseBlocks(lines, 0, lines.length);
  }

  static parseInline(text: string): Array<InlineToken> {
    return MarkdownParser.mergeAdjacentTokens(MarkdownParser.parseInlineSegment(text, InlineTokenStyle.Plain, ''));
  }

  static normalizeMathMarkdown(markdown: string): string {
    return markdown.replace(/\r\n/g, '\n');
  }

  private static parseBlocks(lines: Array<string>, startIndex: number, endIndex: number): Array<MarkdownBlock> {
    const blocks: Array<MarkdownBlock> = [];
    let index: number = startIndex;

    while (index < endIndex) {
      const line: string = lines[index];
      if (MarkdownParser.isBlank(line)) {
        index++;
        continue;
      }

      const fenceMatch: FenceMatchResult = MarkdownParser.matchFence(line);
      if (fenceMatch.matched) {
        const codeBlockResult: BlockParseResult = MarkdownParser.consumeCodeBlock(lines, index, endIndex, fenceMatch);
        blocks.push(codeBlockResult.block);
        index = codeBlockResult.nextIndex;
        continue;
      }

      const mathBlockResult: BlockParseResult | null = MarkdownParser.tryConsumeMathBlock(lines, index, endIndex);
      if (mathBlockResult !== null) {
        blocks.push(mathBlockResult.block);
        index = mathBlockResult.nextIndex;
        continue;
      }

      const atxHeadingBlock: MarkdownBlock | null = MarkdownParser.tryParseAtxHeading(line);
      if (atxHeadingBlock !== null) {
        blocks.push(atxHeadingBlock);
        index++;
        continue;
      }

      const setextHeadingResult: BlockParseResult | null = MarkdownParser.tryConsumeSetextHeading(lines, index, endIndex);
      if (setextHeadingResult !== null) {
        blocks.push(setextHeadingResult.block);
        index = setextHeadingResult.nextIndex;
        continue;
      }

      if (MarkdownParser.isDividerLine(line)) {
        blocks.push(new MarkdownBlock(MarkdownParser.nextBlockId(), MarkdownBlockType.Divider));
        index++;
        continue;
      }

      const imageBlock: MarkdownBlock | null = MarkdownParser.tryParseAnyImageBlock(line);
      if (imageBlock !== null) {
        blocks.push(imageBlock);
        index++;
        continue;
      }

      if (index + 1 < endIndex && MarkdownParser.isTableStart(lines[index], lines[index + 1])) {
        const tableResult: BlockParseResult = MarkdownParser.consumeTable(lines, index, endIndex);
        blocks.push(tableResult.block);
        index = tableResult.nextIndex;
        continue;
      }

      if (MarkdownParser.isQuoteLine(line)) {
        const quoteResult: BlockParseResult = MarkdownParser.consumeQuote(lines, index, endIndex);
        blocks.push(quoteResult.block);
        index = quoteResult.nextIndex;
        continue;
      }

      const listMarkerMatch: ListMarkerMatch = MarkdownParser.matchListMarker(line);
      if (listMarkerMatch.matched) {
        const listResult: BlockParseResult = MarkdownParser.consumeList(lines, index, endIndex);
        blocks.push(listResult.block);
        index = listResult.nextIndex;
        continue;
      }

      const paragraphResult: BlockParseResult = MarkdownParser.consumeParagraph(lines, index, endIndex);
      blocks.push(paragraphResult.block);
      index = paragraphResult.nextIndex;
    }

    return blocks;
  }

  private static consumeCodeBlock(lines: Array<string>, startIndex: number, endIndex: number,
    fenceMatch: FenceMatchResult): BlockParseResult {
    const block: MarkdownBlock = new MarkdownBlock(MarkdownParser.nextBlockId(), MarkdownBlockType.Code);
    block.language = fenceMatch.language;

    const codeLines: Array<string> = [];
    let index: number = startIndex + 1;
    while (index < endIndex) {
      const currentLine: string = lines[index];
      if (MarkdownParser.isFenceCloseLine(currentLine, fenceMatch.markerChar, fenceMatch.markerLength)) {
        index++;
        break;
      }
      codeLines.push(currentLine);
      index++;
    }

    block.code = codeLines.join('\n');
    return new BlockParseResult(block, index);
  }

  private static tryConsumeMathBlock(lines: Array<string>, startIndex: number, endIndex: number): BlockParseResult | null {
    const currentLine: string = lines[startIndex];
    const trimmedLine: string = MarkdownParser.trimLine(currentLine);
    if (trimmedLine === '\\[') {
      return MarkdownParser.consumeDelimitedMathBlock(lines, startIndex, endIndex, '\\]');
    }
    if (trimmedLine === '$$') {
      return MarkdownParser.consumeDelimitedMathBlock(lines, startIndex, endIndex, '$$');
    }

    if (trimmedLine.startsWith('\\[') && trimmedLine.endsWith('\\]') && trimmedLine.length > 4) {
      const block: MarkdownBlock = new MarkdownBlock(MarkdownParser.nextBlockId(), MarkdownBlockType.Math);
      block.mathDisplay = true;
      block.math = trimmedLine.substring(2, trimmedLine.length - 2).trim();
      return new BlockParseResult(block, startIndex + 1);
    }

    if (trimmedLine.startsWith('$$') && trimmedLine.endsWith('$$') && trimmedLine.length > 4) {
      const block: MarkdownBlock = new MarkdownBlock(MarkdownParser.nextBlockId(), MarkdownBlockType.Math);
      block.mathDisplay = true;
      block.math = trimmedLine.substring(2, trimmedLine.length - 2).trim();
      return new BlockParseResult(block, startIndex + 1);
    }

    return null;
  }

  private static consumeDelimitedMathBlock(lines: Array<string>, startIndex: number, endIndex: number,
    closingDelimiter: string): BlockParseResult {
    const block: MarkdownBlock = new MarkdownBlock(MarkdownParser.nextBlockId(), MarkdownBlockType.Math);
    block.mathDisplay = true;

    const mathLines: Array<string> = [];
    let index: number = startIndex + 1;
    while (index < endIndex) {
      const currentLine: string = lines[index];
      if (MarkdownParser.trimLine(currentLine) === closingDelimiter) {
        index++;
        break;
      }
      mathLines.push(currentLine);
      index++;
    }

    block.math = mathLines.join('\n').trim();
    return new BlockParseResult(block, index);
  }

  private static consumeQuote(lines: Array<string>, startIndex: number, endIndex: number): BlockParseResult {
    const block: MarkdownBlock = new MarkdownBlock(MarkdownParser.nextBlockId(), MarkdownBlockType.Quote);
    const quoteLines: Array<string> = [];
    let index: number = startIndex;

    while (index < endIndex) {
      const currentLine: string = lines[index];
      if (MarkdownParser.isQuoteLine(currentLine)) {
        quoteLines.push(currentLine.replace(/^\s{0,3}>\s?/, ''));
        index++;
        continue;
      }
      if (MarkdownParser.isBlank(currentLine)) {
        quoteLines.push('');
        index++;
        continue;
      }
      break;
    }

    block.children = MarkdownParser.parseBlocks(quoteLines, 0, quoteLines.length);
    for (let childIndex = 0; childIndex < block.children.length; childIndex++) {
      if (block.children[childIndex].type === MarkdownBlockType.Paragraph) {
        block.items.push(block.children[childIndex].tokens);
      }
    }
    return new BlockParseResult(block, index);
  }

  private static consumeList(lines: Array<string>, startIndex: number, endIndex: number): BlockParseResult {
    const firstMarker: ListMarkerMatch = MarkdownParser.matchListMarker(lines[startIndex]);
    const block: MarkdownBlock = new MarkdownBlock(MarkdownParser.nextBlockId(), firstMarker.type);
    if (firstMarker.type === MarkdownBlockType.OrderedList) {
      block.startNumber = firstMarker.orderNumber;
    }

    let index: number = startIndex;
    while (index < endIndex) {
      const marker: ListMarkerMatch = MarkdownParser.matchListMarker(lines[index]);
      if (!marker.matched || marker.indent !== firstMarker.indent || !MarkdownParser.isSameListFamily(marker, firstMarker)) {
        break;
      }

      const item: MarkdownListItem = new MarkdownListItem(MarkdownParser.nextListItemId());
      item.checked = marker.checked;
      const itemLines: Array<string> = [];
      itemLines.push(marker.content);
      index++;

      const contentIndent: number = marker.indent + marker.markerLength;
      while (index < endIndex) {
        const currentLine: string = lines[index];
        if (MarkdownParser.isBlank(currentLine)) {
          itemLines.push('');
          index++;
          continue;
        }

        const siblingMarker: ListMarkerMatch = MarkdownParser.matchListMarker(currentLine);
        if (siblingMarker.matched && siblingMarker.indent === firstMarker.indent &&
          MarkdownParser.isSameListFamily(siblingMarker, firstMarker)) {
          break;
        }

        if (MarkdownParser.leadingSpaceCount(currentLine) < contentIndent) {
          break;
        }

        itemLines.push(MarkdownParser.stripIndent(currentLine, contentIndent));
        index++;
      }

      item.blocks = MarkdownParser.parseBlocks(itemLines, 0, itemLines.length);
      if (item.blocks.length === 0 && marker.content.length > 0) {
        const paragraphBlock: MarkdownBlock = new MarkdownBlock(MarkdownParser.nextBlockId(), MarkdownBlockType.Paragraph);
        paragraphBlock.tokens = MarkdownParser.parseInline(marker.content);
        item.blocks.push(paragraphBlock);
      }

      block.listItems.push(item);
      block.taskStates.push(marker.checked);
      block.items.push(MarkdownParser.extractListPreviewTokens(item, marker.content));
    }

    return new BlockParseResult(block, index);
  }

  private static extractListPreviewTokens(item: MarkdownListItem, fallbackContent: string): Array<InlineToken> {
    if (item.blocks.length > 0 && item.blocks[0].type === MarkdownBlockType.Paragraph) {
      return item.blocks[0].tokens;
    }
    return MarkdownParser.parseInline(fallbackContent);
  }

  private static consumeTable(lines: Array<string>, startIndex: number, endIndex: number): BlockParseResult {
    const block: MarkdownBlock = new MarkdownBlock(MarkdownParser.nextBlockId(), MarkdownBlockType.Table);
    const headerCells: Array<string> = MarkdownParser.splitTableCells(lines[startIndex]);
    const alignmentCells: Array<string> = MarkdownParser.splitTableCells(lines[startIndex + 1]);

    for (let headerIndex = 0; headerIndex < headerCells.length; headerIndex++) {
      block.headers.push(MarkdownParser.parseInline(headerCells[headerIndex]));
    }
    for (let alignmentIndex = 0; alignmentIndex < alignmentCells.length; alignmentIndex++) {
      block.tableAlignments.push(MarkdownParser.parseTableAlignment(alignmentCells[alignmentIndex]));
    }

    let index: number = startIndex + 2;
    while (index < endIndex && MarkdownParser.isTableRow(lines[index])) {
      const cells: Array<string> = MarkdownParser.splitTableCells(lines[index]);
      const row: Array<Array<InlineToken>> = [];
      for (let cellIndex = 0; cellIndex < block.headers.length; cellIndex++) {
        if (cellIndex < cells.length) {
          row.push(MarkdownParser.parseInline(cells[cellIndex]));
        } else {
          row.push([]);
        }
      }
      block.rows.push(row);
      index++;
    }

    return new BlockParseResult(block, index);
  }

  private static consumeParagraph(lines: Array<string>, startIndex: number, endIndex: number): BlockParseResult {
    const block: MarkdownBlock = new MarkdownBlock(MarkdownParser.nextBlockId(), MarkdownBlockType.Paragraph);
    const paragraphLines: Array<string> = [];
    let index: number = startIndex;

    while (index < endIndex) {
      if (MarkdownParser.isBlank(lines[index])) {
        break;
      }
      if (index > startIndex && MarkdownParser.startsBlock(lines, index, endIndex)) {
        break;
      }
      paragraphLines.push(MarkdownParser.trimLine(lines[index]));
      index++;
    }

    block.tokens = MarkdownParser.parseInline(paragraphLines.join(' '));
    return new BlockParseResult(block, index);
  }

  private static tryParseAtxHeading(line: string): MarkdownBlock | null {
    const match: RegExpMatchArray | null = line.match(/^\s{0,3}(#{1,6})\s*(.*?)\s*#*\s*$/);
    if (match === null) {
      return null;
    }
    if (match[2].length === 0 && match[1].length === 0) {
      return null;
    }

    const block: MarkdownBlock = new MarkdownBlock(MarkdownParser.nextBlockId(), MarkdownBlockType.Heading);
    block.level = match[1].length;
    block.tokens = MarkdownParser.parseInline(match[2]);
    return block;
  }

  private static tryConsumeSetextHeading(lines: Array<string>, startIndex: number, endIndex: number): BlockParseResult | null {
    if (startIndex + 1 >= endIndex) {
      return null;
    }
    const currentLine: string = lines[startIndex];
    if (MarkdownParser.isBlank(currentLine) || MarkdownParser.isBlockStarterLine(currentLine)) {
      return null;
    }

    const underlineLine: string = lines[startIndex + 1];
    const underlineMatch: RegExpMatchArray | null = underlineLine.match(/^\s{0,3}(=+|-+)\s*$/);
    if (underlineMatch === null) {
      return null;
    }

    const block: MarkdownBlock = new MarkdownBlock(MarkdownParser.nextBlockId(), MarkdownBlockType.Heading);
    block.level = underlineMatch[1].charAt(0) === '=' ? 1 : 2;
    block.tokens = MarkdownParser.parseInline(MarkdownParser.trimLine(currentLine));
    return new BlockParseResult(block, startIndex + 2);
  }

  private static tryParseAnyImageBlock(line: string): MarkdownBlock | null {
    const markdownImageBlock: MarkdownBlock | null = MarkdownParser.tryParseImageBlock(line);
    if (markdownImageBlock !== null) {
      return markdownImageBlock;
    }

    const htmlImageBlock: MarkdownBlock | null = MarkdownParser.tryParseHtmlImageBlock(line);
    if (htmlImageBlock !== null) {
      return htmlImageBlock;
    }

    return MarkdownParser.tryParseBareImageBlock(line);
  }

  private static tryParseImageBlock(line: string): MarkdownBlock | null {
    const match: RegExpMatchArray | null = line.match(/^\s*!\[(.*?)\]\((\S+?)(?:\s+["'](.*?)["'])?\)\s*$/);
    if (match === null) {
      return null;
    }

    const block: MarkdownBlock = new MarkdownBlock(MarkdownParser.nextBlockId(), MarkdownBlockType.Image);
    block.imageAlt = match[1];
    block.imageUrl = MarkdownParser.normalizeImageUrl(match[2]);
    if (match[3] !== undefined) {
      block.imageTitle = match[3];
    }
    return block;
  }

  private static tryParseHtmlImageBlock(line: string): MarkdownBlock | null {
    const trimmedLine: string = MarkdownParser.trimLine(line);
    const imgTagMatch: RegExpMatchArray | null = trimmedLine.match(/^<img\b[^>]*>$/i);
    if (imgTagMatch === null) {
      return null;
    }

    const source: string = MarkdownParser.readHtmlImageAttribute(trimmedLine, 'src');
    if (source.length === 0) {
      return null;
    }

    const block: MarkdownBlock = new MarkdownBlock(MarkdownParser.nextBlockId(), MarkdownBlockType.Image);
    block.imageUrl = MarkdownParser.normalizeImageUrl(source);
    block.imageAlt = MarkdownParser.readHtmlImageAttribute(trimmedLine, 'alt');
    block.imageTitle = MarkdownParser.readHtmlImageAttribute(trimmedLine, 'title');
    return block;
  }

  private static tryParseBareImageBlock(line: string): MarkdownBlock | null {
    const trimmedLine: string = MarkdownParser.trimLine(line);
    if (!MarkdownParser.looksLikeImageUrl(trimmedLine)) {
      return null;
    }

    const block: MarkdownBlock = new MarkdownBlock(MarkdownParser.nextBlockId(), MarkdownBlockType.Image);
    block.imageUrl = MarkdownParser.normalizeImageUrl(trimmedLine);
    return block;
  }

  private static normalizeImageUrl(imageUrl: string): string {
    const trimmedUrl: string = MarkdownParser.trimLine(imageUrl);
    if (trimmedUrl.length === 0) {
      return '';
    }
    if (trimmedUrl.startsWith('http://') || trimmedUrl.startsWith('https://')) {
      return trimmedUrl;
    }
    if (trimmedUrl.startsWith('/')) {
      return `${MarkdownParser.IMAGE_BASE_URL}${trimmedUrl}`;
    }
    return `${MarkdownParser.IMAGE_BASE_URL}/${trimmedUrl}`;
  }

  private static readHtmlImageAttribute(html: string, attributeName: string): string {
    const attributePattern: RegExp = new RegExp(`${attributeName}\\s*=\\s*["']([^"']+)["']`, 'i');
    const match: RegExpMatchArray | null = html.match(attributePattern);
    if (match === null || match[1] === undefined) {
      return '';
    }
    return match[1];
  }

  private static looksLikeImageUrl(value: string): boolean {
    if (value.length === 0 || value.includes(' ')) {
      return false;
    }

    const normalizedValue: string = value.toLowerCase();
    if (!(normalizedValue.startsWith('http://') || normalizedValue.startsWith('https://') ||
      normalizedValue.startsWith('/') || normalizedValue.startsWith('./') || normalizedValue.startsWith('../'))) {
      return false;
    }

    return normalizedValue.endsWith('.png') ||
      normalizedValue.endsWith('.jpg') ||
      normalizedValue.endsWith('.jpeg') ||
      normalizedValue.endsWith('.gif') ||
      normalizedValue.endsWith('.webp') ||
      normalizedValue.endsWith('.bmp') ||
      normalizedValue.endsWith('.svg');
  }

  private static parseInlineSegment(text: string, inheritedStyle: number, href: string): Array<InlineToken> {
    const tokens: Array<InlineToken> = [];
    let buffer: string = '';
    let cursor: number = 0;

    const flushBuffer = (): void => {
      if (buffer.length === 0) {
        return;
      }
      tokens.push(MarkdownParser.createToken(buffer, inheritedStyle, href));
      buffer = '';
    };

    while (cursor < text.length) {
      const codeSpanMatch: InlineMatchResult = MarkdownParser.matchCodeSpan(text, cursor, inheritedStyle, href);
      if (codeSpanMatch.matched) {
        flushBuffer();
        MarkdownParser.appendTokens(tokens, codeSpanMatch.tokens);
        cursor = codeSpanMatch.nextIndex;
        continue;
      }

      const mathMatch: InlineMatchResult = MarkdownParser.matchMathInline(text, cursor, inheritedStyle, href);
      if (mathMatch.matched) {
        flushBuffer();
        MarkdownParser.appendTokens(tokens, mathMatch.tokens);
        cursor = mathMatch.nextIndex;
        continue;
      }

      if (text[cursor] === '\\' && cursor + 1 < text.length && MarkdownParser.isEscapable(text[cursor + 1])) {
        buffer += text[cursor + 1];
        cursor += 2;
        continue;
      }

      const autoLinkMatch: InlineMatchResult = MarkdownParser.matchAutoLink(text, cursor, inheritedStyle);
      if (autoLinkMatch.matched) {
        flushBuffer();
        MarkdownParser.appendTokens(tokens, autoLinkMatch.tokens);
        cursor = autoLinkMatch.nextIndex;
        continue;
      }

      const linkMatch: InlineMatchResult = MarkdownParser.matchLink(text, cursor, inheritedStyle);
      if (linkMatch.matched) {
        flushBuffer();
        MarkdownParser.appendTokens(tokens, linkMatch.tokens);
        cursor = linkMatch.nextIndex;
        continue;
      }

      const bareUrlMatch: InlineMatchResult = MarkdownParser.matchBareUrl(text, cursor, inheritedStyle);
      if (bareUrlMatch.matched) {
        flushBuffer();
        MarkdownParser.appendTokens(tokens, bareUrlMatch.tokens);
        cursor = bareUrlMatch.nextIndex;
        continue;
      }

      const styledMatch: StyledInlineMatchResult = MarkdownParser.matchStyledInline(text, cursor);
      if (styledMatch.matched) {
        flushBuffer();
        const styledTokens: Array<InlineToken> = MarkdownParser.parseInlineSegment(styledMatch.content,
          inheritedStyle | styledMatch.style, href);
        MarkdownParser.appendTokens(tokens, styledTokens);
        cursor = styledMatch.nextIndex;
        continue;
      }

      buffer += text[cursor];
      cursor++;
    }

    flushBuffer();
    return MarkdownParser.mergeAdjacentTokens(tokens);
  }

  private static matchCodeSpan(text: string, cursor: number, inheritedStyle: number, href: string): InlineMatchResult {
    let backtickCount: number = 0;
    while (cursor + backtickCount < text.length && text[cursor + backtickCount] === '`') {
      backtickCount++;
    }
    if (backtickCount === 0) {
      return new InlineMatchResult(false);
    }

    const delimiter: string = MarkdownParser.repeatChar('`', backtickCount);
    const closeIndex: number = MarkdownParser.findUnescaped(text, delimiter, cursor + backtickCount);
    if (closeIndex < 0) {
      return new InlineMatchResult(false);
    }

    const rawContent: string = text.substring(cursor + backtickCount, closeIndex);
    const normalizedContent: string = rawContent.replace(/^ /, '').replace(/ $/, '');
    return new InlineMatchResult(true, closeIndex + backtickCount, [
      MarkdownParser.createToken(normalizedContent, inheritedStyle | InlineTokenStyle.Code, href)
    ]);
  }

  private static matchMathInline(text: string, cursor: number, inheritedStyle: number, href: string): InlineMatchResult {
    if (MarkdownParser.hasPrefix(text, cursor, '\\(')) {
      const closeIndex: number = text.indexOf('\\)', cursor + 2);
      if (closeIndex > cursor + 2) {
        const mathContent: string = text.substring(cursor + 2, closeIndex).trim();
        return new InlineMatchResult(true, closeIndex + 2, [
          MarkdownParser.createToken(mathContent, inheritedStyle | InlineTokenStyle.Math, href)
        ]);
      }
    }

    if (text[cursor] === '$' && (cursor === 0 || text[cursor - 1] !== '\\')) {
      if (cursor + 1 < text.length && text[cursor + 1] === '$') {
        return new InlineMatchResult(false);
      }

      let closeIndex: number = cursor + 1;
      while (closeIndex < text.length) {
        if (text[closeIndex] === '$' && text[closeIndex - 1] !== '\\') {
          const mathContent: string = text.substring(cursor + 1, closeIndex).trim();
          if (mathContent.length > 0) {
            return new InlineMatchResult(true, closeIndex + 1, [
              MarkdownParser.createToken(mathContent, inheritedStyle | InlineTokenStyle.Math, href)
            ]);
          }
          break;
        }
        closeIndex++;
      }
    }

    return new InlineMatchResult(false);
  }

  private static matchAutoLink(text: string, cursor: number, inheritedStyle: number): InlineMatchResult {
    if (text[cursor] !== '<') {
      return new InlineMatchResult(false);
    }
    const closeIndex: number = text.indexOf('>', cursor + 1);
    if (closeIndex < 0) {
      return new InlineMatchResult(false);
    }

    const value: string = text.substring(cursor + 1, closeIndex);
    if (!MarkdownParser.isUrl(value)) {
      return new InlineMatchResult(false);
    }

    return new InlineMatchResult(true, closeIndex + 1, [
      MarkdownParser.createToken(value, inheritedStyle, value)
    ]);
  }

  private static matchLink(text: string, cursor: number, inheritedStyle: number): InlineMatchResult {
    let isImageSyntax: boolean = false;
    if (text[cursor] === '!') {
      if (cursor + 1 >= text.length || text[cursor + 1] !== '[') {
        return new InlineMatchResult(false);
      }
      isImageSyntax = true;
      cursor++;
    }

    if (text[cursor] !== '[') {
      return new InlineMatchResult(false);
    }

    const labelCloseIndex: number = MarkdownParser.findMatchingBracket(text, cursor);
    if (labelCloseIndex < 0 || labelCloseIndex + 1 >= text.length || text[labelCloseIndex + 1] !== '(') {
      return new InlineMatchResult(false);
    }

    const destinationCloseIndex: number = MarkdownParser.findMatchingParen(text, labelCloseIndex + 1);
    if (destinationCloseIndex < 0) {
      return new InlineMatchResult(false);
    }

    const label: string = text.substring(cursor + 1, labelCloseIndex);
    const destinationRaw: string = text.substring(labelCloseIndex + 2, destinationCloseIndex);
    const destination: string = MarkdownParser.extractLinkDestination(destinationRaw);
    if (destination.length === 0) {
      return new InlineMatchResult(false);
    }

    const labelTokens: Array<InlineToken> = MarkdownParser.parseInlineSegment(label, inheritedStyle, destination);
    if (labelTokens.length === 0) {
      const fallbackLabel: string = isImageSyntax && label.length === 0 ? destination : label;
      labelTokens.push(MarkdownParser.createToken(fallbackLabel, inheritedStyle, destination));
    }

    return new InlineMatchResult(true, destinationCloseIndex + 1, labelTokens);
  }

  private static matchBareUrl(text: string, cursor: number, inheritedStyle: number): InlineMatchResult {
    if (!(text.startsWith('http://', cursor) || text.startsWith('https://', cursor))) {
      return new InlineMatchResult(false);
    }

    let endIndex: number = cursor;
    while (endIndex < text.length && !MarkdownParser.isWhitespace(text[endIndex]) &&
      text[endIndex] !== '<' && text[endIndex] !== '>') {
      endIndex++;
    }

    const rawValue: string = text.substring(cursor, endIndex);
    const normalizedValue: string = MarkdownParser.trimTrailingUrlPunctuation(rawValue);
    if (normalizedValue.length === 0) {
      return new InlineMatchResult(false);
    }

    const nextIndex: number = cursor + normalizedValue.length;
    return new InlineMatchResult(true, nextIndex, [
      MarkdownParser.createToken(normalizedValue, inheritedStyle, normalizedValue)
    ]);
  }

  private static matchStyledInline(text: string, cursor: number): StyledInlineMatchResult {
    const delimiters: Array<string> = ['***', '___', '~~', '**', '__', '*', '_'];
    const styles: Array<number> = [
      InlineTokenStyle.Bold | InlineTokenStyle.Italic,
      InlineTokenStyle.Bold | InlineTokenStyle.Italic,
      InlineTokenStyle.Strike,
      InlineTokenStyle.Bold,
      InlineTokenStyle.Bold,
      InlineTokenStyle.Italic,
      InlineTokenStyle.Italic
    ];

    for (let delimiterIndex = 0; delimiterIndex < delimiters.length; delimiterIndex++) {
      const delimiter: string = delimiters[delimiterIndex];
      if (!MarkdownParser.hasPrefix(text, cursor, delimiter)) {
        continue;
      }

      const closeIndex: number = MarkdownParser.findUnescaped(text, delimiter, cursor + delimiter.length);
      if (closeIndex <= cursor + delimiter.length) {
        continue;
      }

      const content: string = text.substring(cursor + delimiter.length, closeIndex);
      return new StyledInlineMatchResult(true, closeIndex + delimiter.length, content, styles[delimiterIndex]);
    }

    return new StyledInlineMatchResult(false);
  }

  private static startsBlock(lines: Array<string>, index: number, endIndex: number): boolean {
    const line: string = lines[index];
    if (MarkdownParser.isBlank(line)) {
      return true;
    }
    if (MarkdownParser.isBlockStarterLine(line)) {
      return true;
    }
    if (index + 1 < endIndex && MarkdownParser.isTableStart(line, lines[index + 1])) {
      return true;
    }
    return false;
  }

  private static isBlockStarterLine(line: string): boolean {
    return MarkdownParser.matchFence(line).matched ||
      MarkdownParser.isMathBlockStarterLine(line) ||
      MarkdownParser.isAtxHeadingLine(line) ||
      MarkdownParser.isDividerLine(line) ||
      MarkdownParser.isImageLine(line) ||
      MarkdownParser.isQuoteLine(line) ||
      MarkdownParser.matchListMarker(line).matched;
  }

  private static matchFence(line: string): FenceMatchResult {
    const match: RegExpMatchArray | null = line.match(/^\s{0,3}(`{3,}|~{3,})(.*)$/);
    if (match === null) {
      return new FenceMatchResult(false);
    }

    const marker: string = match[1];
    const language: string = MarkdownParser.trimLine(match[2]).split(/\s+/)[0];
    return new FenceMatchResult(true, marker, marker.charAt(0), marker.length, language);
  }

  private static isMathBlockStarterLine(line: string): boolean {
    const trimmedLine: string = MarkdownParser.trimLine(line);
    return trimmedLine === '\\[' ||
      trimmedLine === '$$' ||
      (trimmedLine.startsWith('\\[') && trimmedLine.endsWith('\\]') && trimmedLine.length > 4) ||
      (trimmedLine.startsWith('$$') && trimmedLine.endsWith('$$') && trimmedLine.length > 4);
  }

  private static isFenceCloseLine(line: string, markerChar: string, markerLength: number): boolean {
    const closePattern: RegExp = new RegExp(`^\\s{0,3}${markerChar}{${markerLength},}\\s*$`);
    return closePattern.test(line);
  }

  private static isDividerLine(line: string): boolean {
    return /^\s{0,3}([-*_])(?:\s*\1){2,}\s*$/.test(line);
  }

  private static isAtxHeadingLine(line: string): boolean {
    return /^\s{0,3}(#{1,6})\s*(.*?)\s*#*\s*$/.test(line);
  }

  private static isImageLine(line: string): boolean {
    const trimmedLine: string = MarkdownParser.trimLine(line);
    return /^\s*!\[(.*?)\]\((\S+?)(?:\s+["'](.*?)["'])?\)\s*$/.test(line) ||
      /^<img\b[^>]*>$/i.test(trimmedLine) ||
      MarkdownParser.looksLikeImageUrl(trimmedLine);
  }

  private static isQuoteLine(line: string): boolean {
    return /^\s{0,3}>\s?.*$/.test(line);
  }

  private static matchListMarker(line: string): ListMarkerMatch {
    const taskMatch: RegExpMatchArray | null = line.match(/^(\s{0,8})[-*+]\s+\[(x|X| )\]\s*(.*)$/);
    if (taskMatch !== null) {
      return new ListMarkerMatch(true, taskMatch[1].length, 6,
        MarkdownBlockType.TaskList, taskMatch[3], taskMatch[2].toLowerCase() === 'x');
    }

    const unorderedMatch: RegExpMatchArray | null = line.match(/^(\s{0,8})[-*+]\s*(.*)$/);
    if (unorderedMatch !== null) {
      return new ListMarkerMatch(true, unorderedMatch[1].length, 2,
        MarkdownBlockType.UnorderedList, unorderedMatch[2]);
    }

    const orderedMatch: RegExpMatchArray | null = line.match(/^(\s{0,8})(\d+)[.)]\s*(.*)$/);
    if (orderedMatch !== null) {
      const markerLength: number = orderedMatch[2].length + 2;
      return new ListMarkerMatch(true, orderedMatch[1].length, markerLength,
        MarkdownBlockType.OrderedList, orderedMatch[3], false, Number(orderedMatch[2]));
    }

    return new ListMarkerMatch(false);
  }

  private static isSameListFamily(left: ListMarkerMatch, right: ListMarkerMatch): boolean {
    return left.type === right.type;
  }

  private static isTableStart(headerLine: string, separatorLine: string): boolean {
    if (!headerLine.includes('|')) {
      return false;
    }

    const headerCells: Array<string> = MarkdownParser.splitTableCells(headerLine);
    const separatorCells: Array<string> = MarkdownParser.splitTableCells(separatorLine);
    if (headerCells.length < 2 || headerCells.length !== separatorCells.length) {
      return false;
    }

    for (let index = 0; index < separatorCells.length; index++) {
      if (!/^:?-{3,}:?$/.test(MarkdownParser.trimLine(separatorCells[index]))) {
        return false;
      }
    }
    return true;
  }

  private static isTableRow(line: string): boolean {
    return !MarkdownParser.isBlank(line) && line.includes('|');
  }

  private static splitTableCells(line: string): Array<string> {
    let normalizedLine: string = MarkdownParser.trimLine(line);
    if (normalizedLine.startsWith('|')) {
      normalizedLine = normalizedLine.substring(1);
    }
    if (normalizedLine.endsWith('|')) {
      normalizedLine = normalizedLine.substring(0, normalizedLine.length - 1);
    }

    const cells: Array<string> = [];
    let currentCell: string = '';
    let cursor: number = 0;
    while (cursor < normalizedLine.length) {
      if (normalizedLine[cursor] === '|' && (cursor === 0 || normalizedLine[cursor - 1] !== '\\')) {
        cells.push(MarkdownParser.trimLine(currentCell));
        currentCell = '';
        cursor++;
        continue;
      }
      currentCell += normalizedLine[cursor];
      cursor++;
    }
    cells.push(MarkdownParser.trimLine(currentCell));
    return cells;
  }

  private static parseTableAlignment(cell: string): MarkdownTableAlignment {
    const normalized: string = MarkdownParser.trimLine(cell);
    const startsWithColon: boolean = normalized.startsWith(':');
    const endsWithColon: boolean = normalized.endsWith(':');
    if (startsWithColon && endsWithColon) {
      return MarkdownTableAlignment.Center;
    }
    if (startsWithColon) {
      return MarkdownTableAlignment.Left;
    }
    if (endsWithColon) {
      return MarkdownTableAlignment.Right;
    }
    return MarkdownTableAlignment.None;
  }

  private static findMatchingBracket(text: string, openIndex: number): number {
    let depth: number = 0;
    let cursor: number = openIndex;
    while (cursor < text.length) {
      if (text[cursor] === '\\') {
        cursor += 2;
        continue;
      }
      if (text[cursor] === '[') {
        depth++;
      } else if (text[cursor] === ']') {
        depth--;
        if (depth === 0) {
          return cursor;
        }
      }
      cursor++;
    }
    return -1;
  }

  private static findMatchingParen(text: string, openIndex: number): number {
    if (openIndex >= text.length || text[openIndex] !== '(') {
      return -1;
    }

    let depth: number = 0;
    let cursor: number = openIndex;
    while (cursor < text.length) {
      if (text[cursor] === '\\') {
        cursor += 2;
        continue;
      }
      if (text[cursor] === '(') {
        depth++;
      } else if (text[cursor] === ')') {
        depth--;
        if (depth === 0) {
          return cursor;
        }
      }
      cursor++;
    }
    return -1;
  }

  private static extractLinkDestination(rawValue: string): string {
    const trimmed: string = MarkdownParser.trimLine(rawValue);
    if (trimmed.length === 0) {
      return '';
    }

    if (trimmed.startsWith('<')) {
      const closeIndex: number = trimmed.indexOf('>');
      if (closeIndex > 0) {
        return trimmed.substring(1, closeIndex);
      }
    }

    let whitespaceIndex: number = -1;
    for (let index = 0; index < trimmed.length; index++) {
      if (MarkdownParser.isWhitespace(trimmed[index])) {
        whitespaceIndex = index;
        break;
      }
    }

    if (whitespaceIndex < 0) {
      return trimmed;
    }
    return trimmed.substring(0, whitespaceIndex);
  }

  private static trimTrailingUrlPunctuation(value: string): string {
    let result: string = value;
    while (result.length > 0) {
      const lastChar: string = result.charAt(result.length - 1);
      if (lastChar === '.' || lastChar === ',' || lastChar === '!' || lastChar === '?' ||
        lastChar === ';' || lastChar === ':') {
        result = result.substring(0, result.length - 1);
        continue;
      }
      if (lastChar === ')' && MarkdownParser.countChar(result, '(') < MarkdownParser.countChar(result, ')')) {
        result = result.substring(0, result.length - 1);
        continue;
      }
      if (lastChar === ']') {
        result = result.substring(0, result.length - 1);
        continue;
      }
      break;
    }
    return result;
  }

  private static countChar(text: string, target: string): number {
    let count: number = 0;
    for (let index = 0; index < text.length; index++) {
      if (text[index] === target) {
        count++;
      }
    }
    return count;
  }

  private static findUnescaped(text: string, searchValue: string, fromIndex: number): number {
    let index: number = text.indexOf(searchValue, fromIndex);
    while (index >= 0) {
      if (!MarkdownParser.isEscaped(text, index)) {
        return index;
      }
      index = text.indexOf(searchValue, index + searchValue.length);
    }
    return -1;
  }

  private static isEscaped(text: string, index: number): boolean {
    let backslashCount: number = 0;
    let cursor: number = index - 1;
    while (cursor >= 0 && text[cursor] === '\\') {
      backslashCount++;
      cursor--;
    }
    return backslashCount % 2 === 1;
  }

  private static hasPrefix(text: string, index: number, prefix: string): boolean {
    if (index + prefix.length > text.length) {
      return false;
    }
    return text.substring(index, index + prefix.length) === prefix;
  }

  private static appendTokens(target: Array<InlineToken>, source: Array<InlineToken>): void {
    for (let index = 0; index < source.length; index++) {
      target.push(source[index]);
    }
  }

  private static mergeAdjacentTokens(tokens: Array<InlineToken>): Array<InlineToken> {
    const merged: Array<InlineToken> = [];
    for (let index = 0; index < tokens.length; index++) {
      const current: InlineToken = tokens[index];
      if (merged.length === 0) {
        merged.push(current);
        continue;
      }

      const previous: InlineToken = merged[merged.length - 1];
      if (previous.style === current.style && previous.href === current.href) {
        previous.text += current.text;
        continue;
      }
      merged.push(current);
    }
    return merged;
  }

  private static createToken(text: string, style: number = InlineTokenStyle.Plain, href: string = ''): InlineToken {
    MarkdownParser.tokenCounter++;
    return new InlineToken(`token-${MarkdownParser.tokenCounter}`, text, style, href);
  }

  private static nextBlockId(): string {
    MarkdownParser.blockCounter++;
    return `block-${MarkdownParser.blockCounter}`;
  }

  private static nextListItemId(): string {
    MarkdownParser.listItemCounter++;
    return `list-item-${MarkdownParser.listItemCounter}`;
  }

  private static repeatChar(value: string, count: number): string {
    let result: string = '';
    for (let index = 0; index < count; index++) {
      result += value;
    }
    return result;
  }

  private static stripIndent(line: string, indent: number): string {
    let cursor: number = 0;
    let remainingIndent: number = indent;
    while (cursor < line.length && remainingIndent > 0 && line[cursor] === ' ') {
      cursor++;
      remainingIndent--;
    }
    return line.substring(cursor);
  }

  private static leadingSpaceCount(line: string): number {
    let count: number = 0;
    while (count < line.length && line[count] === ' ') {
      count++;
    }
    return count;
  }

  private static trimLine(line: string): string {
    return line.replace(/^\s+/, '').replace(/\s+$/, '');
  }

  private static isBlank(line: string): boolean {
    return MarkdownParser.trimLine(line).length === 0;
  }

  private static isUrl(value: string): boolean {
    return /^https?:\/\/[^\s]+$/i.test(value);
  }

  private static isWhitespace(value: string): boolean {
    return value === ' ' || value === '\n' || value === '\r' || value === '\t';
  }

  private static isEscapable(value: string): boolean {
    return '\\`*_{}[]()#+-.!|~>'.includes(value);
  }
}
