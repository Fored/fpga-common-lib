.PHONY: test test-bscan lint check

PYTHON ?= python
RUFF ?= ruff

test: test-bscan

test-bscan:
	cd bscan/py && $(PYTHON) -m unittest discover -v

lint:
	$(RUFF) check bscan/py

check: lint test
