/*
Copyright © 2025 Reuben Thomas <rrt@sc3d.org>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.
*/
package cmd

import (
	"bufio"
	"bytes"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"syscall"

	"github.com/Jemmic/go-pcre2"
	"github.com/famz/SetLocale"
	"github.com/spf13/cobra"
	"golang.org/x/term"
)

func info(msg string) {
	fmt.Fprintln(os.Stderr, msg)
}

func warn(msg string) {
	info(fmt.Sprintf("%s: %s\n", programName, msg))
}

func die(code int, msg string) {
	warn(msg)
	os.Exit(code)
}

// TODO: enum Case { LOWER, UPPER, CAPITALIZED, MIXED }

// A suitable buffer size for stream I/O.
// const streamBufSize = 1024 * 1024

func removeTempFile(tmpPath string) {
	if err := os.Remove(tmpPath); err != nil {
		warn(fmt.Sprintf("error removing temporary file %s: %s", tmpPath, err.Error()))
	}
}

func getDirTree(root string) []string {
	results := []string{}
	filepath.WalkDir(root, func(path string, file fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if path != root {
			if file.IsDir() {
				childPath := filepath.Join(filepath.Dir(path), file.Name())
				results = append(results, getDirTree(childPath)...)
			} else {
				results = append(results, path)
			}
		}
		return nil
	})
	return results
}

func replace(input *os.File, inputFilename string, output *os.File, oldRegex *pcre2.Regexp, replaceOpts uint32, newPattern string) (int, error) { // TODO iconv
	// lookbehind := false // FIXME
	numMatches := 0
	// const maxLookbehindBytes = 255 * 6 // 255 characters (PCRE2's hardwired limit) in UTF-8.
	// bufSize := streamBufSize
	// retryPrefix := ""
	atBob := false

	// TODO: helper function to read input
	buf := new(bytes.Buffer)
	buf.ReadFrom(input)
	searchStr := buf.String()

	// TODO: helper function to write output

	// tonext := ""
	lookbehindMargin := ""
	matcher := oldRegex.NewMatcher()
	nRead := 0

	var result string
	matchFrom := len(lookbehindMargin)
	endPos := matchFrom
	doPartial := uint32(0)
	if nRead > 0 {
		doPartial = pcre2.PARTIAL_HARD
	}
	notbol := uint32(0)
	if !atBob {
		notbol = pcre2.NOTBOL
	}
	// for {
	// Do match, and return on error.
	rc := matcher.ExecString(searchStr, doPartial|notbol)
	if rc < 0 && rc != pcre2.ERROR_NOMATCH && rc != pcre2.ERROR_PARTIAL {
		warn(fmt.Sprintf("%s: %s", inputFilename, matcher.GetError()))
	}

	// Append unmatched input to result.
	startPos := len(searchStr)
	if rc != pcre2.ERROR_NOMATCH {
		startPos = matcher.GroupIndices(0)[0]
	}
	// FIXME result += searchStr[endPos:startPos]
	endPos = matcher.GroupIndices(0)[1]

	// TODO: If the match is zero-width and at the end of the buffer, but
	// not the end of the input, treat it as partial.

	// TODO: If we didn't get a match, break for more input
	switch rc {
	case pcre2.ERROR_NOMATCH:
		return -1, nil // break
	case pcre2.ERROR_PARTIAL:
		// TODO: For a partial match, copy text to re-match and grow buffer.
	}

	// Perform substitutions.
	replacement := oldRegex.ReplaceAllString(searchStr, newPattern, replaceOpts|pcre2.NOTEMPTY|pcre2.NO_UTF_CHECK)
	// TODO: detect and report errors.

	// TODO: Match case of replacement to case of original if required.

	// Add replacement to result.
	result += replacement

	// Move past the match.
	numMatches += 1 // FIXME
	matchFrom = endPos
	if startPos == endPos {
		// If we're at the end of the input, break.
		if endPos == len(searchStr) {
			return -1, nil // break
		}
		matchFrom += 1 // FIXME: advance by one character
	}
	// }

	// TODO: If we're using lookbehind, keep some of the buffer for next time.

	if output != nil {
		// Write output.
		// TODO: iconv
		output.WriteString(result)
	}

	atBob = false

	return numMatches, nil
}

