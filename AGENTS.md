# AGENTS.md

<!-- nuclearlang -->
## NuclearLang

This project is written in NuclearLang (`.nuc`), dialect `react`. Its syntax is not TypeScript, Dart nor Python.

- Before writing code, read the sheet: `nuclear spec --brief --dialect react`.
- After each change: `nuclear check <file>.nuc --dialect react --json` must report no errors; fix exactly what each error says (most carry a `fix`).
- Look up instead of guessing: an API `nuclear defs show <Name> --dialect react`; a kind or decorator
  `nuclear help <word> --dialect react` (all: `nuclear help words --dialect react`); a topic `nuclear help <topic>`.
- Never edit generated code (`build/` and the `.ts`/`.dart`/`.py` built from the `.nuc`): change the `.nuc` files.
<!-- /nuclearlang -->
