<!-- ©AngelaMos | 2026 -->
<!-- README.md -->

<div align="center">
  <h1 align="center">erhm☝️🤓 Downvoted👎</h1>
  <img width="260" height="260" alt="Kali-dragon-icon svg" src="https://i.pinimg.com/1200x/bc/e8/41/bce841a5a922e5e6d8b7476f95bebffa.jpg" alt="erhm"/>
</div>


## Quickstart

Install — one line (clones + builds; needs zig 0.16 & git):

```sh
curl -fsSL https://angelamos.com/erhm/install.sh | bash
```

Or from a local clone:

```sh
./install.sh
```

Or with `just`:

```sh
just build      # debug build
just static     # one static musl binary, zero deps
just scrape     # scrape the default subreddits into ./data
just analyze    # crunch ./data into analysis.json + posts.csv
```

Or drive it directly:

```sh
zig build run -- scrape --subs quant,cpp,fpga --max 500 --top-comments 30
zig build run -- analyze --data data
```

## Flags

```
scrape  --subs a,b,c        comma-separated subreddits
        --max N             posts/sub from top/year      (default 500)
        --month-max N       posts/sub from top/month     (default 200)
        --top-comments N    top posts that get a comment dive (default 30)
        --per-comments N    top comments kept per post   (default 15)
        --data DIR          output directory             (default data)
        --base-ms N         throttle floor in ms         (default 2500)
        --jitter-ms N       random extra throttle in ms  (default 1500)

analyze --data DIR
```

## Output

```
data/
  raw/<sub>_posts.json       per-sub posts
  raw/<sub>_comments.json    per-sub comment threads
  all_posts.json             everything, merged + deduped
  all_comments.json
  scrape_status.json         run stats
  analysis.json              clusters, n-grams, pain points, topic heatmap
  posts.csv                  flat table for spreadsheets
```

## How it works

It scrapes `old.reddit.com` HTML — the stable, server-rendered surface with `data-*` attributes — rather than the official API, which now largely rejects unauthenticated traffic. A polite throttle, jitter, and exponential backoff on `403/429/5xx` keep it under Reddit's rate limits. The HTML is parsed by a purpose-built attribute scanner (no regex engine, no DOM library), and the analyzer reduces it all with hash-map counters and keyword sets.

```
src/
  main.zig     CLI dispatch
  cli.zig      config, argument parsing, timestamped logger
  http.zig     throttled fetcher with retry/backoff
  parse.zig    hand-rolled old.reddit HTML scanner
  scrape.zig   pagination, dedup, year+month merge, comment dives, crash-safe saves
  analyze.zig  title-shape clusters, n-grams, pain themes, format winners, heatmap
  model.zig    Post / Comment / CommentThread
```

## License

AGPL 3.0
