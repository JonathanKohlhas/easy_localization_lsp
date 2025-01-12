# Rename Operation

## Description
The rename operation can rename single translation keys, or whore groups of translation keys. Users select a translation key and trigger the normal LSP rename, type in a new value and the rename happens

## Problem
### Multiple Translation Files
Multiple translation files make this problem more difficult.
For different files for different languages in the same project, keys should always be renamed together, but for related projects that have overlapping keys this is not always the case, maybe the key overlap is a mistake and the rename is intended to fix that mistake.
This could be solved with a scope system:
- Only in this file
- In all files from same project
- In all files that have the key

Users can set a default scope in the config and also set when they want to be prompted:
- only when doing rename inside the json
- only when doing rename inside dart
- never
- always

Default: never ask
with special action to only rename in current project

Maybe use project hierarchy here? to select where to apply changes in a situation with nested subprojects

### Renaming Key Paths
When renaming keys like "homeScreen.tree.greeting" => "homeScreen.header.greeting" it's not clear if the intention is to move the greeting key from the tree group to the header group or to rename the whole tree group to header group / merge tree and header group
Could be done by rules + interactive selection from user:
- if multiple parts of the key change, assume the key is being moved not the whole group
- if a section is deleted assume the key is being moved
- if a section is added assume the key is being moved
- if only one section is changed and it's not the last section ask user if they want to move the key or rename the group
- if only one section is changed and it's the last section ask user if they want  rename the key

Other operations, like dissolving a group, could be code actions that are suggested when the group is selected

## Examples
### Single Key Rename
Files:
project1/en.json
```json
{
  "homeScreen.tree.greeting": "Hello"
}
```

project1/de.json
```json
{
  "homeScreen.tree.greeting": "Hallo"
}
```

project2/en.json
```json
{
  "homeScreen.tree.greeting": "Hello"
}
```

project1/foo.dart
```dart
void foo() {
  print('homeScreen.tree/*CURSOR*/.greeting'.tr);
}
```
When user triggers rename, they get a prompt to rename the key that contains:
"homeScreen.tree.greeting"
User enters "homeScreen.header.hello"
User sees a prompt:
- Rename in all files from project1
- Rename in all files that have the key
  
User selects "Rename in all files from project1"
The files are updated to:
project1/en.json
```json
{
  "homeScreen.header.hello": "Hello"
}
```
project1/de.json
```json
{
  "homeScreen.header.hello": "Hallo"
}
```
project2/en.json
```json
{
  "homeScreen.tree.greeting": "Hello"
}
```
project1/foo.dart
```dart
void foo() {
  print('homeScreen.header.hello'.tr);
}
```

