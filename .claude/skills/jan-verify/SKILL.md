---
name: jan-verify
description: Verify Janela properly before a commit, push or release. Runs the unit suite, RuboCop and the browser suite more than once, builds the gem and checks what it contains, and after a push confirms CI and the live demo. Use before saying work is done, and always before a release.
---

# Verify Janela

"The tests pass" means nothing if they passed once by luck. This is the
check that holds up.

## 1. Nothing else running

A second test process on the shared SQLite test database produces dozens
of unrelated failures. Check first:

```bash
pgrep -af "rails test|rake( |$)|rake test|rake system|chromedriver" | grep -v pgrep
```

Anything listed that belongs to this repository should finish or be
stopped before trusting a result.

## 2. Unit suite and style

```bash
bundle exec rake
```

That runs the unit tests and RuboCop together. Both must be clean.

## 3. Browser suite, more than once

```bash
for i in 1 2 3; do
  out=$(bundle exec rake system 2>&1)
  echo "$out" | grep -E "runs,|Failure:|Error:" || { echo "run $i never reported"; echo "$out" | tail -20; }
done
```

Three clean runs, not one. The guard matters: piping straight into
`grep` prints nothing at all when the suite fails to start, and three
silent iterations read exactly like three clean ones. A browser test that fails one run in three is
a real race until proven otherwise, in the library or in the test.

**If a test is flaky, do not retry it into passing.** Measure it:

```bash
pass=0; fail=0
for i in $(seq 1 20); do
  if bin/rails test test/system/<file>.rb -n "/<name>/" 2>&1 | grep -q "0 failures, 0 errors"; then
    pass=$((pass+1)); else fail=$((fail+1)); fi
done
echo "pass=$pass fail=$fail"
```

Then find out whether the result is wrong or only slow: raise the wait
time temporarily. If a longer wait does not help, the page is ending in a
wrong state and that is a bug. Compare against the last commit before the
change to learn whether the change caused it. Record what was measured in
the commit message.

## 4. The gem itself

```bash
gem build janela.gemspec -o /tmp/janela-check.gem
tar -xOf /tmp/janela-check.gem data.tar.gz | tar -tz | grep -E "docs/|stylesheets|javascripts|UPGRADING|LICENSE"
rm /tmp/janela-check.gem
```

Confirm anything new that a host needs is actually packaged. The gemspec
ships `app`, `config`, `db`, `lib` and `docs`, and nothing from `test`.

## 5. The doctor on the demo

The demo's tasks are namespaced under `app:` from the repository root,
and running it from the root matters: the working directory persists
between commands, so a `cd` here strands every command that follows.

```bash
bin/rails app:janela:doctor
```

The demo's baseline today is **one warning and no errors**:
`unauthenticated-endpoints`, which is correct for a demo that is
deliberately public. Anything else is either a real finding or a check
that needs teaching. Do not silence the baseline warning to make the
output clean.

## 6. After a push

Wait for CI rather than assuming it:

```bash
gh run list --branch main --limit 3
gh run watch <run id> --exit-status
```

Then check the live demo is running the commit that was pushed, and that
anything added actually serves:

```bash
demo=$(gh variable list --json name,value --jq '.[] | select(.name=="DEMO_URL") | .value')
curl -s "$demo/version"
curl -s -o /dev/null -w "%{http_code}\n" "$demo/<new page>"
```

A page that passes locally and in CI can still 404 in production if the
image leaves out a file it reads. That has happened.

## Report

State the numbers, not an impression: unit runs and assertions, browser
runs across repeats, RuboCop offences, and the live commit. If anything
was skipped, say which step and why.
