# Top-level Makefile.am
#
# Copyright (c) 2025 Reuben Thomas

ACLOCAL_AMFLAGS = -I m4

SUBDIRS = lib

include $(top_srcdir)/aminclude_static.am

AM_VALAFLAGS = --debug --vapidir=$(srcdir)
if OS_WIN32
AM_VALAFLAGS += -D WINDOWS
endif
VAPIS =	config.vapi cmdline.vapi gnu.vapi pcre2.vapi uchardet.vapi iconv.vapi

LDADD = $(top_builddir)/lib/libgnu.a $(CODE_COVERAGE_LDFLAGS)
AM_CPPFLAGS = -I$(top_srcdir)/lib -I$(top_builddir)/lib $(CODE_COVERAGE_CPPFLAGS)
AM_CFLAGS = -w

MAINTAINERCLEANFILES = rpl.1
EXTRA_DIST = \
	$(TEST_FILES) $(VAPIS) \
	opts.ggo \
	man-extras.1 \
	rpl.1 \
	cmdline-vala.h \
	build-aux/rpl-help2man-wrapper \
	m4/gnulib-cache.m4

# Ignore built files that are part of the distribution (specifically, rpl.1).
distcleancheck_listfiles = \
       find . -type f -exec sh -c 'test -f $(srcdir)/$$1 || echo $$1' \
            sh '{}' ';'

bin_PROGRAMS = rpl
if PCRE2_16_DEMO
noinst_PROGRAMS = pcre2-16-demo
endif
man_MANS = rpl.1
check_PROGRAMS = test
TESTS = test
LOG_DRIVER = \
	env AM_TAP_AWK='$(AWK)' TEST_FILES_DIR=$(top_srcdir)/test-files $(SHELL) \
	$(top_srcdir)/build-aux/tap-driver.sh
TEST_FILES = \
	$(wildcard test-files/*.txt) \
	$(wildcard test-files/*/*.txt*) \
	$(wildcard test-files/test-tree/*/*.txt) \
	$(wildcard test-files/test-tree-expected/*/*.txt)

rpl_SOURCES = rpl.vala cmdline.c cmdline.h
rpl_CFLAGS = $(AM_CFLAGS) --include config.h $(GLIB_CFLAGS) $(PCRE2_CFLAGS) $(UCHARDET_CFLAGS) $(CODE_COVERAGE_CFLAGS)
rpl_VALAFLAGS = $(AM_VALAFLAGS) --pkg config --pkg cmdline --pkg gio-2.0 --pkg posix --pkg gnu --pkg pcre2 --pkg uchardet --pkg iconv
rpl_LDADD = $(LDADD) $(GLIB_LIBS) $(PCRE2_LIBS) $(UCHARDET_LIBS)

rpl.c: cmdline.h

cmdline.h cmdline.c: $(top_srcdir)/opts.ggo
	gengetopt < $(top_srcdir)/opts.ggo --unamed-opts="OLD-TEXT NEW-TEXT [FILE...]"

pcre2_16_demo_SOURCES = pcre2-16-demo.vala
pcre2_16_demo_CFLAGS = $(AM_CFLAGS) --include config.h --include pcre2-16.h $(GLIB_CFLAGS) $(PCRE2_CFLAGS)
pcre2_16_demo_VALAFLAGS = $(AM_VALAFLAGS) --pkg pcre2
pcre2_16_demo_LDADD = $(LDADD) $(GLIB_LIBS) -lpcre2-16

test_SOURCES = test.vala testcase.vala slurp.vala
# -W flag in next line is to work around https://gitlab.gnome.org/GNOME/vala/-/issues/1413
test_CFLAGS = $(AM_CFLAGS) --include config.h $(GLIB_CFLAGS) $(PCRE2_CFLAGS) $(UCHARDET_CFLAGS) -Wno-incompatible-function-pointer-types
test_VALAFLAGS = $(AM_VALAFLAGS) --pkg config --pkg gio-2.0 --pkg pcre2 --pkg posix --pkg gnu
test_LDADD = $(LDADD) $(GLIB_LIBS) $(PCRE2_LIBS) $(UCHARDET_LIBS)

rpl.1: man-extras.1 configure.ac $(builddir)/rpl$(EXEEXT) build-aux/rpl-help2man-wrapper
## Exit gracefully if rpl.1 is not writeable, such as during distcheck!
	$(AM_V_GEN)if ( touch $@.w && rm -f $@.w; ) >/dev/null 2>&1; then \
	  $(srcdir)/build-aux/missing --run $(HELP2MAN) --output=$@ --no-info --include $(srcdir)/man-extras.1 $(top_srcdir)/build-aux/rpl-help2man-wrapper; \
	fi

CODE_COVERAGE_OUTPUT_FILE = rpl.info
CODE_COVERAGE_OUTPUT_DIRECTORY = coverage
CODE_COVERAGE_GENHTML_OPTIONS = --synthesize-missing --ignore-errors source
clean-local: code-coverage-clean
distclean-local: code-coverage-dist-clean
assert-full-coverage:
	gcovr --gcov-ignore-errors source_not_found --filter rpl.vala --fail-under-line 100 .

CLOC = cloc

loc:
	$(CLOC) *.vala $(VAPIS) Makefile.am configure.ac

release: distcheck
	git diff --exit-code && \
	git tag -a -m "Release tag" "v$(VERSION)" && \
	git push && git push --tags && \
	gh release create v$(VERSION) --title "Release v$(VERSION)" $(DIST_ARCHIVES)
