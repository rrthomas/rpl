# configure.ac
#
# Copyright (c) 2009-2025 Reuben Thomas

# Initialise autoconf and automake
AC_INIT([rpl],[2.0alpha3],[rrt@sc3d.org])
AC_CONFIG_AUX_DIR([build-aux])
AC_REQUIRE_AUX_FILE([tap-driver.sh])
AM_INIT_AUTOMAKE([-Wall std-options foreign])

# Checks for programs
AM_PROG_CC_C_O
AM_PROG_AR
AC_PROG_RANLIB
PKG_PROG_PKG_CONFIG
AX_CHECK_GNU_MAKE(,[AC_MSG_WARN([GNU make is required to build from Vala sources])])

# help2man and gengetopt
# Set a value even if not found, so that an invocation via build-aux/missing works
AC_PATH_PROG([HELP2MAN], [help2man], [help2man])
AC_PATH_PROG([GENGETOPT], [gengetopt], [gengetopt])

# Vala
AM_PROG_VALAC(0.52,,[AC_MSG_WARN([valac not found or too old: cannot compile Vala sources])])
PKG_CHECK_MODULES(GLIB, [glib-2.0 gio-2.0 gio-unix-2.0])

# Extra libraries
PKG_CHECK_MODULES(PCRE2, [libpcre2-8])
AC_DEFINE([PCRE2_CODE_UNIT_WIDTH], [8], [Define to select code unit width for libpcre2])
PKG_CHECK_MODULES(UCHARDET, [uchardet])

# Generate output
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_FILES([Makefile])
AC_OUTPUT
