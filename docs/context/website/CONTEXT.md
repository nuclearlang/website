---
layer: L2
component: website
read-when: you change the documentation website or a doc that is published on it
---

# Website

Its own repository, `website` (today `~/Documents/projects/nuc/react/nuclearlang_website`; ADR-0083): only the site, written in Nuclear with
Dragonfly web (react); the content stays with the code it documents. Its README has the details.

- `site.toml` holds every text, menu, link and address of the site (ADR-0101); the side menu lists pages by path or
  `*` pattern of the source tree.
- `tools/content.mjs` reads the `.md` files of the source roots (`nuclear`, `dragonfly-*`), skipping
  `[source] internal` (`docs/aprende/`, `docs/context/`), and writes `public/content/` (pages as JSON with shiki
  highlighting, `site.json`, `home.json`, the search index), `/static/` plain pages, `llms.txt` / `llms-full.txt`
  (ADR-0088), the sitemap, and copies `tools/release/install.sh` / `install.ps1` to the root.
- A new dialect or framework feature gets its user guide (a `.md` in its repository) and, if it is a new area, a
  line in `site.toml`'s sidebar.
- Language: English (ADR-0082). Deploy (GitHub Pages, SPA fallback) is pending (STATUS.md).
