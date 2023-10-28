# NAME

leafxml\_xform.pl - Text transformations using LeafXML functions.

# SYNOPSIS

    leafxml_xform.pl esc 0 < input.txt > output.txt
    leafxml_xform.pl e64 < input.txt > output.txt
    leafxml_xform.pl d64 < input.txt > output.txt

# DESCRIPTION

Read text from standard input, transform it using LeafXML functions, and
print the transformed text to standard output.

The input may be in UTF-8 with or without a byte order mark, or in
UTF-16 with a byte order mark.  The output is always in UTF-8 without a
byte order mark.

The `esc` invocation performs entity escaping.  It does not, however,
verify that only valid codepoints are in use in the input.  This
invocation takes a single parameter, which must be `0` for content text
escaping, `1` for single-quoted attribute escaping, or `2` for
double-quoted attribute escaping.

The `e64` invocation encodes the text into Base64, where UTF-8 encoding
is used within the Base64 data.

The `d64` invocation decodes text from Base64 with UTF-8 into full
UTF-8.
