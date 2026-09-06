# homebox-chart

A Helm chart for [HomeBox](https://github.com/sysadminsmedia/homebox) — the
self-hosted home inventory and organisation system.

Upstream ships a container image but no Kubernetes packaging, so everyone
self-hosting it on Kubernetes writes their own manifests. This is that work,
done once.

```sh
helm install homebox oci://ghcr.io/excavador/charts/homebox --version 0.1.0
```

## Hardened by default

Two of this chart's defaults are **deliberately the opposite of upstream's**:

| setting | upstream | here |
| --- | --- | --- |
| `options.allowRegistration` | `true` | `false` |
| `options.allowLocalLogin` | `true` | `false` |

HomeBox enables open registration and local password login out of the box.
Behind single sign-on, that leaves a self-service signup form and a
credential path that bypasses your identity provider entirely. Turning them
back on should be a decision, not an accident.

## Single sign-on

HomeBox speaks OIDC natively — no reverse-proxy header shims required.

```yaml
oidc:
  enabled: true
  issuerUrl: https://id.example.com
  clientId: homebox
  existingSecret: homebox-oidc     # key: oidc-client-secret
  autoRedirect: true               # skip the local login page
```

If an operator provisions the client for you — a Zitadel `OIDCApp` CR, for
instance — the client **id** is not known when you author values either.
Leave `clientId` empty and the chart reads it from the same secret:

```yaml
oidc:
  existingSecret: homebox-oidc
  existingSecretKey: oidc-client-secret
  existingSecretClientIdKey: client-id
```

Register a **confidential (web) client** — HomeBox requires a client secret,
so a public/PKCE client will not work. The redirect URI is:

```
https://<your-host>/api/v1/users/login/oidc/callback
```

### A note on `allowedGroups`

Group filtering reads a **flat list of strings** from the claim named by
`oidc.groupClaim` (default `groups`). Some providers — Zitadel among them —
emit roles as a nested object instead, and filtering silently matches
nothing. Confirm your provider's claim shape before relying on it; leave
`allowedGroups` empty and gate access at your proxy or gateway otherwise.

## Database

`sqlite3` (default) keeps everything in the PVC. On Kubernetes prefer
`postgres`: a SQLite file on node-local storage pins the pod to one node for
the life of the volume.

```yaml
database:
  driver: postgres
  host: homebox-pg-rw
  existingSecret: homebox-pg-app   # key: password
```

## Secrets that must not rotate

`auth.existingSecret` supplies `HBOX_AUTH_API_KEY_PEPPER`, which is HMAC'd
into stored API key hashes so a database-only leak yields nothing usable.
**It must stay stable across restarts** — rotating it invalidates every API
key ever issued. Generate once and keep it somewhere you control:

```sh
openssl rand -base64 48
```

## Versioning

Chart version is **independent semver**; `appVersion` tracks the HomeBox
release. The two started aligned at `0.26.2` and diverge from there — a
chart-only fix cannot borrow an upstream version it does not correspond to.

Releases are cut by tagging `v<chart-version>`. The tag is the sole
version authority: [helmctl](https://github.com/truvity/ocictl) injects it
as the chart version at publish time and strips the `created` annotation,
so identical chart content always produces an identical digest and the
published tags stay immutable across re-releases.

## Development

```sh
devbox shell   # or direnv allow
just check     # lint, render both database paths, assert hardened defaults
just package   # deterministic package with the same tool CI publishes with
```

CI runs the same `just check` inside the same devbox, so tool versions
cannot drift between your machine and the pipeline.

## Licence

MIT — see [LICENSE](LICENSE). HomeBox itself is licensed separately by its
own authors.
