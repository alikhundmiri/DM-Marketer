# ColdFlow / DM Marketer: Persona Mock-User Test

Date: 2026-10-20. Simulated test. All personas are invented; every number is a labelled assumption or guess unless a source is cited. This is a decision tool, not a forecast.

---

## 0. Ground truth and ASSUMED design

### What the code actually does (read, not modified)
- Share extension (`ShareExtension/ShareViewController.swift`): formats are Tweet reply / X DM / Email reply. With Apple Intelligence it drafts in-sheet, then "Copy & close". Without it, it saves the post to an App Group, posts a local notification, and shows "Tap the DM Marketer notification to write your reply with your downloaded model." If notifications are denied it says "Open DM Marketer to write your reply."
- **Gap A:** the in-sheet Apple path uses a hard-coded product string (`static let product = "ColdFlow: ..."`, commented "Hard-coded until the app writes the active topic into the App Group"). So the Apple-Intelligence path does not yet use the user's own Topic. A user's first in-sheet draft would pitch the wrong product.
- **Gap B:** the extension still carries spike diagnostics ("Copy report", "Test: open X from the sheet").
- **Gap C:** notification permission is requested in `ContentView` on first launch (alert and sound), with no pre-prompt explaining why.
- The model catalog's own copy sets expectations: Qwen 2.5 0.5B is "2-4 seconds", Gemma 3 1B is "15-30 seconds on iPhone 13", Qwen 3.5 2B "requires iPhone 14 Pro or newer", Gemma 4 E2B is 3.7 GB and needs 8 GB RAM. Downloads run 395 MB to 3.7 GB from Hugging Face.
- Chat quick actions include "Less salesy" and "Empathetic". The Topic form asks for name, "What You're Promoting" and a link.
- Real onboarding and paywall do not exist.

### ASSUMED onboarding + paywall (my design, used for every persona)
| # | Screen | Content |
|---|---|---|
| 1 | Value prop | "Reply to the right post in 20 seconds. Runs on your phone. No account, no subscription." Mascot, one screenshot. |
| 2 | How the share sheet works | 3-step illustration: Share, then DM Marketer, then Copy & close. Instruction to find "DM Marketer" under "More" and pin it. |
| 3 | Your product | Create first Topic: name, what you promote, link. |
| 4 | Engine check | Detects Apple Intelligence. If yes: "You're set." If no: "Pick a model to download" (recommends Qwen 2.5 0.5B, 395 MB), with Wi-Fi note. Download starts after purchase. |
| 5 | Notifications | Pre-prompt: "We'll tell you when a draft is ready." Then the system dialog. |
| 6 | Paywall | **Hard paywall, one-time $14.99.** Bullets: unlimited drafts, offline, no subscription, all models. Restore Purchases. **No free trial. No sample draft before paying.** |

Gaps the personas react to: no trial, no quality preview, no social proof, and the price is shown before the user has seen a single draft.

### Price grid per persona (Y = yes, M = maybe, N = no)
| Persona | $4.99 | $9.99 | $14.99 | $29.99 | Ceiling |
|---|---|---|---|---|---|
| Maya | Y | Y | Y | M | ~$25 |
| Dev | Y | Y | M-Y | N | ~$18 |
| Priya | Y | Y | M | N | ~$12 |
| Jordan | Y | M | N | N | ~$8 |
| Tyler | M | N | N | N | ~$5 |

---

## 1. Personas

