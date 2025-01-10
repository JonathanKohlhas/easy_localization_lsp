import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:glob/glob.dart';
import 'package:yaml/yaml.dart';

class EasyLocalizationAnalysisOptions {
  final List<String> translationFiles;
  late final List<Glob> translationFileGlobs = [
    for (final trf in translationFiles) Glob(trf)
  ];
  EasyLocalizationAnalysisOptions({
    List<String>? translationFiles,
  }) : translationFiles = translationFiles ?? const ["**/translation/*.json"];

  factory EasyLocalizationAnalysisOptions.fromMap(Map<String, dynamic> map) {
    return EasyLocalizationAnalysisOptions(
      translationFiles:
          (map["translation_files"] as List<dynamic>?)?.cast<String>(),
    );
  }

  bool isTranslationFile(String path) =>
      translationFileGlobs.any((glob) => glob.matches(path));
}

EasyLocalizationAnalysisOptions? analysisOptionsFromFile(
    AnalysisContext context) {
  final config =
      context.contextRoot.root.getChildAssumingFile("easy_localization.yaml");
  if (!config.exists) return null;
  final map = loadYaml(config.readAsStringSync());
  return EasyLocalizationAnalysisOptions.fromMap(map);
}
