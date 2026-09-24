# work_startup_bootstrap

Minimal public entry point.

```powershell
irm https://boot.azif.ca/go|iex
```

`boot.azif.ca/go` redirects to this repo's raw `bootstrap.ps1`, which:

1. Signs in to GitHub. It uses the device flow, so you approve a code in the
   browser. If `gh` is already logged in, it reuses that token instead.
2. Fetches the real bootstrap from a private repo with that token and runs it.

No secrets are stored here.
