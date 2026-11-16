.PHONY: build test sample

build:
	mkdir -p build && cat src/dora.sml src/main.sml > build/all.sml && polyc -o build/dora-ict-register build/all.sml 2>/dev/null

test: build
	echo 'use "src/dora.sml"; use "tests/tests.sml";' | poly -q && bash tests/cli.sh

sample: build
	mkdir -p docs site
	build/dora-ict-register examples --today 2026-11-16 > docs/sample-output.txt; true
	build/dora-ict-register examples --today 2026-11-16 --tsv > docs/sample-output.tsv; true
	python3 scripts/site.py docs/sample-output.tsv site/index.html "dora-ict-register" "Checks a DORA register of information on ICT third-party providers: missing exit plans, audit rights, LEIs, non-EEA data location and expiring contracts. Standard ML." "Synthetic data."
