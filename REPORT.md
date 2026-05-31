<!--
©AngelaMos | 2026
report.md
-->

# getcracked.io — Reddit Ad & Content Playbook

**A data-grounded teardown of what language, hooks, and formats actually win in the quant / quant-adjacent corner of Reddit — and how to turn that into ads and short-form content that won't get downvoted into oblivion.**

---

## 0. Methodology & honest caveats (read this first)

**What was pulled.** A one-time research scrape of **11 live subreddits** (12 targeted; `r/QuantFinanceJobs` does not exist — old.reddit 302-redirects it to subreddit search, so it was skipped per spec). For each sub: **top posts of the past year** (paginated to the API ceiling, ~500–670 each for the big subs) **plus top of the past month**. For the top ~30 posts by score in each sub, the **top ~15 comments** were also pulled.

| Metric | Value |
|---|---|
| Posts captured | **6,467** |
| Comment threads dived | **328** |
| Individual comments analyzed | **4,576** |
| Subreddits | FPGA, algotrading, cpp, cpp_questions, csMajors, cscareerquestions, financialcareers, leetcode, quant, quant_hft, quantfinance |
| HTTP requests | 420 (2 throttled give-ups, ~0.5% loss) |

**How it was pulled (matters for trust).** Reddit now hard-blocks the unauthenticated `.json` API at the CDN edge — every variant returned a 403 bot-wall regardless of User-Agent. The working path was **old.reddit.com HTML**, which still serves each post with all structured fields in `data-*` attributes (score, comment count, type, domain, timestamp) plus an `after=` pagination cursor. Requests were throttled (2.5s + jitter) with exponential backoff on 429s. We tripped the rate limit exactly once mid-run; the scraper backed off and recovered automatically.

**Caveats — don't over-read the data:**
- **No `upvote_ratio`.** The old.reddit HTML listing does not expose it reliably. That CSV column exists but is intentionally blank. Score + comment count are solid; ratio is not available without the (blocked) API or per-post hits.
- **"Top of year" is the *top* slice, not a random sample.** For the large subs we captured the highest-scoring 500–670 posts. That's exactly what we want for "what performs," but it means medians here are medians *of already-popular posts*, not of the whole sub.
- **Score scale is wildly different per sub.** `r/cscareerquestions` median (of its top posts) is 506; `r/quant_hft` is 3. A "viral" quant_hft post would be a rounding error in csMajors. **Always read performance *within* a sub, not across subs.**
- **The mass CS subs (csMajors, cscareerquestions, leetcode) dominate raw scores** and tell us about *format and emotion*. The **niche quant subs (quant, quantfinance, quant_hft, cpp)** are smaller but tell us about *specific topics, firms, and objections* for getcracked's actual buyer. The playbook below weights them accordingly.
- **Title-shape clusters overlap.** One title can be a confession *and* a rant (e.g. "I GOT THE JOB!! F*** MY OLD MANAGER!!!"). Counts are not mutually exclusive.

Raw data: `/data/all_posts.json`, `/data/all_comments.json`, per-sub files in `/data/raw/`, machine-readable rollup in `/data/analysis.json`, flat table in `/data/posts.csv`.

---

## 1. Title patterns — which shapes overperform

Each of the 6,467 titles was classified (regex-based) into one or more shape clusters. Below: count, median score across the dataset, top real examples, and per-sub overperformance (cluster median ÷ that sub's overall median; **>1.0 means the shape beats the sub's baseline**).

### Ranked by median score