| | Maya Okafor | Dev Raman | Priya Nair | Jordan Pierce | Tyler Brandt |
|---|---|---|---|---|---|
| Age / job | 29, solo founder of a $3k MRR B2B micro-SaaS (invoice reconciliation) | 34, freelance brand and web consultant, 4 retainer clients | 38, newsletter and podcast host (28k subs), books guests and sponsors | 31, SDR at a 400-person SaaS company | 22, ex-student running a "lead-gen agency" |
| Phone | iPhone 15 Pro (Apple Intelligence) | iPhone 14, 6 GB (no Apple Intelligence) | iPhone 16 (Apple Intelligence) | iPhone 13, ~4 GB | iPhone 15 Pro (Apple Intelligence) |
| Habits | Doomscrolls X and Reddit in 10-minute bursts, 3x a day, hunting "anyone know a tool for X?" posts | Works LinkedIn and X on the train and between calls | Always on Instagram, X, Substack. Heavy email. | Outreach in Sales Navigator and Outreach.io on a laptop. Phone is for texts and TikTok. | Lives in a desktop automation stack and 4 Telegram groups |
| Tech comfort | High | Medium-high | Medium | Medium | High |
| Current outreach | Manual reply-guy: types each reply, 10-15 per day, 2-3 convert to a conversation | Warm DMs from posts, 5-8 per week, copy-pastes from a Notes template | 3-6 guest or sponsor emails and DMs per week | Mandated 60 touches per day through the CRM sequencer | 300-500 scripted DMs per day via browser tools |
| Patience | Medium (wants 20 seconds or less) | Medium-high | Low-medium | Low | Very low |
| Price sensitivity | Low for tools that save time, high for subscriptions | Medium. Bills clients, expenses tools. | Medium-high | High (personal money) | Very high |
| AI skepticism | Moderate: "AI replies sound like AI" | Moderate, practical | Moderate-high (brand voice) | Low skepticism, but company has approved tools only | None, loves AI, wants more of it |
| Attention / notifications | Focus mode on during deep work. Reads lock screen, swipes away often. | Do Not Disturb for client meetings. Taps notifications. | 300+ notifications per day, swipes all. Badge-blind. | Work Focus filters everything non-work | Lives in Telegram, ignores all else |

**Fit scores**
- **Maya, 82%.** Exactly the "reply to a problem post with a pitch" job. She is on the Apple path, which is the best experience. Not 100% because she wants a link-tracking and follow-up record, and a Reddit comment is not a DM.
- **Dev, 76%.** Warm outreach from social posts is the core loop. He loses points for being on the slow path (iPhone 14, no Apple Intelligence) and for needing more polish and brand tone than a 0.5B model delivers.
- **Priya, 55%.** The share-then-reply loop fits her guest and sponsor outreach. But she needs volume, templates and tracking, and her voice is her brand. Email is her main channel and the app's email mode is only a short-reply format.
- **Jordan, 40%.** The workflow is real but his company dictates tools and compliance, and his outreach is on desktop. A personal $15 app for work is a personal expense on a job that does not reward it.
- **Tyler, 20%.** He wants the exact thing the app refuses to do: bulk, scheduled, automated sending. The only overlap is "AI writes DMs".

---

## 2. Part 1: Discovery, onboarding, paywall

### Maya (82%)
**Discovery:** a founder on X posted "I replace my reply-guy routine with an offline app, one-time price". Maya searched the App Store for "reply assistant" and found it. Listing impression: the icon (reply-arrow speech bubble) is clean, but screenshots that show the share sheet matter most to her. If shots showed only a chat UI she would have scrolled on. "One-time purchase" in the subtitle is what made her tap.

| Screen | Sees | Monologue | Emotion | Decision |
|---|---|---|---|---|
| 1 Value prop | "No account, no subscription" | "Finally someone not charging me $20/mo to rewrite a tweet." | Interested | Continue |
| 2 Share sheet | 3-step diagram | "Cool, but does it work with Reddit and LinkedIn, not just X?" | Mild doubt | Continue |
| 3 Topic | Name, pitch, link | "I'll paste my one-liner. Wait, will it write like a bot?" | Focused | Continue |
| 4 Engine | "Apple Intelligence detected" | "No download. Good. Is Apple's model good enough at sales copy?" | Relief with skepticism | Continue |
| 5 Notifications | Pre-prompt | "I'm on the Apple path, do I need these? Fine, allow." | Neutral | Continue (allows) |
| 6 Paywall | $14.99 one-time, no trial | "I haven't seen one draft. Fifteen bucks is nothing next to one customer, but a preview would've sold me." | Pragmatic, slightly annoyed | **Pays $14.99** |

What would have changed her mind: nothing at $14.99. At $29.99 she hesitates and wants a trial. A sample draft before paywall would move her from 80% to about 90%.

### Dev (76%)
**Discovery:** a friend (another freelancer) forwarded the App Store link in a Slack group: "that offline DM thing". Listing impression: a good icon, but an iPhone 14 owner scanning the description sees "Apple Intelligence" and "model download" and wonders whether it works for him.

