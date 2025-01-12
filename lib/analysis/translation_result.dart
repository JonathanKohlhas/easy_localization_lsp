import 'package:easy_localization_lsp/json/parser.dart';

enum TranslationFailureReason {
  noSuchTranslationKeyTooLong,
  noSuchTranslationKeyTooShort,
  callIsPluralButNoPluralTranslation,
  callHasGenderButNoGenderTranslation,
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
