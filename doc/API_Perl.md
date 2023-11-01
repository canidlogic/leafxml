# LeafXML Perl API

The LeafXML Perl library consists of the `LeafXML::Parser` and `LeafXML::Util` modules in the `LeafXML` subdirectory of the `perl` directory of this distribution.  The Perl library has the same range of functionality as the JavaScript LeafXML library.

`LeafXML::Parser` is a class that parses through LeafXML files.  `LeafXML::Util` exports various utility functions that are especially helpful for encoding LeafXML.

In addition to this document, also see the POD documentation for the modules, Markdown compilations of which are found in the `pod` subdirectory of the `perl` directory.

Unless otherwise specified, scalar strings should be encoded such that there is one character per codepoint.  Scalar strings should not use surrogate pairs, nor should they be a binary string with one character per UTF-8 byte.

## Utility functions

The following utility functions are exported from the `LeafXML::Util` module.

    isInteger($val)

Given a value of any type, return 1 if it is an integer or 0 if not.  Returns 1 only if the value `looks_like_number()` according to `Scalar::Util` and it is equal to itself when floored with `int()`.  This does _not_ perform any range check for a safe integer range.

    validCode($c)

Given an integer, return 1 if this numeric value represents a codepoint that is valid within LeafXML files, or 0 otherwise.  Note that you must pass an integer, _not_ a single-character string.  The valid range is defined in the LeafXML specification character set section.  It includes the full Unicode range from 0x0 to 0x10FFFF, excluding surrogates, various control codes, and certain undefined ranges.

    validString($str)

Given a scalar string, return 1 if each of its characters passes `validCode()`, or 0 otherwise.  An empty string yields a true result.  The function has an optimized implementation, so that it does not actually call `validCode()` for each character, even though the effect is the same.

    validName($str)

Given a scalar string, return 1 if it is allowable as an element or attribute name within LeafXML, or 0 otherwise.  Valid names are a subset of valid strings.  Empty strings do _not_ pass this function.  The name may contain any number of colons and still be valid, though colons have a special meaning for XML namespaces.  See the LeafXML specification for further information about names.

## XML encoding functions

The following function that assists in encoding LeafXML is exported from the `LeafXML::Util` module:

    escapeText($str, [$style])

Given a scalar string, return a transformed string with entity escaping applied.  The optional style argument must be an integer, with 0 for content-text escaping, 1 for single-quoted attribute escaping, or 2 for double-quoted attribute escaping.  If not provided, a default of 0 is assumed.  All three styles perform the following escapes:

    &amp;  for literal &
    &lt;   for literal <
    &gt;   for literal >

Style 1 (single-quoted attribute) also performs the following escape, in addition to the three above:

    &apos; for literal '

Style 2 (double-quote attribute) also performs the following escape, in addition to the three above:

    &quot; for literal "

This function only performs the substitutions appropriate for the style.  It does not check whether all codepoints in the string are valid for LeafXML, which you can do with the `validString()` function defined earlier.

## File transport functions

The `LeafXML::Util` module exports functions for working with text data transported in files.  The following functions are available:

    readFullText(\$target, [$path])

Decode a file into a Unicode scalar string.  The `target` argument is a reference to a scalar that will have the decoded result string written to it.  The `path` argument is the file path to read.  If the `path` argument is omitted, then standard input will be read.

This function reads in binary mode and is able to decode UTF-8 both with and without a byte order mark, and UTF-16 with a byte order mark.  The string written to `result` will never include a byte order mark.  A fatal error occurs in case of decoding error.

When this function reads from standard input, it will change the `binmode` to `:raw` so that it reads in binary mode.

    writeFullText(\$source, [$path])

Encode a Unicode scalar string into a file.  The `source` argument is a reference to a scalar that holds the string to encode.  The `path` argument is the file path to create and write.  If the file path already exists, it will be overwritten with a new file.  If the `path` argument is omitted, then standard output will be written.

The provided string may only include surrogate codepoints when those surrogates are properly paired.  Furthermore, the first codepoint in the string may not be U+FEFF, which would be confused with a byte order mark after binary encoding.  If an empty string is passed, it is automatically replaced with a string containing a single U+0020 space character.

This function writes in binary mode and always uses UTF-8 without a byte order mark.  The `source` string is cleared to an empty string before returning, because it may have been encoded in place.  A fatal error occurs in case of encoding error.

When this function writes to standard output, it will change the `binmode` to `:raw` so that it writes in binary mode.

## Base64 transport functions

The `LeafXML::Util` module also exports functions for working with text data transported in Base64 strings.  Base64 transport is especially useful when embedding XML files within other markup files.

The Base64 alphabet used by these functions starts with uppercase letters `A` through `Z`, then lowercase letters `a` through `z`, then decimal digits `0` through `9`, and finally the symbols `+` and `/`.  The `=` symbol is used for padding at the end if necessary so that the total number of Base64 digits is a multiple of four.

An empty string results in an empty Base64 encoding.  Also, Base64 encodings may use any amount of spaces, tabs, carriage returns, and line feeds at any position.  The Base64 decoding function will filter out all whitespace before decoding.

The following functions are exported by the `LeafXML::Util` module for Base64 transport:

    toText64($str)

