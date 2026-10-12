# Upstream sources

kern ports text and ideas from these sources. `scripts/fetch-upstream` clones each at its pin into `.upstream/<key>/`. Review upstream changes quarterly: `git -C .upstream/<key> fetch && git -C .upstream/<key> log --oneline <commit>..origin/HEAD`.

| Key | Source | Version | Licence | Copyright | Commit | URL |
|---|---|---|---|---|---|---|
| superpowers | obra/superpowers | 6.4.1 | MIT | Copyright (c) 2025 Jesse Vincent | 5bf4e78011075bcfc0dc295f0724994cd123ee71 | https://github.com/obra/superpowers |
| pstack | cursor/plugins, pstack/ | 0.15.17 | MIT | Copyright (c) 2026 Lauren Tan | 11713c6 | https://github.com/cursor/plugins |
| pocock | mattpocock/skills | 1.3.1 | MIT | Copyright (c) 2026 Matt Pocock | 49dd158 | https://github.com/mattpocock/skills |
| addy | addyosmani/agent-skills | 0.6.12 | MIT | Copyright (c) 2025 Addy Osmani | 1be8e34 | https://github.com/addyosmani/agent-skills |
| caveman | caveman | 3.2.0 | Apache-2.0 | Copyright 2026 Julius Brussee | installed plugin cache 3.2.0 | https://github.com/JuliusBrussee/caveman |

The `local` key in `fetch-upstream` copies the owner's adapted `recall`, `unslop`, `no-comments` and `comment-sicko` files; they are the owner's own work and need no entry here.
