# Contributing to website

Thank you for helping. This repository is part of [NuclearLang](https://github.com/nuclearlang): the language is the
[nuclear](https://github.com/nuclearlang/nuclear) repository, and the other repositories live as folders inside a clone of it, each with its
own git (the tools find each other that way).

## Set up

```sh
git clone https://github.com/nuclearlang/nuclear && cd nuclear
for r in dragonfly dragonfly-mobile dragonfly-backend dragonfly-web nuclear-vscode; do git clone https://github.com/nuclearlang/$r; done
./install.sh && cd ..
git clone https://github.com/nuclearlang/website && cd website
export NUCLEAR_TREE=../nuclear                     # the working tree (site.toml's [source] tree is the author's)
```

## Before a pull request

```sh
(cd tools && npm install) && node tools/content.mjs
dragonfly build && dragonfly install && dragonfly test
(cd build/app && npx vite build)
```

- Everything is written in English: code, comments, docs and messages.
- A change that the user of NuclearLang can see updates its documentation in the same pull request (the spec of
  the area, the guide, `docs/context/` for agents and contributors).
- Rules and the reasons behind them: the [nuclear repository's AGENTS.md](https://github.com/nuclearlang/nuclear/blob/main/AGENTS.md) and its
  [decision records](https://github.com/nuclearlang/nuclear/tree/main/docs/adr).

By contributing you agree that your contribution is licensed under the [Apache License 2.0](LICENSE).
