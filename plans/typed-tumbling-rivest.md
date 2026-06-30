# Austin Lakes Dentistry — World-Class Redesign (presentation-only)

## Context

The faithful lift-and-shift is content-correct but inherits the original WordPress
theme's dated 2010s look: 0.5rem corners everywhere, tiny buttons, flat `bg-sand`
cards, dotted dividers, a cramped hero, everything set in Inter while a premium serif
(**Fraunces**) sits loaded-but-unused, and thin footers. The user (after seeing it)
asked to make it "way nicer, modern, cleaner, world class" — explicitly **without
changing any copy, content, or images**. Two small content fixes were already applied
this turn (local PDF paths in patient-information, real Google review URL in reviews)
and the 3 PDFs were downloaded to `public/forms/`.

This is a **purely presentational** redesign: relayout + restyle + motion. Every text
string, image asset, nav label, route, and all SEO (titles/meta/canonical/OG/JSON-LD)
stays byte-for-byte. Committed direction: **Warm editorial clinical** — large Fraunces
serif headlines + clean Inter body, generous whitespace, cinematic imagery, soft
blue tints, layered depth, refined rounded cards. Brand blue `#2a7dd4` + charcoal
`#272a29` remain the anchors.

## Hard constraints (do not violate)

- **No copy changes.** Reuse every existing string verbatim from the page files and
  `lib/home-content.ts`, `lib/content.ts`, `lib/site.ts`, the `TESTIMONIALS`/`POLICIES`/
  `FORMS`/`PAYMENTS` arrays, and `rec.bodyHtml`.
- **No image swaps.** Same assets in `public/core/`, `public/slider/`, `public/forms/`.
- **No SEO changes.** `metadataFor`, `webPageSchema`, `breadcrumbSchema`, `articleSchema`,
  `dentistSchema`, robots/noindex logic untouched.
- **Keep the single global CTA band** (ContactCta) — do not reintroduce a per-page CTA.
- Respect `prefers-reduced-motion`. Keep async `PageProps`/`await params` patterns.

## Design system overhaul — `app/globals.css` + `app/layout.tsx`

The system is the leverage point: upgrade tokens once, every page benefits.

- **Type:** map `--font-display: var(--font-fraunces)` (currently points at Inter).
  Fraunces is already imported in `layout.tsx` — just ensure its `variable` is on
  `<html>` (it is). Headings (`h1–h3`) → Fraunces with tuned `letter-spacing`/`line-height`
  and `font-optical-sizing: auto`; body/UI stays Inter. Larger, more confident scale.
- **Color depth (additive — keep existing tokens):** add `--color-navy` (deep
  blue-charcoal, ~`#10263a`) for richer dark sections, `--color-canvas` (cool off-white
  ~`#f4f8fc`) for section alternation, and a reusable lake gradient. Keep `lake`,
  `lake-deep/soft/tint`, `slate`, `sand`.
- **Surfaces/depth:** new radii (`--radius-card` → ~1.25rem; pill buttons), softer,
  larger blue-tinted shadows (refine `--shadow-soft`/`--shadow-lift`), and tasteful
  gradient/mesh backgrounds (rewrite `.bg-mesh`, add `.bg-lake-grad`, `.bg-navy`).
- **Motion:** keep `.reveal`; add a tiny `components/reveal.tsx` (IntersectionObserver
  client wrapper, no deps) to stage section entrances; refine hover lifts. All gated by
  reduced-motion.
- **Prose:** elevate `.prose-warm` (used by blog/privacy/services bodies via
  `ArticleBody`) — better measure, heading rhythm, link styling, figure treatment.

## Shared chrome (every page)

- `components/site-header.tsx` — refined sticky nav: better padding/scale, blur-on-scroll
  surface, polished dropdowns + mobile drawer, pill call-to-action. Same links/labels.
- `components/hero-slider.tsx` — cinematic: taller, gradient scrim, serif caption,
  refined controls/dots, graceful crossfade. Same slides/copy/CTAs.
- `components/appointment-form.tsx` + `components/contact-form.tsx` — refined card
  (larger radius, nicer field + focus states, polished header/success state). Same
  fields/labels/post target.
- `components/contact-cta.tsx` — elevate the charcoal pre-footer (type, spacing, small
  icons, layout). Same three actions/copy.
- `components/site-footer.tsx`, `sub-footer.tsx`, `sticky-footer.tsx` — richer, cleaner
  footer system. Same content.
- `components/breadcrumbs.tsx`, `components/blog-index.tsx`, `components/article-body.tsx`,
  `components/page-shell.tsx` — editorial polish consistent with the system.

## Pages (relayout only, same content)

Apply the system per page; representative work:
- `app/page.tsx` — hero, serif "Welcome" block, feature cards (rounded, depth, hover),
  framed map section.
- `app/about/page.tsx`, `app/services/page.tsx`, `app/patient-information/page.tsx`,
  `app/reviews/page.tsx`, `app/contact-us/page.tsx` — restyle bands/cards/forms; reviews
  testimonial cards and patient-info policy cards get the new card + type treatment.
- `app/blog/page.tsx`, `app/blog/[slug]/page.tsx`, `app/austin-tx/[slug]/page.tsx`,
  `app/privacy-policy/page.tsx`, `app/sitemap/page.tsx` — editorial/article polish.

## Preview access (the "can't see privacy/sitemap" issue)

Privacy + sitemap routes already render correctly; the blocker is **Vercel Deployment
Protection** gating the whole deployment behind team login. Disable it so the link is
shareable, while keeping it out of search:

- Disable SSO/Deployment Protection on project `prj_1qGybveV5KCpBK3Uj6PpdnosfBtY`
  (team `team_rXEKvH2ZyAiWH68Psz44Rl4g`) via the Vercel REST API
  (`PATCH /v9/projects/{id}?teamId=...` with `ssoProtection: null`), using the CLI's
  stored token.
- **Noindex stays on** — `NEXT_PUBLIC_INDEXABLE=false` (robots disallow + `noindex,
  nofollow` meta), so it can't be crawled/indexed even though it's openable.
- Redeploy preview with `vercel deploy -y --no-wait` and confirm the URL opens anonymously.

## Verification

1. `npm run build` → clean, all routes prerender (currently 319 pages), TypeScript passes.
2. Run dev (port 3137); screenshot **home, about, services, patient-information, reviews,
   contact-us, blog index, a blog post, privacy-policy, sitemap** at **1440px and 390px**;
   visually confirm: warm editorial system applied, copy/images unchanged, single CTA band,
   nav labels incl. "Patient Education", PDFs link to `/forms/*`, Google button uses the
   real URL.
3. Confirm `<meta name="robots" content="noindex, nofollow">` still present on a page.
4. Spot-check the 3 PDFs load at `/forms/...` and open; privacy + sitemap render.
5. Disable Deployment Protection, redeploy, confirm the preview URL opens without login.
6. Run `pr-review-guardian` on the changed files; iterate to clean.
7. Send the user the working preview link. (No git commit/push — user commits manually.)