| Screen | Sees | Monologue | Emotion | Decision |
|---|---|---|---|---|
| 1 | Value prop | "Offline AI, no keys. Okay, privacy is a plus for client stuff." | Interested | Continue |
| 2 | Share sheet steps | "I'll have to dig through 'More' to find it. Annoying but doable." | Neutral | Continue |
| 3 | Topic | "I sell services, not a product. Do I make a topic per service?" | Slight confusion | Continue |
| 4 | Engine: no Apple Intelligence, pick a model | "Download 395 MB on mobile? Lemme wait for Wi-Fi. 'Slower generation' is code for 'worse'. Hmm." | Worried | Hesitate |
| 5 | Notifications | "The reply arrives as a notification? So I share, wait, then tap? That's not a 'share and done' flow." | Doubt | Continue, grudgingly |
| 6 | Paywall | "I'm paying before I know whether a 0.5B model can write anything not embarrassing." | Skeptical | **Pays $14.99 after 3 minutes of thought** (M-Y). Would pay $9.99 without thinking. |

What would change his mind: a trial or a 14-day refund promise; a "good enough" sample from the 0.5B model.

### Priya (55%)
**Discovery:** a newsletter peer mentioned it in a Substack note. Listing impression: "Looks like a DM tool for sales people, not for a creator." She almost did not install.

| Screen | Sees | Monologue | Emotion | Decision |
|---|---|---|---|---|
| 1 | Value prop | "Reply to the right post... I mostly email guests." | Lukewarm | Continue |
| 2 | Share sheet | "I use the share sheet all the time, fine." | Neutral | Continue |
| 3 | Topic | "Topic = my podcast pitch. Okay, that's easy." | Fine | Continue |
| 4 | Apple Intelligence detected | "Nice, no download." | Relief | Continue |
| 5 | Notifications | "More notifications. No." Taps Don't Allow. | Irritated | Continue (denies) |
| 6 | Paywall | "Fifteen dollars for a draft writer when ChatGPT is free in my pocket?" | Doubtful | **Hesitates; pays on a launch discount of $9.99 (Y), $14.99 is M** |

What would change her mind: seeing her own voice reflected in a sample; batch mode for multiple guests; a template library.

### Jordan (40%)
**Discovery:** a TikTok clip "AI DMs on your phone, no subscription" that a colleague sent. Listing impression: "Looks like a toy next to Sales Navigator."

| Screen | Sees | Monologue | Emotion | Decision |
|---|---|---|---|---|
| 1 | Value prop | "Cool, but my VP will never let me DM prospects off-platform." | Amused | Continue |
| 2 | Share sheet | "I don't work from my phone." | Disengaged | Continue |
| 3 | Topic | "What's my product? Our company name? This isn't my pitch, it's the company's approved one." | Friction | Hesitate |
| 4 | Engine: iPhone 13, download | "395 MB for something that might take 30 seconds a draft." | Annoyed | Hesitate |
| 5 | Notifications | Work Focus will hide them anyway. | Indifferent | Allow |
| 6 | Paywall | "I'm not paying $15 for a hobby app in a job that gives me a CRM." | Dismissive | **Bails at $14.99. Would pay $4.99 as an impulse, $9.99 is M** |

### Tyler (20%)
**Discovery:** App Store search "dm automation instagram twitter" surfaced it in the long tail. Listing impression: "Where's the scheduler?"

| Screen | Sees | Monologue | Emotion | Decision |
|---|---|---|---|---|
| 1 | Value prop | "Manual sending... lol." | Mocking | Continue (curious) |
| 2 | Share sheet | "One post at a time? I do 400 a day." | Disappointed | Hesitate |
| 3 | Topic | Skips. | Bored | Continue |
| 4 | Engine | Apple Intelligence detected | Neutral | Continue |
| 5 | Notifications | Deny. | Bored | Continue |
| 6 | Paywall | "No bulk, no automation, no trial. Next." | Dismissive | **Bails.** Would pay $4.99 "to see". |

---

## 3. Part 2: Post-install life

