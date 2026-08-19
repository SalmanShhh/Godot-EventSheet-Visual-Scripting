"""Resolve conflicted translation CSVs by taking BOTH sides, with a real CSV parser.

Rebuilds each file from stage 2 (ours) followed by every stage-3 (theirs) row ours lacks.
Values are multi-line quoted, so a line-based union would corrupt them.
Deleted before committing - a working tool, not a shipped one.
"""
import csv
import io
import subprocess
import sys

for path in sys.argv[1:]:
    def side(stage, path=path):
        blob = subprocess.run(["git", "show", ":%d:%s" % (stage, path)],
                              capture_output=True, check=True).stdout.decode("utf-8")
        return list(csv.reader(io.StringIO(blob, newline="")))

    ours = side(2)
    theirs = side(3)
    seen = {r[0] for r in ours if r}
    added = 0
    for row in theirs:
        if not row or row[0] in seen:
            continue
        ours.append(row)
        seen.add(row[0])
        added += 1
    with open(path, "w", encoding="utf-8", newline="") as handle:
        csv.writer(handle, lineterminator="\n").writerows(ours)
    print("%s: kept %d, added %d" % (path, len(ours) - added, added))
