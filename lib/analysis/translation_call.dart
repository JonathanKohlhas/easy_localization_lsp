// ignore_for_file: implementation_imports

import 'package:analyzer/src/dart/ast/ast.dart';
import 'package:easy_localization_lsp/analysis/translation_file.dart';
import 'package:easy_localization_lsp/json/parser.dart';
import 'package:easy_localization_lsp/util/location.dart';

class TranslationCall {
  final MethodInvocation invocation;
  final Location location;
  TranslationCall(this.invocation, this.location);

  String? get translationKey => switch (invocation) {
        MethodInvocation(target: SimpleStringLiteral(value: final value)) =>
          value,
        // TODO(JonathanKohlhas): Support method invocations that contain string interpolation
        _ => null,
      };

  bool get hasGender => invocation.argumentList.arguments
      .where(
        (arg) => switch (arg) {
          NamedExpression(
            name: Label(label: SimpleIdentifier(name: "gender"))
          ) =>
            true,
          _ => false,
        },
      )
      .isNotEmpty;

  bool get isPlural => switch (invocation) {
        MethodInvocation(methodName: SimpleIdentifier(name: "plural")) => true,
        _ => false,
      };

  ResolvedTranslationCall resolve(List<TranslationFile> files) {
    final translations = files
        .map((file) {
          if (!file.contains(this)) {
            return null;
          }
          return file.getLocation(this);
        })
        .whereType<JsonLocationValue>()
        .toList();
    return ResolvedTranslationCall(invocation, location, translations);
  }
}

class ResolvedTranslationCall extends TranslationCall {
  ResolvedTranslationCall(super.invocation, super.location, this.translations);

  final List<JsonLocationValue> translations;

  bool get isValid => translations.isNotEmpty;
}
