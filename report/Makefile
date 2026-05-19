PDF    = main.pdf
SRC    = main.tex
BIBTEX = bibtex

.PHONY: all clean

all: $(PDF)

$(PDF): $(SRC) references.bib
	pdflatex $(SRC)
	$(BIBTEX) main
	pdflatex $(SRC)
	pdflatex $(SRC)

clean:
	rm -f *.aux *.bbl *.blg *.log *.out *.toc *.lof *.lot $(PDF)
