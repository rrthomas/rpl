/* pcre2.vapi
 *
 * Copyright (C) 2025 Reuben Thomas
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 * As a special exception, if you use inline functions from this file, this
 * file does not by itself cause the resulting executable to be covered by
 * the GNU Lesser General Public License.
 *
 * Author:
 *  Reuben Thomas <rrt@sc3d.org>
 */

[CCode (cprefix = "PCRE2_", lower_case_cprefix = "pcre2_", cheader_filename = "pcre2.h")]
namespace Pcre2 {
	[CCode (cprefix = "PCRE2_")]
	namespace Version {
		public const int MAJOR;
		public const int MINOR;
		public const string PRERELEASE;
		public const string DATE;
	}

	[CCode (cname = "uint32_t", cprefix = "PCRE2_", has_type_id = false)]
	[Flags]
	public enum CompileFlags {
		ANCHORED,
		NO_UTF_CHECK,
		ENDANCHORED,

		ALLOW_EMPTY_CLASS,
		ALT_BSUX,
		AUTO_CALLOUT,
		CASELESS,
		DOLLAR_ENDONLY,
		DOTALL,
		DUPNAMES,
		EXTENDED,
		FIRSTLINE,
		MATCH_UNSET_BACKREF,
		MULTILINE,
		NEVER_UCP,
		NEVER_UTF,
		NO_AUTO_CAPTURE,
		NO_AUTO_POSSESS,
		NO_DOTSTAR_ANCHOR,
		NO_START_OPTIMIZE,
		UCP,
		UNGREEDY,
		UTF,
		NEVER_BACKSLASH_C,
		ALT_CIRCUMFLEX,
		ALT_VERBNAMES,
		USE_OFFSET_LIMIT,
		EXTENDED_MORE,
		LITERAL,
		MATCH_INVALID_UTF,
	}

	[CCode (cname = "uint32_t", cprefix = "PCRE2_EXTRA_", has_type_id = false)]
	[Flags]
	public enum ExtraCompileFlags {
		ALLOW_SURROGATE_ESCAPES,
		BAD_ESCAPE_IS_LITERAL,
		MATCH_WORD,
		MATCH_LINE,
		ESCAPED_CR_IS_LF,
		ALT_BSUX,
		ALLOW_LOOKAROUND_BSK,
	}

	[CCode (cname = "uint32_t", cprefix = "PCRE2_JIT_", has_type_id = false)]
	[Flags]
	public enum JitCompileFlags {
		COMPLETE,
		PARTIAL_SOFT,
		PARTIAL_HARD,
		INVALID_UTF,
	}

	[CCode (cname = "uint32_t", cprefix = "PCRE2_", has_type_id = false)]
	[Flags]
	public enum MatchFlags {
		ANCHORED,
		NO_UTF_CHECK,
		ENDANCHORED,

		NOTBOL,
		NOTEOL,
		NOTEMPTY,
		NOTEMPTY_ATSTART,
		PARTIAL_SOFT,
		PARTIAL_HARD,
		COPY_MATCHED_SUBJECT,

		// dfa_match only
		DFA_RESTART,
		DFA_SHORTEST,

		// substitute only
		SUBSTITUTE_GLOBAL,
		SUBSTITUTE_EXTENDED,
		SUBSTITUTE_UNSET_EMPTY,
		SUBSTITUTE_UNKNOWN_UNSET,
		SUBSTITUTE_OVERFLOW_LENGTH,
		SUBSTITUTE_LITERAL,
		SUBSTITUTE_MATCHED,
		SUBSTITUTE_REPLACEMENT_ONLY,

		// not dfa_match
		NO_JIT,
	}

	// TODO:
	// /* Options for pcre2_pattern_convert(). */

	// PCRE2_CONVERT_UTF
	// PCRE2_CONVERT_NO_UTF_CHECK
	// PCRE2_CONVERT_POSIX_BASIC
	// PCRE2_CONVERT_POSIX_EXTENDED
	// PCRE2_CONVERT_GLOB
	// PCRE2_CONVERT_GLOB_NO_WILD_SEPARATOR
	// PCRE2_CONVERT_GLOB_NO_STARSTAR

	// /* Newline and \R settings, for use in compile contexts. The newline values
	// must be kept in step with values set in config.h and both sets must all be
	// greater than zero. */

	// PCRE2_NEWLINE_CR
	// PCRE2_NEWLINE_LF
	// PCRE2_NEWLINE_CRLF
	// PCRE2_NEWLINE_ANY
	// PCRE2_NEWLINE_ANYCRLF
	// PCRE2_NEWLINE_NUL

