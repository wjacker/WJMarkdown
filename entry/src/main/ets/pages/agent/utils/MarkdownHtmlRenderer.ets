import {
  InlineToken,
  InlineTokenStyle,
  MarkdownBlock,
  MarkdownBlockType,
  MarkdownListItem,
  MarkdownTableAlignment
} from '../models/MarkdownModels';
import { MarkdownParser } from './MarkdownParser';

export class MarkdownHtmlRenderer {
  static render(markdown: string): string {
    const normalizedMarkdown: string = MarkdownParser.normalizeMathMarkdown(markdown);
    return MarkdownHtmlRenderer.renderBlocks(MarkdownParser.parse(normalizedMarkdown));
  }

  private static renderBlocks(blocks: Array<MarkdownBlock>): string {
    let html: string = '';
    for (let index: number = 0; index < blocks.length; index++) {
      html += MarkdownHtmlRenderer.renderBlock(blocks[index]);
    }
    return html;
  }

  private static renderBlock(block: MarkdownBlock): string {
    if (block.type === MarkdownBlockType.Heading) {
      return `<h${block.level}>${MarkdownHtmlRenderer.renderInlineTokens(block.tokens)}</h${block.level}>`;
    }
    if (block.type === MarkdownBlockType.Math) {
      const rawMath: string = MarkdownHtmlRenderer.escapeHtml(block.math);
      return `<div class="math-block">` +
        `<div class="math-select-source">${rawMath}</div>` +
        `<div class="math-render">\\[${rawMath}\\]</div>` +
        `</div>`;
    }
    if (block.type === MarkdownBlockType.Code) {
      return `<pre><code>${MarkdownHtmlRenderer.escapeHtml(block.code)}</code></pre>`;
    }
    if (block.type === MarkdownBlockType.Quote) {
      return `<blockquote>${MarkdownHtmlRenderer.renderBlocks(block.children)}</blockquote>`;
    }
    if (block.type === MarkdownBlockType.UnorderedList ||
      block.type === MarkdownBlockType.OrderedList ||
      block.type === MarkdownBlockType.TaskList) {
      return MarkdownHtmlRenderer.renderList(block);
    }
    if (block.type === MarkdownBlockType.Divider) {
      return '<hr />';
    }
    if (block.type === MarkdownBlockType.Table) {
      return MarkdownHtmlRenderer.renderTable(block);
    }
    if (block.type === MarkdownBlockType.Image) {
      let captionHtml: string = '';
      if (block.imageAlt.length > 0) {
        captionHtml = `<div class="image-caption">${MarkdownHtmlRenderer.escapeHtml(block.imageAlt)}</div>`;
      }
      return `<figure><img src="${MarkdownHtmlRenderer.escapeAttribute(block.imageUrl)}" alt="${MarkdownHtmlRenderer.escapeAttribute(block.imageAlt)}" />${captionHtml}</figure>`;
    }
    return `<p>${MarkdownHtmlRenderer.renderInlineTokens(block.tokens)}</p>`;
  }

  private static renderList(block: MarkdownBlock): string {
    const tagName: string = block.type === MarkdownBlockType.OrderedList ? 'ol' : 'ul';
    const className: string = block.type === MarkdownBlockType.TaskList ? ' class="task-list"' : '';
    const startAttr: string = block.type === MarkdownBlockType.OrderedList && block.startNumber > 1
      ? ` start="${block.startNumber}"`
      : '';
    let itemsHtml: string = '';
    for (let index: number = 0; index < block.listItems.length; index++) {
      itemsHtml += MarkdownHtmlRenderer.renderListItem(block, block.listItems[index], index);
    }
    return `<${tagName}${className}${startAttr}>${itemsHtml}</${tagName}>`;
  }

  private static renderListItem(block: MarkdownBlock, item: MarkdownListItem, index: number): string {
    let prefixHtml: string = '';
    let itemClassName: string = '';
    if (block.type === MarkdownBlockType.TaskList) {
      itemClassName = ' class="task-list-item"';
      prefixHtml = `<span class="task-checkbox${item.checked ? ' is-checked' : ''}">${item.checked ? 'x' : ''}</span>`;
    }

    let contentHtml: string = '';
    if (item.blocks.length > 0) {
      contentHtml = MarkdownHtmlRenderer.renderBlocks(item.blocks);
    } else if (index < block.items.length) {
      contentHtml = MarkdownHtmlRenderer.renderInlineTokens(block.items[index]);
    }
    return `<li${itemClassName}>${prefixHtml}<div class="task-list-content">${contentHtml}</div></li>`;
  }

  private static renderTable(block: MarkdownBlock): string {
    let headerHtml: string = '';
    for (let index: number = 0; index < block.headers.length; index++) {
      headerHtml += `<th style="text-align:${MarkdownHtmlRenderer.toCssAlign(block, index)};">${MarkdownHtmlRenderer.renderInlineTokens(block.headers[index])}</th>`;
    }

    let bodyHtml: string = '';
    for (let rowIndex: number = 0; rowIndex < block.rows.length; rowIndex++) {
      let rowHtml: string = '';
      const row = block.rows[rowIndex];
      for (let cellIndex: number = 0; cellIndex < row.length; cellIndex++) {
        rowHtml += `<td style="text-align:${MarkdownHtmlRenderer.toCssAlign(block, cellIndex)};">${MarkdownHtmlRenderer.renderInlineTokens(row[cellIndex])}</td>`;
      }
      bodyHtml += `<tr>${rowHtml}</tr>`;
    }

    return `<table><thead><tr>${headerHtml}</tr></thead><tbody>${bodyHtml}</tbody></table>`;
  }

  private static toCssAlign(block: MarkdownBlock, columnIndex: number): string {
    if (columnIndex >= block.tableAlignments.length) {
      return 'left';
    }
    const alignment: MarkdownTableAlignment = block.tableAlignments[columnIndex];
    if (alignment === MarkdownTableAlignment.Center) {
      return 'center';
    }
    if (alignment === MarkdownTableAlignment.Right) {
      return 'right';
    }
    return 'left';
  }

  private static renderInlineTokens(tokens: Array<InlineToken>): string {
    let html: string = '';
    for (let index: number = 0; index < tokens.length; index++) {
      html += MarkdownHtmlRenderer.renderInlineToken(tokens[index]);
    }
    return html;
  }

  private static renderInlineToken(token: InlineToken): string {
    if ((token.style & InlineTokenStyle.Math) !== 0) {
      const rawMath: string = MarkdownHtmlRenderer.escapeHtml(token.text);
      return `<span class="math-inline">` +
        `<span class="math-select-source">${rawMath}</span>` +
        `<span class="math-render">\\(${rawMath}\\)</span>` +
        `</span>`;
    }

    let html: string = MarkdownHtmlRenderer.escapeHtml(token.text);
    if ((token.style & InlineTokenStyle.Code) !== 0) {
      html = `<code>${html}</code>`;
    }
    if ((token.style & InlineTokenStyle.Strike) !== 0) {
      html = `<del>${html}</del>`;
    }
    if ((token.style & InlineTokenStyle.Italic) !== 0) {
      html = `<em>${html}</em>`;
    }
    if ((token.style & InlineTokenStyle.Bold) !== 0) {
      html = `<strong>${html}</strong>`;
    }
    if (token.href.length > 0) {
      html = `<a href="${MarkdownHtmlRenderer.escapeAttribute(token.href)}">${html}</a>`;
    }
    return html;
  }

  private static escapeHtml(value: string): string {
    return value
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  private static escapeAttribute(value: string): string {
    return MarkdownHtmlRenderer.escapeHtml(value);
  }
}
