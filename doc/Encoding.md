# LeafXML encoding guidelines

The LeafXML specification describes the LeafXML format in terms of how to decode it.  This supplemental document provides advice for how to generate and encode LeafXML documents for best compatibility with various XML processors.

## Character set

Use only Unicode codepoints in the character set defined by the LeafXML specification.  This mostly involves not using control codes and not using codepoints left undefined by Unicode.  (In the case of control codes, those would be better handled by using XML structures.)

Do not attempt to circumvent the character set by using numeric entity escapes for codepoints outside the character set.  Although the XML 1.1 specification allows this to a certain extent, LeafXML decoders will reject it.

## Character encoding

LeafXML decoders support UTF-16 with a byte order mark, and UTF-8 both with and without a byte order mark.

Encoders are encouraged to use UTF-8 without a byte order mark, because this is by far the most compatible encoding in modern practice.

## Line breaks

Encoders are encouraged to either use U+000A (Line Feed; LF) for line breaks, or the sequence U+000D U+000A (Carriage Return; CR, followed by Line Feed; LF).

LF line breaks are the common form on POSIX platforms.  CR+LF line breaks are the common form on Windows platforms.

## Normalization

Encoders are recommended to ensure that the whole XML file is in Unicode normal form NFC.  LeafXML decoders will automatically normalize input, but the XML standard technically does not require normalization on input, so it is a good idea to have everything normalized so XML files behave the same way across different XML decoders.

## Header

Although not required by the XML specifications, it is considered good practice to start an XML file with the following header line:

    <?xml version="1.0" encoding="UTF-8"?>

If UTF-16 encoding is used, replace UTF-8 with UTF-16.  However, UTF-8 is recommended even if the file only uses US-ASCII, since US-ASCII is a subset of UTF-8 and UTF-8 is the more common label.

Certain XML formats may recommend that a `<!DOCTYPE` declaration be made after this opening header line.  This may be done, following the formula given by the specific XML format.  However, note that LeafXML does not allow DTDs to be embedded within the `<!DOCTYPE` declaration using square brackets.  (XML formats rarely do this, relying instead on external DTD references, which are allowed.)

Any amount of blank lines may be present in the header, except that the XML header line should be the very first line with no whitespace preceding it.

## Tags

A _starting tag_ has the following syntax:

    <elname param1="value1" param2="value2">

The `elname` is the element name.  This is followed by zero or more parameter declarations, which are a parameter name, an equals sign, and then a quoted parameter value.  Double quotes `""` and single quotes `''` may be used with no difference in meaning, though double quotes are more common.

Element and attribute names are case sensitive.

There must be no whitespace between the opening `<` and the element name.  Each parameter declaration must be separated from what came before it by at least one whitespace character, with tabs, spaces, and line breaks all allowed as whitespace.  There may optionally be whitespace before the closing `>` character.  Although whitespace is technically allowed around the equals sign in parameters, this is not typically done.

Parameter values should use the following escapes:

    &amp;  for literal &
    &lt;   for literal <
    &gt;   for literal >
    &quot; for literal "
    &apos; for literal '

The `&quot;` and `&apos;` are only needed within double-quoted and single-quoted attribute values, respectively, to escape the quote mark.

Parameter values are technically allowed to have line breaks within them, but usually XML files confine each parameter value to a single line, even if the parameter value is very long.

LeafXML decoders always apply whitespace compression to parameter values.  It is therefore recommended within parameter values to only use single U+0020 (Space; SP) codepoints as whitespace, and to not use them at the beginning nor the end of the parameter value, and to not use more than one of them in a row.

Empty parameter values (`""` or `''`) are allowed.

An _empty tag_ has the following syntax:

    <elname param1="value1" param2="value2"/>

This syntax is exactly same as the syntax for a starting tag, except there is a U+002F (`/`) immediately before the closing `>`.  No whitespace is allowed between `/` and `>`.

An _end tag_ has the following syntax:

    </elname>

This syntax is exactly the same as the syntax for a starting tag, except there is a U+002F (`/`) immediately between the opening `<` and the element name, and no parameters are allowed in an end tag.

### Nesting rules

Each starting tag must be closed with an end tag that has the exact same element name.

Each empty tag is equivalent to a starting tag followed immediately by an end tag with the same element name.  Some XML formats might have subtle differences between empty tags and a starting tag followed immediately by an end tag, so encoders should use whichever style is idiomatic for a particular tag in a particular XML format.

Tags must all be properly nested.  That is, between a starting tag and its matching end tag, all starting tags contained within must be ended before the matching end tag occurs.  At the top level, there must be exactly one root element in the XML file.

## Text content

Text content may be included between tags, but should not be present before the start of the root tag nor after the end of the root tag.

Text content may include any codepoints in the character set, except that the following three escapes should be used:

    &amp; for literal &
    &lt;  for literal <
    &gt;  for literal >

LeafXML decoders will always preserve all whitespace in text content.  If whitespace is significant, it is recommended to include the following attribute in the starting tag before the text content:

    xml:space="preserve"

This explicitly indicates to XML decoders that whitespace should be preserved in text content within this element.  Without the declaration, some XML decoders may process whitespace within text content in some way.  Since LeafXML decoders always preserve whitespace, they simply ignore this declaration.

Although CDATA sections are allowed within text content, they are not recommended due to possible interpretation differences across other XML decoders.  The sole case where CDATA sections should be used is where they are completely idiomatic within the specific XML format.  For example, some XML formats enclose embedded JavaScript or CSS within CDATA sections.  In this case, follow the idiomatic syntax of the specific XML format.

## Instructions and comments

Apart from the header of the XML file, XML instructions and XML comments are not recommended in XML files.

## Namespaces

Element names should only include a colon character if they are part of a namespace.  A namespaced element name has the following syntax:

    prefix:local

The `prefix` is a prefix which selects the specific namespace, and `local` is a name within this selected namespace.

The `xml` and `xmlns` namespace prefixes are predefined and should not be declared.

Although declarations can technically be made on any starting or empty tag, usual practice is to make all namespace declarations on the root element starting tag.  The namespace declarations apply already to the tag on which they are declared, so the root element can be in a namespace declared within the root element starting tag.

Namespace declarations are attributes that have the following format:

    xmlns:prefix="http://example.com/namespace"

The namespace declaration attribute must have the prefix `xmlns` and then `prefix` is the specific namespace prefix that is being declared.  The attribute value must be non-empty and is usually a URI that uniquely identifies the namespace.  No processing or percent escaping is performed on the URI.  You may not use the following two reserved namespace values:

    http://www.w3.org/XML/1998/namespace
    http://www.w3.org/2000/xmlns/

A default namespace declaration is made like this:

    xmlns="http://example.com/namespace"

The default namespace will be applied to all elements that do not have a prefix.  If no default namespace is declared, then elements without a prefix will not be in any namespace.

Attributes do not normally use prefixes, and the default namespace does _not_ apply to attributes, so attributes are usually outside of any namespace.

The only exception is for certain attributes that are not considered part of their element, but rather are considered as some external metadata marking up the element.  In this case, prefixes are used with attributes to put them in a specific namespace.
