# NuclearLang website

The NuclearLang site, written in **Nuclear** with Dragonfly's web platform (dialect `react`): its screens, state
managers, search and content repository are `.nuc` files. The content is the documentation of the `nuclearlang`
repositories (`docs/`, `spec/` of `nuclear`, `dragonfly-mobile`, `dragonfly-backend`, `dragonfly-web`), turned into
JSON by a build script; the app only reads it.

```
config.nuc                       dragonfly(platform = "web", dialect = "react"), app(title, description)
config/project_config.nuc        Http(baseUrl = "/"): the site reads its own public/content/
components/docs/
  data/content_repository.nuc    page, site, search index and home (public/content/*.json)
  domain/                        models, use cases (GetPage, GetSite, GetHome, Search), the search score
  presentation/                  HomeScreen "/", DocScreen "/:area/:name", DocGroupScreen "/:area/:group/:name",
                                 NotFoundScreen; the layout (top bar, menu, footer) and the search box
public/styles.css, favicon.svg   the look: the Chernobyl palette of the editors (dark) and a light theme
test/docs_test.nuc               the search ranking, the pages and the home page (the repository is a mock)
site.toml                        every text, menu, link and address: site, top bar, side menu (paths or * patterns),
                                 home page (actions, features, sample and its targets, platforms, install)
tools/content.mjs                public/content, public/static, llms.txt, llms-full.txt, sitemap.xml, robots.txt and
                                 the installers (install.sh, install.ps1 from the tree's tools/release/)
```

## Build

```sh
(cd tools && npm install)        # markdown-it, shiki and smol-toml, once
node tools/content.mjs           # the content, from the tree site.toml names ([source] tree; NUCLEAR_TREE overrides it)
dragonfly build                  # the app into build/app (public/ copied)
dragonfly install                # npm install in build/app
dragonfly test                   # vitest: the tests of test/
dragonfly run                    # vite dev, http://localhost:5173
(cd build/app && npx vite build) # the published site in build/app/dist
```

`tools/content.mjs` renders every page's markdown with the code already highlighted (shiki, with the Nuclear grammar
of the editors and their Chernobyl theme), so the browser receives HTML and never parses markdown. The home page's
sample is transpiled to TypeScript, Dart and Python by the installed `nuclear` when the site is built. For search
engines and agents that read without JavaScript, every page also has a plain HTML copy in `/static/` (and the
sitemap, `llms.txt`, `llms-full.txt`).

The addresses are the paths of the repositories' files: `/docs/language/01-syntax` is `docs/language/01-syntax.md`.
A link between pages reloads the page (the content is cached by the browser); navigation by address inside the app is
a later step of the web platform.
