<!-- Part of spacecraft-steelbore-standard — see SKILL.md for the index -->
## §9 — Privacy-Friendly Application (PFA) Policy

Every Spacecraft Software application must satisfy **all three** PFA requirements:

| Requirement        | Rule                                                                     |
|--------------------|--------------------------------------------------------------------------|
| No Tracking/No Ads | Zero advertising, tracking, analytics SDKs, or telemetry beacons        |
| Minimal Permissions| Only essential permissions; requested lazily at point of use, never eagerly |
| Local Storage      | User data stored locally by default; sync is strictly opt-in, E2E encrypted |

When reviewing or designing any feature that touches data handling, permissions,
or networking, verify all three PFA requirements are met.

### §9.1 — No Third-Party Subresources

The three rows above are scoped to an **application**, and that left a gap: a
document is not an application, so nothing in §9 reached the HTML this standard
publishes — which loaded its §12 fonts from a third-party CDN, disclosing every
reader's IP, User-Agent and Referer on every page view. No tracker, no analytics
SDK: the letter of the first row was met while its purpose was not.

**The rule is therefore a property of artifacts, not applications.** No
Spacecraft Software artifact — application, library, document, stylesheet,
diagram, slide, or generated page — fetches a subresource from a host the
project does not control at render time.

| Rule | Detail |
|------|--------|
| Fonts resolve locally | Baseline is `@font-face` whose `src` names `local()` only, backed by the generic `monospace` fallback. An artifact needing faithful rendering for every reader MAY also ship the file beside itself, listed after `local()` — §12's licence whitelist exists so it may be redistributed. Bundling is a fidelity choice; the fetch is what is forbidden |
| All subresource classes | Scripts, stylesheets, images and media follow the same rule. A CDN reference is third-party whatever it carries |
| Degrading is not complying | A fallback that renders acceptably when the fetch fails does not cure the fetch. The request **is** the disclosure |
| Hyperlinks are unaffected | A link the reader chooses to follow is not a subresource; this governs what an artifact loads unasked |
| Exceptions are declared | Where an artifact genuinely cannot function without a third-party fetch, document it in `README.md` naming the host, the data disclosed, and why no bundled alternative exists — the same shape as a §3.1 exemption |

A self-contained artifact is also offline-capable, reproducible, and immune to an
upstream host disappearing, so this costs little beyond the bytes it bundles.

---

