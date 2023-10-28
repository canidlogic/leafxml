# NAME

leafxml\_echo.pl - Transcode text using LeafXML functions.

# SYNOPSIS

    leafxml_echo.pl -i /path/to/input.txt -o /path/to/output.txt
    leafxml_echo.pl -i - -o - < input.txt > output.txt

# DESCRIPTION

Read Unicode text using `readFullText()` and then write the same
Unicode text using `writeFullText()`.

Input supports UTF-8 both with and without Byte Order Mark, as well as
UTF-16 with a Byte Order Mark.  Output is always UTF-8 without a Byte
Order Mark.  This script therefore converts any of the supported input
formats to plain UTF-8.  If input is completely empty, output will
contain a single space character.

Program arguments are given in key/value pairs.  The keys `-i` and
`-o` must be defined exactly once, and no other keys may be defined.
These two keys define the input file and the output file, respectively.
Each is either the path to a file to read or create, or the special
value `-` which means read standard input or standard output,
respectively.
