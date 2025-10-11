# configure.ac
#
# Copyright (c) 2009-2025 Reuben Thomas

# Initialise autoconf and automake
AC_INIT([rpl],[2.0.1],[rrt@sc3d.org])
AC_CONFIG_AUX_DIR([build-aux])
AC_REQUIRE_AUX_FILE([tap-driver.sh])
AM_INIT_AUTOMAKE([-Wall std-options foreign])

# Checks for programs
AM_PROG_CC_C_O
gl_EARLY
AM_PROG_AR
AC_PROG_RANLIB
PKG_PROG_PKG_CONFIG
AX_CHECK_GNU_MAKE(,[AC_MSG_WARN([GNU make is required to build from Vala sources])])
AX_CODE_COVERAGE

# help2man and gengetopt
# Set a value even if not found, so that an invocation via build-aux/missing works
AC_PATH_PROG([HELP2MAN], [help2man], [help2man])
AC_PATH_PROG([GENGETOPT], [gengetopt], [gengetopt])

# Vala
AM_PROG_VALAC(0.56,,[AC_MSG_WARN([valac not found or too old: cannot compile Vala sources])])
PKG_CHECK_MODULES(GLIB, [glib-2.0 gio-2.0])

# Detect Windows
AC_MSG_CHECKING([for native Win32])
native_win32=no
case "$host" in
  *-*-mingw*)
    native_win32=yes
    ;;
esac
AC_MSG_RESULT([$native_win32])
AM_CONDITIONAL(OS_WIN32, test "$native_win32" = yes)

# Initialize gnulib
gl_INIT

# Extra libraries
AC_ARG_WITH([old-pcre],
  [AS_HELP_STRING([--with-old-pcre], [allow the use of PCRE >= 10.35])],
  [case $withval in
     yes)    pcre_min_version=10.35 ;;
     no)     ;;
     *)      AC_MSG_ERROR([bad value $withval for old-pcre option]) ;;
   esac
   pcre_min_version=$withval],
   [pcre_min_version=10.45])
PKG_CHECK_MODULES(PCRE2, [libpcre2-8 >= $pcre_min_version])
AC_DEFINE([PCRE2_CODE_UNIT_WIDTH], [8], [Define to select code unit width for libpcre2])
PKG_CHECK_MODULES(UCHARDET, [uchardet])

# PCRE2 16-bit flavor demo
AC_ARG_WITH([16bit-demo],
  [AS_HELP_STRING([--with-16bit-demo], [build PCRE2 16-bit flavor demo])],
  [case $withval in
     yes|no) ;;
     *)      AC_MSG_ERROR([bad value $withval for old-pcre option]) ;;
   esac
   with_16bit_demo=$withval],
   [with_16bit_demo=no])
AM_CONDITIONAL([PCRE2_16_DEMO], [test "$with_16bit_demo" = yes])

# Generate output
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_FILES([Makefile lib/Makefile])
AC_OUTPUT

# Warn if PCRE is too old for \1 syntax
pcre_version=$(pkg-config --modversion libpcre2-8)
AS_VERSION_COMPARE([$pcre_version], [10.45],
  [AC_MSG_WARN([libpcre2 $pcre_version too old for \1 capture reference syntax (needs 10.45) but using anyway])])
