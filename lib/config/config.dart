import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:glob/glob.dart';
import 'package:yaml/yaml.dart';

class EasyLocalizationAnalysisOptions {
  EasyLocalizationAnalysisOptions({
    List<String>? translationFiles,
    List<String>? translationFilesExcludes,
  })  : translationFiles = translationFiles ??
            const [
              "**/translation/*.json",
              "**/translations/*.json",
            ],
        translationFilesExcludes = translationFilesExcludes ??
            const [
              "**/build/**",
            ];

  factory EasyLocalizationAnalysisOptions.fromMap(Map<String, dynamic> map) {
    return EasyLocalizationAnalysisOptions(
      translationFiles: (map["translation_files"] as List<dynamic>?)?.cast<String>(),
    );
  }

  late final List<Glob> translationFileGlobs = [for (final trf in translationFiles) Glob(trf)];
  late final List<Glob> translationFileExcludesGlobs = [for (final trf in translationFilesExcludes) Glob(trf)];
  final List<String> translationFiles;
  final List<String> translationFilesExcludes;

  bool isTranslationFile(String path) =>
      translationFileGlobs.any((glob) => glob.matches(path)) &&
      !translationFileExcludesGlobs.any((glob) => glob.matches(path));
}

EasyLocalizationAnalysisOptions? analysisOptionsFromFile(AnalysisContext context) {
  final config = context.contextRoot.root.getChildAssumingFile("easy_localization.yaml");
  if (!config.exists) return null;
  final map = loadYaml(config.readAsStringSync());
  return EasyLocalizationAnalysisOptions.fromMap(map);
}
