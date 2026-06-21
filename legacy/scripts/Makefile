.PHONY: format typecheck lint test check clean

UV ?= uv

format:
	$(UV) run ruff check . --fix
	$(UV) run ruff format .

typecheck:
	$(UV) run mypy

lint:
	$(UV) run ruff check .

test:
	$(UV) run pytest

check: lint typecheck test

clean:
	rm -rf .mypy_cache .pytest_cache .ruff_cache
	find . -type d -name __pycache__ -prune -exec rm -rf {} +
