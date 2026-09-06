.PHONY: bundle

bundle:
	@echo "Bundling k8squest..."
	@set -eu; \
		epoch="$${SOURCE_DATE_EPOCH:-$$(git log -1 --format=%ct -- . 2>/dev/null || printf '0')}"; \
		tmp="$$(mktemp "$(CURDIR)/.k8squest-bundle.XXXXXX.tar.gz")"; \
		trap 'rm -f "$$tmp"' EXIT HUP INT TERM; \
		tar --create --gzip --file="$$tmp" \
			--sort=name \
			--format=gnu \
			--mtime="@$$epoch" \
			--owner=0 --group=0 --numeric-owner \
			--mode='u+rwX,go+rX,go-w' \
			--exclude='venv' \
			--exclude='__pycache__' \
			--exclude='*.pyc' \
			--exclude='workspace' \
			--exclude='progress.json' \
			--exclude='.git' \
			--exclude='k8squest-bundle.tar.gz' \
			--exclude='.k8squest-bundle.*.tar.gz' \
			-C "$(CURDIR)/.." "$(notdir $(CURDIR))"; \
		chmod 0644 "$$tmp"; \
		mv -f "$$tmp" "$(CURDIR)/k8squest-bundle.tar.gz"; \
		trap - EXIT HUP INT TERM
	@echo "Created: k8squest-bundle.tar.gz ($$(du -h k8squest-bundle.tar.gz | cut -f1))"
