import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../l10n_app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

/// The legal documents that ship inside the app.
///
/// `docs/legal/*.md` is the source of truth; `docs/legal/generar.py` renders it
/// into `assets/legal/*.json`, which is what this screen reads. The content is
/// drawn with native widgets on purpose: opening the Términos or the Aviso de
/// Privacidad must never hand the user off to a browser.
enum LegalDocument {
  terms('assets/legal/terminos-y-condiciones.json'),
  privacy('assets/legal/aviso-de-privacidad.json');

  const LegalDocument(this.assetPath);

  final String assetPath;
}

/// Reads one bundled document and renders it with the Detox design system.
class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

  /// Pushes the viewer on top of the current route.
  static void open(BuildContext context, LegalDocument document) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(document: document),
      ),
    );
  }

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  late Future<Map<String, dynamic>> _document;

  @override
  void initState() {
    super.initState();
    _document = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final raw = await rootBundle.loadString(widget.document.assetPath);
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  void _retry() {
    setState(() => _document = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Transparent, title-less bar: the document carries its own heading and
      // the only control the user needs here is the way back.
      appBar: AppBar(),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _document,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _LegalFailure(onRetry: _retry);
          }
          final document = snapshot.data;
          if (document == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _LegalBody(document: document);
        },
      ),
    );
  }
}

class _LegalBody extends StatelessWidget {
  const _LegalBody({required this.document});

  final Map<String, dynamic> document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? DetoxColors.muted : DetoxColors.lightMuted;
    final border =
        isDark ? DetoxColors.cardBorder : DetoxColors.lightCardBorder;
    final t = AppStrings.of(context);

    final title = document['title'] as String? ?? '';
    final updated = document['updated'] as String? ?? '';
    final blocks = ((document['blocks'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        // The generator repeats the date in the first paragraph. It is already
        // shown under the title, so that duplicate line is dropped here.
        .where((block) =>
            !(updated.isNotEmpty &&
                block['type'] == 'paragraph' &&
                ((block['text'] as String?) ?? '').contains(updated)))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          DetoxSpace.page, 0, DetoxSpace.page, DetoxSpace.section * 2),
      children: [
        AppPageHeader(title: title, subtitle: ''),
        if (updated.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '${t.legalUpdatedLabel} · $updated',
            style: theme.textTheme.labelSmall?.copyWith(color: muted),
          ),
        ],
        const SizedBox(height: DetoxSpace.item),
        Container(height: 1, color: border),
        SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final block in blocks) _LegalBlock(block: block),
            ],
          ),
        ),
      ],
    );
  }
}

/// One block of the document, rendered with native widgets.
class _LegalBlock extends StatelessWidget {
  const _LegalBlock({required this.block});

  final Map<String, dynamic> block;

  @override
  Widget build(BuildContext context) {
    final type = block['type'] as String? ?? '';
    final text = block['text'] as String? ?? '';

    if (type == 'heading') {
      final level = (block['level'] as num?)?.toInt() ?? 2;
      // Level 1 is the document name and already titles the page.
      if (level <= 1 || text.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(top: level == 2 ? 26 : 18),
        child: Text(
          text,
          style: level == 2
              ? Theme.of(context).textTheme.titleLarge
              : Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    if (type == 'paragraph') {
      final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.55,
          );
      return Padding(
        padding: const EdgeInsets.only(top: DetoxSpace.item),
        child: _InlineText(text: text, style: style),
      );
    }

    if (type == 'list') {
      final items = ((block['items'] as List?) ?? const []).cast<String>();
      return Padding(
        padding: const EdgeInsets.only(top: DetoxSpace.item),
        child: _LegalList(
          items: items,
          ordered: block['ordered'] == true,
        ),
      );
    }

    if (type == 'table') {
      return Padding(
        padding: const EdgeInsets.only(top: DetoxSpace.item + 4),
        child: _LegalTable(
          header: ((block['header'] as List?) ?? const []).cast<String>(),
          rows: ((block['rows'] as List?) ?? const [])
              .map((row) => (row as List).cast<String>())
              .toList(),
        ),
      );
    }

    if (type == 'quote') {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Padding(
        padding: const EdgeInsets.only(top: DetoxSpace.item + 4),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(detoxRadius),
            color: isDark ? DetoxColors.bgAlt : DetoxColors.lightBgAlt,
            border: Border.all(
              color: isDark ? DetoxColors.cardBorder : DetoxColors.lightCardBorder,
            ),
          ),
          child: _InlineText(
            text: text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? DetoxColors.muted : DetoxColors.lightMuted,
                  height: 1.5,
                ),
          ),
        ),
      );
    }

