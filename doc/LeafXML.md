# LeafXML specification

LeafXML parses a subset of XML.  It does not support every possible XML file.  However, the XML subset supported by LeafXML is a common and useful subset.  Furthermore, LeafXML avoids attempting to parse arcane XML features that could lead to instability or security issues.

## Character set

LeafXML files are a sequence of Unicode codepoints.  All codepoints within a LeafXML file must be one of the following:

- U+0009 (Horizontal Tab; HT)
- U+000A (Line Feed; LF)
- U+000D (Carriage Return; CR)
- U+0020 to U+007E
- U+0085 (Next Line; NEL)
- U+00A0 to U+D7FF
- U+E000 to U+FDCF
- U+FDF0 to U+10FFFD, excluding trailing codepoints

_Trailing codepoints_ are any codepoints where the least significant 16 bits are either FFFE or FFFF.

The codepoint range defined above covers the entire Unicode range of U+0000 to U+10FFFF, except for the following:

- No CO and C1 controls besides HT, LF, CR, and NEL
- No DEL (U+007F)
- No surrogate codepoints
- No internal processing non-characters in U+FDD0 to U+FDEF
- No trailing codepoints

Codepoints that are encoded in numeric entity escapes must be within the character set when decoded.  For example, `&#x84;` is not a valid entity escape, because its decoded value U+0084 is not in the allowed character set.

## Character encoding

When LeafXML is stored in binary streams, the character set defined in the preceding section must be encoded into a sequence of bytes.

The bytes at the beginning of the binary stream determine the specific encoding, as follows:

- `0xFE 0xFF` : UTF-16 BE (Big Endian)
- `0xFF 0xFE` : UTF-16 LE (Little Endian)
- `0xEF 0xBB 0xBF` : UTF-8 with BOM
- Anything else : UTF-8 without BOM

If the bytes at the beginning of the binary stream match one of the three byte signatures given above, then the byte signature is _not_ part of the encoded text data, but rather purely serves to indicate the type of encoding that is used.  If there is no recognized byte signature (UTF-8 without BOM), then the encoded text data starts right away.

For a full specification of UTF-8 and UTF-16, see the separate Unikit project.

## Text algorithms

Certain text processing algorithms are referenced from multiple locations in this specification.  They are documented here in the following subsections so that they do not need to be repeated each time they are mentioned.

### Line break normalization

Line break normalization takes as input a sequence of codepoints and returns a transformed sequence of codepoints, where all line breaks have been normalized to the single codepoint U+000A (LF).  XML standards require this normalization to LF line breaks before passing text to processing applications.

XML 1.1 allows for all the following types of line breaking styles, which should all be normalized to U+000A by the line break normalization algorithm:

1. U+000A (LF)
2. U+000D U+000A (CR+LF)
3. U+000D U+0085 (CR+NEL)
4. U+0085 (NEL)
5. U+2028 (LS)
6. U+000D (CR)

Longest possible matching should be used for converting line breaks.  That is, U+000D (CR) should only be matched as a line break if it is not followed by U+000A (LF) or U+0085 (NEL).  If CR is followed by LF or NEL, then the longer match CR+LF or CR+NEL should be used instead of the shorter match CR.

Line break normalization is not performed right away on the decoded codepoint stream because line break codepoints might be encoded in entity escapes, which have not been processed yet.

### Unicode normalization

Unicode normalization takes as input a sequence of codepoints and returns a transformed sequence of codepoints that has been normalized according to the Unicode algorithms.  LeafXML always uses Unicode normal form NFC.

Unicode normalization is not performed right away on the decoded codepoint stream because some codepoints might be encoded in entity escapes, which have not been processed yet.  Also, content assemblies need to be concatenated from tokens before they are normalized, since concatenating two normalized strings does not always yield a normalized result. 

For a full specification of Unicode normalization, see the separate Unikit project.

### Entity escaping

The entity escaping algorithm takes as input a sequence of codepoints and returns a transformed sequence of codepoints where all entity escapes have been replaced by the codepoints they encode.

