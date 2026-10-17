# wallet.eluv.io

A one-page Firebase site that is the **login UI URL** (`selfservice.flows.login.ui_url`) of the prod Ory
project "Eluvio Media Wallet Auth". Ory sends browsers here when a social login (Apple, Google, Facebook)
does not succeed, and the page sends them back to the site where they started.

## Why it exists

On a successful login, Ory redirects to the client's `return_to`. On anything else (provider cancel or
error, account-linking conflict) it ignores `return_to` and redirects to the single login UI URL with
`?flow=<id>`. The wallet's own `/oidc?flow=<id>` page can show that flow, but only on a site that shares
the flow's cookie domain: reading a flow requires the browser's Ory CSRF cookie (an Ory API key does not
work in its place).

Prod has many sites on several Ory custom domains: `ory.svc.contentfabric.io` (wallet, wallet.dev,
wallet.preview), `ory.svc.eluv.io` (fox, vix, nba-cup, nba-summer, ...), `ory.svc.nba.com`, and others.
The wallet picks its Ory domain from the site's registrable domain. A single fixed landing page can't
serve all of them, so this page reads the flow and forwards the user.

## What the page does

1. Reads the flow from `https://ory.svc.eluv.io/self-service/<type>/flows?id=<id>`. This works for flows
   started on any `*.eluv.io` site, because this page is on the same cookie domain. The type is login for
   `/oidc`, or registration/verification/recovery/settings for `/ui/<type>`.
2. If that works, it redirects to the flow's `return_to` with `flow=<id>` added (login flows only), so
   that site's `/oidc` page shows the message.
3. If it can't read the flow, it hands off to authd at
   `https://as.glb.contentfabric.io/as/wlt/ory/login_ui?flow=<id>` (elv-master, `WltOryLoginUi`). authd
   reads `contentfabric.io` flows by forwarding the browser's cookies, and redirects to that flow's
   `return_to`. If it can't read the flow either, it redirects to `https://wallet.contentfabric.io/oidc`.
4. With no `flow` at all, it redirects to `https://wallet.contentfabric.io/`.

It only follows a `return_to` that Ory returned, and Ory validated that against `allowed_return_urls` when
the flow was created, so this is not an open redirect.

## Don't use Custom UI Base URLs for shared domains

Ory's per-custom-domain "Custom UI Base URL" (Console → Branding → UI URLs) looks like the obvious fix, but
it rewrites the **host of every redirect** on that domain, including successful logins: a Fox login
returned to `wallet.eluv.io/oidc?next=…` instead of `fox.eluv.io`. Only use a base URL when every site on
that Ory domain is the same host as the base URL. Today that's `epcrugby.tv` and `pasifika.plus` only.
`ory.svc.eluv.io`, `ory.svc.nba.com` and `ory.svc.contentfabric.io` must have no base URL.

## Setup

- Firebase project `production-web-apps-c0c6b`, hosting site `wallet-eluv-io`. `firebase.json` rewrites
  every path to `index.html`.
- DNS (eluv.io at GoDaddy): `CNAME wallet.eluv.io → wallet-eluv-io.web.app`.
- Ory prod project `e17fa37c-1854-4ed6-b225-cf112d1d609c`: login `ui_url` = `https://wallet.eluv.io/oidc`.
  Keep the `/oidc` path: base-URL domains (epcrugby.tv, pasifika.plus) keep it and swap only the host, so
  they land on the wallet's `/oidc` page.

```
make deploy   # firebase deploy of this site
make check    # page served on every path, no-cache header present
```

Rollback: set the prod login `ui_url` back to `https://wallet.contentfabric.io/oidc`. Successful logins
are unaffected either way; only failed logins pass through here.

## Testing

After any change here, in authd's `login_ui`, or in Ory's UI or return URLs, test **both success and
failure** on each kind of site. Sign out first each time:

| Site                                    | Google success, ends on    | Apple cancel, ends on                    |
|-----------------------------------------|----------------------------|------------------------------------------|
| `fox.eluv.io` (shared Ory domain)       | fox.eluv.io, signed in     | `fox.eluv.io/oidc?…&flow=…` with message |
| `nba-cup.eluv.io` (second property)     | nba-cup.eluv.io, signed in | `nba-cup.eluv.io/oidc?…&flow=…`          |
| `wallet.contentfabric.io`               | same site, signed in       | `wallet.contentfabric.io/oidc?flow=…`    |
| `wallet.dev.contentfabric.io` (prod Ory) | same site, signed in      | `wallet.dev.contentfabric.io/oidc?…`     |
| `epcrugby.tv` (has a base URL)          | epcrugby.tv, signed in     | `epcrugby.tv/oidc?flow=…`                |

Quick check of where each Ory domain sends a failed login:

```
for d in eluv.io contentfabric.io epcrugby.tv; do
  curl -s -o /dev/null -D - https://ory.svc.$d/self-service/login/browser | grep -i '^location'
done
```

Test with a real sign-in click, not by opening an Ory URL directly. The wallet's `/oidc` page relies on
the property it saved in session storage when the login started.

## Adding another multi-site custom domain

A custom domain with **one** site can just get a Custom UI Base URL equal to that site's host (like
epcrugby.tv). A domain shared by **several** sites (e.g. `nba.com`) needs a reader page on that domain,
added as another hop in the chain. The login `ui_url` stays `https://wallet.eluv.io/oidc`; never point it
at the new page, because that would drop the other domains.

1. New Firebase site with this same `index.html`, `ory.svc.eluv.io` replaced by `ory.svc.<domain>`; its
   can't-read target stays authd.
2. In this site's `index.html`, change the can't-read target from authd to
   `https://wallet.<domain>/oidc?flow=…`.
3. DNS on the domain owner's side: `wallet.<domain>` CNAME → the new Firebase site.
4. Ory Console: the `ory.svc.<domain>` custom domain's CORS must allow `https://wallet.<domain>`.
5. Run the test matrix above, plus a success and a cancel on a site of the new domain.

## Known limits

- `ory.svc.nba.com` flows can't be read by this page or authd, so they fall back to
  `wallet.contentfabric.io/oidc`. NBA hosts currently have no social login.
- Account-linking conflicts land on the right site, but the wallet's conflict page doesn't show the
  "Confirm with <provider>" button for accounts without a password (wallet change, `OryLogin.jsx`).
