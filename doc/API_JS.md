# LeafXML JavaScript API

The entire LeafXML JavaScript library is contained within the `leafxml.js` script contained in the `js` directory of this distribution.  The JavaScript library has the same range of functionality as the Perl LeafXML library.

This script library is intended to be used with client-side JavaScript in a web browser.  To include the library, include the following `<script>` tag in an HTML file header section:

    <html>
      <head>
        ...
        <script src="leafxml.js"></script>
        ...
      </head>
      ...
    </html>

The only action taken by the LeafXML script is to define a global object `LeafXML` in the global `window` object.  Once this script has run, you can refer to exported functions like `LeafXML.readFullText()` and you can generate new parser instances like `new LeafXML.Parser()`.

The entire library is wrapped within an anonymous function, so the definition of `LeafXML` in the global `window` object is the only modification to the runtime environment that should be visible.

## Utility functions

The following utility functions are exported in the `LeafXML` object.

    LeafXML.isInteger(val)

Given a value of any type, return a boolean indicating whether it is an integer.  Returns true only if the value has the JavaScript type `number` and its floored value is equal to its original value.  This does _not_ perform any range check for a safe integer range.

    LeafXML.validCode(c)

Given an integer, return a boolean indicating whether this numeric value represents a codepoint that is valid within LeafXML files.  Note that you must pass an integer, _not_ a single-codepoint string.  The valid range is defined in the LeafXML specification character set section.  It includes the full Unicode range from 0x0 to 0x10FFFF, excluding surrogates, various control codes, and certain undefined ranges.

    LeafXML.validString(str)

Given a string, return a boolean indicating whether it contains only codepoints that pass `validCode()`.  An empty string yields a true result.  The function has an optimized implementation, so that it does not actually call `validCode()` for each codepoint, even though the effect is the same.

    LeafXML.validName(str)

Given a string, return a boolean indicating whether it is allowable as an element or attribute name within LeafXML.  Valid names are a subset of valid strings.  Empty strings do _not_ pass this function.  The name may contain any number of colons and still be valid, though colons have a special meaning for XML namespaces.  See the LeafXML specification for further information about names.

## XML encoding functions

The following function that assists in encoding LeafXML is exported in the `LeafXML` object:

    LeafXML.escapeText(str, style)

Given a string, return a transformed string with entity escaping applied.  The style argument must be an integer, with 0 for content-text escaping, 1 for single-quoted attribute escaping, or 2 for double-quoted attribute escaping.  All three styles perform the following escapes:

    &amp;  for literal &
    &lt;   for literal <
    &gt;   for literal >

Style 1 (single-quoted attribute) also performs the following escape, in addition to the three above:

    &apos; for literal '

Style 2 (double-quote attribute) also performs the following escape, in addition to the three above:

    &quot; for literal "

This function only performs the substitutions appropriate for the style.  It does not check whether all codepoints in the string are valid for LeafXML, which you can do with the `validString()` function defined earlier.

## File transport functions

The `LeafXML` object exports functions for working with text data transported in files.  Client-side JavaScript does not have normal access to a file system.  Instead, the LeafXML file transport functions accept `ArrayBuffer` objects and return `Uint8Array` objects.

You can read `ArrayBuffer` objects from Blobs and Files by using a  `FileReader` with the `readAsArrayBuffer()` method.  You can receive `ArrayBuffer` objects from the server through `XMLHttpRequest` by specifying `arraybuffer` as the `responseType`.

You can construct `Blob` objects around `Uint8Array` objects by specifying an array containing the `Uint8Array` to the Blob constructor.  These `Blob` objects can then be turned in URLs using `URL.createObjectURL()`.  You can also transmit `Uint8Array` objects to a server through `XMLHttpRequest` using the `send()` function.

The following functions are exported by the `LeafXML` object for file transport:

    LeafXML.readFullText(abuf)

Decode a binary `ArrayBuffer` and return a Unicode string.  This function supports UTF-8 encoding both with and without a byte order mark, and UTF-16 encoding with a byte order mark.  The returned string will never include the byte order mark.  An exception is thrown in case of decoding error.

    LeafXML.writeFullText(str)

Encode a Unicode string and return a binary `Uint8Array`.  This function always uses UTF-8 encoding without a byte order mark.  If an empty string is passed, it will be automatically replaced with a string consisting of a single U+0020 space codepoint, so that the resulting buffer is not empty.

The provided string may only include surrogate codepoints when those surrogates are properly paired.  Furthermore, the first codepoint in the string may not be U+FEFF, which would be confused with a byte order mark after binary encoding.

An exception is thrown in case of encoding error.

## Base64 transport functions

The `LeafXML` object also exports functions for working with text data transported in Base64 strings.  Base64 transport is especially useful when embedding XML files within other markup files.

The Base64 alphabet used by these functions starts with uppercase letters `A` through `Z`, then lowercase letters `a` through `z`, then decimal digits `0` through `9`, and finally the symbols `+` and `/`.  The `=` symbol is used for padding at the end if necessary so that the total number of Base64 digits is a multiple of four.

An empty string results in an empty Base64 encoding.  Also, Base64 encodings may use any amount of spaces, tabs, carriage returns, and line feeds at any position.  The Base64 decoding function will filter out all whitespace before decoding.

The following functions are exported by the `LeafXML` object for Base64 transport:

    LeafXML.toText64(str)

