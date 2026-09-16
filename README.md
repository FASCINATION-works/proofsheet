# Proofsheet

Proofsheet captures repeatable screenshots from web applications. A YAML manifest describes the browser viewport, authentication, pages, readiness selectors, clicks, safety checks, and element crops. The `proofsheet` CLI runs the manifest in headless Chrome and writes PNG files.

## Installation

Install the gem:

```sh
gem install proofsheet
```

Proofsheet requires Chrome and libvips on the machine doing the capture.

## Manifest

Create `proofsheet.yml` in the root of the project whose screenshots you want to capture:

```yaml
host: "https://example.com"

expect:
  username: "demo@example.com"

credentials:
  username: "env:PROOFSHEET_USERNAME"
  password: "env:PROOFSHEET_PASSWORD"

login:
  path: "/sign-in"
  username_field: "email"
  password_field: "password"
  submit: "Sign in"
  expect:
    selector: "header"
    text: "demo@example.com"

targets:
  account: 42

defaults:
  viewport: [1440, 900]
  output_dir: "docs/screenshots"

shots:
  dashboard:
    path: "/accounts/%{account}"
    wait_for: "[data-testid='dashboard']"
    expect:
      selector: ".account-name"
      text: "Demo Account"

  activity:
    path: "/accounts/%{account}/activity"
    wait_for: "[data-testid='activity-chart']"
    click: "[data-range='7d']"
    clip:
      selector: "[data-testid='activity-chart']"
      padding: 5

  toolbar:
    path: "/accounts/%{account}"
    clip:
      selector: ".toolbar"
      full_width: true
```

The `login` section is optional; `credentials` is required when `login` is present. The `expect`, `targets`, `wait_for`, `click`, and `clip` sections are optional. The default viewport is `1440×900`, and the default output directory is `screenshots`.

Credential sources must be environment variables such as `env:PROOFSHEET_USERNAME` or 1Password secret references such as `op://Vault/Item/username`. Add `op_account` under `credentials` when 1Password needs an explicit account.

An `expect.username` value stops capture before Chrome starts if the loaded username is not the intended screenshot account. A login or shot-level `expect` stops capture when the expected text is absent from the selected element.

For pages whose final URL is only discoverable in the browser, `path_script` may contain JavaScript that returns a path. Set `resolved_wait_for` to wait for the destination content:

```yaml
shots:
  latest-report:
    path: "/reports"
    wait_for: "[data-latest-report]"
    path_script: "document.querySelector('[data-latest-report]').getAttribute('href')"
    resolved_wait_for: "iframe[title='Report']"
```

## CLI

Capture every shot:

```sh
proofsheet capture
```

Capture selected shots, use another manifest, or override its host:

```sh
proofsheet capture dashboard activity
proofsheet capture --config config/docs.yml
proofsheet capture --host http://localhost:3000
```

List the manifest without starting Chrome:

```sh
proofsheet list
```

Relative output paths are resolved from the directory where the command runs.

## Development

Run `bin/setup`, then `bundle exec rake` to run the specs and linter. To install this gem locally, run `bundle exec rake install`.

## License

Proofsheet is available under the terms of the MIT License.
