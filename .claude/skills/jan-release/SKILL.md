---
name: jan-release
description: Cut a Janela release to RubyGems. Decides the version, updates every place the version lives, cuts the changelog, writes the upgrade steps and post install message, verifies, then tags only after CI passes so the release workflow publishes. Use when the maintainer asks for a release. Pass the version, or let the skill recommend one.
disable-model-invocation: true
argument-hint: [version]
---

# Release Janela

Pushing a tag publishes to RubyGems through trusted publishing, and a
published version can never be reused. Everything before the tag is
reversible; the tag is not. Only release when the maintainer has asked.

## 1. Decide the version

Janela is `0.x`, so under semantic versioning:

- **Minor** (`0.4.0` to `0.5.0`) when a host can see anything break: a
  rename, a changed URL shape, a changed return type, a migration they
  must run.
- **Patch** (`0.4.0` to `0.4.1`) when nothing a host relies on changes.

Read the `[Unreleased]` section of `CHANGELOG.md`. If any entry would
make a host change code, it is a minor release, however small the entry.

## 2. Check nothing is half done

```bash
git status --short
gh run list --branch main --limit 2
gh issue list --state open --label bug
```

A red `main` or an open bug that shows wrong numbers is a reason to stop
and say so, not to release over.

## 3. Update every place the version lives

All of these, together:

| File | What changes |
| --- | --- |
| `lib/janela/version.rb` | `VERSION` |
| `package.json` | `"version"`, for the npm package |
| `README.md` | the `gem "janela", "~> X.Y"` install line and the **Status** line |
| `UPGRADING.md` | any `yarn add ...#vX.Y.Z` pin |

Then search for anything else still naming the old version:

```bash
git grep -n "<old version>" -- . ':!CHANGELOG.md' ':!docs/decisions'
```

Anything a page renders should read `Janela::VERSION` rather than a
string, so it cannot go stale.

## 4. Cut the changelog

- Rename `## [Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD`.
- Add the release link at the bottom:
  `[X.Y.Z]: https://github.com/retail-tasker/janela/releases/tag/vX.Y.Z`
- Keep each list continuous. A blank line between two bullets splits the
  list when rendered.
- Every entry says what changed for a host and why, not how the code
  moved.

## 5. Tell hosts what to do (ADR 015)

For a minor release:

- **`UPGRADING.md`** gets a `## <old> to <new>` section at the top, with
  numbered steps, the exact before and after, and a closing line saying
  what did not change.
- **`janela.gemspec`**'s `post_install_message` is replaced with this
  release's message. Say exactly who needs to act, so everyone else knows
  they do not. Point at `UPGRADING.md`.
- **The doctor** learns to find any renamed identifier, in
  `Janela::Doctor::RENAMED`. It matches substrings, so check a new entry
  cannot match the new name as well; `selected_value` would match
  `selected_values`.

For a patch release that asks nothing of hosts, remove the
`post_install_message` rather than repeating an old one. A message
printed on every install stops being read.

## 6. Verify

Run `/jan-verify` in full. Then build the gem and confirm it contains
what this release added and says the right version:

```bash
gem build janela.gemspec -o /tmp/janela-release.gem
tar -xOf /tmp/janela-release.gem data.tar.gz | tar -tz | grep -E "<what this release added>"
rm /tmp/janela-release.gem
```

## 7. Commit, push, and wait for CI

Stage explicit paths. The release commit is titled `Release X.Y.Z` and
its body says what is in it and why it is minor or patch.

```bash
git push origin main
sha=$(git rev-parse HEAD)
gh run list --commit "$sha" --workflow main.yml --limit 1
```

GitHub takes a few seconds to queue a run, and asking for the newest run
by branch in that window returns the previous, already green one. Ask by
commit, and treat an empty answer as "not started yet, wait", never as
"nothing to wait for". Then watch the run this commit actually produced:

```bash
gh run watch <run id> --exit-status
```

**Do not tag until CI on this commit is green on every Ruby version and
the browser suite.** The tag is the point of no return.

## 8. Tag and publish

```bash
git tag -a vX.Y.Z -m "Janela X.Y.Z

<two or three lines on what is in it>"
git push origin vX.Y.Z
gh run list --workflow release.yml --limit 2
gh run watch <run id> --exit-status
```

## 9. Confirm it is really out

Check RubyGems itself, then install it somewhere disposable and look:

```bash
curl -s https://rubygems.org/api/v1/versions/janela.json | head -c 300
gem install janela -v X.Y.Z --install-dir /tmp/janela-installed --no-document --ignore-dependencies
rm -rf /tmp/janela-installed
```

The install prints the post install message. Read it as a host would.
Two things to expect rather than be alarmed by: RubyGems' index lags the
publish by up to a minute, so a first attempt that cannot find the
version means wait and try again, not that the release failed. And
`--ignore-dependencies` is there because a full install pulls Rails and
everything else, which takes minutes and proves nothing about this gem.

The release workflow publishes the gem; it does not create a GitHub
Release. The changelog's `releases/tag/vX.Y.Z` links resolve to the tag
page either way. Write release notes by hand if they are wanted.

Finally, confirm the demo deployed the release commit:

```bash
demo=$(gh variable list --json name,value --jq '.[] | select(.name=="DEMO_URL") | .value')
curl -s "$demo/version"
```

## 10. Tell each issue which version it shipped in

An issue closes when its commit lands on `main`, not when a release goes
out, so between the two it reads as closed while anyone installing from
RubyGems still has the bug. One comment per issue closes that gap, and
makes the issue useful to whoever finds it a year later.

Find what this tag shipped, from the commit messages between the tags:

```bash
git log <previous tag>..vX.Y.Z --format=%B \
  | grep -oiE "(closes|fixes|resolves) #[0-9]+" \
  | grep -oE "[0-9]+" | sort -un
```

Then comment the version on each, and say where to read the detail:

```bash
gh issue comment <n> --body "Shipped in 0.4.0, on RubyGems now. See the changelog for what changed and UPGRADING.md if your application has to act."
```

Only comment on issues that are actually closed. One that is still open
was referenced without being fixed, which is worth saying in the report
rather than commenting on.

## Report

The version, the tag and its commit, the RubyGems confirmation, the live
demo version, the issues told which version they shipped in, and exactly
which hosts need to act and on what.
