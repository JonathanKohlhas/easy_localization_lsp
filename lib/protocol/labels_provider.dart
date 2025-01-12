import 'package:lsp_server/lsp_server.dart';

class TranslationLabel implements ToJsonable {
  final String label;
  final Range range;

  TranslationLabel(this.label, this.range);

  @override
  Object? toJson() {
    return {
      'label': label,
      'range': range.toJson(),
    };
  }
}

class TranslationLabelNotification implements ToJsonable {
  final String uri;
  final List<TranslationLabel> labels;

  TranslationLabelNotification(this.uri, this.labels);

  @override
  Object? toJson() {
    return {
      'uri': uri,
      'labels': labels.map((e) => e.toJson()).toList(),
    };
  }
}

const String publishTranslationLabelsMethod = "easyLocalization/textDocument/publishTranslationLabels";

typedef TranslationLabelProvider = bool;

extension TranslationLabelProviderConnection on Connection {
  void sendTranslationLabels(TranslationLabelNotification notification) {
    sendNotification(publishTranslationLabelsMethod, notification.toJson());
  }
}

const String translationLabelsProvider = "easyLocalizationTranslationLabelsProvider";