Entity escaping is not performed right away on the decoded codepoint stream because not all text in an XML document is subject to entity escaping.

All entity escapes begin with U+0026 (`&`) and run up to and including the next U+003B (`;`).  It is an error if no U+003B is present before the end of the input codepoint sequence.  Every instance of U+0026 in the input codepoint sequence is the start of an entity escape.

The following named entity escapes are replaced with specific codepoints as indicated below.  These are escapes for literal symbols that would cause parsing errors if they were not escaped:

- `&amp;` for U+0026 (`&`)
- `&lt;` for U+003C (`<`)
- `&gt;` for U+003E (`>`)
- `&apos;` for U+0027 (`'`)
- `&quot;` for U+0022 (`"`)

The following two kinds of numeric entity escapes are also supported:

- `&#60;` for a decimal numeric escape
- `&#x3c;` for a base-16 numeric escape

The base-16 digits used in base-16 numeric escapes are case insensitive, so you can use `&#x3c` or `&#x3C` with no difference in meaning.  However, the `x` at the start of the base-16 numeric escape _is_ case sensitive and must be lowercase.  The number of digits used in numeric escapes is variable, but LeafXML encoders should use the minimum possible number of digits.

There is no difference in meaning between a named escape, a decimal numeric escape, or a base-16 numeric escape.  Therefore, `&lt;`, `&#60;`, and `&#x3c;` all select U+003C with no difference in meaning.

Numeric escapes are only allowed to escape codepoints that are within the character set defined ealier.  For example, `&#xFFFE;` is not allowed because U+FFFE is not within the character set.

### Whitespace compression

The whitespace compression algorithm takes as input a sequence of codepoints and returns a transformed sequence of codepoints where all whitespace has been "compressed."

All whitespace sequences consisting only of the following codepoints are replaced with a single U+0020 SP codepoint:

- U+0009 Horizontal Tab (HT)
- U+000A Line Feed (LF)
- U+000D Carriage Return (CR)
- U+0020 Space (SP)

After that replacement is performed, any leading or trailing U+0020 SP codepoints are dropped from the string.

The result is that U+0020 SP is the only XML whitespace codepoint used in the compressed string, it is neither the first nor last codepoint in a compressed string, and two U+0020 SP codepoints never occur next to each other in a compressed string.

## Tokenizing

Unicode codepoints within a LeafXML file are parsed into a sequence of _tokens._  Each token consists of a non-empty sequence of Unicode codepoints.  Concatenating each of the tokens together yields the full sequence of codepoints in the file.

LeafXML has the following types of tokens:

1. Text tokens
2. Tag tokens
3. CDATA tokens
4. Instruction tokens
5. DOCTYPE tokens
6. Comment tokens

_Text tokens_ are codepoint sequences that may contain any codepoints except U+003C `<`.  Text tokens may not be empty and must contain at least one codepoint.  Text tokens are the only token type that does not begin with the U+003C codepoint.

_Tag tokens_ begin with U+003C `<`, followed by any codepoint other than U+0021 (`!`), U+003F (`?`) or U+003E (`>`).  Tag tokens consist of a mixture of the following three span types:

1. Plain spans
2. Single-quote spans
3. Double-quote spans

Plain spans contain any sequence of codepoints other than U+003E (`>`), U+0027 (`'`), or U+0022 (`"`).  Single-quote spans begin and end with U+0027 (`'`), and between those delimiters contain an optional sequence of any codepoints except for the U+0027 delimiter.  Double-quote spans begin and end with U+0022 (`"`), and between those delimiters contain an optional sequence of any codepoints except for the U+0022 delimiter.

Tag tokens run up to and including the first U+003E (`>`) that is not part of a single-quote or double-quote span.  It is an error if there is no such U+003E before the end of the file.

_CDATA tokens_ begin with the following opening sequence:

    <![CDATA[

CDATA tokens run up to and including the first instance of the following closing sequence:

    ]]>

It is an error if there is no closing sequence before the end of the file.