	// PCRE2_BSR_UNICODE
	// PCRE2_BSR_ANYCRLF

	/* Request types for pcre2_pattern_info() */
	[CCode (cprefix = "PCRE2_INFO_", has_type_id = false)]
	public enum PatternInfo {
		ALLOPTIONS,
		ARGOPTIONS,
		BACKREFMAX,
		BSR,
		CAPTURECOUNT,
		FIRSTCODEUNIT,
		FIRSTCODETYPE,
		FIRSTBITMAP,
		HASCRORLF,
		JCHANGED,
		JITSIZE,
		LASTCODEUNIT,
		LASTCODETYPE,
		MATCHEMPTY,
		MATCHLIMIT,
		MAXLOOKBEHIND,
		MINLENGTH,
		NAMECOUNT,
		NAMEENTRYSIZE,
		NAMETABLE,
		NEWLINE,
		DEPTHLIMIT,
		SIZE,
		HASBACKSLASHC,
		FRAMESIZE,
		HEAPLIMIT,
		EXTRAOPTIONS,
	}

	/* Request types for pcre2_config(). */
	[CCode (cprefix = "PCRE2_CONFIG_", has_type_id = false)]
	public enum Config {
		BSR,
		JIT,
		JITTARGET,
		LINKSIZE,
		MATCHLIMIT,
		NEWLINE,
		PARENSLIMIT,
		DEPTHLIMIT,
		UNICODE,
		UNICODE_VERSION,
		VERSION,
		HEAPLIMIT,
		NEVER_BACKSLASH_C,
		COMPILED_WIDTHS,
		TABLES_LENGTH,
	}

	[CCode (cprefix = "PCRE2_ERROR_", has_type_id = false)]
	public enum Error {
		END_BACKSLASH,
		END_BACKSLASH_C,
		UNKNOWN_ESCAPE,
		QUANTIFIER_OUT_OF_ORDER,
		QUANTIFIER_TOO_BIG,
		MISSING_SQUARE_BRACKET,
		ESCAPE_INVALID_IN_CLASS,
		CLASS_RANGE_ORDER,
		QUANTIFIER_INVALID,
		INTERNAL_UNEXPECTED_REPEAT,
		INVALID_AFTER_PARENS_QUERY,
		POSIX_CLASS_NOT_IN_CLASS,
		POSIX_NO_SUPPORT_COLLATING,
		MISSING_CLOSING_PARENTHESIS,
		BAD_SUBPATTERN_REFERENCE,
		NULL_PATTERN,
		BAD_OPTIONS,
		MISSING_COMMENT_CLOSING,
		PARENTHESES_NEST_TOO_DEEP,
		PATTERN_TOO_LARGE,
		HEAP_FAILED,
		UNMATCHED_CLOSING_PARENTHESIS,
		INTERNAL_CODE_OVERFLOW,
		MISSING_CONDITION_CLOSING,
		LOOKBEHIND_NOT_FIXED_LENGTH,
		ZERO_RELATIVE_REFERENCE,
		TOO_MANY_CONDITION_BRANCHES,
		CONDITION_ASSERTION_EXPECTED,
		BAD_RELATIVE_REFERENCE,
		UNKNOWN_POSIX_CLASS,
		INTERNAL_STUDY_ERROR,
		UNICODE_NOT_SUPPORTED,
		PARENTHESES_STACK_CHECK,
		CODE_POINT_TOO_BIG,
		LOOKBEHIND_TOO_COMPLICATED,
		LOOKBEHIND_INVALID_BACKSLASH_C,
		UNSUPPORTED_ESCAPE_SEQUENCE,
		CALLOUT_NUMBER_TOO_BIG,
		MISSING_CALLOUT_CLOSING,
		ESCAPE_INVALID_IN_VERB,
		UNRECOGNIZED_AFTER_QUERY_P,
		MISSING_NAME_TERMINATOR,
		DUPLICATE_SUBPATTERN_NAME,
		INVALID_SUBPATTERN_NAME,
		UNICODE_PROPERTIES_UNAVAILABLE,
		MALFORMED_UNICODE_PROPERTY,
		UNKNOWN_UNICODE_PROPERTY,
		SUBPATTERN_NAME_TOO_LONG,
		TOO_MANY_NAMED_SUBPATTERNS,
		CLASS_INVALID_RANGE,
		OCTAL_BYTE_TOO_BIG,
		INTERNAL_OVERRAN_WORKSPACE,
		INTERNAL_MISSING_SUBPATTERN,
		DEFINE_TOO_MANY_BRANCHES,
		BACKSLASH_O_MISSING_BRACE,
		INTERNAL_UNKNOWN_NEWLINE,
		BACKSLASH_G_SYNTAX,
		PARENS_QUERY_R_MISSING_CLOSING,
		VERB_UNKNOWN,
		SUBPATTERN_NUMBER_TOO_BIG,
		SUBPATTERN_NAME_EXPECTED,
		INTERNAL_PARSED_OVERFLOW,
		INVALID_OCTAL,
		SUBPATTERN_NAMES_MISMATCH,
		MARK_MISSING_ARGUMENT,
		INVALID_HEXADECIMAL,
		BACKSLASH_C_SYNTAX,
		BACKSLASH_K_SYNTAX,
		INTERNAL_BAD_CODE_LOOKBEHINDS,
		BACKSLASH_N_IN_CLASS,
		CALLOUT_STRING_TOO_LONG,
		UNICODE_DISALLOWED_CODE_POINT,
		UTF_IS_DISABLED,
		UCP_IS_DISABLED,
		VERB_NAME_TOO_LONG,
		BACKSLASH_U_CODE_POINT_TOO_BIG,
		MISSING_OCTAL_OR_HEX_DIGITS,
		VERSION_CONDITION_SYNTAX,
		INTERNAL_BAD_CODE_AUTO_POSSESS,
		CALLOUT_NO_STRING_DELIMITER,
		CALLOUT_BAD_STRING_DELIMITER,
		BACKSLASH_C_CALLER_DISABLED,
		QUERY_BARJX_NEST_TOO_DEEP,
		BACKSLASH_C_LIBRARY_DISABLED,
		PATTERN_TOO_COMPLICATED,
		LOOKBEHIND_TOO_LONG,
		PATTERN_STRING_TOO_LONG,
		INTERNAL_BAD_CODE,
		INTERNAL_BAD_CODE_IN_SKIP,
		NO_SURROGATES_IN_UTF16,
		BAD_LITERAL_OPTIONS,
		SUPPORTED_ONLY_IN_UNICODE,
		INVALID_HYPHEN_IN_OPTIONS,
		ALPHA_ASSERTION_UNKNOWN,
		SCRIPT_RUN_NOT_AVAILABLE,
		TOO_MANY_CAPTURES,
		CONDITION_ATOMIC_ASSERTION_EXPECTED,
		BACKSLASH_K_IN_LOOKAROUND,

