# NAME

leafxml\_parse.pl - Test driver for the LeafXML parser.

# SYNOPSIS

    leafxml_parse.pl < input.xml > output.txt

# DESCRIPTION

Parses an XML file given on standard input with LeafXML and reports the
fully parsed results on standard output.

Each parsing event is printed on a separate line.  The line always
begins with the line number that the parsing event occurred on, followed
by a colon and a space.

Next comes the event type.  This is either `BEGIN`, `TEXT`, or `END`.

For `TEXT` events, the event type is followed by a space and then the
content text.  Backslashes are encoded as `\\` and line breaks are
encoded as `\n`.

For `BEGIN` events, the event type is followed by a space and then the
element name.  After the element name, there is a list of all
attributes, both plain attributes and external namespaced attributes.
Each attribute is the attribute name, an equals sign, and then the
attribute value double-quoted.  Attribute values encode backslashes as
`\\`, line breaks as `\n`, and double quotes as `\"`.

Each element name and each attribute name has an unsigned decimal
integer and a colon prefixed to it.  If the unsigned decimal integer is
zero, it means the element name or attribute name is not in any
particular namespace.  If the unsigned decimal integer is greater than
zero, it means the name is in a specific namespace.

After all parsed events have been reported on standard output, a
namespace table is written.  This maps the unsigned decimal integers to
the specific namespace values.