    if (type == 'rule') {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Divider(
          height: 1,
          thickness: 1,
          color: isDark ? DetoxColors.cardBorder : DetoxColors.lightCardBorder,
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _LegalList extends StatelessWidget {
  const _LegalList({required this.items, required this.ordered});

  final List<String> items;
  final bool ordered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final markerColor = isDark ? DetoxColors.accent : DetoxColors.accentDeep;
    final style = theme.textTheme.bodyMedium?.copyWith(height: 1.55);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < items.length; index++)
          Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: ordered ? 24 : 16,
                  child: Text(
                    ordered ? '${index + 1}.' : '•',
                    style: style?.copyWith(
                      color: markerColor,
                      fontWeight: detoxWeightEmphasis,
                    ),
                  ),
                ),
                Expanded(
                  child: _InlineText(text: items[index], style: style),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Tables are stacked instead of squeezed: on a phone the first cell becomes
/// the row heading and the remaining cells read as label/value lines.
class _LegalTable extends StatelessWidget {
  const _LegalTable({required this.header, required this.rows});

  final List<String> header;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border =
        isDark ? DetoxColors.cardBorder : DetoxColors.lightCardBorder;
    final muted = isDark ? DetoxColors.muted : DetoxColors.lightMuted;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(detoxRadius),
        color: theme.colorScheme.surface,
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) Divider(height: 1, thickness: 1, color: border),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InlineText(
                    text: rows[index].isEmpty ? '' : rows[index].first,
                    style: theme.textTheme.titleMedium,
                  ),
                  for (var cell = 1;
                      cell < rows[index].length;
                      cell++) ...[
                    const SizedBox(height: 6),
                    _InlineText(
                      text: header.length == 2
                          ? rows[index][cell]
                          : '${cell < header.length ? header[cell] : ''}: '
                              '${rows[index][cell]}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: muted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Renders the tiny slice of Markdown the documents use: `**emphasis**` and
/// `` `code` ``. Everything else is plain text.
class _InlineText extends StatelessWidget {
  const _InlineText({required this.text, this.style});

  final String text;
  final TextStyle? style;

  static final RegExp _pattern = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final base = style ?? theme.textTheme.bodyMedium ?? const TextStyle();

    if (!_pattern.hasMatch(text)) {
      return Text(text, style: base);
    }

    final emphasis = base.copyWith(fontWeight: detoxWeightEmphasis);
    final code = base.copyWith(
      fontFamily: 'monospace',
      color: isDark ? DetoxColors.accentSoft : DetoxColors.accentDeep,
    );

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final bold = match.group(1);
      spans.add(bold != null
          ? TextSpan(text: bold, style: emphasis)
          : TextSpan(text: match.group(2), style: code));
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(TextSpan(style: base, children: spans));
  }
}

class _LegalFailure extends StatelessWidget {
  const _LegalFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? DetoxColors.muted : DetoxColors.lightMuted;
    final t = AppStrings.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DetoxSpace.section),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined, size: 30, color: muted),
            const SizedBox(height: 12),
            Text(
              t.legalOpenFailed,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(t.retry),
            ),
          ],
        ),
      ),
    );
  }
}
