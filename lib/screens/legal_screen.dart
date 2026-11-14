import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../config.dart';

/// The legal documents shipped in `assets/legal/`.
enum LegalDocument {
  privacy('Privacy Policy', 'assets/legal/privacy_policy.md'),
  terms('Terms of Service', 'assets/legal/terms_of_service.md');

  const LegalDocument(this.title, this.assetPath);

  final String title;
  final String assetPath;
}

/// Reads one of the bundled markdown documents and renders it in the app.
/// Keeping the files in `assets/legal/` means the App Store listing, the
/// website and the app can all use the same text.
class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late Future<String> _content = _load();

  Future<String> _load() => rootBundle.loadString(widget.document.assetPath);

  @override
  void didUpdateWidget(LegalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document) {
      _content = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.document.title)),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: _content,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    'This document could not be loaded. Please try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              );
            }
            return SelectionArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
                children: [
                  ..._MarkdownBuilder(context).build(snapshot.data!),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 14),
                  Text(
                    LegalInfo.copyright,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Locmate is operated by ${LegalInfo.company}, '
                    '${LegalInfo.address}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Small markdown renderer for the legal pages. It supports the subset used by
/// the documents: headings, paragraphs, bullet lists, horizontal rules and
/// `**bold**` text. Avoiding a markdown dependency keeps the app lean.
class _MarkdownBuilder {
  _MarkdownBuilder(this.context);

  final BuildContext context;

  List<Widget> build(String markdown) {
    final scheme = Theme.of(context).colorScheme;
    final widgets = <Widget>[];
    final paragraph = <String>[];
    final bullets = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text.rich(
            _inline(
              paragraph.join(' '),
              TextStyle(
                fontSize: 13.5,
                height: 1.55,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
      paragraph.clear();
    }

    void flushBullets() {
      if (bullets.isEmpty) return;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final bullet in bullets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7, left: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text.rich(
                          _inline(
                            bullet,
                            TextStyle(
                              fontSize: 13.5,
                              height: 1.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
      bullets.clear();
    }

    for (final rawLine in markdown.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        flushParagraph();
        flushBullets();
        continue;
      }
      if (line.startsWith('## ')) {
        flushParagraph();
        flushBullets();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 7),
            child: Text(
              line.substring(3).trim(),
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: scheme.onSurface,
              ),
            ),
          ),
        );
        continue;
      }
      if (line.startsWith('### ')) {
        flushParagraph();
        flushBullets();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Text(
              line.substring(4).trim(),
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
        );
        continue;
      }
      if (line.startsWith('# ')) {
        // The app bar already shows the document title.
        flushParagraph();
        flushBullets();
        continue;
      }
      if (line == '---') {
        flushParagraph();
        flushBullets();
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: scheme.outlineVariant),
          ),
        );
        continue;
      }
      if (line.startsWith('- ')) {
        flushParagraph();
        bullets.add(line.substring(2).trim());
        continue;
      }
      flushBullets();
      paragraph.add(line);
    }

    flushParagraph();
    flushBullets();
    return widgets;
  }

  TextSpan _inline(String text, TextStyle style) {
    final spans = <InlineSpan>[];
    final bold = RegExp(r'\*\*(.+?)\*\*');
    var start = 0;
    for (final match in bold.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    return TextSpan(style: style, children: spans);
  }
}