_Instruction tokens_ begin with the following opening sequence

    <?

They run up to and including the first instance of the following closing sequence:

    ?>

The opening and closing sequences of instruction tokens may not share the `?` codepoint.  In other words, there must be at least two `?` codepoints within an instruction token.  It is an error if there is no closing sequence before the end of the file.

_DOCTYPE tokens_ begin with the following opening sequence:

    <!DOCTYPE

DOCTYPE tokens consist of a mixture of the following three span types:

1. Type spans
2. Single-quote spans
3. Double-quote spans

Type spans contain any sequence of codepoints other than U+003E (`>`), U+0027 (`'`), U+0022 (`"`), U+005B (`[`), or U+005D (`]`).  Single-quote spans begin and end with U+0027 (`'`), and between those delimiters contain an optional sequence of any codepoints except for the U+0027 delimiter.  Double-quote spans begin and end with U+0022 (`"`), and between those delimiters contain an optional sequence of any codepoints except for the U+0022 delimiter.

DOCTYPE tokens run up to and including the first U+003E (`>`) that is not part of a single-quote or double-quote span.  It is an error if there is no such U+003E before the end of the file.

The XML standards allow DOCTYPE tokens to contain embedded DTD declarations between U+005B (`[`) and U+005D (`]`) delimiters.  However, this is a complex feature that is seldom used in practice, so LeafXML prevents its use by blocking the U+005B and U+005D delimiters within DOCTYPE tokens.

_Comment tokens_ begin with the following opening sequence:

    <!--

Comment tokens run up to and including the first instance of the following closing sequence:

    -->

It is an error if there is no closing sequence before the end of the file.

### Token filtering

LeafXML decoders apply _token filtering_ to discard certain tokens before applying further processing.  Token filtering discards the following token types:

1. Instruction tokens
2. DOCTYPE tokens
3. Comment tokens

Before discarding a DOCTYPE token, LeafXML decoders should verify that there is at most one DOCTYPE token in the XML document and that the DOCTYPE token occurs before the first tag token.

Discarding tokens is important so that content assemblies (described later) are not broken up by interleaved instruction or comment tokens during decoding.

## Assembly

Tokens are grouped into _assemblies,_ where each assembly contains a sequence of one or more tokens.  When the tokens of each assembly are concatenated together into one long sequence, this concatenated sequence is equivalent to the full sequence of tokens in the LeafXML file, excluding tokens that are discarded by token filtering.  The following subsections document the types of assemblies and their uses.

### Content assemblies

Sequences of text and CDATA tokens are contained within content assemblies.  LeafXML decoders will join sequences of adjacent text and CDATA tokens into single content assemblies by concatenation.  This concatenation takes place after token filtering.

Before text tokens are concatenated into a content assembly, entity escaping is applied to the text token.

Before CDATA tokens are concatenated into a content assembly, the opening and closing sequences of the CDATA block are trimmed out.  Entity escaping is _not_ applied to CDATA tokens.

After all text and CDATA tokens have been concatenated into a content assembly, line break normalization is performed.  Finally, the full text data within the content assembly is run through Unicode normalization to NFC.

If the full content assembly after decoding and normalization is empty, then it is discarded by decoders.  If the full content assembly after decoding and normalization is not empty but contains only the following characters, then it is a _padding content assembly:_

- U+0009 (Horizontal Tab; HT)
- U+0020 (Space; SP)
- U+000A (Line Feed; LF)

Padding content assemblies that appear before the first tag assembly or after the last tag assembly are discarded by decoders.  If any non-padding content assembly appears before the first tag assembly or after the last tag assembly, then LeafXML decoders will treat this as a stray content error.

### Tag assemblies

Each tag token is contained within its own separate tag assembly.  Before parsing a tag token within a tag assembly, line break normalization is performed on the whole tag token.

_Whitespace_ is defined as any codepoint sequence consisting only of the following codepoints:

- U+0009 Horizontal Tab (HT)
- U+000A Line Feed (LF)
- U+0020 Space (SP)