### Maya (paid, retained)
| Day | What happens |
|---|---|
| 0 | Sets up the topic during onboarding. Opens X, shares a "tool for invoice matching?" thread. Share sheet reads the thread, drafts in about 6 seconds. **Draft pitches "ColdFlow"** (Gap A) because the product is hard-coded. She thinks it is a bug, edits, and files feedback. Or, if fixed, the draft is serviceable but a bit "salesy". She taps "Less salesy" and gets a better one. Copy & close, returns to X, pastes. Total 25 seconds. Feels: pleased, mild irritation. |
| 1 | Uses it 6 times. The share-sheet position is down in "More"; she pins it. Each time she must switch back to X manually (the sheet cannot open other apps), which costs 3 seconds. |
| 3 | Habit forming. 8-10 uses per day. Notices she edits ~40% of drafts. Reddit replies come out too long. Likes that it stays offline. |
| 7 | Gets her first conversation from a draft she barely edited. She tweets about it. This is the stickiness moment. |
| 14 | Wants: a saved history to find who she replied to, a short "here's my link" toggle, and per-platform length. Sees the Chats list but it is not a CRM. Annoyed, not leaving. |
| 30 | 8 uses per week steady. Recommends to two indie friends. |
| 90 | Still active. Wants Apple Intelligence quality improvements via iOS updates; the app benefits automatically. Would pay for a "pro" add-on (history sync or analytics). |

Notification: not used for her (Apple path), so no notification fatigue. If she were on the GGUF path she would swipe it away half the time. Refund: no (3%). Recommends to: other indie hackers and bootstrapped founders, via X replies.
**Single reason she stays:** it removes 80% of the typing from a habit she already has. **Churn day:** retained.

### Dev (paid at $14.99, slower path)
| Day | What happens |
|---|---|
| 0 | Pays on Wi-Fi at home. Downloads Qwen 2.5 0.5B (395 MB, about a minute). Shares a LinkedIn post. Handed off: "Tap the notification." Waits. Notification arrives after about 8 seconds. Taps it. Opens the app. A draft appears. It is generic ("Hi, I saw your post about X and thought you might like..."). He winces. |
| 1 | Tries Gemma 3 1B (772 MB). Draft is better but takes 20-25 seconds on his iPhone 14. Impatient. Shares 3 posts and gets 3 notifications; one gets swept by DND, so he forgets the draft for an hour. |
| 3 | Uses it 4 times. The flow share, notification, tap, wait, copy, switch back to LinkedIn is **7 steps**. He realises it is slower than his Notes template for easy cases. |
| 7 | Uses it for tough cases only (first contact with a cold lead). Sends 2 DMs. One reply. Feels the tool is "ok". |
| 14 | A client project eats his week. Zero uses. |
| 30 | Opens twice. Tries Qwen 3.5 2B (1.4 GB), better but slow. Considers a refund; the 14-day window has passed. |
| 90 | Rarely. Maybe 1 use per 2 weeks. |

Notification handling: taps when in focus; DND hides it; he sometimes loses the thread of what the draft was for. Refund: 12% (would ask at day 3 if frustration peaked). Recommends to: freelancers who have a recent iPhone (15 Pro+) only. Tells friends "great if you've got a new iPhone".
**Single reason he drops:** the slow path's 7-step flow and mediocre small-model drafts do not beat his template. **Churn day:** about day 75 (effectively dormant from day 14; active-use churn at ~day 45).

### Priya (paid at $14.99, 35% case; notifications denied, Apple path)
| Day | What happens |
|---|---|
| 0 | Shares a guest-candidate's tweet. Draft is short and punchy. She wants a warm tone for a podcast invite. Switches to "Email reply". Draft is 3-5 sentences, generic. Edits heavily. |
| 1 | Uses it 2 times. Voice mismatch bothers her; she says "this sounds like everyone." |
| 3 | 3 uses. She likes the thread-aware context ("it read the whole thread") more than the prose. |
| 7 | 2 uses. Wishes for saved topics per show, and a template library for sponsors. |
| 14 | 1 use. Tries bulk-ish: wants to draft 10 sponsor emails at once. Cannot. |
| 30 | Zero. ChatGPT with her custom instructions does more. |
| 90 | Deleted the app during a storage clean. |

