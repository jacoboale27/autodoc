import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/providers/language_provider.dart';
import 'package:autodoc/core/services/translation_service.dart';

class TranslatedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const TranslatedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final targetLang = languageProvider.currentLanguageCode;

    // 1. If base language is selected, display text immediately
    if (targetLang == 'es') {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    // 2. Try synchronous translation from Hive box
    final syncTranslation = TranslationService().translateSync(
      text,
      targetLang,
    );
    if (syncTranslation != null) {
      return Text(
        syncTranslation,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    // 3. If not cached, load asynchronously and fetch from API
    return FutureBuilder<String>(
      future: TranslationService().translate(text, targetLang),
      builder: (context, snapshot) {
        final displayText = snapshot.data ?? text;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isLoading ? 0.7 : 1.0,
          child: Text(
            displayText,
            style: style,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: overflow,
          ),
        );
      },
    );
  }
}
