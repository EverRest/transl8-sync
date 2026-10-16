# transl8-sync

Pull translations from transl8 into your repository, or push source strings to transl8, from GitHub Actions or GitLab CI.

The action wraps the transl8 CLI from the npm package `@transl8.ai/api-client`. To see the CLI help, run:

```bash
npx -y -p @transl8.ai/api-client transl8 --help
```

## GitHub Actions

```yaml
steps:
  - uses: actions/checkout@v5
  - uses: EverRest/transl8-sync@v1
    with:
      api-key: ${{ secrets.TRANSL8_API_KEY }}
      api-base-url: https://your-transl8-host
      project: my-project
      locales: fr,de,ja
      out-dir: locales
```

Set `api-base-url` to the host only. Do not add `/api/v1`. The CLI has no default host, so you must set it.
The runner needs Node.js. GitHub-hosted runners have it.

### Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `api-key` | yes | | transl8 project API key (`ta_live_...`). Pass it through a secret. Never write it inline. |
| `project` | yes | | transl8 project id or slug. |
| `api-base-url` | yes | | transl8 API host, for example `https://your-transl8-host`. Host only, without `/api/v1`. |
| `command` | no | `pull` | `pull` exports a locale to a file. `push` imports a file. |
| `locales` | no | | Comma-separated locales for `pull`, for example `fr,de,ja`. Required for `pull`. Ignored for `push`. |
| `format` | no | `json` | Export or import format. |
| `file` | no | | File to import. Required when `command` is `push`. |
| `out-dir` | no | `.` | Directory where `pull` writes the `<locale>.<format>` files. |

### Push example

```yaml
- uses: EverRest/transl8-sync@v1
  with:
    api-key: ${{ secrets.TRANSL8_API_KEY }}
    api-base-url: https://your-transl8-host
    project: my-project
    command: push
    file: locales/en.json
```

## API key scopes

A read-only key (`exports:read`) is enough for a locale of up to 1000 rows. A larger locale starts an async export job. That job needs the `exports:write` scope too. Without it, the pull fails with `EXPORT_TOO_LARGE ... needs an API key with the exports:write scope`.

## GitLab CI

Include the job from this repository:

```yaml
include:
  - remote: 'https://raw.githubusercontent.com/EverRest/transl8-sync/main/gitlab/transl8-pull.yml'

transl8-pull:
  variables:
    TRANSL8_API_BASE_URL: 'https://your-transl8-host'
    TRANSL8_PROJECT: 'my-project'
    TRANSL8_LOCALES: 'fr,de,ja'
```

The `variables:` block of your `transl8-pull` job overrides the defaults of the included job. The job writes `locales/<locale>.<format>` files and keeps them as artifacts.

Set `TRANSL8_API_KEY` as a masked and protected CI/CD variable. Never commit it.

To push source strings, copy the `transl8-push` example from the end of [`gitlab/transl8-pull.yml`](gitlab/transl8-pull.yml). You can also copy the whole file into your `.gitlab-ci.yml` instead of using `include`.

## Versioning

- `@v1` is a moving tag. It points to the latest `v1.x.y` release.
- `@v1.x.y` is fixed. Use it when you need an exact version.

The action runs the CLI at major version 2 (`@transl8.ai/api-client@2`).

## Tests

```bash
bash run.test.sh
bash gitlab/transl8-pull.test.sh
```

## License

MIT. See [LICENSE](LICENSE).