| Shape | n | Median score | One-line read |
|---|---|---|---|
| **Screenshot / image-bait** | 960 | **276.5** | The single biggest lever. A picture (chat screenshot, meme, offer letter, chart) crushes text everywhere. |
| **Confession / "I got the offer"** | 161 | **254** | Emotional win/loss stories. Huge in the niche subs. |
| **Numbered list / data drop** | 133 | **235** | "4 years at big tech…", "40% of layoffs were…", "3000 LeetCodes". Concrete number in the title. |
| **Outrage / rant** | 138 | **175.5** | "FUCK LEETCODE…", "hiring is the most broken I've ever seen". Caps + profanity travel. |
| **Comp / salary** | 178 | **93** | A dollar figure or "TC" in the title. |
| **Identity flex** | 115 | **64** | "I work in prop trading and…", "As a hiring manager…". Credibility hook. |
| **Help / desperation** | 249 | **64** | "Rejected after 4 rounds", "I think I'm done". |
| **"Is X worth it"** | 49 | **61** | "Is LC even still worth grinding?", "Beware of ALL quant courses." |
| **Comparison / vs** | 337 | **48** | "Finance bro vs Tech bro", "FPGA vs CPU". |
| **Advice / guide** | 346 | **45** | "A Straightforward Guide to…", "How I stopped forgetting LC solutions". |
| **Plain question** | 2,369 | **57** | The *default* shape (and the most common). Note the low median: asking a question is table-stakes, not a standout. |

### The 5 best real examples per top cluster

**Screenshot / image-bait** (median 276.5)
- "The kids are… not alright" — **5,903** (csMajors)
- "Cursor is now free for students" — **5,549** (csMajors)
- "What do we think guys?" — **5,492** (csMajors)
- "lazy guide from unemployed to employed in CS" — **4,595** (csMajors)
- "My job search" — **4,414** (csMajors)

**Confession / "I got the offer"** (median 254)
- "Can't stop tearing up, got my first FAANG offer from Apple" — **5,749** (csMajors)
- "I GOT THE JOB!! F*** MY OLD MANAGER!!!" — **2,288** (cscareerquestions)
- "I got a SWE job at Google with outstanding interview performance and wanna help people do the same - AMA" — **2,255** (leetcode)
- "Got dumped by GF of 4 years but got a Meta offer today" — **4,484** (leetcode)
- "Nevermind I got the job" — **2,024** (csMajors)

**Numbered list / data drop** (median 235)
- "4 years at Big tech. Being likeable beats being productive every single time" — **4,990** (cscareerquestions)
- "Graduated top 10 CS, ~4k apps, 700+ LC, no offers. Parents kicking me out. I think I'm done." — **2,453** (csMajors)
- "40% of Amazon's recent layoffs were engineers" — **1,467** (cscareerquestions)
- "3000 LEETCODES let's GO we are in the end game now" — **1,419** (leetcode)
- "2025 New Grad Job Search (USA)" — **1,415** (csMajors)

**Outrage / rant** (median 175.5)
- "Hiring manager perspective: hiring is the most broken I've ever seen" — **1,892** (cscareerquestions)
- "FUCK LEETCODE FUCK LINKEDIN & FUCK THESE JOB FAIRS" — **1,870** (csMajors)
- "[Rant] Rejected in 15 minutes by CEO after 4 rounds and days of work" — **1,569** (cscareerquestions)
- "DO NOT FALL FOR THE INTERVIEW CODER SCAM" — **1,421** (leetcode)
- "Beware of ALL quant courses. None of them are worth even a penny." — **336** (quant)

### Which shapes overperform *per subreddit* (the actionable part)

> Numbers are cluster-median ÷ sub-median. Bold = the format to lead with in that sub.

| Subreddit | Biggest overperforming shapes (multiplier) |
|---|---|
| **r/quant** | **Numbered list/data 3.83×**, screenshot **3.14×**, rant 1.74×, comp 1.21× |
| **r/quantfinance** | **Numbered list 2.94×**, confession **2.17×**, screenshot 1.97× |
| **r/quant_hft** | **Screenshot 9.67×** (!), comp **5.17×**, "worth it" 2.33× (tiny n — treat as directional) |
| **r/cpp** | **Rant 1.96×**, screenshot **2.75×**, confession 1.23×, identity 1.23× |
| **r/cpp_questions** | "Worth it" 2.06×, identity 1.47×, comparison 1.18× (this is a *help* sub — flexes underperform) |
| **r/csMajors** | Comp 1.40×, screenshot 1.39×, confession 1.12× |
| **r/cscareerquestions** | Screenshot 2.09×, numbered list 1.42×, rant 1.13×, comp 1.10× |
| **r/FPGA** | **Confession 2.66×**, screenshot **2.68×**, rant 1.53×, identity 1.50× |
| **r/algotrading** | Screenshot 2.01×, confession 1.71×, numbered list 1.58× |
| **r/financialcareers** | Screenshot 1.52×, numbered list 1.38×, confession 1.25× |
| **r/leetcode** | Screenshot 1.34×, confession 1.23×, numbered list 1.13× |

