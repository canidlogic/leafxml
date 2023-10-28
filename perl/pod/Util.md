# NAME

LeafXML::Util - Utility functions for LeafXML.

# SYNOPSIS

    use LeafXML::Util qw(
      isInteger
      validCode
      validString
      validName
      readFullText
      writeFullText
      escapeText
      toText64
      fromText64
    );
    
    # Check whether a given value is a scalar integer
    if (isInteger($val)) {
      ...
    }
    
    # Check whether a numeric codepoint is allowed in LeafXML
    if (validCode($code)) {
      ...
    }
    
    # Check whether a scalar string only contains valid codepoint
    if (validString($str)) {
      ...
    }
    
    # Check whether a scalar string is a valid LeafXML name
    if (validName($str)) {
      ...
    }
    
    # Read a whole text file into a Unicode string
    my $text;
    readFullText(\$text, "/path/to/file.txt");
    
    # Read standard input into a Unicode string
    my $text;
    readFullText(\$text);
    
    # Write a whole text file from a Unicode string
    my $text = "Example file\n";
    writeFullText(\$text, "/path/to/file.txt");
    
    # Write a whole text file to standard output from a Unicode string
    my $text = "Example file\n";
    writeFullText(\$text);
    
    # Escape content text
    my $escaped = escapeText($text);
    
    # Escape single-quoted attribute text
    my $escaped = escapeText($text, 1);
    
    # Escape double-quoted attribute text
    my $escaped = escapeText($text, 2);
    
    # Encode a Unicode string to UTF-8 encoded in Base64
    my $b64 = toText64($text);
    
    # Decode UTF-8 encoded in Base64 to a Unicode string
    my $text = fromText64($b64);

# DESCRIPTION

Utility functions for working with LeafXML.  These are especially
helpful for writing encoders.

# FUNCTIONS

- **isInteger(val)**

    Check that the given value is an integer.  Return 1 if an integer or 0
    if not.

- **validCode(codepoint)**

    Check whether a given integer value is a valid Unicode codepoint that
    can be used within LeafXML.  Returns 1 if yes, 0 if not.

- **validString(str)**

    Check whether a given string only contains codepoints that pass the
    `validCode()` function.  Returns 1 if yes, 0 if not.  Empty strings do
    pass this function.

    This function is optimized so that it does not actually invoke
    `validCode()` but rather uses a regular expression.

- **validName(str)**

    Check whether a given string qualifies as a valid XML name.  This 
    function allows names to contain colons.

- **readFullText(\\$target, \[path\])**

    Read a whole text file into a decoded Unicode string.

    The first parameter is always a reference to a scalar where the text
    will be stored.  This scalar will have one character per codepoint, and
    never has any Byte Order Mark.

    If the second parameter is present, it is a scalar specifying a file
    path to the text file to load the text from.  If the second parameter is
    absent, the file is read from standard input.

    This function supports UTF-8 with or without a Byte Order Mark, and
    UTF-16 with a Byte Order Mark.

- **writeFullText(\\$target, \[path\])**

    Read a whole text file from a decoded Unicode string.

    The first parameter is always a reference to a scalar storing the
    Unicode string to write.  Empty strings are acceptable, but will be
    automatically replaced with a string containing a single U+0020 Space
    character.

    Each character in the string must be a codepoint in range 0x0 to
    0x10FFFF, excluding the surrogate range 0xd800 to 0xdfff.  Additionally,
    if the string is not empty, the very first character may not be 0xfeff,
    which would be confused with a Byte Order Mark.

    If the second parameter is present, it is a scalar specifying a file
    path to the text file to write the text to.  If the second parameter is
    absent, the file is written to standard output.

    This function always encodes as UTF-8 without a Byte Order Mark, which
    is the preferred encoding in modern use.

    The referenced scalar will be reset to empty before the function
    returns, since the encoding function might modify it in place.

- **escapeText(input, \[attr\])**

    Apply entity escaping to input text.

    The first parameter is always the unescaped source string.

    The second parameter, if present, is an integer in range 0 to 2.  The
    value zero means escaping should be performed for content text between
    element tags.  The value one means escaping should be performed for a
    single-quoted attribute value.  The value two means escaping should be
    performed for a double-quoted attribute value.

    If the second parameter is absent, a default value of zero is assumed.

    The entity escapes are as follow:

        &amp;  for literal &
        &lt;   for literal <
        &gt;   for literal >
        &quot; for literal "
        &apos; for literal '

    The ampersand and angle escapes are used in all escaping styles.  The
    double quote escape is only used if the second parameter is set to 2.
    The single quote escape is only used if the second parameter is set to
    1.

    This function does not verify that all codepoints are valid.  It merely
    performs the appropriate substitutions.  The return value is the escaped
    string.

- **toText64(str)**

    Encode a Unicode string into UTF-8 encoded in Base64.

    Each character in the string must be a codepoint in range 0x0 to
    0x10FFFF, excluding the surrogate range 0xd800 to 0xdfff.

    An empty string is acceptable, and will result in an empty string being
    returned.

    The Base64 style used here has `+` and `/` as the last two digits and
    uses `=` for end padding to make sure the total number of Base64 digits
    mod 4 is zero.

    No whitespace or line breaking will be added to the Base64 result
    string.

- **fromText64(str)**

    Decode a Unicode string from UTF-8 encoded in Base64.

    Spaces, tabs, carriage returns, and line feeds will automatically be
    filtered out of the given string.

    After whitespace filtering, the string must only contain Base64 digits,
    where `+` and `/` are the last two digits.  The total number of Base64
    digits must be a multiple of four, with `=` used as padding if
    necessary at the end.  An empty string after whitespace filtering is
    acceptable, which will produce an empty result.

    The result string is verified to only contain codepoints in range 0x0 to
    0x10FFFF, excluding the surrogate range 0xd800 to 0xdfff.
