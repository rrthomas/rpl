# Top-level Makefile.am
#
# Copyright (c) 2025 Reuben Thomas

ACLOCAL_AMFLAGS = -I m4

AM_VALAFLAGS = --debug --vapidir=$(srcdir)
VAPIS =	config.vapi cmdline.vapi pcre2.vapi uchardet.vapi iconv.vapi

MAINTAINERCLEANFILES = rpl.1
EXTRA_DIST = \
	$(TEST_FILES) $(VAPIS) \
	opts.ggo \
	man-extras.1 \
	rpl.1 \
	cmdline-vala.h \
	build-aux/rpl-help2man-wrapper

# Ignore built files that are part of the distribution (specifically, rpl.1).
distcleancheck_listfiles = \
       find . -type f -exec sh -c 'test -f $(srcdir)/$$1 || echo $$1' \
            sh '{}' ';'

bin_PROGRAMS = rpl
man_MANS = rpl.1
check_PROGRAMS = test
TESTS = test
LOG_DRIVER = env AM_TAP_AWK='$(AWK)' TEST_FILES_DIR=$(top_srcdir)/test-files $(SHELL) \
				$(top_srcdir)/build-aux/tap-driver.sh
TEST_FILES = \
	test-files/aba.txt \
	test-files/abc-123.txt \
	test-files/lorem.txt \
	test-files/mixed-case.txt \
	test-files/lorem-iso-8859-1.txt \
	test-files/lorem-utf-8.txt \
	test-files/utf-8-sig.txt

rpl_SOURCES = rpl.vala slurp.vala cmdline.c cmdline.h
rpl_CFLAGS = --include config.h $(GLIB_CFLAGS) $(PCRE2_CFLAGS) $(UCHARDET_CFLAGS)
rpl_VALAFLAGS = $(AM_VALAFLAGS) --pkg config --pkg cmdline --pkg gio-2.0 --pkg gio-unix-2.0 --pkg posix --pkg pcre2 --pkg uchardet --pkg iconv
rpl_LDADD = $(LDADD) $(GLIB_LIBS) $(PCRE2_LIBS) $(UCHARDET_LIBS)

rpl.c: cmdline.h

cmdline.h cmdline.c: $(top_srcdir)/opts.ggo
	gengetopt < $(top_srcdir)/opts.ggo --unamed-opts="OLD-TEXT NEW-TEXT [FILE...]"

test_SOURCES = test.vala testcase.vala slurp.vala
# -W flag in next line is to work around https://gitlab.gnome.org/GNOME/vala/-/issues/1413
test_CFLAGS = --include config.h $(GLIB_CFLAGS) $(PCRE2_CFLAGS) $(UCHARDET_CFLAGS) -Wno-incompatible-function-pointer-types
test_VALAFLAGS = $(AM_VALAFLAGS) --pkg config --pkg gio-2.0 --pkg gio-unix-2.0 --pkg pcre2 --pkg posix
test_LDADD = $(LDADD) $(GLIB_LIBS) $(PCRE2_LIBS) $(UCHARDET_LIBS)

rpl.1: man-extras.1 configure.ac $(builddir)/rpl$(EXEEXT) build-aux/rpl-help2man-wrapper
## Exit gracefully if rpl.1 is not writeable, such as during distcheck!
	$(AM_V_GEN)if ( touch $@.w && rm -f $@.w; ) >/dev/null 2>&1; then \
	  $(srcdir)/build-aux/missing --run $(HELP2MAN) --output=$@ --no-info --include $(srcdir)/man-extras.1 $(top_srcdir)/build-aux/rpl-help2man-wrapper; \
	fi

CLOC = cloc

loc:
	$(CLOC) *.vala $(VAPIS) Makefile.am configure.ac

release: distcheck
	git diff --exit-code && \
	git tag -a -m "Release tag" "v$(VERSION)" && \
	git push && git push --tags && \
	gh release create v$(VERSION) --title "Release v$(VERSION)" $(DIST_ARCHIVES)
