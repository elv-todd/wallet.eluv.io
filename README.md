# wallet.eluv.io

A one-page Firebase site that is the Ory "Custom UI Base URL" for the prod Ory custom domain
`ory.svc.eluv.io`. Several unrelated properties share that Ory domain (fox.eluv.io, vix.eluv.io,
nba-cup.eluv.io, nba-summer.eluv.io, ...), and Ory allows only one base URL per custom domain, so this
neutral page sits in front of them instead of one brand's site.

## What it does

When a social login does not succeed (provider cancel or error, or an account-linking conflict), Ory
redirects the browser to `https://wallet.eluv.io/oidc?flow=<id>`. The page:

1. reads the login flow from `https://ory.svc.eluv.io/self-service/login/flows?id=<id>`;
2. redirects to the flow's `return_to` (the property that started the login) with `flow=<id>` added, so
   that property's `/oidc` page shows the message;
3. otherwise redirects to the generic wallet, `https://wallet.contentfabric.io/`.

Reading the flow only works from an `eluv.io` page: Ory requires the browser's CSRF cookie, which lives
on the `eluv.io` cookie domain. That is why this can't simply be `wallet.contentfabric.io`. Prod Ory's
CORS already allows `https://wallet.eluv.io`. `return_to` was validated by Ory against
`allowed_return_urls` when the flow was created, so this is not an open redirect.

## Setup

- Firebase project `production-web-apps-c0c6b`, hosting site `wallet-eluv-io`.
- DNS: `wallet.eluv.io` per the Firebase custom-domain wizard (e.g. `CNAME wallet-eluv-io.web.app`).
- Ory Console (prod project "Eluvio Media Wallet Auth") → Branding → UI URLs → custom domain
  `ory.svc.eluv.io` → Custom UI Base URL `https://wallet.eluv.io`. Set this only after
  `https://wallet.eluv.io` serves the page with a valid certificate.

## Commands

```
make deploy   # firebase deploy of this site
make check    # page served on every path, no-cache header present
make serve    # local preview (no Ory cookies locally, so it always falls back)
```

## Testing

On a property like `https://fox.eluv.io`, start Sign in with Apple and cancel at Apple. Expected:
`wallet.eluv.io/oidc?flow=…` briefly, then `https://fox.eluv.io/oidc?flow=…&…` showing the cancel
message.
