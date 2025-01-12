/* --------------------------------------------------------------------------------------------
 * Copyright (c) Microsoft Corporation. All rights reserved.
 * Licensed under the MIT License. See License.txt in the project root for license information.
 * ------------------------------------------------------------------------------------------ */

import * as path from 'path';
import { workspace, ExtensionContext } from 'vscode';

import {
	CloseAction,
	CloseHandlerResult,
	ErrorAction,
	ErrorHandler,
	ErrorHandlerResult,
	LanguageClient,
	LanguageClientOptions,
	Message,
	RevealOutputChannelOn,
	ServerOptions,
	TransportKind
} from 'vscode-languageclient/node';
import { EasyLocalizationTranslationDecorator } from './translation_decorations';

let client: LanguageClient;

class MyErrorHandler implements ErrorHandler {

	error(error: Error, message: Message | undefined, count: number | undefined): ErrorHandlerResult | Promise<ErrorHandlerResult> {
		//print and ignore 
		console.error(error);
		return {
			action: ErrorAction.Continue,
		}

	}
	closed(): CloseHandlerResult | Promise<CloseHandlerResult> {
		return {
			action: CloseAction.Restart,
		}
	}

}

export function activate(context: ExtensionContext) {
	// The server is implemented in node
	// const serverModule = "/home/jonathan/Development/Workspace/easy_localization_lsp/bin/easy_localization_lsp.exe"
	const exe = "dart run" + " " + path.join(__dirname, "..", "easy_localization_lsp.dill");

	// If the extension is launched in debug mode then the debug server options are used
	// Otherwise the run options are used
	const serverOptions: ServerOptions = {
		command: exe,
		options: {
			env: process.env,
			shell: true,
		},
		transport: TransportKind.stdio,
		// transport: {
		// 	kind: TransportKind.socket,
		// 	port: 43536,
		// }
	};

	// Options to control the language client
	const clientOptions: LanguageClientOptions = {
		revealOutputChannelOn: RevealOutputChannelOn.Info,
		// Register the server for plain text documents
		documentSelector: [{ scheme: 'file', language: 'dart' }, { scheme: 'file', language: 'json' }],
		synchronize: {
			// Notify the server about file changes to '.clientrc files contained in the workspace
			fileEvents: [workspace.createFileSystemWatcher('**/*.json'), workspace.createFileSystemWatcher('**/*.dart')]
		},
		errorHandler: new MyErrorHandler(),

	};


	// Create the language client and start the client.
	client = new LanguageClient(
		'easy_localization_lsp',
		'Easy Localization LSP',
		serverOptions,
		clientOptions
	);

	const translationDecorator = new EasyLocalizationTranslationDecorator(client)
	client.registerFeature(translationDecorator.feature);
	context.subscriptions.push(translationDecorator);

	// Start the client. This will also launch the server
	client.start();
}

export function deactivate(): Thenable<void> | undefined {
	if (!client) {
		return undefined;
	}
	return client.stop();
}

