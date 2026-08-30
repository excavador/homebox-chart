# helmctl (truvity/ocictl) — deterministic chart packaging. Pinned, and
# run through `go run` so there is nothing to install.
# renovate: datasource=github-releases depName=truvity/ocictl
HELMCTL_VERSION := "v0.5.1"

default: check

# Everything CI runs, locally.
check: lint template hardened

lint:
    helm lint charts/homebox

# Render both database paths. The postgres branch is where the secret
# wiring lives, so rendering only the default would prove very little.
template:
    @helm template hb charts/homebox >/dev/null && echo "ok: sqlite"
    @helm template hb charts/homebox \
        --set database.driver=postgres \
        --set database.host=example-rw \
        --set database.existingSecret=example-db \
        --set oidc.enabled=true \
        --set oidc.issuerUrl=https://example.invalid \
        --set oidc.clientId=example \
        --set oidc.existingSecret=example-oidc >/dev/null && echo "ok: postgres + oidc"

# The two defaults that invert upstream must never drift back on.
hardened:
    @out=$(helm template hb charts/homebox); \
      echo "$out" | grep -A1 'HBOX_OPTIONS_ALLOW_REGISTRATION' | grep -q '"false"' || { echo "FAIL: registration is not disabled by default"; exit 1; }; \
      echo "$out" | grep -A1 'HBOX_OPTIONS_ALLOW_LOCAL_LOGIN' | grep -q '"false"' || { echo "FAIL: local login is not disabled by default"; exit 1; }; \
      echo "ok: hardened defaults intact"

# Deterministic local package — same tool CI publishes with, so a chart
# built here has the same digest as the released one.
package version="0.0.0-dev":
    go run github.com/truvity/ocictl/cmd/helmctl@{{HELMCTL_VERSION}} package \
        --chart charts/homebox --version {{version}} --destination dist/

release-check:
    goreleaser check
