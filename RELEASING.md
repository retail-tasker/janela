# Releasing Janela

Two people publish releases: Jay Killeen and Vanessa Soares. The release
workflow waits for one of them to approve it. Everyone else opens pull requests.

Pushing a version tag publishes to RubyGems through trusted publishing, and a
published version can never be reused. So the tag is the point of no return, and
everything before it is reversible.

## Choosing the version

Janela follows semantic versioning.

- **Before 1.0** a minor release (`0.11.0` to `0.12.0`) is any release where a
  host can see something break: a rename, a changed URL, a changed return type, a
  migration to run. A patch release (`0.11.0` to `0.11.1`) changes nothing a host
  relies on.
- **From 1.0** the public surface changes only in a major release. That surface
  is what `docs/theming.md` lists as the contract, the measures and dimensions
  DSL, `janela_pane` and `janela_frame`, the pane URL shape and the dashboard
  filter parameters (ADR 037).

If any entry under `[Unreleased]` would make a host change code, the release is
minor (or major), however small the entry.

## Steps

1. **Check nothing is half done.** A clean tree, a green `main`, and no open bug
   that shows a wrong number.
2. **Update every place the version lives:** `lib/janela/version.rb`,
   `package.json`, the install line and status line in `README.md`, and anything
   in `docs/roadmap.md` the release made untrue.
3. **Cut the changelog.** Rename `[Unreleased]` to the version and date, add the
   link at the bottom, and read the entries against each other.
4. **Tell hosts what to do (ADR 015).** For a release that asks something of them:
   a section in `UPGRADING.md` with the steps and the exact before and after, and the gemspec's
   `post_install_message`. For one that doesn't, remove the message.
5. **Verify.** `bundle exec rake`, `bundle exec rake system` more than once,
   `gem build janela.gemspec` and look inside it, and `bin/rails
   app:janela:doctor` on the demo.
6. **Commit** as `Release X.Y.Z`, push, and wait for CI to be green on every Ruby
   version and the browser suite. Do not tag over a red run without understanding
   it.
7. **Tag and push:**

   ```bash
   git tag -a vX.Y.Z -m "Janela X.Y.Z"
   git push origin vX.Y.Z
   ```

8. **Approve the publish.** The release workflow waits on the protected `release`
   environment, and one of the two maintainers approves it in GitHub. This
   is deliberate: a tag push alone no longer publishes. (The RubyGems trusted
   publisher is not yet restricted to this environment, so the gate binds on
   GitHub's side; see ADR 052.) To publish an existing tag by hand, start the
   workflow from that tag, not from a branch.
9. **Confirm it is out.** RubyGems lists the version (the index can lag a
   minute), and installing it prints the post install message.
10. **Tell the issues.** Comment the version on each issue the release closed.

The steps are also written as a checklist for an agent in
`.claude/skills/jan-release/`.
