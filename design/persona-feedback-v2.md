# ColdFlow / DM Marketer: Persona Feedback on the v2 Plan

Date: 2026-10-20. Follow-up to `persona-mock-test-report.md` (not modified). Same five invented personas, same traits. Personas' reactions are my own reasoning; every conversion, retention, refund and cost figure is a GUESS unless a source is cited. Source quality is marked: **[P]** primary (Apple/X page fetched or quoted by the search tool), **[S]** secondary (blog/news), **[U]** unverified.

---

## 0. Verified facts (checked 2026-10-20)

### 0.1 Apple on-device model: context window and structured output
| Fact | Status | Source |
|---|---|---|
| The on-device Foundation Models model has a **4,096-token context window per session, shared by instructions, prior turns, tool calls/outputs, the new prompt AND the response.** A WWDC26 Q&A is quoted as saying 4,000 input tokens leave about 96 for output. | **[P] via search summary** of Apple TN3193. My direct fetch of TN3193 returned only the page title, so the exact wording is not re-read by me. | [TN3193](https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window), [WWDC26 session 8121](https://developer.apple.com/videos/play/wwdc2026/8121/) |
| Exceeding it throws `exceededContextWindowSize`. It can fire below 4,096 because the model needs room to finish. | [S] forum reports | [Apple forum thread 800238](https://developer.apple.com/forums/thread/800238) |
| iOS 26.4 added `SystemLanguageModel.contextSize` and `tokenCount(for:)`, so the app can measure real tokens. | [S/P] via search summary of Apple material. Check the API reference in Xcode. | [InfoQ, Mar 2026](https://infoq.com/news/2026/03/apple-foundation-models-context) |
| A larger **Private Cloud Compute** model offers 32K, also a shared budget. Whether third-party apps can call it, and under what terms: **[U]**. It is not on-device, so using it breaks the "never leaves your device" claim. | [S/U] | WWDC26 Q&A above |
| **Guided generation exists.** `@Generable` + `@Guide` define a Swift struct; constrained sampling means the output is an instance of the type, no malformed JSON. Call shape is `session.respond(to:generating:)`. The JSON schema is injected into the prompt by default (`includeSchemaInPrompt`), so it **costs some of the 4,096 tokens** (my estimate 50-150, GUESS). | **[P]** concept; [S] for signature details | [Apple: guided generation](https://developer.apple.com/tutorials/data/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation.md), [WWDC25 286 notes](https://wwdcnotes.com/documentation/wwdc25-286-meet-the-foundation-models-framework/) |

**What it means for the owner's example.** Chapters of 2,000 to 4,500 tokens do not fit. A 4,500-token chapter exceeds the whole window on its own. A 2,000-token chapter eats about 50% of it. Budget for one reply (GUESSES): system instructions 100-150, schema 50-150, the tweet 60-150 (plus thread context 100-300), reserved output 100-150 (a 280-char tweet is about 70 tokens, plus slack). That is **roughly 500-900 tokens of overhead, leaving about 2,500-3,300 tokens of absolute ceiling, and a sensible context budget of 1,200-1,800** to keep a safety margin and keep a small model focused. The Bookshelf must be redesigned (section A.2).

### 0.2 Free trial on a one-time purchase
- **Yes, it is allowed.** App Review Guideline 3.1.1 (fetched from Apple 2026-10-20) says: "Non-subscription apps may offer a free time-based trial period before presenting a full unlock option by setting up a Non-Consumable IAP item at Price Tier 0 that follows the naming convention: 'XX-day Trial.' Prior to the start of the trial, your app must clearly identify its duration, the content or services that will no longer be accessible when the trial ends, and any downstream charges the user would need to pay for full functionality." Apple points to Receipts and DeviceCheck for managing access. **[P]** [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- StoreKit's *introductory offers* (free trial inside the subscription system) are for auto-renewable subscriptions only. **[P/S]** [Apple intro offers doc](https://developer.apple.com/documentation/storekit/implementing-introductory-offers-in-your-app.md). So a "1-day Trial" free non-consumable is the sanctioned path; because it is a purchase record it survives reinstall (sound inference, [S] commentary).
- Constraints: disclosure before starting (duration, what locks, final price); no separate demo build (guideline 2.2, [S]); do not invent your own unlock codes ([S]).
- Alternatives: a free tier (e.g. 5 drafts, then unlock IAP) is normal freemium and also fine under 3.1.1 (my reading, not verified line by line). Counting drafts is better than a clock for this app (see A.4).

### 0.3 X API (2026)
| Fact | Status | Source |
|---|---|---|
| Pay-per-use is the default model for new developers from **6 Feb 2026**; free tier closed to new signups; legacy $200/$5,000 tiers closed to new signups. | [S] | [MediaNama, Feb 2026](https://www.medianama.com/2026/02/223-x-developer-api-pricing-pay-per-use-model/), [opentweet](https://opentweet.io/x-api-pricing) |
| Rates: read posts **$0.005 per post returned**; user lookup **$0.010 per user**; "owned reads" (own data, endpoints like `/users/{id}/tweets`, `/mentions`) **$0.001 per resource**, **but only when the authenticated user owns the developer app**; create post $0.015 ($0.20 with a URL per one source); likes read $0.001. Same resource re-requested within 24h UTC is deduplicated (soft guarantee). Cap 3M post reads per billing cycle. | [S] page "last checked against docs.x.com: Oct 10, 2026". Rates vary between blogs. Treat Developer Console as authoritative. | opentweet page above |
| Who pays: developer buys credits upfront; "each purchase of Credits applies to a single X account"; each call deducts credits. | **[P]** [X PPU agreement](https://docs.x.com/developer-terms/ppu-agreement) |
| Per-user OAuth is almost certainly needed to read a user's own posts/engagement. The PPU agreement text does not discuss OAuth. | **[U]** |
| Display: you may reproduce a "reasonable amount" of X content and show it to users, only modified for display; no iframes; must delete on request within 24h; Display Requirements apply. Automated replies/actions are governed by the separate Automation Rules, reportedly requiring explicit approval for AI reply bots (self-serve only for replies the account was summoned to). Our app drafts and the human posts, so it is outside that, but I could not verify this reading. | **[P]** display; [S/U] automation | PPU agreement; [Open Terms Archive](https://opentermsarchive.org/en/memos/x-replaces-its-dollar200-entry-level-api-plan-with-a-pay-per-use-model/) |

**Consequence.** Owned-read $0.001 does not help: the *user* does not own *our* developer app. Every engagement fetch is the developer's cost at about $0.005 per returned post/reply, billed per resource. That is a recurring variable cost attached to a one-time price. See C.4 for the arithmetic.

### 0.4 Feasibility
- **Apple Notes:** I found no public API to read Notes from a third-party app, and an Apple DTS engineer states there is no URL scheme to open Notes. Practical route: the user shares a single note via the share sheet into our extension (text arrives as a shared item); bulk export is Mac-only via third-party tools. [S/U] [Apple forum 844528](https://developer.apple.com/forums/thread/844528), [Zapier](https://zapier.com/blog/export-apple-notes.md). Treat as: "one note at a time via Share", plus paste.
- **Google Docs:** Restricted Drive scopes (full Drive / drive.readonly) require OAuth verification and, when data is stored/transmitted on servers, a CASA security assessment every 12 months (reported 4-6+ weeks). The per-file `drive.file` scope is lighter but user must pick files with the Picker. I could not confirm classification of a Docs read-only scope. [S] [Google restricted scope verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/restricted-scope-verification), [Nango](https://nango.dev/docs/api-integrations/google-shared/google-security-review). Cheaper route: user exports Docs as text/Markdown/PDF to Files, or copy-pastes; app imports from the Files picker.
- **Confluence:** needs Atlassian OAuth 2.0 (3LO) app registration and per-site consent; heavy for a solo dev. **[U]** from my own knowledge. Defer.
- **On-device chapter suggestion:** `NLEmbedding` / `NLContextualEmbedding` give on-device vectors with no model download and no network; sentence-embedding asset availability has been flaky and language coverage limited (English works) per forum reports. [S] [NLEmbedding doc](https://developer.apple.com/documentation/naturallanguage/nlembedding.md), [Callstack](https://callstack.com/blog/on-device-ai-introducing-apple-embeddings-in-react-native). Plan: embed chunk text in the main app (not the extension, which has tight memory limits [my knowledge, U]), store vectors in the App Group, cosine-rank in the extension, with BM25-style keyword fallback. Suggesting by asking the LLM costs window tokens; do not.
- **iPhones that are Apple-Intelligence-capable:** Apple does not disclose it. Counterpoint: over **450M** Apple-Intelligence-capable iPhones shipped cumulatively through Q1 2026 [S via search summary] ([Counterpoint](https://counterpointresearch.com/cn/insights/apple-has-shipped-over-450-million-apple-intelligence-capable-iphones)). A developer blog estimates roughly a **third** of active iPhones entering fall 2026 [S/U, unnamed method]. Active iPhone base: older Intego figure 1.46B [S, dated]; I assume about 1.5-1.6B (GUESS). 450M plus roughly 100M more shipped since Q1 gives about 550M, so **about 33-36%** (range 28-40%). Not all capable phones have it enabled or an eligible region/language (GUESS 90% usable). The capable share is higher among my target buyers (founders, recent upgraders): **I use A 60%, B 40%, C 45%, D 33%** (GUESSES). Update this from real data (App Store analytics device-model breakdown) after launch.

---

## A. Candid product critique

### A.1 What is strong
1. **Dropping the GGUF path is the best idea in the plan.** The first report's top drop-off cause was the slow path (7 steps, notification hand-off, mediocre 0.5B drafts). Apple's model runs in the share extension, so the whole loop stays inside the sheet. It also deletes llama.cpp, downloads, model catalog UI, notification permissions, and a class of bugs. Use that to *simplify the product and the story*.
2. **Trial: allowed and correct instinct.** The first report named "pay before seeing a draft" as the #2 reason for drop-off.
3. **Fixing the Topic bug / diagnostics** is table stakes. Do it first.
4. **Context that makes a draft sound like me** is the thing generic chat does not give you at the moment of replying. That is the real product. The reply-layer-in-the-share-sheet beats opening ChatGPT, pasting the tweet, and pasting your context.
5. **Explicit expectations in onboarding** (device, one at a time, what is stored) filters out Tyler and prevents 1-star reviews.

### A.2 What is flawed or risky
1. **"Move away from ChatGPT/Claude" is the wrong frame.** A roughly 3B-class on-device model with a 4K window will not out-write a frontier model. Nobody is "moving away"; they will keep ChatGPT for real writing. Position as "the reply layer that already knows your product, in the share sheet, private". Complement, not replacement. (3B size is from my memory of Apple's tech report, U.)
2. **"Local + private context" is a real hook only for some.** ChatGPT Projects and Claude Projects already store product context with zero setup effort per use. Privacy matters to people with confidential material (client NDAs, unreleased product, pricing, deal terms). For a founder whose product is public marketing copy, privacy is nice-to-have. Test it (D.5), do not assume it.
3. **The Bookshelf as specified does not fit the model.** 2,000-4,500-token chapters vs a shared 4,096-token window (0.1). Even the "remove chapters until it fits" UX is hostile: the user does the model's packing job and sees a wall of red numbers. A budget of 1,200-1,800 tokens of context means **2-4 small cards, not books**.
4. **Setup effort is the real killer.** Books, chapters, import from four sources, and then curating a selection per reply. Most users will create nothing. See abandonment model in B.
5. **Suggestion step adds latency and a decision to every reply.** The product's promise is "20 seconds". "Pick your chapters" on every share breaks it. Suggestion must be silent by default (auto-select top cards within budget, one tap to change).
6. **X API engagement tracker breaks the model of the business.** One-time price vs recurring per-call cost where the heaviest users cost the most (C.4). It also needs per-user OAuth, a token store, probably a backend proxy (shipping a developer key in the app is extractable [my knowledge]), which contradicts "no account, nothing leaves your device" and is a new compliance surface (X display rules, deletion within 24h of request). It is also the largest feature (L) for a thing a "got a reply? yes/no" tap approximates.
7. **Runtime-only gating is dangerous.** If the listing cannot exclude iPhone 14 and older [U: I did not verify whether a `UIRequiredDeviceCapabilities` key can express "Apple Intelligence capable"], people on unsupported phones can see a ~4.x-star app, buy, hit the wall, refund, and review. Mitigation: free download + free "N-day Trial" non-consumable (0.2), run the eligibility check *before* showing any paywall, put "Requires iPhone 15 Pro or newer with Apple Intelligence" in the first line of the subtitle/description and screenshot 1.
8. **A 1-day trial is too short for this app** (B and D show why). A habit and a context setup need several days of replies.
9. **Hard wall halves the audience** (C.1). That is a trade for quality, not a free move.
10. **Pitching quality risk.** A small model plus injected context can parrot case-study snippets or invent facts. Without a faithfulness guard (copy numbers only from the cards, keep outputs short, user always edits) it will produce confident wrong claims under the user's name.

### A.3 Redesign: Bookshelf that works in 4,096 tokens
Design principle: **the user stores long text; the model only ever sees short, pre-compressed text selected per tweet.**
- **Cards, not chapters, are what the model reads.** Each Book chapter has: (a) *full text* (stored, any length, never sent whole), (b) a **card** of 80-250 tokens (user-written, or auto-summarised by the local model once at import, user approves), (c) *chunks* of about 150 tokens with embeddings for snippet retrieval.
- **Two permanent cards (always included, about 400 tokens total): Product Card and Voice Card.** Product Card = the existing Topic extended (what it is, who for, price, link, one-line proof). Voice Card = tone rules plus 3-5 of the user's own best replies/tweets as examples (few-shot examples beat adjectives).
- **Per-reply retrieval: 1-3 snippets**, ranked by embedding similarity to the shared tweet, within the remaining budget (about 600-1,000 tokens). Case study for "invoice tool?" tweet; FAQ for "is it GDPR-safe?" tweet.
- **Token meter, not an error.** A small bar "Context 1,420 / 1,800 tokens". Greedy fill by score. Show what was dropped and offer "swap". The "remove a chapter to fit" message becomes a rare edge case, only for the manual override. Per-chapter token count shown (via `tokenCount(for:)`, fallback chars/3.5) with a green/amber/red on *card* size, red above 300.
- **Import = make cards easy.** (1) Paste text. (2) Share any text, note or tweet from any app into "Save to Bookshelf / Save as voice sample" (this reuses the existing share extension and solves Notes, Docs, Safari at once, one item at a time). (3) Files picker for .txt/.md/.pdf. Local model summarises long imports into a card candidate. Defer Google OAuth, Confluence, X-archive import.
- **Tweet history import:** do not use X API. Voice samples via "Share one of my tweets, tap Save as voice sample" (10 shares build a voice card), plus an optional paste of the X data archive text later.
- **Structured output:** use `@Generable struct Reply { var tweet: String }` with a `@Guide` description. Drop the hand-written "Output JSON" sentence. The "no em dashes" rule is unreliable as a prompt instruction; enforce in code by replacing the character after generation, and validate length (<=280) with one retry.
- **Safety rail:** the prompt tells the model to use only facts present in the context; show the card names used ("Used: Voice, Product, Case study: Acme") so the user can see why a claim appeared.

### A.4 Trial design recommendation
Use the sanctioned free non-consumable but make it **7 days or 10 drafts, whichever is first** (names must follow "XX-day Trial"; you can still count drafts in-app and disclose it, but check that wording with App Review, U). If the owner insists on 1 day, I would at least require the user to do the Topic + Voice card setup *inside* the first session and show a finished draft before any paywall. A 1-day trial helps Maya types and nobody else (B).

### A.5 Minimal v2 scope (MVP) and what to defer
**Ship:** Apple-only gate with graceful messaging; real Topic in share sheet; diagnostics out; guided generation with token guard; free "N-day Trial" + $14.99 unlock; Product Card + Voice Card + "Save as voice sample" share action; silent snippet retrieval from a handful of pasted/shared chunks; local history of replied-to links; manual "Got a reply / Converted" tap; clear onboarding. Instrument with a minimal opt-in event log for the test.
**Defer:** X API Recent Engagements (rethink: add-on or BYO key), Google Docs, Confluence, X-archive import, multi-book hierarchy UI, PCC fallback, bulk anything.

---

## B. Persona re-run

Shared setup: onboarding now says "Needs iPhone 15 Pro or newer with Apple Intelligence. One reply at a time, no bulk, no auto-sending. Your product, voice and notes stay on this phone." One-time $14.99 after a 1-day free trial. Notification permission step is gone (no hand-off). Price grid refers to the $14.99 baseline.

Bookshelf abandonment model used (GUESSES, per persona, among people who start the trial): finishes Product Card in session 1 / adds a Voice Card by day 3 / ever creates 3+ chapters.

### B.1 Maya Okafor (82%, iPhone 15 Pro, capable)
**Reactions, first person**
1. *Apple Intelligence only:* "Fine, I'm covered. Honestly good news, no model downloads and the share sheet should just do it."
2. *1-day trial:* "Good. Though a day is tight if I want to set up context. I do 10 to 15 replies a day, so one day is enough for me to know."
3. *Share sheet uses my real Topic:* "That was the bug I'd have rage-quit over. Obvious."
4. *Engagement tracker via X API:* "I'd love it. A list of who answered my replies is exactly what I paste into a spreadsheet today. I'd connect X. If it needs a monthly fee I'd pay a few bucks. If it breaks I'd be annoyed, I'd rather it not be flaky."
5. *Bookshelf:* "I'd build a product card, a voice card with my best 5 tweets, and a case study card. About 15 minutes. I won't build books with chapters, I'll build three notes."
6. *Onboarding clarity:* "'One at a time' is how I work already. Good."
**Emotion:** pleased, a bit protective of her time. **Would use:** share sheet, Product + Voice cards, link history. **Annoys:** token budget errors ("don't make me do the model's job"), any extra tap per reply, any hint of cloud.
**Positioning:** "Local AI + private context" half-resonates. "My product is public, privacy isn't my pain. But I already have a Claude Project with my positioning and it takes me 30 seconds of copy-paste to use it for a reply. A share sheet that already knows me and writes in 6 seconds, that I'd pay for." She is paying for speed-in-flow plus context-for-free, not for privacy.
**Purchase:** before 80% at $14.99, ceiling about $25. Now **85% at $14.99, ceiling about $30** (+5 pts, +$5): context memory raises perceived value and the trial removes the "I haven't seen a draft" objection. Capped by fear of generic Apple-model prose.
**1-day trial walkthrough:** Hour 0: installs, pastes her pitch into the Product Card, adds 3 old tweets as voice samples (10 min). Hour 0.5: replies to 3 live "tool for X?" threads, edits 1. Day: 10 drafts, copies 7. Evening: notices voice drifts salesy and tweaks the Voice Card. She sees value before the day is out. Enough: **yes**. Buys at the end of day 1, probably within the trial-ending prompt.
**Bookshelf:** builds it (90% make a Product Card, 75% add a Voice Card, 35% ever create 3+ chapters).
**Retention:** day 7 95%, day 30 85%, day 90 75% still active. **Churn day:** retained (risk: an iOS update changes model behaviour, or her card goes stale). Refund 3%.
**One-time LTV:** $12.74 x 0.97 = $12.36 + referral 0.7 buyers x $12.74 = $8.92 = **$21.3** (was $19.96) before any X API cost. If the engagement tracker is on at developer cost, her heavy usage can cost $2-12 per month (C.4), turning this LTV negative within a year.

### B.2 Dev Raman (76%, iPhone 14: WALLED OUT)
**Reactions**
1. *Apple Intelligence only:* "I read 'Requires iPhone 15 Pro or newer' in the subtitle and I'm out. It's an iPhone 14, 4 years old, works perfectly. I'm not buying a phone for a $15 app." **Lost customer, P(buy) = 0.**
2. *1-day trial:* "Can't try it. If it let me install and then told me 'unsupported', I'd be annoyed."
3. *Real Topic:* n/a. 4. *Engagement tracker:* "I'd want it, clients ask 'which posts are working'. But I'd need it on my phone."
5. *Bookshelf:* "Strongest part for me. I do not want client details in ChatGPT; that's a real NDA issue. A local context that holds per-client voice and positioning would be a reason to use it. I'd build one book per client, 10-20 minutes each. That's the pitch that'd have sold me." 6. *Onboarding:* "At least it's honest."
**Emotion:** disappointed, not angry, because the listing was clear. **Annoys:** being cut out by hardware. **Positioning:** resonates *strongly* (privacy is a concrete NDA need, not abstract), and that is the irony: the best privacy-motivated persona is on the excluded side.
**Purchase:** was 60% at $14.99 / ceiling $18. Now **0%** today. Conditional on owning a capable phone: **70%, ceiling $20** (privacy plus trial). Chance he upgrades within 12 months and comes back: about 25% upgrade x 10% remembers = **2-3%** (GUESS). Year-1 expected value about $0.
**Hypothetical 1-day trial (if capable):** hour 0 imports one client's brand notes via share; day: 4 replies for that client, 2 copied. One day is **not quite enough**: he doesn't do volume. He would need 3-5 days. P(convert after 1 day) 45%, after 7 days 70%.
**Retention conditional on capable phone:** day 7 70%, day 30 45%, day 90 30% (the slow-path problem is gone but his volume is low and client work crowds it out). **Churn day:** about 90 (dormant), conditional. Actual: not a customer.
**LTV:** $0 now; conditional $15.0 -> about $17 (privacy-driven word of mouth to freelancers who do have capable phones).
**Bookshelf (conditional):** 70% build a Product Card per client, 40% a Voice Card, 25% 3+ chapters.

### B.3 Priya Nair (55%, iPhone 16, capable)
**Reactions**
1. *Apple only:* "I'm fine, and thank God no notification dance." 2. *1-day trial:* "Okay, I can at least see a draft. But one day: I do 3 outreach messages a week." 3. *Real Topic:* "Of course." 4. *Engagement tracker:* "My outreach is mostly email and Instagram DMs. A tracker for X replies is a nice thing, not my thing." 5. *Bookshelf:* "My voice is my brand. If it can learn from my newsletter, I'm interested. If it's three bullet points of tone, I've already got that in ChatGPT custom instructions. And I can drop 200 issues into a ChatGPT project, why would I use a 4K-token thing?" 6. *Onboarding:* "Clear. I appreciate 'no bulk'."
**Emotion:** curious, then skeptical. **Would use:** Voice Card via sample saves; guest-invite replies. **Annoys:** setup, generic-sounding output, no email depth.
**Positioning:** "Local + private" mildly resonates (sponsor rates, guest negotiations feel private). But "ChatGPT with my newsletter archive is more me." Net: does not beat ChatGPT for voice; wins only on convenience in the share sheet.
**Purchase:** was 35% at $14.99 / ceiling $12. Now **38%** at $14.99, ceiling **$12** (unchanged). Small gain from trial plus visible voice card; context window capped quality prevents more.
**1-day trial walkthrough:** installs, adds 3 voice samples from her tweets (10 min), tries 2 replies in a day. "Sounds a bit more like me. A bit." One day shows a draft but not whether voice holds. P(convert after 1 day) 30%; after 7 days 40%.
**Bookshelf:** 55% Product Card, 40% Voice Card, **15% ever 3+ chapters**. She will likely try to import Notion/Notes bulk, fail (one note at a time), and quit the setup at the third import.
**Retention:** day 7 55%, day 30 25%, day 90 10%. **Churn day:** about 28 (was 21; the share-sheet speed holds her a bit longer). Refund 8% (trial reduces regret).
**LTV:** $12.74 x 0.92 = $11.72 + referral 0.1 x 12.74 = $1.27 = **$13.0** (was $12.48).

### B.4 Jordan Pierce (40%, iPhone 13: WALLED OUT)
**Reactions**
1. *Apple only:* "iPhone 13. Not eligible. Moving on." **Lost customer, P(buy)=0** (was 10%). 2. *Trial:* "Wouldn't matter." 3. *Real Topic:* n/a. 4. *Engagement tracker:* "My CRM tracks replies." 5. *Bookshelf:* "My company's approved talk tracks are the context. I can't paste them into a personal app, so private-on-my-phone doesn't help me; compliance says no tool outside the approved list." 6. *Onboarding:* "Clear, and clearly not for me."
**Emotion:** indifferent. **Positioning:** does not resonate: his issue is permission, not privacy.
**Purchase:** 0% now. Conditional on a capable phone: 8% (ceiling $8, same as before). **Effect of the wall on revenue:** a loss of about $0.96 per visit in the first report. In practice a benefit: removes the segment that churned in a week with 25% refunds. No Bookshelf use. If he somehow paid: churn day 5-7, refund 25%, retention 20/5/0.
**LTV (if he bought): $9.56 before; wall makes realised LTV $0.**

### B.5 Tyler Brandt (20%, iPhone 15 Pro, capable)
**Reactions**
1. *Apple only:* "Fine, got the phone." 2. *Trial:* "Free, I'll poke at it for ten minutes. If it can't batch I'm gone." 3. *Real Topic:* shrugs. 4. *Engagement tracker:* "A tracker for hand-sent replies? lol. Give me a dashboard for 400 DMs a day." 5. *Bookshelf:* "I have prompts in a Notion. I'm not typing chapters into a phone." 6. *Onboarding:* reads "no bulk, one at a time", closes the app. The onboarding now does its job; he leaves before the paywall.
**Emotion:** dismissive. **Positioning:** no. "Local AI" is a negative: he wants cloud scale.
**Purchase:** was 3%. Now **1.5% at $14.99** (ceiling $5). The trial costs nothing and the honest onboarding repels him earlier, which reduces refunds and rage reviews.
**Trial walkthrough:** 10 minutes, 3 drafts, finds no bulk, deletes. One day is more than enough to confirm it isn't for him.
**Bookshelf:** 5% create a card. **Retention:** day 7 0%, day 30 0%. **Churn day:** 0 (same session). Refund 20% of the few who buy. **LTV:** about **$9** per buyer ($12.74 x 0.8 refund-adjusted, minus review cost, GUESS); expected per visit about $0.14 (1.5% x $9).

### B.6 Who builds a Bookshelf, who never bothers
| Persona | Product Card | Voice Card | 3+ chapters ever | Honest verdict |
|---|---|---|---|---|
| Maya | 90% | 75% | 35% | Builds the minimum, three small cards in 15 min. Never builds "books". |
| Dev (capable) | 70% | 40% | 25% | Per-client cards; the only persona for whom privacy is the motive. Lost to the wall. |
| Priya | 55% | 40% | 15% | Starts, tries bulk import, abandons. |
| Jordan | 15% | 5% | 0% | Never. |
| Tyler | 10% | 2% | 0-5% | Never. |
Across buyers weighted by segment: **about 40-50% of trial starters never create anything beyond the Topic** (GUESS), and fewer than 20% ever create 3+ chapters. Design for a one-screen Product Card and a "save as voice sample" share action; treat everything past that as a power-user bonus.

---

## C. Updated numbers

### C.1 SAM / SOM after the hard wall (GUESSES labelled; capable shares from 0.4)
SAM people per segment (iPhone owners from the first report x English 0.55 x capable share x usable-and-enabled 0.9; iOS 26 is implied by the hardware):
| Segment | iPhone owners (first report) | Capable share | SAM v2 | SAM v1 |
|---|---|---|---|---|
| A. Indie/solo founders | 1.65M | 60% | **0.49M** | 0.82M |
| B. Freelancers/consultants | 2.70M | 40% | **0.54M** | 1.34M |
| C. Creators/community | 0.90M | 45% | **0.20M** | 0.45M |
| D. Sales/SDR (10% buy personally) | 0.25M | 33% | **0.04M** | 0.12M |
| Total | | | **about 1.27M** | about 2.7M |
The wall cuts SAM by about **53%**. Audience shifts toward indie founders (39% of SAM v2 vs 30% before) and away from freelancers, who are now the biggest segment *lost* (60% of them excluded).

SOM year 1: conversion per SAM person raised to about 1.6x the v1 rate (GUESS: v1 conversion was diluted by the slow-path majority, about 1.4x; trial about 1.1x; context/positioning about 1.05x; but a 1-day trial and "Apple-only" copy keep it modest):
| Segment | v2 conversion | Buyers | Net per buyer | Net revenue |
|---|---|---|---|---|
| A | 0.80% | 3,920 | $12.36 | $48.5K |
| B | 0.32% | 1,712 | $11.21 | $19.2K |
| C | 0.16% | 320 | $11.72 | $3.8K |
| D | 0.08% | 33 | $9.56 | $0.3K |
| **Total** | | **about 5,985** | | **about $71.8K** (was about $86K) |

### C.2 Per-segment LTV (one-time, per buyer; before X API cost)
A $21.3 (was $19.96) | B $15-17 conditional, $0 for walled (was $15.03) | C $13.0 (was $12.48) | D $0 walled (was $9.56) | Tyler-type about $9 (was $7.64).

### C.3 Before / after
| Metric | Report 1 | v2 plan | Delta |
|---|---|---|---|
| SAM people | 2.7M | 1.27M | -53% |
| Year-1 buyers (guess) | about 7,270 | about 5,985 | -18% |
| Year-1 net revenue, before X API cost | about $86K | about $72K | **-17%** |
| Maya P(buy) / ceiling / LTV | 80% / $25 / $19.96 | 85% / $30 / $21.3 | up |
| Dev P(buy) / LTV | 60% / $15.03 | **0%** (walled; 70% conditional) / $0 | lost |
| Priya P(buy) / ceiling | 35% / $12 | 38% / $12 | flat |
| Jordan P(buy) | 10% | **0%** (walled) | lost, little value anyway |
| Tyler P(buy) | 3% | 1.5% | lower, fewer rage refunds |
| Median buyer retention d90 (A) | retained | 75% | similar |
| Variable cost per active user | about $0 | $0 (no X API) to $1-12/month (with X API) | **new** |

### C.4 X API unit economics (all GUESSES except the per-resource prices in 0.3)
Assume each tracked reply returns on average 4 billable resources per poll (the reply itself with metrics plus about 3 responses) at $0.005 = $0.02 per tracked reply per poll. Polling is deduped within 24h.
- **Light** (Dev/Priya style, 3 replies per week, 14-day tracking, daily polls): about 6 live x $0.02 x 30 = **about $3.6/month**; with decay polling (days 1, 3, 7) about $0.8/month.
- **Heavy** (Maya, 10 per week, 14-day window): about 20 live x $0.02 x 30 = **about $12/month** daily; **about $2.6/month** with decay polling (3 polls per post).
- Net revenue per buyer is **$12.74 once**. At $2.6/month the cost eats it in 5 months; at $12/month in one month. Add user lookups at $0.01 each. Even disciplined polling means a perpetual developer-paid tail on a one-time sale.
- Year-1 estimate: 40% of 5,985 buyers use it for an average 3 months at $2/month = **about $14K** (GUESS), growing in later years.
**So the engagement tracker must be (a) a paid subscription add-on, (b) bring-your-own X developer key (very poor UX, X developer account requires its own setup), or (c) replaced by manual outcome logging in the MVP.** Also needs a backend proxy and token storage, which weakens the privacy story.

### C.5 Verdict on revenue (GUESSES)
- **v2 as written** (Apple-only, trial, Bookshelf, developer-paid X engagements): year-1 net **about $72K minus about $14K X API = about $58K, i.e. about -33% vs $86K.** Range: -15% to -55% depending on how many use engagements and whether conversion really rises 1.6x.
- **v2 MVP** (no X API, cards instead of books, 7-day trial or 10 drafts): about $72K, **-17%**, with a more loyal user base and no variable cost.
- **Upside lever:** a better product justifies **$19.99** (Maya's ceiling $30, Dev $20 conditional, Priya $12, so this loses Priya-types). Assume conversion x0.85, revenue x(16.99/12.74) x 0.85 = x1.13 => **about $81K**, i.e. **-6% vs report 1**, with fewer refunds. The honest answer: **the hard wall decreases expected year-1 revenue; only a higher price and cheaper cost structure get it back near parity.** The wall is still worth it if the trade is "smaller, happier, cheaper to support", but do not count on it being revenue-positive.
- Also note the mix improves: refunds, 1-star reviews and support from slow-path users fall, and the Apple path is the only one that supports the share-sheet hand-off with no notification.

---

## D. Real-user test plan (one person, 14 days)

### D.1 ICP and screener (reply by DM or form, 6 questions)
1. What do you sell or promote, and who for? (free text)
2. In the last 7 days, how many times did you reply to someone else's post to promote or start a conversation? (0 / 1-5 / 6-20 / 20+) **Need 6+.**
3. Where? (X / Reddit / LinkedIn / other)
4. What iPhone model do you carry? **Need 15 Pro / 15 Pro Max / 16 series / 17 series (Settings > Apple Intelligence & Siri is on).** Hard filter.
5. What do you use today to write those replies? (by hand / ChatGPT / Claude / templates / nothing)
6. Do you keep your product context in ChatGPT/Claude Projects or memory? (yes / no / which)
Disqualify: bulk automation users (>50 sends/day), company-mandated CRM only. Want a mix: 8 solo founders, 4 freelancers, 2 creators, 1-2 skeptics who use ChatGPT Projects heavily.

### D.2 Where to recruit (10-20 completed participants; aim for 40 outreach contacts)
Check each community's self-promotion rules first.
- **X:** reply to your own followers and to people who post "building in public" / "looking for tool" threads; search `"reply guy" OR "cold DM" OR "build in public" min_faves:5`. Warm DMs after 2-3 genuine interactions.
- **Indie Hackers** (forum and groups), **r/indiehackers, r/SaaS, r/EntrepreneurRideAlong, r/solopreneur**: post a "looking for 15 testers, iPhone 15 Pro+ only" thread with the screener.
- **Freelancer/consultant communities** (e.g. Slack/Discord groups the owner already belongs to) and past friends-of-friends.
- **Creator circles:** Substack Notes, newsletter-operator Slacks.
- **Local:** owner's own network; ask each participant for one referral.
Cap at 20; unpaid; offer lifetime free unlock and a founder's call.

### D.3 Outreach message templates (DM-sized)
- **Cold X DM (founder):** "Hey [name], saw you replying to 'tool for X?' threads. I built an iPhone app that drafts those replies from the share sheet using your product context, all on-device. Looking for 15 testers on iPhone 15 Pro or newer for 2 weeks. Free forever if you give feedback. Interested?"
- **Reddit post title/body:** "Testing a share-sheet app that writes replies to posts using your own product notes, fully on-device (needs iPhone 15 Pro+). 2 weeks, free, 15 spots. Comment with what you sell and your iPhone model."
- **Freelancer (warm):** "You mentioned not pasting client details into ChatGPT. I'm testing an iPhone app that keeps client notes on-device and drafts replies in the share sheet. Want to try it for 2 weeks? Needs iPhone 15 Pro or newer."
- **Follow-up (day 3, no reply):** "No worries if not! Just closing my list of 15 spots tomorrow. Happy to send TestFlight either way."
- **Decline-handling for wrong phone:** "Thanks! This test needs iPhone 15 Pro+. If you upgrade I'd love your feedback later."

### D.4 TestFlight logistics
Public link or email invites, up to 10,000 external testers; the first external build needs Beta App Review (about 1-2 days, plan for it); builds expire after 90 days (my knowledge, verify in App Store Connect). Ship the build with the real flow: free "N-day Trial" mock using TestFlight's sandbox purchases so the paywall appears at trial end (testers are not charged). Set a testers' feedback form link in the app. Send the build **day -3**; start the clock when each tester first opens the app, not when invited.

### D.5 Instrumentation (local counters, uploaded only if the tester opts in; tell them what is collected)
Events: install_time, first_open, topic_created, product_card_created, voice_card_created (and count of voice samples saved), chapters_created, chapters_total_tokens, share_sheet_opened, draft_generated, draft_copied (the key success event), draft_edited_before_copy (approx: copy happens after regenerate/edit), regenerate_count, context_budget_exceeded, suggestion_accepted/changed, time_to_first_draft (install to first draft_generated), time_to_first_copy, days_active, trial_end_paywall_seen, would_buy_tap (a mock "Buy $14.99?" yes/no at day 14), reply_outcome_marked. Add a one-question weekly in-app prompt: "How disappointed would you be if this vanished? (very/somewhat/not)".
Trial-to-paid proxy: % tapping "Buy" at the mocked paywall at trial end *plus* answer to "would you pay $14.99 today?" at day 14.

### D.6 Schedule
| Day | Action | Check-in question |
|---|---|---|
| -3 | Send TestFlight and screener results | "Anything blocking install?" |
| 0 | Onboarding walkthrough; they set up Product Card | "Describe what you did in the first 10 minutes." |
| 1 | Ping: how many replies? | "Did the draft use your product correctly? Any wrong facts?" |
| 3 | Prompt to add a Voice Card | "Did it sound like you? What did you change?" |
| 5 | Nudge to use on a real reply | "Did any reply get an answer?" |
| 7 | 5-minute survey | "Sean Ellis question; what's missing?" |
| 8-10 | Positioning test (D.7) | see below |
| 14 | Interview (20 min) | script D.8 |
All questions go by DM, one at a time, never more than 2 messages per day.

### D.7 Testing "local + private context" vs ChatGPT Projects
- **Blind comparison:** each tester creates a ChatGPT/Claude Project with the same Product + Voice text. Take 5 real tweets they pick; generate replies with (a) their Project, (b) the app. Show unlabeled; they pick the better reply and say which they'd send. Threshold: app wins or ties in **>=40%** of pairs and speed-in-flow (seconds from tweet to pasted reply) is **>=2x faster**.
- **Positioning A/B:** half the testers get the "local AI + your private context" onboarding, half "reply to the right post in 20 seconds, it already knows your product". Compare Product-Card completion rate and day-7 retention. n is small, so read direction, not significance.
- **Privacy probe:** ask "what would you NOT put into ChatGPT?" If under 30% name anything concrete, privacy is not the lead message.

### D.8 Interview script (20 min)
1. Walk me through the last time you used it. 2. What were you doing right before? 3. What did you paste into ChatGPT instead, and why? 4. Show me a draft you sent unedited. A draft you threw away. 5. Did you create any cards? Why/why not? How long did that take? 6. Did you notice the token meter? What did you think? 7. Anything it got wrong about your product? 8. What did you give up on? 9. Would you pay $14.99? $19.99? What would make that a clear yes? 10. If I removed it tomorrow, what would you do instead? 11. Who else should I give this to?

### D.9 Kill / continue thresholds (numeric, on iPhone-15-Pro+ testers, n=10-20)
| Metric | Continue | Rework | Kill |
|---|---|---|---|
| Time to first draft | <=5 min median | 5-10 | >10 |
| First-session draft copied | >=70% | 50-70 | <50 |
| Day-7 active (>=3 days with a copy) | >=50% | 30-50 | <30 |
| Created Product Card | >=70% | 40-70 | <40 |
| Created Voice Card or 3+ chapters | >=40% | 20-40 | <20 (cut Bookshelf, keep product) |
| Drafts copied per active week | >=8 | 3-8 | <3 |
| "Very disappointed if gone" | >=40% | 25-40 | <25 |
| Would pay $14.99 (mock paywall) | >=40% | 20-40 | <20 |
Overall: **continue if 5+ rows are "continue" and none is "kill" on first-session copy, day-7 active or would-pay.**

---

## E. Top-10 prioritized build list

| # | Item | Size | Why this order |
|---|---|---|---|
| 1 | Share sheet uses the real Topic (App Group) and diagnostics removed | S | Known bug; blocks every test |
| 2 | Apple-only gate: availability states (`deviceNotEligible`, not enabled, model not ready), clear onboarding copy, delete GGUF path and notification step | M | Biggest simplification, unblocks in-sheet flow |
| 3 | Guided generation (`@Generable` reply), token guard via `tokenCount`/`contextSize`, em-dash and length post-filter, one retry | M | Reliability; defines the real context budget |
| 4 | Free "N-day Trial" non-consumable + $14.99 unlock; eligibility check before any paywall; sample draft before paywall | M | Sanctioned by 3.1.1; fixes #2 drop-off cause |
| 5 | Product Card + Voice Card with token meter; "Save as voice sample" share action | M | Core of the new positioning at minimal setup effort |
| 6 | Minimal opt-in instrumentation + TestFlight build, then run the 14-day test | S | Gate for everything after |
| 7 | Local reply history with link storage, manual "got a reply / converted" tap | S | The cheap version of the outreach tracker |
| 8 | Silent snippet retrieval over Bookshelf chunks (embeddings in app, ranking in extension, keyword fallback), budget bar, manual swap | L | Only after #5 proves people create cards |
| 9 | Import: paste, Files (txt/md/pdf), share-in from Notes/Safari, local summarise-to-card | M | Lower setup effort; no OAuth |
| 10 | **Deferred:** X API Recent Engagements as paid add-on or BYO key (plus backend proxy), Google Docs (OAuth/verification), Confluence | L each | Costly, recurring cost and compliance; revisit only if testers beg for it |

Order to build: 1, 2, 3, 4, 5, 6 (ship test), then 7, then 8-9 based on the test, then 10 only on evidence.

---

## Caveats
Personas and all rates are my own constructs. The strongest facts: the 4,096-token shared window and guided generation (Apple), the 3.1.1 trial rule (Apple, fetched today), X's per-resource pay-per-use model and developer-pays billing (X agreement plus third-party price pages). Unverified: per-user OAuth specifics, X Automation Rule application, device-capability gating in the listing, `tokenCount` minimum iOS, exact capable-iPhone share (33-36% is derived from a Counterpoint shipment figure and an unsourced blog estimate), Apple Notes/Confluence integration details.