func slurpPatterns(filename string) string {
	var bytes []byte
	var err error
	if bytes, err = os.ReadFile(filename); err == nil {
	} else {
		die(1, fmt.Sprintf("error reading pattern file %s", filename))
	}
	return string(bytes)
}

func main(cmd *cobra.Command, args []string) {
	programName = cmd.Name()

	files := args[2:]
	if len(files) == 0 {
		if recursive {
			die(1, "cannot use --recursive with no file arguments!")
		}
		files = append(files, "-")
	} else {
		// If we used --recursive, expand the list of files.
		if recursive {
			expandedFiles := []string{}
			for _, file := range files {
				if perms, err := os.Lstat(file); err == nil {
					if perms.IsDir() {
						expandedFiles = append(expandedFiles, getDirTree(file)...)
					} else {
						expandedFiles = append(expandedFiles, file)
					}
				}
			}
			files = expandedFiles
		}
	}

	// TODO: Apply any globs.

	// Check we do have some files to process.
	if len(files) == 0 {
		die(1, "the given filename patterns did not match any files!")
	}

	// Get old and new text patterns.
	var oldText string
	var newText string
	if patternFiles {
		oldText = slurpPatterns(args[0])
		newText = slurpPatterns(args[1])
	} else {
		oldText = args[0]
		newText = args[1]
	}

	// Tell the user what is going to happen
	if !quiet {
		replacingMsg := "replacing"
		if dryRun {
			replacingMsg = "simulating replacement of"
		}
		caseMsg := "case sensitive"
		if ignoreCase {
			caseMsg = "ignoring case"
		} else if matchCase {
			caseMsg = "matching case"
		}
		wholeWordsMsg := "partial words matched"
		if wholeWords {
			wholeWordsMsg = "whole words only"
		}
		warn(fmt.Sprintf("%s \"%s\" with \"%s\" (%s; %s)", replacingMsg, oldText, newText, caseMsg, wholeWordsMsg))
	}

	if dryRun && !quiet {
		warn("the files listed below would be modified in a replace operation")
	}

	// FIXME
	// var extraOptions uint32 = 0
	// if wholeWords {
	// 	extraOptions |= pcre2.EXTRA_MATCH_WORD
	// }

	var opts uint32 = pcre2.MULTILINE | pcre2.UTF | pcre2.UCP
	replaceOpts := uint32(0)
	if fixedStrings {
		opts = pcre2.LITERAL //  Override default options, which are incompatible with LITERAL.
		// FIXME: replaceOpts |= pcre2.SUBSTITUTE_LITERAL
	}
	if ignoreCase || matchCase {
		opts |= pcre2.CASELESS
	}
	regex, err := pcre2.Compile(oldText, opts)
	if err != nil {
		die(1, fmt.Sprintf("bad regex %s (%s)", oldText, err.Error()))
	}
	if err := regex.JITCompile(pcre2.JIT_COMPLETE | pcre2.JIT_PARTIAL_HARD); err != nil && verbose {
		warn("JIT compilation of regular expression failed")
	}

	// Process files
	totalFiles := uint(0)
	matchedFiles := uint(0)
	totalMatches := 0
	for _, filename := range files {
		havePerms := false
		var perms os.FileInfo
		var input *os.File
		var output *os.File
		tmpPath := ""
		if filename == "-" {
			filename = "standard input"
			// TODO Gnu.set_binary_mode(os.Stdin, O_BINARY)
			input = os.Stdin
			// TODO Gnu.set_binary_mode(os.Stdout, O_BINARY)
			output = os.Stdout
		} else {
			// Check `filename` is a regular file, and get its permissions
			if perms, err = os.Lstat(filename); err != nil {
				warn(fmt.Sprintf("skipping %s: %s", filename, err.Error()))
				continue
			}
			havePerms = true
			if perms.IsDir() {
				warn(fmt.Sprintf("skipping directory %s", filename))
				continue
			} else if !perms.Mode().IsRegular() {
				warn(fmt.Sprintf("skipping %s: not a regular file", filename))
				continue
			}

			// Open the input file
			if input, err = os.Open(filename); err != nil {
				warn(fmt.Sprintf("skipping %s: %s", filename, err.Error()))
				continue
			}

			// Create the output file
			if dryRun {
				output = nil
			} else {
				output, err = os.CreateTemp(filepath.Dir(filename), ".tmp.rpl-")
				if err != nil {
					warn(fmt.Sprintf("skipping %s: cannot create temp file: %s", filename, err.Error()))
					continue
				}
				tmpPath = output.Name()

				// Set permissions and owner
				if stat, ok := perms.Sys().(*syscall.Stat_t); ok {
					if err = os.Chown(tmpPath, int(stat.Uid), int(stat.Gid)); err != nil {
						err = os.Chmod(tmpPath, perms.Mode().Perm())
					}
					if err != nil {
						warn(fmt.Sprintf("unable to set attributes of %s: %s", filename, err.Error()))
						if force {
							warn("new file attributes may not match!")
						} else {
							warn(fmt.Sprintf("skipping %s", filename))
							removeTempFile(tmpPath)
							continue
						}
					}
				}
			}
		}

		totalFiles += 1

		if verbose && !dryRun {
			warn(fmt.Sprintf("processing %s", filename))
		}

		encoding := "UTF-8" // TODO: If we don't have an explicit encoding, guess

		// Process the file
		var numMatches = 0
		if encoding != "" {
			// TODO: set up iconv
		}
		if numMatches, err = replace(input, filename, output, regex, replaceOpts, newText); err != nil {
			warn(fmt.Sprintf("error processing %s: %s; skipping!", filename, err.Error()))
			input.Close()
			numMatches = -1
		}
		// TODO: tear down iconv

		if err = input.Close(); err != nil {
			warn(fmt.Sprintf("error closing %s: %s", filename, err.Error()))
		}
		if output != nil {
			if err = output.Close(); err != nil {
				warn(fmt.Sprintf("error closing output: %s", err.Error()))
			}
		}

		// Delete temporary file if either we had an error (numMatches < 0)
		// or nothing changed (numMatches == 0).
		if numMatches <= 0 {
			if tmpPath != "" {
				removeTempFile(tmpPath)
			}
			continue
		}
		matchedFiles += 1

		if prompt {
			fmt.Fprintf(os.Stderr, "\nUpdate \"%s\"? [Y/n] ", filename)

			line := ""
			reader := bufio.NewReader((os.Stdin))
			for ok := true; ok; ok = err != nil && line != "" && !strings.Contains("YyNn", string([]rune(line)[0:1])) {
				line, err = reader.ReadString('\n')
			}
			if line != "" && strings.Contains("Nn", string([]rune(line)[0:1])) {
				info("Not updated")
				if tmpPath != "" {
					removeTempFile(tmpPath)
				}
				continue
			}

			info("Updated")
		}

		if tmpPath != "" {
			if backup {
				backupName := fmt.Sprintf("%s~", filename)
				if err := os.Rename(filename, backupName); err != nil {
					warn(fmt.Sprintf("error renaming %s to %s: ", filename, backupName))
					removeTempFile(tmpPath)
					continue
				}

			}

			// Overwrite the result
			if err = os.Rename(tmpPath, filename); err != nil {
				warn(fmt.Sprintf("could not move %s to %s: %s", tmpPath, filename, err.Error()))
				removeTempFile(tmpPath)
				continue
			}

			// Restore the times
			if keepTimes && havePerms {
				// TODO
			}
		}

		totalMatches += numMatches
	}

	// We're about to exit, give a summary.
	if !quiet {
		var action string
		if dryRun {
			action = "found"
		} else {
			action = "replaced"
		}
		var plural string = "s"
		if totalFiles == 1 {
			plural = ""
		}
		warn(fmt.Sprintf("%d matches %s in %d out of %d file%s", totalMatches, action, matchedFiles, totalFiles, plural))
	}

	os.Exit(0)
}

