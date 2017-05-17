GRAPHS := $(wildcard graphs/*.dot)
IMAGES := $(GRAPHS:.dot=.png)

slides.pdf: slides.tex $(IMAGES)
	pdflatex -shell-escape -interaction=nostopmode $< -o $@

.PHONY: present
present: slides.pdf
	evince -s $<

%.png: %.dot
	dot -Tpng $< -o $@