A _name_ is a sequence of one or more codepoints, where every codepoint is one of the following:

- U+002D (`-`)
- U+002E (`.`)
- U+0030 through U+0039 (`0-9`)
- U+003A (`:`)
- U+005F (`_`)
- U+0041 through U+005A (`A-Z`)
- U+0061 through U+007A (`a-z`)
- U+00B7 (Middle Dot)
- U+00C0 through U+1FFF, except U+00D7, U+00F7, and U+037E
- U+200C (ZWNJ)
- U+200D (ZWJ)
- U+203F (Tie Above)
- U+2040 (Tie Under)
- U+2070 through U+218F
- U+2C00 through U+2FEF
- U+3001 through U+D7FF
- U+F900 through U+FDCF
- U+FDF0 through U+EFFFD, except trailing codepoints

(Trailing codepoints are any codepoint where the 16 least significant bits are FFFE or FFFF.  Trailing codepoints are excluded from the character set defined earlier.)

In addition, the first codepoint of a name may not be any of the following:

- U+002D (`-`)
- U+002E (`.`)
- U+0030 through U+0039 (`0-9`)
- U+00B7 (Middle Dot)
- U+0300 to U+036F (Combining Diacritical Marks)
- U+203F (Tie Above)
- U+2040 (Tie Under)

A tag token is parsed according to the following model:

1. U+003C (`<`)
2. Optionally, U+002F (`/`)
3. Tag name
4. Zero or more attributes
5. Optional whitespace
6. Optionally, U+002F (`/`)
7. U+003E (`>`)

Items (2) and (6) within a tag token may not be both present at the same time.  However, it possible to have one or the other, or neither.  If neither is present, the tag is a _start tag._  If (2) is present, the tag is an _end tag._  If (6) is present, the tag is an _empty tag._

End tags may not have any attributes.

Attributes are parsed according to the following model:

1. Required whitespace
2. Attribute name
3. Optional whitespace
4. U+003D (`=`)
5. Optional whitespace
6. Attribute value

Attribute values are either double-quoted or single-quoted, with no difference in meaning between the two styles.  A single tag token may mix both attribute value styles.

Double-quoted attribute values are parsed according to the following model:

1. U+0022 (`"`)
2. Any sequence of codepoints except U+0022 and U+003C 
3. U+0022 (`"`)

Single-quoted attribute values are parsed according to the following model:

1. U+0027 (`'`)
2. Any sequence of codepoints except U+0027, and U+003C
3. U+0027 (`'`)

The sequence of codepoints within quoted attribute values may be empty.  Entity escaping is used within attribute values.

The tag assembly is a parsed representation of the tag.  The tag assembly has the following information:

1. Element name
2. Tag type (start, end, or empty)
3. Mapping of attribute names to attribute values

End tags always have an empty attribute map, because attributes are not allowed on end tags.

The element name is from item (3) in the tag token model.  Element names are normalized according to NFC.  Element names are case-sensitive.

The tag type is determined by the presence of slashes next to the angle brackets, as described earlier.

Each attribute name is normalized according to NFC and used as the key in the attribute mapping.  Attribute names are case-sensitive.  It is an error if the same tag has more than one attribute with the same attribute name.

Each attribute value is decoded first by entity escaping, second by whitespace compression, and third by Unicode normalization to NFC.  Empty attribute values are allowed.

## Empty tag expansion

During decoding, each empty tag assembly is automatically replaced by a starting tag assembly followed immediately by an ending tag assembly.  The starting tag assembly is identical to the original empty tag except for the starting tag type.  The ending tag assembly has the same element name as the starting tag but it has no attributes in its attribute mapping. 

A starting tag followed immediately by a closing tag is equivalent in XML to an empty tag.  Empty tag expansion allows LeafXML decoders to handle both cases the exact same way.

## Tag stack

Each tag assembly causes a modification to the _tag stack._  The tag stack starts out empty, and its state starts out "initial."  When the first element is pushed onto the tag stack, its state changes to "active."  If the tag stack becomes empty in active state, its state changes to "finished."  It is an error if an element is pushed onto the tag stack when its state is "finished," because this would indicate more than one root element.

