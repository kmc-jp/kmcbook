LATEX=platex

kmcbook.cls: kmcclasses.ins kmcclasses.dtx
	$(LATEX) $<