Notification: denied, so the Apple path does not matter. If she were on the GGUF path she would have missed everything. Refund: 12%. Recommends: nobody; would say "fine for sales people".
**Single reason she drops:** her work is voice and volume, not speed on one reply. **Churn day:** about day 21.

### Jordan, "what if he'd paid anyway" (say $14.99 or $4.99)
- Day 0: GGUF path on an iPhone 13. Qwen 2.5 0.5B draft in 5 seconds, generic. Day 1: tries Gemma 3 1B; 30 seconds wait; Focus mode hides the notification; draft forgotten.
- Day 3: one use on a LinkedIn post of a prospect, but his company's policy discourages personal tools with prospect data. Day 7: none.
- Day 14 onward: uninstalled. Refund: 25% (asks at day 5). Recommends: nobody.
- Single reason: the job is done elsewhere and mandated. **Churn day:** about day 7.

### Tyler, "what if he'd paid anyway" ($4.99)
- Day 0: tries five shares, finds "one at a time", asks for refund within hours. Day 1: refund requested (40%). Gives a 2-star review: "No bulk, no automation, useless for scale".
- **Churn day:** day 1. Recommends: warns others off. The review is the main cost.

---

## 4. Part 3: Numbers

### 4.1 Per-persona economics (all GUESSES, stated assumptions)
Assumptions: price $14.99, Apple small-business cut 15% so net $12.74. "Referral value" is expected extra paying users caused, times $12.74 (guess). Refund rate is the conditional chance a buyer refunds (guess). LTV (one-time) = 12.74 x (1 - refund) + referral value.

| Persona | P(buy @ $14.99) | Uses/wk steady | Active life (months) | Refund | Referral value | LTV (one-time), per buyer | Expected per install-visit (P x LTV) |
|---|---|---|---|---|---|---|---|
| Maya | 80% | 10 (peaks 40+) | 14+ (retained) | 3% | 0.6 buyers = $7.64 | $19.96 | $15.97 |
| Dev | 60% | 5 falling to 1 | 6 | 12% | 0.3 buyers = $3.82 | $15.03 | $9.02 |
| Priya | 35% | 3 falling to 0 | 3 | 12% | 0.1 buyers = $1.27 | $12.48 | $4.37 |
| Jordan | 10% | 1 | 1 | 25% | 0 | $9.56 | $0.96 |
| Tyler | 3% | 0 (after day 1) | 0.5 | 40% | 0 (negative review risk) | $7.64 | $0.23 |

### 4.2 Subscription comparison ($3.99/mo or $29.99/yr)
Assumptions: net $3.39/mo or $25.49/yr after 15%. On a subscription, lifetimes are shorter than app-life for low-fit users because cancellation is cheap (guess: x0.7 for medium fit, immediate cancel for low fit). Conversion at paywall would also differ: I assume subscription trial-to-paid roughly 40-60% of what a one-time purchase would get for the low-fit users (guess).

| Persona | Likely plan | Months paying | LTV (sub), per subscriber |
|---|---|---|---|
| Maya | annual | 14 mo (1 renewal at 50%) | $25.49 x 1.5 = **$38.2** (monthly route: 10 x 3.39 = $33.9) |
| Dev | monthly | 3 | **$10.2** |
| Priya | monthly | 2 | **$6.8** |
| Jordan | trial then cancel | 1 | **$0-3.4** |
| Tyler | none | 0 | **$0** |

Reading: a subscription roughly doubles revenue from retained heavy users (Maya) but halves or kills revenue from the medium and low-fit majority, and conflicts with the product's headline claim ("no subscription"). Because inference is on-device and marginal cost is zero, the subscription is not cost-justified, and it would erase the positioning edge. **Keep one-time as the base.** Possibly add an optional later "Pro" add-on.

### 4.3 Summary table
| Persona | Fit % | Pays @14.99? | Price ceiling | Churn day | LTV one-time | LTV sub comparison |
|---|---|---|---|---|---|---|
| Maya Okafor (solo founder) | 82 | Yes (80%) | ~$25 | Retained (90+) | $19.96 | $34-38 |
| Dev Raman (freelance consultant, iPhone 14) | 76 | Likely (60%) | ~$18 | ~75 (dormant from ~14) | $15.03 | $10.2 |
| Priya Nair (creator) | 55 | Maybe (35%) | ~$12 | ~21 | $12.48 | $6.8 |
| Jordan Pierce (SDR, iPhone 13) | 40 | No (10%) | ~$8 | ~7 | $9.56 | $0-3.4 |
| Tyler Brandt (bulk automator) | 20 | No (3%) | ~$5 | 1 | $7.64 | $0 |