Encode a Unicode string and return a Base64 string.  The encoding uses `=` for padding if necessary to bring the total number of Base64 digits up to a multiple of four.  No whitespace is present in the returned encoding.  Passing an empty string will result in an empty Base64 string returned.

Each codepoint in the input string must be in range U+0000 to U+10FFFF, excluding unpaired surrogates in range U+D800 to U+DFFF.  The binary encoding used in the Base64 string is UTF-8.

    LeafXML.fromText64(str)

Decode a Base64 string and return a Unicode string.  Spaces, tabs, carriage returns, and line feeds will be filtered out of the input string before decoding.  An empty string after filtering will yield an empty string as a decoded result.  The result is verified to only include codepoints in range U+0000 to U+10FFFF, excluding unpaired surrogates in range U+D800 to U+DFFF.

## ParserFault object

The `LeafXML.ParserFault` constructor is used by the parser object to represent errors encountered while parsing the XML file.  `ParserFault` objects have a `message` property containing an error message and a `toString()` method that contains the class name and the error message, so that the objects can be used like `Error` objects.

Clients can check whether exceptions are `instanceof` the `LeafXML.ParserFault` class to determine whether the error originates from the LeafXML data, rather than some other kind of error.

## Parser object

The `LeafXML.Parser` constructor is used to parse LeafXML files:

    new LeafXML.Parser(str)

Constructs a parser object around a LeafXML file contained within a given Unicode string.  The remaining functions in this section are instance functions of the constructed object.

   setSourceName(str)
   getSourceName

These two functions are used to get and set the source name property of the parser object.  The source name property starts out as `null`.  It can be set to any string value, or to `null`.  The source name is used in parsing error messages to identify the specific XML file.  This is helpful if the program is parsing multiple XML files, so that the specific file can be identified.

    readEvent()

Attempts to read the next XML parsing event, returning `true` if a new event has been loaded or `false` if there are no further parsing events.  An instance of `LeafXML.ParserFault` is thrown if there is a problem parsing the XML file.

The parser starts out without any events loaded, so you must call `readEvent()` before reading the first event.  You can iterate through all parsing events like this:

    while (xmlParser.readEvent()) {
      ...
    }

If you catch an exception thrown by this function, do not attempt to continue parsing through the file with the parser object or undefined behavior occurs.

    eventType()

Return the kind of parsing event that is currently loaded.  You can only use this function after `readEvent()` has indicated that an event is loaded.  The return value is one of the following integers:

- `1` for a starting XML tag
- `0` for content text between tags
- `-1` for an ending tag

    lineNumber()

Return the line number in the XML file at the start of the parsing event.  You can only use this function after `readEvent()` has indicated that an event is loaded.  The return value is an integer, where the first line is line 1.

    contentText()

Return the decoded content text as a string.  You can only use this function after `readEvent()` indicates that an event is loaded and `eventType()` indicates that the event is content text.  The returned content text has already had its entity escapes decoded, its line breaks normalized to line feed characters, and been normalized to Unicode NFC form.

LeafXML only generates content text events between XML tags, so there will be no content text events before the starting tag of the root element, nor any content text events after the ending tag of the root element.

Furthermore, LeafXML will concatenate content text and CDATA sections as much as possible.  This means that there will be at most one content text event between XML tags, with a single content text event covering all content text and CDATA spans between the XML tags.

Whitespace is always fully preseved by the LeafXML decoder in content text events.

    elementName()
    elementNS()

Return the element name and element namespace of a starting tag.  You can only use these function after `readEvent()` indicates that an event is loaded and `eventType()` indicates that the event is a starting XML tag.

The returned element name never includes any namespace prefix, and it has already been normalized to Unicode NFC form.  The returned element namespace is the full namespace value, which is usually a URL, if the element name had a namespace prefix or a default namespace has been defined in the file.  The namespace will be `null` if there is neither a namespace prefix nor a default namespace.

    attr()
    externalAttr()

Return an object representing the plain attribute map and the namespaced attribute map, respectively.  In both cases, the parser's internal mapping object is returned, so clients should not make changes to the returned objects.

The plain attribute map is a simple mapping of attribute names to attribute values.  It includes all attribute names that do not have a namespace prefix, but it excludes the reserved attribute name `xmlns`.  Note that if there is a defined default namespace in the file, it does _not_ apply to attributes.

The namespaced attribute map is a two-level mapping.  The returned object has keys that are full namespace values, which are usually URLs.  The values of this returned object are themselves objects, and these second-level objects have keys that are local attribute names (without any namespace prefix) and values that are attribute values.  To look up an attribute within a particular namespace, first use the namespace value as a key in the first-level object, and second use the local attribute name without any namespace information as a key in the second-level object.

Attributes with an `xmlns:` prefix are reserved for namespace declarations and are _not_ included as namespaced attributes.

For attributes with the reserved `xml:` namespace prefix (such as `xml:space` and `xml:lang`), you will find them in the namespaced attribute map with the following namespace value key in the first-level object:

    http://www.w3.org/XML/1998/namespace

Attribute names have already been normalized to Unicode NFC form.  Attribute values have already have their entity escapes decoded, their internal whitespace sequences collapsed to single spaces, their leading and trailing whitespace trimmed, and been normalized to Unicode NFC form.  Empty attribute values are llowed.
