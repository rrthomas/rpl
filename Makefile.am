# Top-level Makefile.am
#
# Copyright (c) 2025 Reuben Thomas

ACLOCAL_AMFLAGS = -I m4

SUBDIRS = lib

include $(top_srcdir)/aminclude_static.am

AM_VALAFLAGS = --debug --vapidir=$(srcdir) --vapidir=$(srcdir)/vala-extra-vapis
if OS_WIN32
AM_VALAFLAGS += -D WINDOWS
endif
<<<<<<< HEAD
VAPIS =	config.vapi cmdline.vapi gnu.vapi pcre2.vapi
=======
VAPIS =	gnu.vapi
>>>>>>> 0e2db14 (Rewrite rpl in Go (WIP))

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

test_SOURCES = test.vala testcase.vala slurp.vala
# -W flag in next line is to work around https://gitlab.gnome.org/GNOME/vala/-/issues/1413
test_CFLAGS = $(AM_CFLAGS) --include config.h $(GLIB_CFLAGS) -Wno-incompatible-function-pointer-types
test_VALAFLAGS = $(AM_VALAFLAGS) --pkg gio-2.0 --pkg posix --pkg gnu
test_LDADD = $(LDADD) $(GLIB_LIBS)

# FIXME:
# assert-full-coverage:
# 	gcovr --gcov-ignore-errors source_not_found --filter rpl.vala --fail-under-line 100 .

CLOC = cloc

loc:
	$(CLOC) *.go cmd/ Makefile.am configure.ac

release: distcheck
	git diff --exit-code && \
	git tag -a -m "Release tag" "v$(VERSION)" && \
	git push && git push --tags && \
	gh release create v$(VERSION) --title "Release v$(VERSION)" $(DIST_ARCHIVES)
