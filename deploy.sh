#!/usr/bin/env bash
# Stamp the current commit's SHA into index.html's build marker, push to main,
# and wait until GitHub Pages actually serves it.
#
# Run AFTER committing the work you want to deploy:
#     git commit -am "my change" && ./deploy.sh
#
# The page footer (and the marker below) then shows the stamped SHA, so you know
# exactly which commit is live — the script blocks until that SHA is served.

set -euo pipefail

URL="https://jsherman999.github.io/potato_cabinet/"
cd "$(git rev-parse --show-toplevel)"

SHA=$(git rev-parse --short HEAD)

# replace whatever is between the <!--BUILD--> … <!--/BUILD--> markers
perl -0pi -e "s{<!--BUILD-->.*?<!--/BUILD-->}{<!--BUILD-->$SHA<!--/BUILD-->}s" index.html

if ! git diff --quiet -- index.html; then
  git add index.html
  git commit -m "chore: stamp build $SHA"
fi
git push

MARKER="<!--BUILD-->$SHA<!--/BUILD-->"
echo "Pushed build $SHA — waiting for GitHub Pages to serve it…"
for _ in $(seq 1 60); do
  if curl -fsS "${URL}?cb=$(date +%s)" | grep -qF "$MARKER"; then
    echo "✓ live: $SHA  →  $URL"
    exit 0
  fi
  printf '.'
  sleep 10
done
echo
echo "✗ not live after ~10 min — check $URL and the repo's Pages build (Settings → Pages)."
exit 1
