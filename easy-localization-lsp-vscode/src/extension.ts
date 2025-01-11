/* --------------------------------------------------------------------------------------------
 * Copyright (c) Microsoft Corporation. All rights reserved.
 * Licensed under the MIT License. See License.txt in the project root for license information.
 * ------------------------------------------------------------------------------------------ */

import * as path from 'path';
import { workspace, ExtensionContext } from 'vscode';

import {
	LanguageClient,
	LanguageClientOptions,
	ServerOptions,
	TransportKind
} from 'vscode-languageclient/node';

let client: LanguageClient;

export function activate(context: ExtensionContext) {
	// The server is implemented in node
	// const serverModule = "/home/jonathan/Development/Workspace/easy_localization_lsp/bin/easy_localization_lsp.exe"
	const serverModule = "easy_localization_lsp"

	// If the extension is launched in debug mode then the debug server options are used
	// Otherwise the run options are used
	const serverOptions: ServerOptions = {
		command: serverModule,
		options: {
			env: process.env,
			shell: true,
		},
		transport: {
			kind: TransportKind.socket,
			port: 54536,
		}
	};

	// Options to control the language client
	const clientOptions: LanguageClientOptions = {
		// Register the server for plain text documents
		documentSelector: [{ scheme: 'file', language: 'dart' }, { scheme: 'file', language: 'json' }],
		// synchronize: {
		// 	// Notify the server about file changes to '.clientrc files contained in the workspace
		// 	fileEvents: [workspace.createFileSystemWatcher('**/*.json'), workspace.createFileSystemWatcher('**/*.dart')]
		// }
	};

	// Create the language client and start the client.
	client = new LanguageClient(
		'easy_localization_lsp',
		'Easy Localization LSP',
		serverOptions,
		clientOptions
	);

	// Start the client. This will also launch the server
	client.start();
}

export function deactivate(): Thenable<void> | undefined {
	if (!client) {
		return undefined;
	}
	return client.stop();
}

