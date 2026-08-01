"""Report which live Claude Code sessions have an armed /loop.

Loop state is session-scoped and lives in the running process, so there is no
built-in way to see another session's loops: CronList only reports the current
session's jobs, and a dynamic (self-paced) loop exposes nothing queryable at
all. This reconstructs the picture from disk instead.

  ~/.claude/sessions/*.json          -- one record per live session (pid, cwd, status)
  ~/.claude/projects/<slug>/<id>.jsonl -- that session's transcript

A loop is armed in one of two ways, and both leave a trail in the transcript:

  dynamic  (/loop with no interval)  -> ScheduleWakeup, disarmed by {"stop": true}
  interval (/loop 20m ...)           -> CronCreate,     disarmed by CronDelete

Replaying those events in order yields the current state. Usage:

  python check-loops.py [--armed-only]
"""

import argparse
import datetime
import glob
import json
import os
import re

HOME = os.path.expanduser("~")
SESSIONS = os.path.join(HOME, ".claude", "sessions")
PROJECTS = os.path.join(HOME, ".claude", "projects")

LOOP_TOOLS = ("ScheduleWakeup", "CronCreate", "CronDelete")

# Session crons are dropped by the harness after this long (stated in the
# CronCreate result text), so an older one is no longer armed regardless of
# whether a CronDelete was ever recorded.
CRON_LIFETIME_DAYS = 7


def now():
    return datetime.datetime.now(datetime.timezone.utc)


def parse_ts(stamp):
    if not stamp:
        return None
    try:
        return datetime.datetime.fromisoformat(stamp.replace("Z", "+00:00"))
    except ValueError:
        return None


def age_hours(stamp):
    when = parse_ts(stamp)
    return None if when is None else (now() - when).total_seconds() / 3600


def scan(path):
    """Walk a transcript once -> (loop events, timestamp of last entry).

    Each event is (timestamp, tool_name, input, job_id). job_id is the id the
    harness assigned a CronCreate, recovered from the matching tool_result so
    that a later CronDelete can be paired to the exact job it cancelled.
    """
    events = []
    pending = {}   # tool_use id -> index into events, awaiting its result
    last_seen = None

    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            if '"timestamp"' not in line:
                continue
            try:
                entry = json.loads(line)
            except ValueError:
                continue
            last_seen = entry.get("timestamp") or last_seen

            content = (entry.get("message") or {}).get("content")
            if not isinstance(content, list):
                continue
            for chunk in content:
                if not isinstance(chunk, dict):
                    continue
                kind = chunk.get("type")
                if kind == "tool_use" and chunk.get("name") in LOOP_TOOLS:
                    events.append([entry.get("timestamp"), chunk["name"],
                                   chunk.get("input") or {}, None])
                    pending[chunk.get("id")] = len(events) - 1
                elif kind == "tool_result" and chunk.get("tool_use_id") in pending:
                    index = pending.pop(chunk["tool_use_id"])
                    found = re.search(r"job ([0-9a-f]{6,})",
                                      json.dumps(chunk.get("content") or ""))
                    if found:
                        events[index][3] = found.group(1)

    return events, last_seen


def verdict(events):
    """Replay loop events -> (armed, kind, description, armed_at, event_input)."""
    wakeup = None   # most recent ScheduleWakeup that was not a stop
    crons = {}      # job id (or cron expr, pre-result) -> (timestamp, input)

    for stamp, name, data, job_id in events:
        if name == "ScheduleWakeup":
            wakeup = None if data.get("stop") else (stamp, data)
        elif name == "CronCreate":
            crons[job_id or data.get("cron", "?")] = (stamp, data)
        elif name == "CronDelete":
            target = data.get("id")
            if target in crons:
                crons.pop(target)
            else:
                # Pre-result or unknown id: fall back to clearing everything
                # rather than reporting a cancelled job as still armed.
                crons.clear()

    # Drop crons the harness will have expired on its own.
    for key in [k for k, (stamp, _) in crons.items()
                if (age_hours(stamp) or 0) > CRON_LIFETIME_DAYS * 24]:
        crons.pop(key)

    if wakeup:
        stamp, data = wakeup
        return (True, "dynamic",
                "every %ss: %s" % (data.get("delaySeconds"),
                                   summarize(data.get("prompt"))),
                stamp, data)
    if crons:
        stamp, data = sorted(crons.values())[-1]
        return (True, "cron",
                "%s: %s" % (data.get("cron", "?"), summarize(data.get("prompt"))),
                stamp, data)
    return False, None, "no armed loop", None, None


def summarize(prompt, width=64):
    text = " ".join((prompt or "").split())
    return text if len(text) <= width else text[:width - 1] + "…"


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--armed-only", action="store_true",
                        help="hide sessions with no armed loop")
    options = parser.parse_args()

    records = sorted(glob.glob(os.path.join(SESSIONS, "*.json")))
    if not records:
        print("No live Claude Code sessions found.")
        return

    armed_count = 0
    for record in records:
        try:
            with open(record, encoding="utf-8") as handle:
                session = json.load(handle)
        except (ValueError, OSError):
            continue

        session_id = session.get("sessionId")
        label = "%-24s %-5s pid %-6s %s" % (
            session.get("name", "?"), session.get("status", "?"),
            session.get("pid"), session.get("cwd"))

        matches = (glob.glob(os.path.join(PROJECTS, "*", "%s.jsonl" % session_id))
                   if session_id else [])
        if not matches:
            if not options.armed_only:
                print("  ?   %s  (no transcript)" % label)
            continue

        events, last_seen = scan(matches[0])
        armed, kind, description, armed_at, data = verdict(events)
        if not armed:
            if not options.armed_only:
                print("  -   %s" % label)
            continue

        armed_count += 1
        print("ARMED %s" % label)

        # Liveness differs by kind. A dynamic loop re-arms every iteration, so a
        # wakeup far past its own delay means it was interrupted. A recurring
        # cron is armed once and legitimately stays old, so judge it by whether
        # the session is still producing transcript entries.
        idle = age_hours(last_seen)
        note = "" if idle is None else "  |  last activity %s ago" % duration(idle)
        if kind == "dynamic":
            elapsed = age_hours(armed_at)
            delay = (data.get("delaySeconds") or 0) / 3600.0
            if elapsed is not None and delay and elapsed > delay * 3:
                note += "  <-- STALE: wakeup overdue, loop likely interrupted"
        elif idle is not None and idle > 1:
            note += "  <-- cron may be idle or interrupted"

        print("        %s %s  [armed %s]%s" % (kind, description, armed_at, note))

    print("\n%d armed loop%s across %d live session%s."
          % (armed_count, "" if armed_count == 1 else "s",
             len(records), "" if len(records) == 1 else "s"))


def duration(hours):
    if hours < 1:
        return "%dm" % round(hours * 60)
    if hours < 48:
        return "%.1fh" % hours
    return "%.1fd" % (hours / 24)


if __name__ == "__main__":
    main()
