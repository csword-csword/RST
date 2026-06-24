# Pinpoint Pro — feature menu

Model: **the core app is free** with the pin (rep/set tracking, history, workout
builder, gym profiles, location). **Pinpoint Pro** ($49.99/yr) is an optional
upgrade that adds value *on top* — never cripples what someone bought.

The best Pro features share one trait: **they keep delivering after purchase**
(cloud, AI, content, new platforms). That's what makes an annual fee feel fair
instead of resented. Features below are tagged with that in mind.

Effort: **S** = days · **M** = a week or two · **L** = multi-week / needs backend.
Recurring fit: ★ (nice) → ★★★ (strongly justifies an annual fee).

## Already shipped
- **CSV export** of full history (Settings → Your Data) — Pro.
- **Insights** (Home → Insights) — Pro: personal records, estimated 1RM, weekly
  volume chart, and volume-by-muscle-group (`WorkoutStats` + Swift Charts).
- **Rest timer** between sets (countdown, +15s, skip; default in Settings) — **free**.
- **Voice coach** — Pro: speaks rep counts and "time for your next set," ducking
  your music (`VoiceCoach`, AVSpeechSynthesizer). Toggle in Settings.

### Rep-quality insights
**Shipped** (Insights → Tempo & Form, Pro): average rep time (cadence),
time-under-tension per set, within-set **fatigue** (reps slowing), and **rep /
tempo consistency**. These are computed from per-rep timestamps captured live
(`SetRecord.repOffsets`).

Feasibility by **data path**:
- **Advertisement broadcast (current, ≤10 Hz):** reliable for rep count, set
  detection, rest timing, cadence, TUT, fatigue, and consistency (the shipped
  set). Good for coaching cues and form feedback.
- **NOT reliable from 10 Hz:** true velocity-based-training metrics (mean
  concentric velocity in m/s), range of motion, or power — these need
  double-integration of a high-rate, calibrated stream.
- **To unlock premium rep-quality (velocity/ROM/power):** use the M1Pro's
  **connected high-rate accelerometer** mode (stream or flash-log at 50–100 Hz),
  which requires the connected protocol (already requested) and confirming the
  sensor's max output data rate. Recommend shipping the coarse metrics now and
  gating VBT-style metrics on that confirmation.

## A. Data, backup & sync — ★★★ (strongest recurring justification)
| Feature | What it is | Recurring fit | Effort |
|---|---|---|---|
| Cloud backup & sync | History safe in the cloud, synced across iPhone/iPad; survive phone loss/upgrade | ★★★ | M–L |
| Web dashboard | View/analyze workouts on desktop at pinpoint.fitness | ★★★ | L |
| Apple Health sync | Write workouts/energy to Health; read bodyweight | ★★ | S–M |
| Auto-export / scheduled backup | Periodic CSV/JSON to Files or email | ★★ | S |

## B. Insights & coaching — ★★★ (AI/analysis = ongoing value, and unique to your hardware)
| Feature | What it is | Recurring fit | Effort |
|---|---|---|---|
| Advanced analytics | Volume trends, muscle-group balance, 1RM estimates, progression charts | ★★ | M |
| Rep-quality insights | Rep tempo, time-under-tension, rest analysis from the accelerometer — **no one without your pin can do this** | ★★★ | M |
| AI program builder | Generates/adjusts a plan from your history + goals | ★★★ | L |
| Plateau & deload alerts | Detect stalls, suggest deloads/progression | ★★ | M |
| PRs & milestones | Personal records, streaks, push notifications | ★ | S–M |

## C. Planning & guidance
| Feature | What it is | Recurring fit | Effort |
|---|---|---|---|
| Advanced builder | Supersets, circuits, per-exercise rest timers | ★ | M |
| Guided programs | Curated plans (5×5, PPL, etc.) — ongoing content | ★★ | M (+content) |
| Smart rest timer | Auto rest timer with suggestions between sets | ★ | S |
| Unlimited templates | Free = a few; Pro = unlimited *(soft lever — use cautiously; capping can feel stingy)* | ★ | S |

## D. Social & accountability — ★★ (needs backend; strong retention)
| Feature | What it is | Recurring fit | Effort |
|---|---|---|---|
| Friends & sharing | Follow friends, share workouts | ★★ | L |
| Challenges & leaderboards | Compete on volume/streaks | ★★ | L |
| Coach/trainer sharing | Share history with a trainer; trainer view — **B2B2C on-ramp** | ★★★ | M–L |

## E. Multi-pin / household / multi-gym
| Feature | What it is | Recurring fit | Effort |
|---|---|---|---|
| Multiple pins & profiles | Several pins, family members, per-person history | ★★ | M |
| Auto gym detection | Use location to auto-load the right gym profile | ★ | S–M |
| Custom equipment | Add machines/exercises not in the catalogs | ★ | S |

## F. Platforms & convenience — ★★ (great engagement)
| Feature | What it is | Recurring fit | Effort |
|---|---|---|---|
| Apple Watch app | Start/track sets from the wrist, live reps on watch | ★★ | M–L |
| Widgets & Live Activities | Live set on lock screen / Dynamic Island; home-screen stats | ★ | M |
| Siri & Shortcuts | "Start a Pinpoint workout," automations | ★ | S |

## Recommended starting Pro bundle

Lead with features that (a) deliver ongoing value, (b) lean on your hardware moat,
and (c) are realistic to ship:

1. **Cloud backup & sync** — the anchor; people pay to not lose their data.
2. **Rep-quality insights** (tempo / TUT / rest) — only possible *with your pin*, so it's a true differentiator, not a generic tracker feature.
3. **Advanced analytics + PRs** — visible, satisfying, moderate effort.
4. **CSV/Health export** — already started; cheap to round out.

Then expand toward **AI program builder** and **Apple Watch** as tentpole upgrades,
and explore **coach/trainer sharing** as the bridge to a gym/B2B revenue line.

Keep firmly **free**: rep/set tracking, history, the builder, gym profiles,
location, and basic weekly stats — so the device is always fully useful and your
App Store reviews stay healthy.

> Packaging idea: **bundle year 1 of Pro with each device.** Buyers experience the
> Pro value immediately, and year-2 renewal becomes a real decision instead of a
> cold ask — seeding recurring revenue without a second checkout at point of sale.
