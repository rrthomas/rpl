/* cmdline.vapi
 *
 * Copyright (C) 2025 Reuben Thomas <rrt@sc3d.org>
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
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, see <https://www.gnu.org/licenses/>.
 */

[CCode (cprefix = "cmdline", destroy_function = "", cheader_filename = "cmdline-vala.h")]
namespace Gengetopt {
	[CCode (cname = "gengetopt_args_info", destroy_function = "", has_type_id = false)]
	public struct ArgsInfo
	{
		const string help_help; /**< @brief Print help and exit help description.  */
		const string full_help_help; /**< @brief Print help, including hidden options, and exit help description.  */
		const string version_help; /**< @brief Print version and exit help description.  */
		string encoding_arg;	/**< @brief specify character set encoding.  */
		string encoding_orig;	/**< @brief specify character set encoding original value given at command line.  */
		const string encoding_help; /**< @brief specify character set encoding help description.  */
		const string ignore_case_help; /**< @brief search case-insensitively help description.  */
		const string match_case_help; /**< @brief ignore case when searching, but try to match case of replacement to case of original, either capitalized, all upper-case, or mixed help description.  */
		int whole_words_flag;	/**< @brief whole words (OLD-TEXT matches on word boundaries only) (default=off).  */
		const string whole_words_help; /**< @brief whole words (OLD-TEXT matches on word boundaries only) help description.  */
		int backup_flag;	/**< @brief rename original FILE to FILE~ before replacing (default=off).  */
		const string backup_help; /**< @brief rename original FILE to FILE~ before replacing help description.  */
		int quiet_flag;	/**< @brief quiet mode (default=off).  */
		const string quiet_help; /**< @brief quiet mode help description.  */
		int verbose_flag;	/**< @brief verbose mode (default=off).  */
		const string verbose_help; /**< @brief verbose mode help description.  */
		int dry_run_flag;	/**< @brief simulation mode (default=off).  */
		const string dry_run_help; /**< @brief simulation mode help description.  */
		int fixed_strings_flag;	/**< @brief treat OLD-TEXT and NEW-TEXT as fixed strings, not regular expressions (default=off).  */
		const string fixed_strings_help; /**< @brief treat OLD-TEXT and NEW-TEXT as fixed strings, not regular expressions help description.  */
		const string files_help; /**< @brief OLD-TEXT and NEW-TEXT are file names to read patterns from help description.  */
		[CCode (array_length = false)] string[] glob_arg;	/**< @brief modify only files matching the given glob (may be given more than once).  */
		[CCode (array_length = false)] string[] glob_orig;	/**< @brief modify only files matching the given glob (may be given more than once) original value given at command line.  */
		const string glob_help; /**< @brief modify only files matching the given glob (may be given more than once) help description.  */
		const string recursive_help; /**< @brief search recursively help description.  */
		const string prompt_help; /**< @brief prompt before modifying each file help description.  */
		const string force_help; /**< @brief ignore errors when trying to preserve attributes help description.  */
		const string keep_times_help; /**< @brief keep the modification times on modified files help description.  */

		bool help_given ;	/**< @brief Whether help was given.  */
		bool full_help_given ;	/**< @brief Whether full-help was given.  */
		bool version_given ;	/**< @brief Whether version was given.  */
		bool encoding_given ;	/**< @brief Whether encoding was given.  */
		bool ignore_case_given ;	/**< @brief Whether ignore-care was given.  */
		bool match_case_given ;	/**< @brief Whether match-case was given.  */
		bool whole_words_given ;	/**< @brief Whether whole-words was given.  */
		bool backup_given ;	/**< @brief Whether backup was given.  */
		bool quiet_given ;	/**< @brief Whether quiet was given.  */
		bool verbose_given ;	/**< @brief Whether verbose was given.  */
		bool dry_run_given ;	/**< @brief Whether dry-run was given.  */
		bool escape_given ;	/**< @brief Whether escape was given.  */
		bool fixed_strings_given ;	/**< @brief Whether fixed-strings was given.  */
		bool files_given ;	/**< @brief Whether files was given.  */
		uint glob_given ;	/**< @brief How many times glob was given.  */
		bool recursive_given ;	/**< @brief Whether recursive was given.  */
		bool prompt_given ;	/**< @brief Whether prompt was given.  */
		bool force_given ;	/**< @brief Whether force was given.  */
		bool keep_times_given ;	/**< @brief Whether keep-times was given.  */

		[CCode (array_length_cname = "inputs_num", array_length_type = "unsigned")]
		string[] inputs; /**< @brief unnamed options (options without names) */

		[CCode (cname = "cmdline_parser")]
		public static int parser([CCode (array_length_pos = 0.1)] string[] args, ref ArgsInfo args_info);

		[CCode (cname = "cmdline_parser_print_help")]
		public static void parser_print_help();
	}
}