**Takeaways:**
1. **Screenshot/image-bait overperforms in literally every sub** — most dramatically in the niche quant subs (quant 3.1×, quant_hft 9.7×, cpp 2.75×). The quant audience is *starved* for visual content; almost everything they post is plain text, so a single well-made image stands out enormously.
2. **Numbered/data-drop titles are the sleeper hit in r/quant and r/quantfinance** (3.8× and 2.9×). These communities reward a concrete number or breakdown over a vague question.
3. **The plain question — the default shape everyone reaches for — is the *worst* performer relative to baseline** in 9 of 11 subs. Don't lead an ad or a post with a generic question.

---

## 2. Hook language — a steal-able phrasing bank

Pulled from recurring n-grams across 6,467 titles and 4,576 comments. Quoted sparingly; mostly the *pattern* is what you steal.

### Recurring title phrasing (counts across all titles)
- **"new grad" (60), "entry level" (29), "first [offer/internship]" (133 uses of "first")** → the audience self-identifies as *early, unproven, trying to break in*. Mirror that.
- **"job market" (48), "right now" (15), "laid off" (37)** → present-tense anxiety; "the market right now" is a live nerve.
- **"Jane Street" (75)** is the single most-named entity in the entire corpus — more than 2× any other firm. **Citadel Securities (13), Optiver, IMC, HRT** trail.
- **"roast my resume / roast my CV" (18 + 13)** → the community *loves* being critiqued publicly. Big content/engagement format.
- **"interview experience" (23), "final round" (14), "OA"** → process-stage language.
- **"modern C++" (25), "learn C++" (23), "compile time" / "std" / "smart pointers"** → in the cpp world, "modern C++" is the in-group shibboleth.
- **"quant trading / quant research / quant dev" (29 / 21 / 21)** → spell out the *role split*; this audience distinguishes QT vs QR vs QD sharply.

### Recurring comment phrasing (what *they* say back)
- Hedged authority: **"pretty sure," "I'm sure," "I've seen," "to be honest," "the reality is"** — Reddit's voice is confident-but-casual, never corporate.
- Reassurance/dunk pairs: **"good luck" (26)** (sincere) vs the savage one-liners that top comment sections ("It's John Leetcode," "0% chance this is real").
- Experience flex: **"X years ago," "10 years," "20 years," "years of experience"** — credibility is measured in years and war stories.
- **"don't need / don't know / don't think"** dominate — the community talks in terms of *debunking* and *correcting*. Ads that "correct a myth" fit the native voice.

### The phrasing formula (paraphrase, don't lift)
> **[Concrete number or stage] + [specific firm/role] + [present-tense market emotion] + [proof-not-promise]**

e.g. the *shape* of "Got the JS first-round, here's exactly what they asked" beats "Want to ace your quant interview?" every time. The first is a peer sharing; the second is an ad — and they can smell an ad.

---

## 3. Pain points & objections — your ad angles and content topics

Mined from the 4,576 comments. Ranked by frequency of mention (with the noisy/macro themes de-weighted by judgment). Each has a representative real comment.

