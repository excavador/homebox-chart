default: check

# Everything CI runs, locally.
check: lint template

lint:
    helm lint charts/homebox

# Render both database paths — the postgres branch is where the secret
# wiring lives, so a template that only renders the default proves little.
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

package:
    helm package charts/homebox --destination dist/

release-check:
    goreleaser check
