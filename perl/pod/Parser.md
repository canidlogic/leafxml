# NAME

LeafXML::Parser - XML parser for LeafXML subset.

# SYNOPSIS

    use LeafXML::Parser;
    
    # Create a new parser on a Unicode string reference
    my $xml = LeafXML::Parser->create(\$unicode_string);
    
    # Optionally, set a data source name for use in error messages
    $xml->sourceName("example.xml");
    
    # Iterate through all parsed events
    while($xml->readEvent) {
      # Determine event type
      if ($xml->eventType > 0) {
        # Starting tag
        my $lnum  = $xml->lineNumber;
        my $ename = $xml->elementName;
        my $ns_e  = $xml->elementNS;
        my $atts  = $xml->attr;
        my $ext   = $xml->externalAttr;
        
        # Iterate through all attributes not in a namespace
        for my $k (keys %$atts) {
          my $v = $atts->{$k};
          ...
        }
        
        # Iterate through all namespaced attributes
        for my $ns (keys %$ext) {
          for my $k (keys %{{$ext}->{$ns}}) {
            my $v = $ext->{$ns}->{$k};
            ...
          }
        }
      
      } elsif ($xml->eventType == 0) {
        # Content text
        my $lnum = $xml->lineNumber;
        my $text = $xml->contentText;
        ...
        
      } elsif ($xml->eventType < 0) {
        # Ending tag
        my $lnum = $xml->lineNumber;
        ...
      }
    }

# DESCRIPTION

Parser for LeafXML.

The parser operates on a string that has already been decoded into
Unicode codepoints.  An event-based model is used to interpret the XML
file.  This is similar to SAX parsers, except that an event loop is used
instead of callbacks.

The only three event types used in LeafXML are starting tags, ending
tags, and content text that appears between tags.

LeafXML should in most cases be able to parse regular XML files, though
there are some obscure differences between LeafXML and XML.  See the
LeafXML specification for further information.

# CONSTRUCTORS

- **create(\\$unicode\_string)**

    Construct a new LeafXML parser instance.

    The constructor must be given a scalar reference to a Unicode string
    storing the entire LeafXML file to parse.  Undefined behavior occurs if
    this string is manipulated outside the parser in any way while parsing
    is in progress.

    The string must already be decoded such that there is one character per
    Unicode codepoint.  Do not pass a binary string.  No Byte Order Mark
    (BOM) may be present at the start of the string.

# PUBLIC INSTANCE FUNCTIONS

- **sourceName(\[str\])**

    Get or set a data source name for use in diagnostics.

    If called without any parameters, returns the current data source name,
    or `undef` if none defined.  If called with a single parameter, sets
    the data source name, overwriting any current value.  Calling with
    `undef` is allowed, and has the effect of blanking the source name back
    to undefined.

    Defined source names must be scalars.  They will be included in errors
    that are raised by this module during parsing.

- **readEvent()**

    Read the next parsing event from the parser.

    Returns 1 if a new event is available, or 0 if there are no more parsing
    events.  After this function returns 0, any further calls will also
    return 0.

    This must be called before reading the first parsing event.  In other
    words, the first parsing event is not immediately available after parser
    construction.

    Throws errors in case of parsing problems.  Undefined behavior occurs if
    you catch an error and then try to continue parsing.

- **eventType()**

    Determine the type of parsing event that is currently loaded.

    This function may only be used after `readEvent()` has indicated that
    an event is available.

    The return value is 1 for a starting tag, 0 for content text, or -1 for
    an ending tag.

- **lineNumber()**

    Determine the line number in the XML file where the current parsing
    event begins.

    This function may only be used after `readEvent()` has indicated that
    an event is available.

    The first line is line 1.

- **contentText()**

    Determine the decoded content text of a content text event.

    This function may only be used after `readEvent()` has indicated that
    an event is available and `eventType` indicates 0 (content text).

    The content text has already been decoded for entity escapes, and it has
    already been normalized both for line breaks and for Unicode NFC.

    Content text events only occur when they are enclosed in tags.  All
    whitespace is included in content text, and content text events are
    always concatenated so that there is a single span covering everything
    between tags, even across CDATA blocks.

- **elementName()**

    Determine the element name of a starting element event.

    This function may only be used after `readEvent()` has indicated that
    an event is available and `eventType` indicates 1 (starting element).

    The element name is the local name and never includes any namespace
    prefix.  It has already been normalized to NFC.

- **elementNS()**

    Determine the element namespace value of a starting element event.

    This function may only be used after `readEvent()` has indicated that
    an event is available and `eventType` indicates 1 (starting element).

    The namespace value is usually the namespace URI.  `undef` is returned
    if this element is not in any namespace.

- **attr()**

    Return the plain attribute map.  This is returned as a hash reference.
    It is _not_ a copy of the parsed hash reference, so you shouldn't
    modify it.

    This function may only be used after `readEvent()` has indicated that
    an event is available and `eventType` indicates 1 (starting element).

    This hash map has the attribute names as keys and their values as
    values.  Normalization and entity decoding has already been performed.

    Only attribute names that are not in any namespace are included.  The
    special "xmlns" attribute is excluded.

- **externalAttr()**

    Return the namespaced attribute map.  This is returned as a hash
    reference.  It is _not_ a copy of the parsed hash reference, so you
    shouldn't modify it.

    This function may only be used after `readEvent()` has indicated that
    an event is available and `eventType` indicates 1 (starting element).

    The returned hash reference uses the namespace value as the key and maps
    each namespace to another hash that maps local names in that namespace
    to their values.

    Attributes with "xmlns:" prefixes are not included in this mapping.