1. **"You can't 'break into' quant — it's not breakable."** The single most demoralizing recurring belief. *"It's not an industry that can be broken into."* (+119, r/quantfinance). **Angle:** reframe from "break in" (which they've been told is impossible/cringe) to "be the candidate they can't reject."

2. **Pedigree gatekeeping / "everyone else started at 15."** *"You're competing with people who've been obsessed with math and probability since high school."* (+97) and *"go find QT/QRs on LinkedIn and look at their educational background"* (+52). **Angle:** structured roadmap as the equalizer for non-Olympiad, non-target-school people

3. **Deep skepticism of paid prep — bordering on hostility.** *"Beware of ALL quant courses. None of them are worth even a penny."* (+336, a top post). And the brutal tell: *"Bonus points if you sell a course on breaking in. Bonus bonus points if you were only an intern."* (+526, r/financialcareers). **This is the #1 thing that gets a product like getcracked called out.** See §6 scammy-flags.

4. **LeetCode fatigue + "is the grind even the right grind?"** *"Is LC even still worth grinding?"* (+343). The quant crowd adds nuance: quant interviews are *not* LeetCode — *"brain teasers, elementary-to-junior MO questions, basic stats & calculus, game theory, gambling strategy"* (+248, r/quant). **Angle:** "LeetCode ≠ quant prep" is a genuinely useful, contrarian, share-worthy message.

5. **Interview anxiety / choking under pressure** — repeatedly cited as the *real* failure cause: *"candidates fail not because they can't solve the problems but because [nerves]."* (+630, r/leetcode). **Angle:** mock-interview reps, timed practice, "train the nerves not just the math."

6. **Comp confusion + cynicism.** Heavy interest in dollar figures (76 "$XXXk"-style mentions in titles, score-weighted 294) but paired with macro-cynicism about layoffs/AI. **Angle:** real, sourced comp data ("here's what a first-year QT at [tier] actually clears") scratches the itch — *if* it's credible and specific.

7. **"It's all luck / connections / RNG."** *"Looks like connections and your school matter now more than ever."* (+663). *"I think if you're one of the lucky ones that make it in…"* (+1,087). **Angle:** make the controllable part feel controllable — "luck favors the prepared rep count."

8. **C++ is intimidating and the bar is "modern C++."** In r/cpp the anxiety is technical: memory, templates, undefined behavior, "modern C++" as the entry bar. **Angle:** a structured C++ roadmap aimed at *quant/HFT-style* C++ (low-latency, not web).

9. **Prep paralysis / "where do I even start?"** Recurrent "roadmap," "where to start," "too much to learn." **Angle:** the *structured* part of getcracked's roadmap is the antidote — lead with "a path," not "a pile of problems."

10. **"Am I too late / too old / did I miss it?"** *"At some point you just start thinking I'm too old to go through this again."* (+408). **Angle:** age/late-start reassurance content (but keep it honest — see §6).

> **Macro themes that show up but are NOT your fight:** AI replacing engineers, mass layoffs, H1B/visa politics, India hiring. These drive the *biggest* raw scores in cscareerquestions but they're macro-doom, not quant-prep. Riding them risks looking like you're exploiting fear. Reference the *mood* (uncertain market) without LARPing as a layoffs account.

---

## 4. Format winners — text vs image vs link vs video, per sub

Median score by post type. (n = sample size; tiny n flagged.)

| Subreddit | Text | Image | Link | Video | Winner |
|---|---|---|---|---|---|
| r/quant | 65.5 (n526) | **237** (n37) | 100 (n63) | 687 (n2 ⚠) | **Image ~3.6× text** |
| r/quantfinance | 31 (n521) | **63** (n96) | 31 (n21) | 37 (n1 ⚠) | **Image 2× text** |
| r/quant_hft | 5.5 (n54) | **29** (n4 ⚠) | 1 (n36) | — | Image (small n) |
| r/cpp | 72 (n244) | — | **78.5** (n328) | — | Link ≈ text (link slightly up) |
| r/cpp_questions | **17** (n647) | — | — | — | Text-only sub (Q&A) |
| r/csMajors | 285 (n421) | **482** (n189) | 472 (n24) | 551 (n4 ⚠) | **Image 1.7× text** |
| r/cscareerquestions | **506** (n634) | 678 (n1 ⚠) | — | — | **Text** (near image-free sub) |
| r/FPGA | 31 (n414) | **102** (n111) | 45 (n80) | 107 (n35) | **Image/Video ~3× text** |
| r/algotrading | 38 (n445) | **90.5** (n106) | 74 (n99) | 170 (n6 ⚠) | **Image 2.4× text** |
| r/financialcareers | 84 (n513) | **135** (n100) | 137 (n33) | 168 (n1 ⚠) | **Image/Link ~1.6× text** |
| r/leetcode | 242 (n345) | **424.5** (n302) | 411 (n17) | 896 (n7 ⚠) | **Image 1.75× text** (video huge but tiny n) |

**Global:** image median **278.5** (n946) vs text **60** (n4,764) — **images out-score text ~4.6× across the board.** Links 77, video 193.5 (n only 56).

**What this means for getcracked:**
- **A bold image post / image ad is the right native format almost everywhere** — *except* r/cscareerquestions and r/cpp_questions, which are essentially text-discussion subs (an image ad there reads as foreign and will get flagged).
- **r/cpp:** lead with a **link** (to a genuinely useful resource/tool) — that's the native winning format, not an image meme.
- **The quant subs reward images disproportionately** precisely *because* almost nobody posts them. A clean, smart, non-salesy infographic in r/quant is a structural arbitrage.
---

## 5. Topic heatmap — what recurs in high-scoring content (ranked)

Score-weighted mentions across titles + snippets (a mention in a 2,000-score post counts more than in a 5-score post).

### Firms (the names that move) — score-weighted
1. **Jane Street — 208** (runaway #1, the aspirational brand)
2. Citadel / Citadel Securities — 80
3. HRT (Hudson River Trading) — 39 (+ "Hudson River" 6)
4. Optiver — 33
5. Virtu — 30
6. Jump Trading — 25
7. IMC — 23
8. SIG — 14
9. Two Sigma — 9 · QRT — 8 · RenTec/Renaissance — 8 · Tower — 6 · DRW — 4 · Millennium — 4 · Akuna — 3 · DE Shaw — 3 · Point72, Five Rings, Old Mission, Headlands, G-Research — 1–5

> **Implication:** Jane Street is the gravitational center of quant aspiration on Reddit. It belongs in hooks more than any other firm. Citadel Securities is the clear #2. The long tail (Optiver/IMC/HRT/Jump/Virtu) is recognized and credible — name 2–3 to signal you actually know the landscape.

### Languages — score-weighted
1. **C++ — 783** (utterly dominant; "modern C++" is the phrase)
2. FPGA/Verilog/VHDL — 388 / 48 / 16 (the HFT-hardware niche)
3. Python — 58
4. Rust — 52 (rising challenger; appears in "C++ vs Rust" debates)

> C++ is *the* language of this audience. getcracked's "C++/quant roadmap" selling point is dead-on. Python is secondary; Rust is a debate-bait topic, not a core need.

### Concepts / experiences — score-weighted
1. **LeetCode — 822** (most-discussed concept, mostly with fatigue/skepticism)
2. internship — 444 · new grad — 299
3. HFT — 105 · PhD — 92
4. backtest — 75 (algotrading) · OA (online assessment) — 60 · options — 55 · ML — 46 · system design — 45
5. quant dev — 36 · quant research — 35 · referral — 24 · alpha/signal — ~21 each
6. **Brain teasers / probability / mental math / expected value** — individually small in *titles* but the dominant theme inside quant interview *comments* (the +248 "what they actually ask" comment maps it exactly).

### Comp signals
- 76 title mentions of "$XXXk"-pattern, 56 "$"-figures, 52 "XXXk", plus "TC"/"total comp" — score-weighted ~700 combined. **Comp numbers are catnip**, but skepticism is high; only specific, sourced figures land.

---

## 6. Ad & content recommendations (grounded, with the scammy-flags)

### 10 ad headline concepts (each tied to the insight it's built on)

1. **"LeetCode isn't quant prep. Here's what Jane Street actually asks."**
   *Based on:* §3 pain #4 + the +248 r/quant "what they ask" comment + Jane Street as #1 firm. Contrarian, useful, names the brand they care about.
2. **"You don't 'break into' quant. You become un-rejectable. Here's the rep plan."**
   *Based on:* §3 pain #1 (the "can't break in" belief). Reframes the cringe phrase the community mocks.
3. **"Brain teasers, mental math, probability, game theory — the 4 buckets every quant round tests."**
   *Based on:* numbered/data-drop shape overperforms 3.8× in r/quant (§1) + the interview-content comment map (§5).
4. **"Didn't do IMO. Didn't go to a target school. Here's the structured path anyway."**
   *Based on:* §3 pain #2 (pedigree gatekeeping) — speaks to the majority who feel locked out.
5. **"Modern C++ for HFT, not web. Low-latency from day one."**
   *Based on:* C++ = 783 score-weight, "modern C++" shibboleth, cpp rant-shape overperforms (§1, §5).
6. **"Real questions from people who actually sat the Citadel/Optiver/IMC rounds."**
   *Based on:* the product's core differentiator + firm heatmap; "interview experience" is a recurring hook phrase.
7. **"Most candidates don't fail the math. They fail the nerves. Train both."**
   *Based on:* §3 pain #5 (+630 comment), interview-anxiety theme.
8. **"What a first-year QT actually clears — sourced, not vibes."**
   *Based on:* comp-signal demand (§5) + comp-shape overperformance (quant 1.2×, quant_hft 5.2×) — but lead with *credibility*.
9. **"Roast my quant prep: post your gaps, get a plan."**
   *Based on:* "roast my resume/CV" is a top recurring engagement hook (31 mentions) — invert it into an interactive ad.
10. **"3,000 LeetCodes and still no quant offer? You grinded the wrong thing."**
    *Based on:* the "3000 LEETCODES" viral post (1,419) + LeetCode-fatigue pain; speaks to the over-grinder directly.


### What gets you called out as scammy (the landmines)

The data is blunt about what this audience punishes. **Avoid all of these:**

- **Selling "break into quant" as a promise.** The exact mockery exists: *"Bonus points if you sell a course on breaking in. Bonus bonus points if you were only an intern."* (+526) and *"Beware of ALL quant courses, none worth a penny"* (+336, top post). → Sell **reps, structure, and real questions**, never a guaranteed outcome.
- **Fake-native ads.** Image ads in *text-discussion* subs (r/cscareerquestions, r/cpp_questions) read as foreign instantly. Match the sub's native format (§4).
- **Generic-question hooks** ("Want to ace your quant interview?"). The plain-question shape *underperforms* in 9/11 subs (§1) and reads as ad-copy.
- **Vibes-based comp claims.** Unsourced "$500k TC!!" gets torn apart. Cite tier/role/year.
- **Pedigree-erasure promises.** Don't claim a course makes pedigree irrelevant — they *will* link you to LinkedIn profiles proving otherwise (+52 comment). Position as "control the controllables."
- **Exploiting layoff/AI/visa doom** for clicks. Highest-scoring macro topics, but riding them as a prep brand looks predatory (§3 note).
- **Over-polished corporate voice.** The native register is hedged, casual, profane, peer-to-peer ("pretty sure," "ngl," "to be honest"). A glossy brand voice flags as outsider.

**The safe posture:** show up as a *peer who has receipts* (real questions, real reps, real numbers), agree with the valid half of their cynicism, and never promise the outcome — promise the preparation.

---

## TL;DR for the media buyer

- **Format:** lead with a clean, smart **image** everywhere except cscareerquestions/cpp_questions (text) and cpp (link). Images out-score text ~4.6×, and the quant subs reward them most because nobody posts them.
- **Shape:** **numbered/data-drop** and **screenshot-bait** in quant/quantfinance; **confession** stories in FPGA/algo/finance; **rants** in cpp. Never lead with a plain question.
- **Hook vocabulary:** "new grad," "first offer," "the market right now," "Jane Street," "modern C++," "what they actually ask," "roast my…".
- **Angle:** "LeetCode ≠ quant" + "structured path for non-pedigree people" + "real questions from people who sat the round." Comp data and brain-teaser-of-the-day as recurring content.
