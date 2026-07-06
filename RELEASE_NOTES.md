## v1.7.0-beta.9 (build 40) — 2026-06-28

This is a **beta** release, for testing new changes before they ship to everyone. To receive beta updates, turn on **Include beta versions** in Preferences › General.

### Highlights
- **Per-user volumes stay where you put them.** The volume, balance and pan you set for individual people no longer bleed across servers — or onto someone else who happens to share the same login.
- **You decide what gets remembered.** A new setting lets you keep per-user volumes forever, only for the current session, or not at all.

### What's new

**Per-user volumes are now tied to the server.** Some people noticed users showing up at odd volumes — loud or quiet — without ever having touched them. The cause: a level you'd set for one account name was being reused for anyone with that same name, including on completely different servers. (Public servers often share generic logins like `guest`.) Volumes, stereo balance and pan are now scoped to the server they were set on, so a level you set on one server stays there.

**Choose how per-user volumes are remembered.** Preferences › Audio has a new **Per-user volume memory** setting with three options:

- **Off** — nothing is remembered; reconnecting puts everyone back to 50%, like the official client.
- **This session only** — your adjustments last while the app is open, then reset when you quit.
- **Always** (default) — adjustments are remembered across launches, per server.

You can switch modes anytime and it takes effect right away.

### Worth knowing
Because of the fix above, any per-user volumes you had saved are cleared once on this update and start fresh at 50% — those old values were exactly the cross-server data being cleaned up. You'll just need to re-set the few users you care about.

## Install

If you have beta updates enabled, tt-Accessible will install this update for you — no action needed.

Manual install:

1. Download `ttaccessible-1.7.0-beta.9-40.zip` below.
2. Unzip and drag `ttaccessible.app` into your `/Applications` folder, replacing the previous version.
3. Double-click — no Gatekeeper warning thanks to notarization.
