// ignore_for_file: implementation_imports

import 'package:analyzer/src/dart/ast/ast.dart';
import 'package:easy_localization_lsp/analysis/translation_file.dart';
import 'package:easy_localization_lsp/analysis/translation_result.dart';
import 'package:easy_localization_lsp/json/parser.dart';
import 'package:easy_localization_lsp/util/location.dart';

class TranslationCall {
  final MethodInvocation invocation;
  final Location location;
  TranslationCall(this.invocation, this.location);

  String? get translationKey => switch (invocation) {
        MethodInvocation(target: SimpleStringLiteral(value: final value)) => value,
        // TODO(JonathanKohlhas): Support method invocations that contain string interpolation
        _ => null,
      };

  bool get hasGender => invocation.argumentList.arguments
      .where(
        (arg) => switch (arg) {
          NamedExpression(name: Label(label: SimpleIdentifier(name: "gender"))) => true,
          _ => false,
        },
      )
      .isNotEmpty;

  bool get isPlural => switch (invocation) {
        MethodInvocation(methodName: SimpleIdentifier(name: "plural")) => true,
        _ => false,
      };

  ResolvedTranslationCall resolve(List<TranslationFile> files) {
    final translationResults = files.map((file) {
      return file.translateCall(this);
    }).toList();
    return ResolvedTranslationCall(invocation, location, translationResults);
  }
}

class ResolvedTranslationCall extends TranslationCall {
  ResolvedTranslationCall(super.invocation, super.location, this.translationResults);

  final List<TranslationResult> translationResults;

  List<JsonLocationValue> get translations =>
      translationResults.whereType<TranslationSuccess>().map((result) => result.value).toList();

  bool get isValid => translations.isNotEmpty;

  JsonLocationValue? closestTranslation(String file) {
    if (translations.isEmpty) {
      return null;
    }
    return translations.reduce(
      (value, element) {
        int commonPrefixLengthValue = value.location.file.commonPrefixLength(file);
        int commonPrefixLengthElement = element.location.file.commonPrefixLength(file);
        return commonPrefixLengthValue > commonPrefixLengthElement ? value : element;
      },
    );
  }
}

extension CommonPrefixLengthString on String {
  int commonPrefixLength(String other) {
    int i = 0;
    while (i < length && i < other.length && this[i] == other[i]) {
      i++;
    }
    return i;
  }
}
