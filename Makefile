TESTER := $(shell whereis raku-test-all zef | cut -d ' ' -f 2 -s | head -n 1)

install-deps:
	zef --depsonly install .

test: install-deps
	$(TESTER) --verbose test .

install:
	zef install .

all: test

push: test
	git push
