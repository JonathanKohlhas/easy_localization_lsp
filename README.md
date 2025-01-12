# Easy Localization LSP

LSP support for flutter easy localization

## Features

- [x] Code completion for translation keys
- [x] Diagnostics for missing translations
- [x] Hover for translation keys
- [x] Inline decorations showing the translation values in the code
- [x] Go to definition for translation keys
- [x] Find references for translation keys
- [x] Rename symbol for translation keys (experimental) 

## Requirements

- [x] Flutter project with easy_localization package
- [x] dart sdk 

## Editor Support
- VSCode Extension: in folder `easy-localization-lsp-vscode`
- Nvim: Build lsp executable and use lspconfig to set it up (ready to use plugin may be developed in the future)
- IntelliJ Plugin: to be developed

## Known Issues

- Rename symbol is experimental and limited in functionality (currently only renames the key in one translation file and all dart files, with no regard for if the key is actually read from other translation files in the dart files)

## Release Notes

### 1.0.0

Initial release of easy-localization-lsp
FEAT: Code completion for translation keys
FEAT: Diagnostics for missing translations
FEAT: Hover for translation keys
FEAT: Inline decorations showing the translation values in the code
FEAT: Go to definition for translation keys
FEAT: Find references for translation keys
FEAT: Rename symbol for translation keys (experimental)

