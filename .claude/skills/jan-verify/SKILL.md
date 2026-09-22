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

**A seed from a rake run is not reproducible, by design.**
`Minitest::TestTask` builds the command as `Dir[*globs].sort.shuffle`,
and that shuffle runs before minitest has read `--seed`. So the same seed
shuffles a differently ordered list of test files on every run: two runs
at one seed are two different orders. Measured at 1280 runs while
investigating #37.

The consequences are worth holding on to:

- Never pin a seed to chase an order dependent failure under `rake`. Pin
  the order instead, by running the files in one process yourself:
  `bundle exec ruby -Ilib:test:. -e 'require "minitest/autorun"; require "test/a_test.rb"; require "test/b_test.rb"'`
- Pass a seed as `A="--seed=N"`. `TESTOPTS` still works and prints a
  deprecation line per run.
- A suite that passes once has not been shown to be order independent.
  Run it enough times to say so with a number.

## 3. Browser suite, more than once

```bash
for i in 1 2 3; do
  log=/tmp/janela-system-$i.log
  bundle exec rake system > "$log" 2>&1
  grep -E -A 8 "Failure:|Error:" "$log"
  grep -E "runs," "$log" || { echo "run $i never reported"; tail -20 "$log"; }
done
```

Three clean runs, not one. Two things about the shape of that loop
matter:

- The guard: piping straight into `grep` prints nothing at all when the
  suite fails to start, and three silent iterations read exactly like
  three clean ones.
- The log file: keep every run's whole output until the report is
  written. `grep "Failure:"` alone prints the word and the summary line
  and drops the test's name and its assertion, so a run that fails once
  among seven passes becomes "something failed once", which is unknown
  rather than diagnosed and cannot be filed. That happened on `0466f5d`:
  one failure, output gone, seven runs that measured nothing. A failure
  with its output is a measurement. Without it, the runs have to be done
  again.

A browser test that fails one run in three is a real race until proven
otherwise, in the library or in the test.

**If a test is flaky, do not retry it into passing.** Measure it:

```bash
pass=0; fail=0
for i in $(seq 1 20); do
  if bin/rails test test/system/<file>.rb -n "/<name>/" > /tmp/janela-flake-$i.log 2>&1; then
    pass=$((pass+1)); else fail=$((fail+1)); fi
done
echo "pass=$pass fail=$fail"
grep -l -E "Failure:|Error:" /tmp/janela-flake-*.log
```

The failing runs' logs are the evidence the issue or the commit will
carry, so they are kept rather than reduced to a count.

A flaky *unit* test is a different job: the suite is seconds, so measure
it in the hundreds of runs rather than twenty, and on skybox rather than
here. `/skybox-agent-run` carries the recipe, including the one that
matters: copies of the tree, one per worker, because the SQLite test
database cannot be shared. A rate under a few percent is normal for an
order dependent failure and says nothing about how serious it is: #37 was
3% of runs and took out 57 tests when it landed.

**A flake only CI has seen is measured on a runner.** 400 full suite
runs on skybox and 20 local runs of the test alone found nothing that 80
runs on CI runners found twice, because the race was against a network
fetch and a fast machine never loses it. A temporary `workflow_dispatch`
workflow is the way: `416a356` and `18db536` are the shape, in history
rather than in the tree, eight workers with ten full suite runs each,
about ten minutes a dispatch. Run the full suite rather than the test
alone, since a page that only misbehaves after the rest of the suite has
been through the browser is the shape both #48 and the stylesheet race
took: the test alone passed 50 of 50 there. Delete the workflow once the
question is settled either way (`506b1d0`).

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
