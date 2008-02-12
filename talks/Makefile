# -*- coding: utf-8 -*-

## $Date: 2005-05-02 08:11:04 +0200 (Mon, 02 May 2005) $

## $Rev: 82 $

## svn propset svn:keywords "Date LastChangedRevision" ...

# svn --username k ausprobierend, denn ein ci ging nicht und ein Verdacht faellt auf den Usernamen lcuser, den ich hier habe....


# Bisher nicht erwaehnter Nachteil: keine der 3 Praesentationen kann
# derzeit UTF-8: mgp 1.09a kann es von Natur aus nicht. PDF macht es
# nicht aus unbekannten Gruenden, HTML macht es nicht, weil pod2html
# sch...wach ist. Ich muesste mein eigenes axpoint2html schreiben. Da
# ich aber nicht weiss, wie man viele Outputdateien ueber XSLT
# erstellt, ist mir das zu aufwendig.


DISTNAME = podslides-ax-magicpoint
VERSION = 0.01
DISTVNAME = $(DISTNAME)-$(VERSION)
DIST_DEFAULT = tardist
SUFFIX = .gz

# .SUFFIXES:

# .SUFFIXES: .pdf .mgp .axp .xml

# secondary marks files that are only needed temporarily. These get
# deleted when not needed anymore:

# .SECONDARY: kurs.axp kurs.xml

all:
	@echo This Makefile has only SUFFIX rules, you need to call make
	@echo with a target ending in either .pdf or .mgp, and you need to supply
	@echo a POD file ending in .pod. E.g.
	@echo
	@echo "make foo.pdf       # creates foo.pdf from foo.pod"
	@echo "make foo.mgp       # creates foo.mgp from foo.pod"
	@echo
	@echo Then you can run the presentation with either of
	@echo
	@echo acroread foo.pdf
	@echo mgp foo.mgp
	@echo
	@echo Please consult this Makefile for prerequisites.
	@echo


#
# DISTRIBUTION
#

dist : $(DIST_DEFAULT)

tardist : $(DISTVNAME).tar$(SUFFIX)

$(DISTVNAME).tar$(SUFFIX) : distdir
	tar cvf $(DISTVNAME).tar $(DISTVNAME)
	rm -rf $(DISTVNAME)
	gzip -9f $(DISTVNAME).tar

distdir :
	rm -rf $(DISTVNAME)
	mkdir $(DISTVNAME)
	perl "-MExtUtils::Manifest=manicopy,maniread" \
		-e "manicopy(maniread(),'$(DISTVNAME)', 'best');"
	cat axpoint2mgp.pod > $(DISTVNAME)/README

#
# MAGICPOINT
#

# 768x576

show:
	mgp -g 1224x930 -G kurs.mgp &

full-loop:
	while true ; do make kurs.mgp kurs.pdf kurs.html ; sleep 4 ; done > /dev/null

loop:
	while true ; do make kurs.mgp kurs.html ; sleep 4 ; done > /dev/null


html-loop:
	while true ; do make kurs2.html ; sleep 4 ; done > /dev/null


#
# IMPLICIT RULES
#

%.s5: %.xml pox2s5.xsl
	xsltproc pox2s5.xsl $*.xml > $*.s5

%.html: %.pod Makefile splithtml.pl uparrow.gif
	-perl -MPod::Simple::HTML -e Pod::Simple::HTML::go $*.pod $*.html
	perl splithtml.pl $*

%.mgp: %.axp axpoint2mgp.xsl Makefile
	xsltproc axpoint2mgp.xsl $*.axp | piconv -f utf-8 -t latin-1 > $*.mgp

%.pdf: %.axp /usr/local/share/perl/5.8.0/XML/Handler/AxPoint.pm
	axpoint $*.axp > $*.pdf

%.axp: %.xml pod2axpoint.xsl Makefile unumlaut.pl
	xsltproc pod2axpoint.xsl $*.xml  > $*.axp

#%.axp: %.xml pod2axpoint.xsl Makefile unumlaut.pl
#	xsltproc pod2axpoint.xsl $*.xml | perl unumlaut.pl > $*.axp

%.xml: %.pod pod2pox.pl
	perl pod2pox.pl $*.pod > $*.xml

%.mys5: %.xml %.html pox2mys5.pl pox2mys5.xsl
	perl pox2mys5.pl $*.xml