### 4.4 TAM / SAM / SOM (bottom-up; unverified numbers are marked ESTIMATE)

**Sources used**
- Apple's active installed base passed 2.5 billion devices (Apple fiscal Q1 2026 report, via secondary coverage, [Cult of Mac](https://www.cultofmac.com/?p=923303), [Apple Magazine](https://applemagazine.com/apple-active-devices-2-5-billion/amp/)). That is all Apple devices, not iPhones only. Apple does not publish an iPhone-only active count. I did not verify against Apple's primary release.
- Counterpoint estimate: about 1 in 4 active smartphones is an iPhone (as relayed by search summary; unverified).
- IDC: about 232 million iPhones shipped in 2024; about 247 million forecast for 2025 ([SQ Magazine](https://sqmagazine.co.uk/how-many-iphones-sold.md)).
- Freelancers: World Bank-style range 154-435 million online freelance and gig workers; US independent workforce about 72.9 million (MBO Partners) ([Jobbers](https://www.jobbers.io/how-many-freelancers-are-there-in-the-world-2026-statistics-page/), [Exploding Topics](https://explodingtopics.com/blog/number-of-freelancers)). Definitions vary wildly; secondary sources.
- **Not found / not verified:** a count of indie hackers or solopreneurs, and the share of iPhones with Apple Intelligence. I used my own estimates and flag them.

**Segments (iPhone-owning people who regularly reply to social posts to sell or pitch)**
| Segment | Persona | Global people (ESTIMATE) | iPhone share (GUESS) | iPhone owners |
|---|---|---|---|---|
| A. Indie hackers and solo founders marketing on social | Maya | 3.0M | 55% | 1.65M |
| B. Freelancers and consultants doing warm social outreach | Dev | 9M (about 3% of a ~300M online-freelance base) | 30% | 2.7M |
| C. Creators and community managers needing guests or sponsors | Priya | 2.5M (5% of a ~50M creator base) | 35% | 0.9M |
| D. Salespeople and SDRs (CRM mandated) | Jordan | 5M outreach-active, iPhone 50% | 50% | 2.5M |
| E. Bulk-automation growth hackers | Tyler | 1M | 40% | 0.4M |

**TAM** (all iPhone owners who do outreach from posts, any style): 1.65 + 2.7 + 0.9 + 2.5 + 0.4 = **about 8.2M people**. At $14.99 that is about $123M gross one-time (theoretical, not meaningful).

**SAM** (iOS 17+, English-first, does outreach from social posts, and the app's design suits them):
- Exclude E (wants automation) entirely; include only 10% of D (those buying personally).
- Filter: iOS 17+ = 90% (GUESS; Apple's iOS 18 adoption figures were in the 80s% in 2025); English-first = 55% (GUESS).
- Combined filter = 0.9 x 0.55 = 0.495.
- A: 1.65M x 0.495 = 0.82M. B: 2.7M x 0.495 = 1.34M. C: 0.9M x 0.495 = 0.45M. D: 0.25M x 0.495 = 0.12M.
- **SAM about 2.7M people**, about $40M one-time gross at $14.99.
- Apple Intelligence-capable devices (iPhone 15 Pro and newer) are perhaps 35-40% of active iPhones by late 2026 (pure GUESS, no source found), so the best experience reaches about a third of SAM; the rest relies on the GGUF path.

**SOM, year 1** (conversion of SAM to paying customers; GUESSES, plausible for an indie app with organic and X-driven marketing, no paid ads):
| Segment | SAM | Yr-1 paid conversion | Buyers | Net revenue per buyer (after 15% fee and refunds) | Net revenue |
|---|---|---|---|---|---|
| A | 0.82M | 0.50% | 4,090 | $12.36 | $50.6K |
| B | 1.34M | 0.20% | 2,670 | $11.21 | $29.9K |
| C | 0.45M | 0.10% | 445 | $11.21 | $5.0K |
| D | 0.12M | 0.05% | 62 | $9.56 | $0.6K |
| **Total** | 2.7M | 0.27% | **about 7,270** | | **about $86K net** |

Range: 0.1x conversion gives about $9K (a failed launch); 3x gives about $250K. Realistic planning number: **$30-90K net in year 1.** This is lifestyle-business revenue, not a venture outcome. Blended LTV per buyer including referrals is about $17 (weighted by segment buyer count); the referral component is a guess and partly already inside the conversion rates, so do not add it on top of the SOM revenue.

LTV per segment (one-time / sub): A $19.96 / $34-38; B $15.03 / $10.2; C $12.48 / $6.8; D $9.56 / $0-3.4.

---

## 5. Findings

### Top 5 reasons people drop off
1. **Slow-path friction.** On non-Apple-Intelligence phones the loop is share, wait, notification, tap, wait, copy, switch back: about 7 steps, and small-model drafts are generic. This is where Dev and Jordan leak.
2. **Paying before seeing a draft.** Hard paywall at $14.99 with no trial and no sample output asks for faith in an AI-quality product, which is the thing users distrust most.
3. **Draft quality and voice.** Small models and even Apple's model sound generic; people who care about their voice (Priya) edit heavily and then go back to ChatGPT.
4. **Missing workflow glue.** No templates, no tracking of who was replied to, no volume tools. It is a point tool, not a system.
5. **Notification fragility.** Focus modes, denial of permission (asked with no explanation today), and notification fatigue break the handoff on the GGUF path. Plus: wrong audience arriving (bulk-automation seekers, CRM-mandated reps) who churn in a day and leave bad reviews.

### Top 5 reasons people stay
1. It replaces typing in a habit the user already has (Maya's reply-guy routine).
2. Offline, private, no account, one-time price. A clear contrast with $20/month AI tools.
3. Thread-aware context: it reads the post and its thread, so replies are anchored in the actual post.
4. A single early win (a real conversation from a draft) in the first week.
5. Quick refinements ("Less salesy", "Empathetic") and "Write another version" give control without prompt-writing.

### Three changes most likely to raise conversion and retention
1. **Show output before the paywall, and offer a soft trial.** Let the user paste a sample post, see a draft with their topic (Apple path: real; GGUF path: after the small download), then paywall. Add 5 free drafts. Expected effect on paywall conversion: large (my guess: +30-50% relative); it is also the one change that addresses the biggest trust gap.
2. **Fix the topic gap and shorten the handoff.** Make the share sheet use the user's own Topic (remove the hard-coded product), remove spike diagnostics, and for the GGUF path try to generate within the extension if memory allows (even the 0.5B), or at least show progress plus a "Copy" shortcut in the notification action. Pre-prompt the notification permission with a reason.
3. **Price and positioning.** Lead with indie hackers and freelancers (A and B) in the listing and screenshots (show the share sheet on Reddit, X, LinkedIn). Launch at $9.99 for the first month to build reviews, settle at $14.99, and consider a later optional "Pro" (history, per-platform length, templates) rather than a subscription. Say plainly in the listing that there is no bulk send, to filter out Tyler-type buyers and avoid bad reviews.

### Candid verdict
There is a real use case, but it is narrow: **solo founders and freelancers on a recent iPhone who already spend time replying to problem posts by hand.** For them it saves real typing time, the price is trivial relative to one closed customer, and the offline/one-time angle is a genuine differentiator. Outside that segment it is weak: salespeople have mandated tools, creators need voice and volume, and automation seekers will hate it by design. The slow GGUF path on older iPhones is the weakest part of the product: it is a download plus a wait plus a notification handoff for a mediocre draft, and it should not be a selling point. Free ChatGPT on a phone is the real competitor, and the app wins only on speed-in-flow (share sheet) and not having to explain context each time. The business is likely a small, healthy, one-person indie income ($30-90K net in year 1 on my assumptions), not a large market. Subscription is a poor fit; a later paid add-on is better.

Caveats: personas are fictional, reactions are my own reasoning, and all conversion, retention, refund and referral figures are guesses. The only externally sourced numbers are the Apple 2.5B active-device figure, IDC shipments, and the freelancer ranges, all via secondary sources and unverified against primaries.
