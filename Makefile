LATEX=platex

TARGET=kmcbook.cls
SOURCE=kmcclasses.ins

$(TARGET): $(SOURCE)
	$(LATEX) $<