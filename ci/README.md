# CI

`github-actions-tests.yml` runs the game's full GUT suite headlessly (no display, no device):
it downloads Godot 4.7.1, imports the project and fails the build unless every test passes.

To enable it, move the file into place and push with a token that has the `workflow` scope:

```bash
mkdir -p .github/workflows
git mv ci/github-actions-tests.yml .github/workflows/tests.yml
git commit -m "ci: run GUT suite on push"
```

It lives here rather than in `.github/workflows/` because the token used for the initial
publish did not carry the `workflow` scope, and GitHub refuses such pushes.
