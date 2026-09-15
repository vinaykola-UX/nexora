import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';

/// Clean ChatGPT-style Markdown renderer for Nexora AI responses.
/// Renders headers, lists, bold/italic formatting, inline code,
/// horizontally scrollable code blocks with language tag and copy button,
/// and responsive tables without external markdown dependencies.
class NexoraMarkdownRenderer extends StatelessWidget {
  const NexoraMarkdownRenderer({
    required this.text,
    super.key,
    this.baseStyle,
    this.textColor,
  });

  final String text;
  final TextStyle? baseStyle;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final defaultTextColor = textColor ?? const Color(NexoraColors.text);
    final defaultStyle = baseStyle ??
        TextStyle(
          fontSize: 14.5,
          height: 1.55,
          color: defaultTextColor,
          letterSpacing: 0.1,
        );

    final blocks = _parseBlocks(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks.map((block) => _buildBlock(context, block, defaultStyle)).toList(),
    );
  }

  // --------------------------------------------------------------------------
  // Block Parsing
  // --------------------------------------------------------------------------

  List<_MarkdownBlock> _parseBlocks(String markdown) {
    final lines = markdown.replaceAll('\r\n', '\n').split('\n');
    final blocks = <_MarkdownBlock>[];
    var i = 0;

    while (i < lines.length) {
      final line = lines[i];

      // 1. Fenced Code Block
      if (line.trim().startsWith('```')) {
        final lang = line.trim().substring(3).trim();
        final codeLines = <String>[];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          codeLines.add(lines[i]);
          i++;
        }
        if (i < lines.length && lines[i].trim().startsWith('```')) {
          i++; // Skip closing ```
        }
        blocks.add(_MarkdownBlock(
          type: _BlockType.codeBlock,
          content: codeLines.join('\n'),
          extra: lang,
        ));
        continue;
      }

      // 2. Table (| header | header |)
      if (_isTableLine(line) && i + 1 < lines.length && _isTableDivider(lines[i + 1])) {
        final tableLines = <String>[line, lines[i + 1]];
        i += 2;
        while (i < lines.length && _isTableLine(lines[i])) {
          tableLines.add(lines[i]);
          i++;
        }
        blocks.add(_MarkdownBlock(
          type: _BlockType.table,
          content: tableLines.join('\n'),
        ));
        continue;
      }

      // 3. Headings (#, ##, ###, ####)
      final trimmed = line.trim();
      if (trimmed.startsWith('#')) {
        var level = 0;
        while (level < trimmed.length && trimmed[level] == '#') {
          level++;
        }
        if (level <= 6 && level < trimmed.length && trimmed[level] == ' ') {
          final headingText = trimmed.substring(level).trim();
          blocks.add(_MarkdownBlock(
            type: _BlockType.heading,
            content: headingText,
            level: level,
          ));
          i++;
          continue;
        }
      }

      // 4. Horizontal Rule (---, ***, ___)
      if (RegExp(r'^(?:-{3,}|\*{3,}|_{3,})$').hasMatch(trimmed)) {
        blocks.add(_MarkdownBlock(type: _BlockType.horizontalRule, content: ''));
        i++;
        continue;
      }

      // 5. Blockquote (> quote)
      if (trimmed.startsWith('>')) {
        final quoteLines = <String>[trimmed.replaceFirst(RegExp(r'^>\s?'), '')];
        i++;
        while (i < lines.length && lines[i].trim().startsWith('>')) {
          quoteLines.add(lines[i].trim().replaceFirst(RegExp(r'^>\s?'), ''));
          i++;
        }
        blocks.add(_MarkdownBlock(
          type: _BlockType.blockquote,
          content: quoteLines.join('\n'),
        ));
        continue;
      }

      // 6. Unordered List Item (- item or * item)
      final unorderedMatch = RegExp(r'^(\s*)[-*+]\s+(.*)$').firstMatch(line);
      if (unorderedMatch != null) {
        final indent = unorderedMatch.group(1)?.length ?? 0;
        final listText = unorderedMatch.group(2) ?? '';
        blocks.add(_MarkdownBlock(
          type: _BlockType.bulletItem,
          content: listText,
          level: (indent / 2).floor(),
        ));
        i++;
        continue;
      }

      // 7. Ordered List Item (1. item)
      final orderedMatch = RegExp(r'^(\s*)(\d+)[.)]\s+(.*)$').firstMatch(line);
      if (orderedMatch != null) {
        final indent = orderedMatch.group(1)?.length ?? 0;
        final number = orderedMatch.group(2) ?? '1';
        final listText = orderedMatch.group(3) ?? '';
        blocks.add(_MarkdownBlock(
          type: _BlockType.numberedItem,
          content: listText,
          extra: number,
          level: (indent / 2).floor(),
        ));
        i++;
        continue;
      }

      // 8. Empty lines
      if (trimmed.isEmpty) {
        blocks.add(_MarkdownBlock(type: _BlockType.spacing, content: ''));
        i++;
        continue;
      }

      // 9. Standard Paragraph (collect consecutive non-block lines)
      final paraLines = <String>[line];
      i++;
      while (i < lines.length) {
        final nextTrimmed = lines[i].trim();
        if (nextTrimmed.isEmpty ||
            nextTrimmed.startsWith('#') ||
            nextTrimmed.startsWith('```') ||
            nextTrimmed.startsWith('>') ||
            RegExp(r'^(?:-{3,}|\*{3,}|_{3,})$').hasMatch(nextTrimmed) ||
            RegExp(r'^[-*+]\s+').hasMatch(nextTrimmed) ||
            RegExp(r'^\d+[.)]\s+').hasMatch(nextTrimmed) ||
            _isTableLine(lines[i])) {
          break;
        }
        paraLines.add(lines[i]);
        i++;
      }

      blocks.add(_MarkdownBlock(
        type: _BlockType.paragraph,
        content: paraLines.join(' '),
      ));
    }

    return blocks;
  }

  bool _isTableLine(String line) {
    final t = line.trim();
    return t.startsWith('|') && t.endsWith('|') && t.length > 2;
  }

  bool _isTableDivider(String line) {
    final t = line.trim();
    if (!t.startsWith('|') || !t.endsWith('|')) {
      return false;
    }
    final cells = t.substring(1, t.length - 1).split('|');
    return cells.every((c) => RegExp(r'^\s*:?-+:?\s*$').hasMatch(c));
  }

  // --------------------------------------------------------------------------
  // Block Building
  // --------------------------------------------------------------------------

  Widget _buildBlock(BuildContext context, _MarkdownBlock block, TextStyle defaultStyle) {
    switch (block.type) {
      case _BlockType.heading:
        return _buildHeading(block.content, block.level ?? 1);
      case _BlockType.codeBlock:
        return _buildCodeBlock(context, block.content, block.extra ?? '');
      case _BlockType.table:
        return _buildTable(block.content, defaultStyle);
      case _BlockType.bulletItem:
        return _buildBulletItem(context, block.content, block.level ?? 0, defaultStyle);
      case _BlockType.numberedItem:
        return _buildNumberedItem(context, block.content, block.extra ?? '1', block.level ?? 0, defaultStyle);
      case _BlockType.blockquote:
        return _buildBlockquote(context, block.content, defaultStyle);
      case _BlockType.horizontalRule:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: NexoraSpacing.md),
          child: Divider(color: Color(NexoraColors.divider), height: 1, thickness: 1),
        );
      case _BlockType.spacing:
        return const SizedBox(height: 6);
      case _BlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildRichText(context, block.content, defaultStyle),
        );
    }
  }

  Widget _buildHeading(String text, int level) {
    double fontSize;
    FontWeight fontWeight;
    double topMargin;
    double bottomMargin;

    switch (level) {
      case 1:
        fontSize = 18.5;
        fontWeight = FontWeight.w700;
        topMargin = 14;
        bottomMargin = 6;
        break;
      case 2:
        fontSize = 16.5;
        fontWeight = FontWeight.w700;
        topMargin = 12;
        bottomMargin = 4;
        break;
      case 3:
        fontSize = 15;
        fontWeight = FontWeight.w600;
        topMargin = 10;
        bottomMargin = 4;
        break;
      default:
        fontSize = 14;
        fontWeight = FontWeight.w600;
        topMargin = 8;
        bottomMargin = 2;
        break;
    }

    return Padding(
      padding: EdgeInsets.only(top: topMargin, bottom: bottomMargin),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: 1.35,
          color: const Color(NexoraColors.text),
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildBulletItem(BuildContext context, String content, int indentLevel, TextStyle defaultStyle) => Padding(
        padding: EdgeInsets.only(
          left: indentLevel * 16.0,
          bottom: 5,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, right: 8),
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(NexoraColors.primary),
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: _buildRichText(context, content, defaultStyle),
            ),
          ],
        ),
      );

  Widget _buildNumberedItem(
    BuildContext context,
    String content,
    String number,
    int indentLevel,
    TextStyle defaultStyle,
  ) =>
      Padding(
        padding: EdgeInsets.only(
          left: indentLevel * 16.0,
          bottom: 5,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '$number.',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(NexoraColors.textSecondary),
                  height: 1.55,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildRichText(context, content, defaultStyle),
            ),
          ],
        ),
      );

  Widget _buildBlockquote(BuildContext context, String content, TextStyle defaultStyle) => Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(NexoraColors.background),
          borderRadius: BorderRadius.circular(6),
          border: const Border(
            left: BorderSide(color: Color(NexoraColors.primary), width: 3.5),
          ),
        ),
        child: _buildRichText(
          context,
          content,
          defaultStyle.copyWith(
            fontStyle: FontStyle.italic,
            color: const Color(NexoraColors.textSecondary),
          ),
        ),
      );

  Widget _buildCodeBlock(BuildContext context, String code, String language) {
    final displayLang = language.trim().isEmpty ? 'CODE' : language.trim().toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF313244), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: const BoxDecoration(
                color: Color(0xFF181825),
                border: Border(bottom: BorderSide(color: Color(0xFF313244), width: 0.8)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    displayLang,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFA6ADC8),
                      letterSpacing: 0.5,
                    ),
                  ),
                  _CodeCopyButton(codeText: code),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                code,
                style: GoogleFonts.firaCode(
                  fontSize: 12.5,
                  height: 1.5,
                  color: const Color(0xFFCDD6F4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(String tableContent, TextStyle defaultStyle) {
    final lines = tableContent.trim().split('\n');
    if (lines.length < 2) {
      return const SizedBox.shrink();
    }

    List<String> extractCells(String line) {
      final trimmed = line.trim();
      final inner = (trimmed.startsWith('|') && trimmed.endsWith('|'))
          ? trimmed.substring(1, trimmed.length - 1)
          : trimmed;
      return inner.split('|').map((c) => c.trim()).toList();
    }

    final headerCells = extractCells(lines[0]);
    final rows = <List<String>>[];

    for (var r = 2; r < lines.length; r++) {
      if (lines[r].trim().isNotEmpty) {
        rows.add(extractCells(lines[r]));
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(NexoraColors.divider), width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder.all(
              color: const Color(NexoraColors.divider),
              width: 0.5,
            ),
            children: [
              TableRow(
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F1EA),
                ),
                children: headerCells
                    .map((cell) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Text(
                            cell,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(NexoraColors.text),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              ...rows.map((row) => TableRow(
                    children: row
                        .map((cell) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Text(
                                cell,
                                style: defaultStyle.copyWith(fontSize: 13),
                              ),
                            ))
                        .toList(),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Inline Markdown Parsing (Bold, Italic, Code, Links)
  // --------------------------------------------------------------------------

  Widget _buildRichText(BuildContext context, String text, TextStyle baseStyle) {
    final spans = _parseInlineSpans(context, text, baseStyle);
    return SelectableText.rich(
      TextSpan(children: spans),
      style: baseStyle,
    );
  }

  List<InlineSpan> _parseInlineSpans(BuildContext context, String text, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    final regex = RegExp(
      '(`([^`]+)`)'
      r'|(\*\*\*(.+?)\*\*\*)'
      r'|(\*\*(.+?)\*\*)'
      r'|(\*([^*\n]+)\*)'
      r'|(\[([^\]]+)\]\(([^)]+)\))'
      '|(~~(.+?)~~)',
    );

    var lastMatchEnd = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: baseStyle,
        ));
      }

      // Inline code: `code`
      if (match.group(2) != null) {
        final codeText = match.group(2)!;
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFFF0EDE6),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFDDD9D0), width: 0.6),
              ),
              child: Text(
                codeText,
                style: GoogleFonts.firaCode(
                  fontSize: 12,
                  color: const Color(0xFFB71C1C),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }
      // Bold + Italic: ***text***
      else if (match.group(4) != null) {
        spans.add(TextSpan(
          text: match.group(4),
          style: baseStyle.copyWith(
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
          ),
        ));
      }
      // Bold: **text**
      else if (match.group(6) != null) {
        spans.add(TextSpan(
          text: match.group(6),
          style: baseStyle.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(NexoraColors.text),
          ),
        ));
      }
      // Italic: *text*
      else if (match.group(8) != null) {
        spans.add(TextSpan(
          text: match.group(8),
          style: baseStyle.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ));
      }
      // Link: [title](url)
      else if (match.group(10) != null && match.group(11) != null) {
        final linkText = match.group(10)!;
        final linkUrl = match.group(11)!;
        spans.add(TextSpan(
          text: linkText,
          style: baseStyle.copyWith(
            color: const Color(NexoraColors.primaryDark),
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w600,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              try {
                final uri = Uri.parse(linkUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              } catch (_) {}
            },
        ));
      }
      // Strikethrough: ~~text~~
      else if (match.group(13) != null) {
        spans.add(TextSpan(
          text: match.group(13),
          style: baseStyle.copyWith(
            decoration: TextDecoration.lineThrough,
            color: const Color(NexoraColors.textMuted),
          ),
        ));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: baseStyle,
      ));
    }

    return spans;
  }
}