		/* "Expected" matching error codes: no match and partial match. */

		NOMATCH,
		PARTIAL,

		/* Error codes for UTF-8 validity checks */

		UTF8_ERR1,
		UTF8_ERR2,
		UTF8_ERR3,
		UTF8_ERR4,
		UTF8_ERR5,
		UTF8_ERR6,
		UTF8_ERR7,
		UTF8_ERR8,
		UTF8_ERR9,
		UTF8_ERR10,
		UTF8_ERR11,
		UTF8_ERR12,
		UTF8_ERR13,
		UTF8_ERR14,
		UTF8_ERR15,
		UTF8_ERR16,
		UTF8_ERR17,
		UTF8_ERR18,
		UTF8_ERR19,
		UTF8_ERR20,
		UTF8_ERR21,

		/* Error codes for UTF-16 validity checks */

		UTF16_ERR1,
		UTF16_ERR2,
		UTF16_ERR3,

		/* Error codes for UTF-32 validity checks */

		UTF32_ERR1,
		UTF32_ERR2,

		/* Miscellaneous error codes for pcre2[_dfa]_match(), substring extraction
		   functions, context functions, and serializing functions. */

		BADDATA,
		MIXEDTABLES,
		BADMAGIC,
		BADMODE,
		BADOFFSET,
		BADOPTION,
		BADREPLACEMENT,
		BADUTFOFFSET,
		DFA_BADRESTART,
		DFA_RECURSE,
		DFA_UCOND,
		DFA_UFUNC,
		DFA_UITEM,
		DFA_WSSIZE,
		INTERNAL,
		JIT_BADOPTION,
		JIT_STACKLIMIT,
		MATCHLIMIT,
		NOMEMORY,
		NOSUBSTRING,
		NOUNIQUESUBSTRING,
		NULL,
		RECURSELOOP,
		DEPTHLIMIT,
		UNAVAILABLE,
		UNSET,
		BADOFFSETLIMIT,
		BADREPESCAPE,
		REPMISSINGBRACE,
		BADSUBSTITUTION,
		BADSUBSPATTERN,
		TOOMANYREPLACE,
		BADSERIALIZEDDATA,
		HEAPLIMIT,
		CONVERT_SYNTAX,
		INTERNAL_DUPMATCH,
		DFA_UINVALID_UTF,
	}

