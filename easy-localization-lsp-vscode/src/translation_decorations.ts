import * as vs from "vscode";
import {
  ClientCapabilities,
  FeatureState,
  LanguageClient,
  LanguageClientOptions,
  NotificationType,
  ServerOptions,
  StaticFeature,
  TransportKind
} from 'vscode-languageclient/node';



class TranslationLabelNotification {
  public static type = new NotificationType<TranslationLabelParams>("easyLocalization/textDocument/publishTranslationLabels");
}

interface TranslationLabelParams {
  uri: string;
  labels: TranslationLabel[];
}

interface TranslationLabel {
  label: string;
  range: vs.Range;
}

type EasyLocalizationTranslationLabelsProviderOptions = boolean;

export class EasyLocalizationTranslationDecorator implements vs.Disposable {
  decorationType: vs.TextEditorDecorationType;
  subscriptions: vs.Disposable[] = [];
  labels: Map<string, TranslationLabel[]> = new Map();
  client: LanguageClient;

  constructor(client: LanguageClient) {
    this.client = client;
    this.decorationType = vs.window.createTextEditorDecorationType({
      after: {
        color: new vs.ThemeColor("dart.closingLabels"),
        margin: "2px",
      },
      rangeBehavior: vs.DecorationRangeBehavior.ClosedOpen,
    });

    this.subscriptions.push(
      vs.window.onDidChangeActiveTextEditor((editor) => {
        if (editor) {
          this.update(editor);
        }
      })
    );
    this.subscriptions.push(
      vs.workspace.onDidChangeTextDocument((e) => {
        for (let editor of vs.window.visibleTextEditors) {
          if (editor.document === e.document) {
            this.update(editor);
          }
        }
      })
    );
    //TODO: support updating when translations change... maybe we can just watch for file changes to json files?
    // this.subscriptions.push(
    //   this.translationServer.onDidChangeTranslation(() => {
    //     for (let editor of vs.window.visibleTextEditors) {
    //       this.update(editor);
    //     }
    //   })
    // );
    if (vs.window.activeTextEditor) {
      this.update(vs.window.activeTextEditor);
    }
  }

  update(editor: vs.TextEditor) {
    console.log("updateDecorations for", editor.document.uri.path);
    let decorations: vs.DecorationOptions[] = [];
    // decorations.push({
    //   hoverMessage: `translation from ${this.translationServer.formatFilePath(
    //     translation.file
    //   )}`,
    //   range: new vs.Range(start, end),
    //   renderOptions: {
    //     after: {
    //       contentText: `=> ${translation.value}`,
    //     },
    //   },
    // });

    let uri = editor.document.uri;
    let labels = this.labels.get(uri.path);
    if (labels) {
      for (let label of labels) {
        decorations.push({
          hoverMessage: label.label,
          range: label.range,
          renderOptions: {
            after: {
              contentText: ` => ${label.label}`,
            },
          },
        });
      }
    }
    editor.setDecorations(this.decorationType, decorations);
  }

  public get feature(): StaticFeature {
    const disposables: vs.Disposable[] = [];
    const client = this.client;
    const labels = this.labels;
    const update = this.update.bind(this);
    return {
      clear() {
        for (const uri of labels.keys()) {
          labels.delete(uri);
        }
        for (const disposable of disposables) {
          disposable.dispose();
        }
      },
      fillClientCapabilities(capabilities: ClientCapabilities) {
        capabilities.experimental ??= {};
        capabilities.experimental.supportsEasyLocalizationTranslationLabels = true;
      },
      getState(): FeatureState {
        return { kind: "static" };
      },
      initialize(serverCapabilities) {
        const provider = serverCapabilities.experimental?.easyLocalizationTranslationLabelsProvider as EasyLocalizationTranslationLabelsProviderOptions | undefined;
        // Just because we're enabled does not mean the server necessarily supports it.
        if (provider) {
          disposables.push(client.onNotification(TranslationLabelNotification.type, (params) => {
            const uri = client.protocol2CodeConverter.asUri(params.uri);
            console.log("got labels for ", uri.path);
            labels.set(uri.path, params.labels);
            for (let editor of vs.window.visibleTextEditors) {
              if (editor.document.uri.path === uri.path) {
                update(editor);
              }
            }
          }));
        }
      },
    }
  }

  dispose() {
    this.subscriptions.forEach((subscription) => subscription.dispose());
    this.decorationType.dispose();
    vs.window.activeTextEditor?.setDecorations(this.decorationType, []);
  }
}