# Makefile for rpl maintainer tasks

all: README.md

dist: all
	git diff --exit-code && \
	rm -rf ./dist && \
	mkdir dist && \
	python -m build

test:
	tox

release:
	make test
	make dist
	version=$$(grep version pyproject.toml | grep -o "[0-9.]\+") && \
	twine upload dist/* && \
	gh release create v$$version --title "Release v$$version" dist/*

README.md: rpl README.md.in Makefile
	cp README.md.in README.md
	printf '\n```\n' >> README.md
	PYTHONPATH=. python -m rpl --help >> README.md
	printf '```\n' >> README.md