	[Compact]
	[CCode (cprefix = "pcre2_", cname = "pcre2_code", free_function = "pcre2_code_free")]
	public class Regex {
		public static Regex? compile ([CCode (array_length_type = "size_t")] uint8[] pattern, CompileFlags options, out int errorcode, out size_t error_offset, CompileContext? ccontext = null);

		[CCode (cname = "pcre2_copy_code")]
		public Regex dup ();

		[CCode (cname = "pcre2_copy_code_with_tables")]
		public Regex dup_with_tables ();

		// TODO:
		//  #define PCRE2_PATTERN_INFO_FUNCTIONS \
		//  PCRE2_EXP_DECL int PCRE2_CALL_CONVENTION \
		//    pcre2_pattern_info(const pcre2_code *, uint32_t, void *); \
		//  PCRE2_EXP_DECL int PCRE2_CALL_CONVENTION \
		//    pcre2_callout_enumerate(const pcre2_code *, \
		//      int (*)(pcre2_callout_enumerate_block *, void *), void *);

		[CCode (cname = "pcre2_match_data_create_from_pattern")]
		private Match? create_match (void *gcontext = null);

		[CCode (cname = "pcre2_match")]
		private int _match (uint8* subject, size_t subject_len, size_t startoffset, MatchFlags options, Match match_data, void *mcontext = null);

		[CCode (cname = "_vala_pcre2_match")]
		public Match? match (GLib.StringBuilder subject, size_t startoffset, uint32 options, out int rc) {
			var match = create_match ();
			if (match == null) {
				rc = Error.NOMEMORY;
				return null;
			}
			rc = _match (subject.data, subject.len, startoffset, options, match);
			return match;
		}

		// TODO:
		//  PCRE2_EXP_DECL int PCRE2_CALL_CONVENTION \
		//    pcre2_dfa_match(const pcre2_code *, PCRE2_SPTR, PCRE2_SIZE, PCRE2_SIZE, \
		//      uint32_t, pcre2_match_data *, pcre2_match_context *, int *, PCRE2_SIZE); \

		[CCode (cname = "pcre2_substitute")]
		public int _substitute (
								 uint8* subject, size_t subject_len, size_t startoffset,
								 MatchFlags options, Match match, void *mcontext,
								 uint8* replacement, size_t replacement_len,
								 uint8* outputbuffer, ref size_t outlength
								);

		[CCode (cname = "_vala_pcre2_substitute")]
		public GLib.StringBuilder substitute (GLib.StringBuilder subject, size_t startoffset, MatchFlags options, Match match, GLib.StringBuilder replacement, out int rc) {
			size_t outlength = subject.len + replacement.len;
			var output = new GLib.StringBuilder.sized(outlength);
			rc = _substitute(subject.data, subject.len, startoffset, options, match, null, replacement.data, replacement.len, output.data, ref outlength);
			if (rc == Error.NOMEMORY) {
				output = new GLib.StringBuilder.sized(outlength);
				rc = _substitute(subject.data, subject.len, startoffset, options, match, null, replacement.data, replacement.len, output.data, ref outlength);
				GLib.assert(rc != Error.NOMEMORY);
			}
			output.len = (ssize_t) outlength;
			return output;
		}

		// TODO:
		//  #define PCRE2_JIT_FUNCTIONS \
		//  PCRE2_EXP_DECL int PCRE2_CALL_CONVENTION \
		//    pcre2_jit_compile(pcre2_code *, JitCompileFlags); \
		//  PCRE2_EXP_DECL int PCRE2_CALL_CONVENTION \
		//    pcre2_jit_match(const pcre2_code *, PCRE2_SPTR, PCRE2_SIZE, PCRE2_SIZE, \
		//      uint32_t, pcre2_match_data *, pcre2_match_context *); \
	}

	[Compact]
	[CCode (cprefix = "pcre2_", cname = "pcre2_compile_context", free_function = "pcre2_compile_context_free")]
	public class CompileContext {
		[CCode (cname = "pcre2_compile_context_create")]
		public CompileContext (void *gcontext = null);

