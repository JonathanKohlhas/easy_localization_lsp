import 'package:easy_localization_lsp/util/location.dart';
import 'package:lsp_server/lsp_server.dart' as lsp;

enum AnalysisErrorSeverity {
  error,
  warning,
  info,
  hint;

  lsp.DiagnosticSeverity toLsp() {
    switch (this) {
      case AnalysisErrorSeverity.error:
        return lsp.DiagnosticSeverity.Error;
      case AnalysisErrorSeverity.warning:
        return lsp.DiagnosticSeverity.Warning;
      case AnalysisErrorSeverity.info:
        return lsp.DiagnosticSeverity.Information;
      case AnalysisErrorSeverity.hint:
        return lsp.DiagnosticSeverity.Hint;
    }
  }
}

enum AnalysisErrorCode {
  unknown,
  noSuchTranslation,
  missingPluralTranslation,
  missingGenderTranslation;

  static AnalysisErrorCode fromString(String code) {
    return AnalysisErrorCode.values.firstWhere((e) => e.name == code, orElse: () => AnalysisErrorCode.unknown);
  }
}

class AnalysisError {
  final AnalysisErrorSeverity severity;
  final AnalysisErrorCode code;
  final Location location;
  final String message;

  AnalysisError(this.severity, this.location, this.message, {this.code = AnalysisErrorCode.unknown});

  lsp.Diagnostic toLsp() {
    return lsp.Diagnostic(
      range: location.toLsp().range,
      severity: severity.toLsp(),
      message: message,
      code: code.name,
    );
  }
}
