# TopNest widget extensions

Version 1 packages are JSON files describing one HTTPS-powered widget. They do not contain executable code, native libraries, shell commands, or arbitrary UI components.

## Package format

```json
{
  "schemaVersion": 1,
  "id": "org.example.my-widget",
  "version": "1.0.0",
  "minTopNestVersion": "0.5.0",
  "author": "Example author",
  "summary": "What this widget shows",
  "widget": {
    "title": "My widget",
    "icon": "star.fill",
    "source": "url",
    "target": "https://api.example.org/value",
    "jsonPath": "data.value",
    "refreshSeconds": 300,
    "display": "number"
  }
}
```

`id` is a stable, lowercase dotted identifier. `version` and `minTopNestVersion` use three numeric components such as `1.2.3`. `target` must be an HTTPS URL without embedded credentials. `jsonPath` selects a value from a JSON response, for example `data.items[0].price`. Supported display values are `text`, `number`, and `gauge`; gauge widgets may also set `gaugeMax`. Optional `prefix` and `suffix` are display text. The app limits the refresh interval to at least 10 seconds and at most one day.

TopNest prompts before installing a package. It shows the author, description, version, and destination hostname. Installing an update replaces the widget definition while keeping the widget's size and position. If a user edits an installed widget manually, it becomes a personal custom widget and is detached from catalog updates.

## Catalog entry

The official catalog is [`extensions/catalog.json`](extensions/catalog.json). Each entry points to one package file and records its SHA-256 digest:

```json
{
  "id": "org.example.my-widget",
  "version": "1.0.0",
  "name": "My widget",
  "summary": "What this widget shows",
  "author": "Example author",
  "packageURL": "https://example.org/my-widget-v1.json",
  "sha256": "64 lowercase hex characters"
}
```

The package ID and version must match the catalog entry. Keep packages versioned. Prefer immutable GitHub Release assets for third-party packages; the included sample lives in the site repository until the first release is published. After editing a package file, compute its new digest with `shasum -a 256 path/to/package.json` and update the catalog entry. Review both changes together.

## Proposing an extension

1. Publish the JSON package in a public repository or immutable release asset.
2. Verify the HTTPS endpoint and explain what data it receives.
3. Open a pull request adding a catalog entry and its SHA-256 digest.
4. Test installation from the site, updates, removal, and the offline file-import fallback.

Catalog maintainers review submissions before publication. The website passes only the extension ID to TopNest; the app retrieves the package URL from the official catalog. The SHA-256 check detects a changed package, but it does not authenticate a compromised catalog. Keep catalog publishing access restricted.

## Scope and safety

Remote catalog packages cannot run shell commands. Legacy custom-widget files imported through **Settings → Widgets** can contain a command, and TopNest displays it before asking the user to add it. This is separate from the extension catalog. A future general-purpose plugin system would need a separate execution model, permissions, compatibility rules, and stronger publisher verification.
