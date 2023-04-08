# Makefile for rpl maintainer tasks

all: README.md

dist: all
	rm -rf ./dist && \
	mkdir dist && \
	python -m build

test:
	tox && \
	git diff --exit-code

release:
	make test
	make dist
	twine upload dist/* && \
	git tag v$$(python3 setup.py --version) && \
	git push --tags

README.md: rpl README.md.in Makefile
	cp README.md.in README.md
	printf '\n```\n' >> README.md
	PYTHONPATH=. python -m rpl --help >> README.md
	printf '```\n' >> README.md