var rootCmd = &cobra.Command{
	Use: "rpl",
	Version: `Copyright (C) 2025 Reuben Thomas <rrt@sc3d.org>

Licence GPLv3+: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.`,
	Short: "Search and replace text in files.",
	Args:  cobra.MinimumNArgs(2),
	Run:   main,
}

var (
	programName string

	// Set from command-line arguments
	setEncoding  string
	wholeWords   bool
	backup       bool
	quiet        bool
	verbose      bool
	dryRun       bool
	fixedStrings bool
	patternFiles bool
	glob         []string
	recursive    bool
	prompt       bool
	force        bool
	keepTimes    bool
	ignoreCase   bool
	matchCase    bool
)

// This is called by main.main().
func Execute() {
	err := rootCmd.Execute()
	if err != nil {
		os.Exit(1)
	}
}

// Get terminal width, default 0.
func termWidth() int {
	fd := int(os.Stdout.Fd())
	width := 0

	// Get the terminal width and dynamically set
	termWidth, _, err := term.GetSize(fd)
	if err == nil {
		width = termWidth
	}

	return width
}

func init() {
	SetLocale.SetLocale(SetLocale.LC_ALL, "")

	cobra.AddTemplateFunc("termWidth", termWidth)

	rootCmd.SetUsageTemplate(`Usage: {{.CommandPath}} [OPTION...] OLD-TEXT NEW-TEXT [FILE...]
	
OLD-TEXT matches at most once in each position.

{{.Flags.FlagUsagesWrapped termWidth}}`)

	rootCmd.Flags().SortFlags = false
	rootCmd.Flags().StringVar(&setEncoding, "encoding", "", "specify character set encoding `ENCODING`")
	rootCmd.Flags().BoolVarP(&wholeWords, "whole-words", "w", false, "whole words (OLD-TEXT matches on word boundaries only)")
	rootCmd.Flags().BoolVarP(&backup, "backup", "b", false, "rename original FILE to FILE~ before replacing")
	rootCmd.Flags().BoolVarP(&quiet, "quiet", "q", false, "quiet mode")
	rootCmd.Flags().BoolVarP(&verbose, "verbose", "v", false, "verbose mode")
	rootCmd.Flags().BoolVarP(&dryRun, "dry-run", "s", false, "simulation mode")
	rootCmd.Flags().BoolVarP(&fixedStrings, "fixed-strings", "F", false, "treat OLD-TEXT and NEW-TEXT as fixed strings, not regular expressions")
	rootCmd.Flags().BoolVar(&patternFiles, "files", false, "OLD-TEXT and NEW-TEXT are file names to read patterns from")
	rootCmd.Flags().StringArrayVarP(&glob, "glob", "x", []string{}, "modify only files matching the glob `PATTERN` (may be given more than once)")
	rootCmd.Flags().BoolVarP(&recursive, "recursive", "R", false, "search recursively")
	rootCmd.Flags().BoolVarP(&prompt, "prompt", "p", false, "prompt before modifying each file")
	rootCmd.Flags().BoolVarP(&force, "force", "f", false, "ignore errors when trying to preserve attributes")
	rootCmd.Flags().BoolVarP(&keepTimes, "keep-times", "d", false, "keep the modification times on modified files")

	rootCmd.Flags().BoolVarP(&ignoreCase, "ignore-case", "i", false, "search case-insensitively")
	rootCmd.Flags().BoolVarP(&matchCase, "match-case", "m", false, "ignore case when searching, but try to match case of replacement to case of original, either capitalized, all upper-case, or mixed")
	rootCmd.MarkFlagsMutuallyExclusive("ignore-case", "match-case")

	rootCmd.Flags().BoolP("extended-regex", "E", false, "use extended regex syntax [IGNORED]")
	rootCmd.Flags().MarkHidden("extended-regex")
}