Encode a Unicode scalar string and return a Base64 scalar string.  The encoding uses `=` for padding if necessary to bring the total number of Base64 digits up to a multiple of four.  No whitespace is present in the returned encoding.  Passing an empty string will result in an empty Base64 string returned.

Each codepoint in the input string must be in range U+0000 to U+10FFFF, excluding surrogates in range U+D800 to U+DFFF.  The binary encoding used in the Base64 string is UTF-8.

    fromText64($str)

Decode a Base64 scalar string and return a Unicode scalar string.  Spaces, tabs, carriage returns, and line feeds will be filtered out of the input string before decoding.  An empty string after filtering will yield an empty string as a decoded result.  The result is verified to only include codepoints in range U+0000 to U+10FFFF, excluding surrogates in range U+D800 to U+DFFF.

## Parser object

The `LeafXML::Parser` class has the following constructor:

    LeafXML::Parser->create(\$str)

Constructs a parser object around a LeafXML file contained within a given Unicode scalar string reference.  Note that the argument is a reference to a scalar string, rather than the scalar string itself.  (This is to avoid copying large strings around.)

The referenced scalar string must not be modified or manipulated with regular expressions while parsing is in progress, or undefined behavior occurs.

The remaining functions in this section are instance functions of the constructed object.

   sourceName([$str])

Get or set the source name property of the parser object.  Providing a parameter sets the value, while not including a parameter returns the current value.  The source name property starts out as `undef`.  It can be set to any string value, or to `undef`.  The source name is used in parsing error messages to identify the specific XML file.  This is helpful if the program is parsing multiple XML files, so that the specific file can be identified.

    readEvent()

Attempts to read the next XML parsing event, returning 1 if a new event has been loaded or 0 if there are no further parsing events.  A fatal error is raised if there is a problem parsing the XML file.

The parser starts out without any events loaded, so you must call `readEvent()` before reading the first event.  You can iterate through all parsing events like this:

    while ($xmlParser->readEvent) {
      ...
    }

If you catch an error thrown by this function, do not attempt to continue parsing through the file with the parser object or undefined behavior occurs.

    eventType()

Return the kind of parsing event that is currently loaded.  You can only use this function after `readEvent()` has indicated that an event is loaded.  The return value is one of the following integers:

- `1` for a starting XML tag
- `0` for content text between tags
- `-1` for an ending tag

    lineNumber()

Return the line number in the XML file at the start of the parsing event.  You can only use this function after `readEvent()` has indicated that an event is loaded.  The return value is an integer, where the first line is line 1.

    contentText()

Return the decoded content text as a scalar string.  You can only use this function after `readEvent()` indicates that an event is loaded and `eventType()` indicates that the event is content text.  The returned content text has already had its entity escapes decoded, its line breaks normalized to line feed characters, and been normalized to Unicode NFC form.

LeafXML only generates content text events between XML tags, so there will be no content text events before the starting tag of the root element, nor any content text events after the ending tag of the root element.

Furthermore, LeafXML will concatenate content text and CDATA sections as much as possible.  This means that there will be at most one content text event between XML tags, with a single content text event covering all content text and CDATA spans between the XML tags.

Whitespace is always fully preseved by the LeafXML decoder in content text events.

    elementName()
    elementNS()

Return the element name and element namespace of a starting tag.  You can only use these function after `readEvent()` indicates that an event is loaded and `eventType()` indicates that the event is a starting XML tag.

The returned element name never includes any namespace prefix, and it has already been normalized to Unicode NFC form.  The returned element namespace is the full namespace value, which is usually a URL, if the element name had a namespace prefix or a default namespace has been defined in the file.  The namespace will be `undef` if there is neither a namespace prefix nor a default namespace.

    attr()
    externalAttr()

Return a hash reference representing the plain attribute map and the namespaced attribute map, respectively.  In both cases, the parser's internal mapping hash is returned, so clients should not make changes to the returned hashes.

The plain attribute map is a simple mapping of attribute names to attribute values.  It includes all attribute names that do not have a namespace prefix, but it excludes the reserved attribute name `xmlns`.  Note that if there is a defined default namespace in the file, it does _not_ apply to attributes.

The namespaced attribute map is a two-level mapping.  The returned hash has keys that are full namespace values, which are usually URLs.  The values of this returned hash are themselves hash references, and these second-level hashes have keys that are local attribute names (without any namespace prefix) and values that are attribute values.  To look up an attribute within a particular namespace, first use the namespace value as a key in the first-level hash, and second use the local attribute name without any namespace information as a key in the second-level hash.

Attributes with an `xmlns:` prefix are reserved for namespace declarations and are _not_ included as namespaced attributes.

For attributes with the reserved `xml:` namespace prefix (such as `xml:space` and `xml:lang`), you will find them in the namespaced attribute map with the following namespace value key in the first-level hash:

    http://www.w3.org/XML/1998/namespace

Attribute names have already been normalized to Unicode NFC form.  Attribute values have already have their entity escapes decoded, their internal whitespace sequences collapsed to single spaces, their leading and trailing whitespace trimmed, and been normalized to Unicode NFC form.  Empty attribute values are allowed.
