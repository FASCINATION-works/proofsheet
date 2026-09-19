# Proofsheet

Proofsheet captures repeatable screenshots from web applications and assembles them into polished image compositions. A YAML manifest describes what to capture; the `proofsheet` CLI runs it in headless Chrome and writes PNG files.

## Installation

```sh
gem install proofsheet
```

Proofsheet requires Ruby 3.2 or newer, Chrome, and libvips.

## Quick start

Create `proofsheet.yml` in your project:

```yaml
host: "https://example.com"

defaults:
  viewport: [1440, 900]
  output_dir: "docs/screenshots"

shots:
  homepage:
    path: "/"
```

Then capture it:

```sh
proofsheet capture
```

The main commands are:

```sh
proofsheet capture   # Capture configured shots and fetched images
proofsheet compose   # Build configured compositions
proofsheet list      # List configured shots without opening Chrome
```

## Features

- Repeatable full-viewport and element-cropped screenshots driven by YAML
- Readiness selectors, scripted clicks, content assertions, target substitution, and browser-resolved paths
- Authenticated captures using environment variables or 1Password references, with identity safeguards
- Local image assets, direct URL downloads, and browser-selected `<img>` downloads using `currentSrc`
- Automatic conversion of downloaded images to PNG, including alpha transparency
- Compositions with solid, transparent, gradient, or image backgrounds
- Layer cropping, proportional resizing, rounded corners, rotation, positioning, and shadows
- Selective capture and composition from the command line

## Usage

See [USAGE.md](USAGE.md) for the complete guide, runnable manifests, generated example images, and configuration reference.

## Development

Run `bin/setup`, then `bundle exec rake` to run the specs and linter. Regenerate the usage guide and its real example images with `bundle exec rake usage`.

To install the gem locally, run `bundle exec rake install`.

## License

Proofsheet is available under the terms of the MIT License.