// ----------------------------------------------------------------------------
// Internal Helpers & Data Classes
// ----------------------------------------------------------------------------

enum _BlockType {
  paragraph,
  heading,
  codeBlock,
  table,
  bulletItem,
  numberedItem,
  blockquote,
  horizontalRule,
  spacing,
}

class _MarkdownBlock {
  _MarkdownBlock({
    required this.type,
    required this.content,
    this.extra,
    this.level,
  });

  final _BlockType type;
  final String content;
  final String? extra;
  final int? level;
}

/// Compact "Copy code" button for code block headers
class _CodeCopyButton extends StatefulWidget {
  const _CodeCopyButton({
    required this.codeText,
  });

  final String codeText;

  @override
  State<_CodeCopyButton> createState() => _CodeCopyButtonState();
}

class _CodeCopyButtonState extends State<_CodeCopyButton> {
  bool _copied = false;

  void _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.codeText));
    if (mounted) {
      setState(() => _copied = true);
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) {
          setState(() => _copied = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: _copy,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _copied ? Icons.check_rounded : Icons.copy_rounded,
                size: 13,
                color: _copied ? const Color(0xFFA6E3A1) : const Color(0xFFA6ADC8),
              ),
              const SizedBox(width: 4),
              Text(
                _copied ? 'Copied!' : 'Copy code',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _copied ? const Color(0xFFA6E3A1) : const Color(0xFFA6ADC8),
                ),
              ),
            ],
          ),
        ),
      );
}
