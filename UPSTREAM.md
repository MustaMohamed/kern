# Upstream sources

kern ports text and ideas from these sources. `scripts/fetch-upstream` clones each source at its pin into `.upstream/<key>/`, caveman included (tag v4.0.1). Review upstream changes quarterly: `git -C .upstream/<key> fetch && git -C .upstream/<key> log --oneline <commit>..origin/HEAD`.

| Key | Source | Version | Licence | Copyright | Commit | URL |
|---|---|---|---|---|---|---|
| superpowers | obra/superpowers | 7.0.0 | MIT | Copyright (c) 2025 Jesse Vincent | bb92a77741419a4ab5f06e711a283343f1ada0c3 | https://github.com/obra/superpowers |
| pstack | cursor/plugins, pstack/ | 0.15.25 | MIT | Copyright (c) 2026 Lauren Tan | 182f2ce414e83224915c190d2f63239c1608d0a5 | https://github.com/cursor/plugins |
| pocock | mattpocock/skills | 1.3.1 | MIT | Copyright (c) 2026 Matt Pocock | 49dd158d1076134a641b33efb035946536778336 | https://github.com/mattpocock/skills |
| addy | addyosmani/agent-skills | 0.6.13 | MIT | Copyright (c) 2025 Addy Osmani | aeac41d4d005999432bb7312f7ff06383a91d59d | https://github.com/addyosmani/agent-skills |
| caveman | caveman | 4.0.1 | Apache-2.0 | Copyright 2026 Julius Brussee | d262ab3882952a59312ff3537cd86d894523c5ab | https://github.com/JuliusBrussee/caveman |

The `local` key in `fetch-upstream` copies the owner's adapted `recall`, `unslop`, `no-comments` and `comment-sicko` files; they are the owner's own work and need no entry here.

caveman licence: Apache-2.0 from 3.0.0 on, copyright "Copyright 2026 Julius Brussee". The 3.2.0 and 4.0.1 trees hold byte-identical `LICENSE`, `LICENSE-MIT`, `LICENSING.md` and `NOTICE`, so `licenses/caveman.*` and `NOTICE` apply to both. The 2026-10-14 audit read 3.2.0; the 2026-10-17 audit read 4.0.1. kern copies no caveman text. Its terse mode takes ideas from the 3.2.0 and 4.0.1 voice rules and prompt parser, which are identical in the two versions.
