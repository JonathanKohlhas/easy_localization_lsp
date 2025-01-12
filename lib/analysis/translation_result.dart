import 'package:easy_localization_lsp/analysis/analysis_error.dart';
import 'package:easy_localization_lsp/json/parser.dart';

enum TranslationFailureReason {
  unknown(-1),
  noSuchTranslationKeyTooLong(0),
  noSuchTranslationKeyTooShort(1),
  callIsPluralButNoPluralTranslation(2),
  callHasGenderButNoGenderTranslation(2);

  /// Higher values mean the reason is more specific.
  /// Lower values mean the reason is more general.
  /// Used to make error messages more specific to help users fix the issue.
  final int specificity;

  const TranslationFailureReason(this.specificity);

  String get message {
    switch (this) {
      case TranslationFailureReason.unknown:
        return 'Unknown error';
      case TranslationFailureReason.noSuchTranslationKeyTooLong:
        return 'No such translation key';
      case TranslationFailureReason.noSuchTranslationKeyTooShort:
        return 'Translation key does not point to a string';
      case TranslationFailureReason.callIsPluralButNoPluralTranslation:
        return 'Translation does not have plural forms';
      case TranslationFailureReason.callHasGenderButNoGenderTranslation:
        return 'Translation does not have gender forms';
    }
  }

  AnalysisErrorCode toAnalysisErrorCode() {
    switch (this) {
      case TranslationFailureReason.unknown:
        return AnalysisErrorCode.unknown;
      case TranslationFailureReason.noSuchTranslationKeyTooLong:
        return AnalysisErrorCode.translationKeyTooLong;
      case TranslationFailureReason.noSuchTranslationKeyTooShort:
        return AnalysisErrorCode.translationKeyTooShort;
      case TranslationFailureReason.callIsPluralButNoPluralTranslation:
        return AnalysisErrorCode.missingPluralTranslation;
      case TranslationFailureReason.callHasGenderButNoGenderTranslation:
        return AnalysisErrorCode.missingGenderTranslation;
    }
  }
}

sealed class TranslationResult {}

class TranslationSuccess extends TranslationResult {
  final JsonLocationValue value;

  TranslationSuccess(this.value);
}

class TranslationFailure extends TranslationResult {
  final TranslationFailureReason reason;

  TranslationFailure(this.reason);
}
