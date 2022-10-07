# Makefile for rpl

all: README.md

lint:
	mypy --strict rpl
	pylint --disable=C,fixme,too-many-locals,too-many-branches,too-many-statements rpl

check:
	tox

release: lint check
	git diff --exit-code && \
	rm -rf ./dist && \
	mkdir dist && \
	python3 setup.py sdist bdist_wheel && \
	twine upload dist/* && \
	git tag v$$(python3 setup.py --version) && \
	git push --tags

README.md: rpl README.md.in Makefile
	cp README.md.in README.md
	printf '\n```\n' >> README.md
	./rpl --help >> README.md
	printf '```\n' >> README.md
