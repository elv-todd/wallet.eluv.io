
PROJECT := production-web-apps-c0c6b
SITE    := wallet-eluv-io

deploy:
	firebase deploy --project $(PROJECT) --only hosting:$(SITE)

# local preview at http://localhost:5000 (no Ory cookies there, so it always falls back)
serve:
	firebase serve --project $(PROJECT) --only hosting:$(SITE)

# after deploy: page served on every path, no-cache header present
check:
	@for u in https://wallet.eluv.io/ "https://wallet.eluv.io/oidc?flow=test"; do \
	  printf "%s -> " "$$u"; curl -s -o /dev/null -w '%{http_code} ' "$$u"; \
	  curl -s -D - -o /dev/null "$$u" | grep -i '^cache-control' | tr -d '\r'; \
	done

.PHONY: deploy serve check
