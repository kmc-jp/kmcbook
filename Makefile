LATEX=platex
LATEXFLAGS=-kanji=utf8

kmcbook.cls: kmcclasses.ins kmcclasses.dtx
	$(LATEX) $(LATEXFLAGS) $<