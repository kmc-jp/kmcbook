LATEX=platex
LATEXFLAGS=-kanji=euc

kmcbook.cls: kmcclasses.ins kmcclasses.dtx
	$(LATEX) $(LATEXFLAGS) $<