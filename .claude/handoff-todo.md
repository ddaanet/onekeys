## Remaining

- Cut a release so the new default mapping reaches the installed plugin —
  the cached install is keyed by version, so the committed change is inert
  until `just release patch` bumps it; the marketplace push at the end is
  classifier-blocked and has to be run by the user with `!`.