		// TODO:
		// #define PCRE2_COMPILE_CONTEXT_FUNCTIONS			   \
		// PCRE2_EXP_DECL pcre2_compile_context *PCRE2_CALL_CONVENTION	\
		//   pcre2_compile_context_copy(pcre2_compile_context *);		\
		// PCRE2_EXP_DECL void PCRE2_CALL_CONVENTION					\
		//   pcre2_compile_context_free(pcre2_compile_context *);		\
		// PCRE2_EXP_DECL int PCRE2_CALL_CONVENTION						\
		//   pcre2_set_bsr(pcre2_compile_context *, uint32_t);			\
		// PCRE2_EXP_DECL int PCRE2_CALL_CONVENTION						\
		//   pcre2_set_character_tables(pcre2_compile_context *, const uint8_t *); \

		[CCode (cname = "pcre2_set_compile_extra_options")]
		public int set_extra_options (ExtraCompileFlags options);

		// PCRE2_EXP_DECL int PCRE2_CALL_CONVENTION						\
		//   pcre2_set_compile_extra_options(pcre2_compile_context *, uint32_t); \
		// PCRE2_EXP_DECL int PCRE2_CALL_CONVENTION						\
		//   pcre2_set_max_pattern_length(pcre2_compile_context *, PCRE2_SIZE); \
		// PCRE2_EXP_DECL int PCRE2_CALL_CONVENTION						\
		//   pcre2_set_newline(pcre2_compile_context *, uint32_t);		\
		// PCRE2_EXP_DECL int PCRE2_CALL_CONVENTION						\
		//   pcre2_set_parens_nest_limit(pcre2_compile_context *, uint32_t); \
		// PCRE2_EXP_DECL int PCRE2_CALL_CONVENTION						\
		//   pcre2_set_compile_recursion_guard(pcre2_compile_context *, \
		//     int (*)(uint32_t, void *), void *);
	}

	[Compact]
	[CCode (cprefix = "pcre2_", cname = "pcre2_match_data", free_function = "pcre2_match_data_free")]
	public class Match {
		[CCode (cname = "pcre2_match_data_create")]
		public Match (uint32 ovecsize = 0, CompileContext? ccontext = null);

		[CCode (cname = "pcre2_get_ovector_count")]
		private uint32 ovector_count ();

		[CCode (cname = "pcre2_get_ovector_pointer")]
		private size_t *ovector_pointer ();

		// This only gives access to the first two-thirds of the ovector,
		// which contains the match and capture offsets.
		private size_t[] ovector {
			get {
				unowned size_t[] vec = (size_t[]) ovector_pointer ();
				vec.length = (int) ovector_count() * 2;
				return vec;
			}
		}

		public size_t group_start(uint32 n) {
			if (n > ovector_count()) {
				return size_t.MAX;
			}
			return ovector[n * 2];
		}

		public size_t group_end(uint32 n) {
			if (n > ovector_count()) {
				return size_t.MAX;
			}
			return ovector[n * 2 + 1];
		}

		// TODO:
		//    PCRE2_EXP_DECL int PCRE2_CALL_CONVENTION \
		//		pcre2_dfa_match(const pcre2_code *, PCRE2_SPTR, PCRE2_SIZE, PCRE2_SIZE, \
		//		  uint32_t, pcre2_match_data *, pcre2_match_context *, int *, PCRE2_SIZE); \
		//    PCRE2_EXP_DECL PCRE2_SPTR PCRE2_CALL_CONVENTION \
		//		pcre2_get_mark(pcre2_match_data *); \
		//    PCRE2_EXP_DECL PCRE2_SIZE PCRE2_CALL_CONVENTION \
		//		pcre2_get_match_data_size(pcre2_match_data *); \
		//    PCRE2_EXP_DECL PCRE2_SIZE PCRE2_CALL_CONVENTION \
		//		pcre2_get_startchar(pcre2_match_data *);
	}

	[CCode (cname = "pcre2_get_error_message")]
	private int _get_error_message(int errorcode, [CCode (array_length_type = "size_t")] uint8[] outputbuffer);

	[CCode (cname = "_vala_pcre2_get_error_message")]
	public string get_error_message(int errorcode) {
		var msg = new uint8[256]; // 120 said to be "ample" in PCRE2 documentation.
		int rc = _get_error_message(errorcode, msg);
		if (rc < 0) {
			return "Error getting error message!";
		}
		return (string) msg;
	}
}
