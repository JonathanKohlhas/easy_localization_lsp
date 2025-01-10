#!/bin/sh
#installs easy_localization_lsp

dart pub global deactivate easy_localization_lsp
rm -R .dart_tool/pub/bin/easy_localization_lsp

dart pub global activate --source path . 
