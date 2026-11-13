.PHONY: all test clean pack dist

all: test

test:
	node test/line-editor.test.js

clean:
	rm -rf dist *.tgz

pack: dist

dist:
	mkdir -p dist
	npm pack --pack-destination dist