Each starting tag pushes its element name onto the tag stack.  Each ending tag verifies that the tag stack is not empty and that the element name on top of the tag stack matches the element name in the ending tag.  Then, each ending tag pops its element name off the top of the tag stack.  Due to empty tag expansion, there should be no empty tag assemblies at this point to process.

At the end of XML interpretation, the tag stack must be empty in "finished" state.  If it is not empty, then there are unclosed tags.  If it is not in "finished" state, then no tags were present.

## Namespace processing

Starting and ending tag assemblies have namespace processing performed on them before they are reported to clients.

A _namespace context_ is a mapping of prefixes to namespace values.  Prefixes have the same format as the name specification given earlier for tag assemblies, except a prefix may not contain U+003A (`:`).  The empty string can also be present as a key in a namespace context, in which case it means the default namespace.

The _namespace stack_ is a stack of namespace contexts.  This stack starts out with a single element, which is the default context.  The namespace stack should never become empty during interpretation.

The default context has the following two mappings:

    xml   -> http://www.w3.org/XML/1998/namespace
    xmlns -> http://www.w3.org/2000/xmlns/

### Namespace declarations

When a starting tag is encountered, a check is made whether any of its attribute names are `xmlns` or begin with `xmlns:`.  If the starting tag has no such attributes, then the namespace context on top of the namespace stack is duplicated on top of the namespace stack.

If there is at least one such attribute, then a copy is made of the context currently on top of the namespace stack, this copy is modified by the namespace attributes, and then the modified namespace context is pushed on top of the namespace stack.

If an attribute with name `xmlns` is present, then a default namespace is added to the new namespace context, overwriting any existing default namespace that may be present.

For each attribute with name beginning with `xmlns:`, the remainder of the attribute name after the colon must be a valid namespace prefix.  A mapping will be added in the new namespace context from this declared prefix, overwriting any existing mapping for that prefix that may be present.

The value of namespace attributes must not be empty.  The value is normalized to Unicode NFC normal form but is otherwise not parsed.

It is an error to attempt to explicitly map the prefix `xmlns` to anything.  Therefore, an attribute with name `xmlns:xmlns` will cause an error and be rejected.

It is allowed to map the prefix `xml`, but the mapped value must always be `http://www.w3.org/XML/1998/namespace`.  No other prefix may ever be mapped to this value.

No prefix may ever be explicitly mapped to the value `http://www.w3.org/2000/xmlns/`.

It is acceptable for two different prefixes to map to the same namespace value.

### Tag rewriting

After all namespace declarations on a starting tag have been handled and the namespace stack has been updated, the next step in LeafXML decoding is to rewrite the starting tag according to namespaces.

If the element name does not have any U+003A (`:`), then the tag namespace is the default namespace in the context on top of the namespace stack.  If there is no default namespace, then the tag namespace is empty.

If the element name has a U+003A (`:`), then there must be exactly one such codepoint in the name.  Split the element name into a prefix (before the U+003A) and a local part (after the U+003A).  Both the prefix and the local part must be non-empty and valid names according to the name specification given earlier for tag assemblies.  The prefix must be present in the context on top of the namespace stack.  The tag namespace in this case is the value the prefix is mapped to in the context.

The local attribute map is a subset of the tag attribute map that excludes any attribute name that has U+003A (`:`) somewhere within it, and also excludes the attribute name `xmlns`.

The external attribute map is a two-level map where the first level has keys equal to namespace values and the second level has local attribute names within those namespaces as keys.  Any attribute name that has U+003A (`:`) somewhere within it must have exactly one such codepoint, which splits the name into a prefix and a local part, both of which are valid names, just like parsing prefixed element names.  If the prefix is `xmlns` then the attribute is skipped and not added to the external attribute map.  Otherwise, the namespace value is looked up in the namespace context on top of the namespace stack and used as the first-level key.  The local part is then used as the second-level key.
