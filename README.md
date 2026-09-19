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

## Compositions

Compositions arrange captured shots on a new PNG canvas. A background can be a solid color, an angled two-color gradient, or an image. Layers can be positioned, resized proportionally, rounded, rotated, and given a shadow.

```yaml
compositions:
  launch-hero:
    canvas: [1600, 1000]
    background:
      gradient: ["#211002", "#5aa579"]
      angle: 135
    layers:
      - shot: dashboard
        x: 120
        y: 140
        crop:
          x: 80
          y: 40
          width: 1200
          height: 700
        width: 980
        radius: 32
        rotate: -4
        shadow:
          x: 8
          y: 24
          blur: 32
          color: "#00000066"
      - shot: activity
        x: 900
        y: 460
        width: 560
        rotate: 5
        shadow: true
```

Solid colors can be written directly as `background: "#fff8f5"`. For a transparent canvas, use `background: "#00000000"`. For an image background, use `background: { image: "assets/background.png" }`; Proofsheet scales and center-crops it to cover the canvas. Colors use `#RRGGBB` or `#RRGGBBAA` notation.

Layer crop coordinates are measured in pixels from the original captured shot. Proofsheet crops first, then resizes proportionally using `width`, rounds corners using `radius`, rotates, adds the shadow, and places the result on the canvas. The radius is measured in pixels after resizing and is clamped to half the layer's smaller dimension.

Setting `shadow: true` uses `x: 0`, `y: 16`, `blur: 24`, and `color: "#00000055"`. Use the expanded shadow mapping shown above to override any of those values.

Capture the source shots, then compose every configured image or selected compositions:

```sh
proofsheet capture
proofsheet compose
proofsheet compose launch-hero
```

## Development

Run `bin/setup`, then `bundle exec rake` to run the specs and linter. To install this gem locally, run `bundle exec rake install`.

## License

Proofsheet is available under the terms of the MIT License.
