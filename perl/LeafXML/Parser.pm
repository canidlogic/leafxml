package LeafXML::Parser;
use v5.16;
use warnings;

use Carp;
use Unicode::Normalize;

use LeafXML::Util qw(
  isInteger
  validCode
  validString
  validName
);

=head1 NAME

LeafXML::Parser - XML parser for LeafXML subset.

=head1 SYNOPSIS

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

=head1 DESCRIPTION

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

=cut

# ===============
# Local functions
# ===============

# _breakNorm(str)
# ---------------
#
# Perform line break normalization on the given string and return the
# normalized version.
#
sub _breakNorm {
  # Get parameters
  ($#_ == 0) or die "Bad call";
  my $str = shift;
  (not ref($str)) or die "Bad call";
  
  # Convert CR+LF and CR+NEL pairs to LF
  $str =~ s/\r(?:\n|\x{85})/\n/g;
  
  # Convert stray CR, NEL, and LS to LF
  $str =~ s/[\r\x{85}\x{2028}]/\n/g;
  
  # Return normalized string
  return $str;
}

# _wsCompress(str)
# ----------------
#
# Perform whitespace compression on the given string and return the
# compressed version.
#
sub _wsCompress {
  # Get parameters
  ($#_ == 0) or die "Bad call";
  my $str = shift;
  (not ref($str)) or die "Bad call";
  
  # Compress whitespace sequences to single spaces
  $str =~ s/[ \t\n\r]+/ /g;
  
  # Trim leading and trailing spaces
  $str =~ s/^\x{20}//;
  $str =~ s/\x{20}$//;
  
  # Return compressed string
  return $str;
}

# _splitName(str)
# ---------------
#
# Split a name into a prefix and a local part.
#
# Returns two values in list context, the first being the prefix and the
# second being the local part.  The prefix does not include the colon,
# and it is undef if there is no namespace.
#
# If the name has exactly one colon, and both the part before and after
# the colon are valid names, then the part before is the prefix and the
# part after is the local name.
#
# In all other cases, the whole name is put into the local part and the
# prefix is undef.  This includes the case where there is more than one
# colon in the name.
#
sub _splitName {
  # Get parameters
  ($#_ == 0) or die "Bad call";
  my $str = shift;
  (not ref($str)) or die "Bad call";
  
  # Define result variables
  my $result_ns    = undef;
  my $result_local = undef;
  
  # Try to split the name
  if ($str =~ /^([^:]+):([^:]+)$/) {
    # Split into namespace prefix and local
    $result_ns = $1;
    $result_local = $2;
    
    # Unless the two are both valid names, fall back to everything in
    # the local part
    unless (validName($result_ns) and validName($result_local)) {
      $result_ns    = undef;
      $result_local = $str;
    }
    
  } else {
    # Not a splittable name
    $result_ns    = undef;
    $result_local = $str;
  }
  
  # Return results
  return ($result_ns, $result_local);
}

=head1 CONSTRUCTORS

=over 4

=item B<create(\$unicode_string)>

Construct a new LeafXML parser instance.

The constructor must be given a scalar reference to a Unicode string
storing the entire LeafXML file to parse.  Undefined behavior occurs if
this string is manipulated outside the parser in any way while parsing
is in progress.

The string must already be decoded such that there is one character per
Unicode codepoint.  Do not pass a binary string.  No Byte Order Mark
(BOM) may be present at the start of the string.

=cut

sub create {
  # Get parameters
  ($#_ == 1) or croak("Bad call");
  shift;
  
  my $str = shift;
  (ref($str) eq 'SCALAR') or croak("Invalid parameter type");
  
  # Create new object
  my $self = { };
  bless($self);
  
  # '_str' stores the string reference
  $self->{'_str'} = $str;
  
  # '_sname' stores the data source name, or undef if not defined
  $self->{'_sname'} = undef;
  
  # '_done' is set to 1 once parsing is complete
  $self->{'_done'} = 0;
  
  # '_lnum' is the current line number in the XML file
  $self->{'_lnum'} = 1;
  
  # '_buf' is the event buffer.
  #
  # Each element is a subarray reference.  Subarrays always have at
  # least one element, where the first element is the line number the
  # element began on.
  #
  # Ending tag subarrays always just have the one element with the line
  # number.
  #
  # Content text subarrays always have two elements, where the first is
  # the line number and the second is the decoded content text.
  #
  # Starting tag subarrays always have five elements:
  #
  #   (1) Line number
  #   (2) Element name
  #   (3) Element namespace, or undef
  #   (4) Attribute map, hash reference
  #   (5) External attribute map, hash reference
  #
  $self->{'_buf'} = [];
  
  # '_cur' is the current loaded element, or undef if none.
  #
  # Has the same format as the elements in the event buffer.
  #
  $self->{'_cur'} = undef;
  
  # '_tstate' is the tag state.
  #
  # 1 means initial state, 0 means active state, -1 means finished
  # state.
  #
  $self->{'_tstate'} = 1;
  
  # '_tstack' is the tag stack.
  #
  # Each starting element pushes the element name onto the tag stack.
  # Each ending element pops an element name off the tag stack, after
  # verifying it matches.
  #
  $self->{'_tstack'} = [];
  
  # '_nstack' is the namespace stack.
  #
  # This stack is never empty.  The element on top is a hash map that
  # maps prefixes to namespace values.  If the empty string is used as a
  # prefix, it sets up a default element namespace.
  #
  # The stack starts out with the "xml" and "xmlns" prefixes defined.
  #
  $self->{'_nstack'} = [
    {
      'xml'   => 'http://www.w3.org/XML/1998/namespace',
      'xmlns' => 'http://www.w3.org/2000/xmlns/'
    }
  ];
  
  # Return new object
  return $self;
}

=back

=cut

# ========================
# Local instance functions
# ========================

# _parseErr(lnum, detail)
# -----------------------
#
# Return a string with a formatted parsing error message.
#
# lnum is the line number, or any integer value less than one if no line
# number available.  detail is the actual error message.
#
# This function does not raise the error itself.
#
sub _parseErr {
  # Get self and parameters
  ($#_ == 2) or die "Bad call";
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die "Bad self";
  
  my $lnum = shift;
  isInteger($lnum) or die "Bad call";
  
  my $detail = shift;
  (not ref($detail)) or die "Bad call";
  
  # Form message
  my $msg = '[XML file';
  
  if (defined $self->{'_sname'}) {
    $msg = $msg . ' "' . $self->{'_sname'} . '"';
  }
  
  if ($lnum >= 1) {
    $msg = $msg . " line $lnum";
  }
  
  $msg = $msg . "] $detail";
  
  # Return message
  return $msg;
}

# _readToken()
# ------------
#
# Read the next raw token from the XML file.
#
# Return has two values in list context.  The first value is the line
# number the token began on.  The second value is the token itself.
#
# If there are no more tokens, both return values will be undef.
#
# The _done and _lnum instance variables will be updated by this
# function.
#
# Line break normalization is already performed on returned tokens,
# because it is necessary to update the line number.  This function will
# also use validString() to make sure that all codepoints within the
# string are valid.
#
sub _readToken {
  # Get self and parameters
  ($#_ == 0) or die "Bad call";
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die "Bad self";

  # If parsing is done, proceed no further and return no more tokens
  if ($self->{'_done'}) {
    return (undef, undef);
  }
  
  # If parsing is not done, attempt to get another token
  my $token;
  if (${$self->{'_str'}} =~ /(

    # ============
    # XML comments
    # ============
    
    (?:
      \x{3c}!\-\-
      (?:[^\-]+|\-[^\-]|\-\-+[^\x{3e}])*
      \-+\-\x{3e}
    ) |
    
    # =======================
    # Processing instructions
    # =======================
    
    (?:
      \x{3c}\?
      (?:[^\?]+|\?+[^\x{3e}])*
      \?+\x{3e}
    ) |
    
    # ===================
    # DOCTYPE declaration
    # ===================
    
    (?:
      \x{3c}!DOCTYPE
      (?:[^\x{3e}'"\x{5b}\x{5d}]+|'[^']*'|"[^"]*")*
      \x{3e}
    ) |
    
    # ===========
    # CDATA block
    # ===========
    
    (?:
      \x{3c}!\x{5b}CDATA\x{5b}
      (?:[^\x{5d}]|\x{5d}[^\x{5d}]|\x{5d}\x{5d}+[^\x{3e}])*
      \x{5d}+\x{5d}\x{3e}
    ) |
    
    # ========
    # Core tag
    # ========
    
    (?:
      \x{3c}[^!\?\x{3e}]
      (?:
        [^\x{3c}\x{3e}'"]+ |
        '[^\x{3c}']*' |
        "[^\x{3c}"]*"
      )*
      \x{3e}
    ) |
    
    # ====
    # Text
    # ====
    
    (?:
      [^\x{3c}]+
    ) |
    
    # =====
    # Error
    # =====
    
    # The only possibility not covered is a lone < bracket that is not
    # part of a valid XML construct.  We will match just this character
    # here, so the tokenizer can easily spot the error.
    
    (?:
      \x{3c}
    )

  )/gsx) {
    
    # We got a token
    $token = $1;
  
  } else {
    # No further tokens
    $self->{'_done'} = 1;
    return (undef, undef);
  }
  
  # Check for parsing error
  if ($token eq '<') {
    die $self->_parseErr($self->{'_lnum'}, "XML tokenization failed");
  }
  
  # Token line number is whatever the line number was before parsing the
  # token
  my $token_line = $self->{'_lnum'};

  # Check that token only contains valid codepoints
  unless (validString($token)) {
    # String has an invalid codepoint, so iterate through updating the
    # token line so we get the correct line number
    my $cv = undef;
    for my $c (split //, $token) {
      $cv = ord($c);
      if ($cv == 0xa) {
        $token_line++;
      } elsif (not validCode($cv)) {
        last;
      }
    }
    (defined $cv) or die;
    
    die $self->_parseErr($token_line, 
      sprintf("Invalid Unicode codepoint U+%04x", $cv));
  }
  
  # Perform line break normalization
  $token = _breakNorm($token);
  
  # Count the number of line breaks
  my @lba = $token =~ /\n/g;
  my $count = scalar(@lba);
  
  # Update line number
  $self->{'_lnum'} += $count;
  
  # Return the token
  return ($token_line, $token);
}

# _entEsc(str, lnum)
# ------------------
#
# Perform entity escaping on the given string and return the string with
# all escapes decoded.
#
# lnum is the line number at the start of the text token, for purposes
# of diagnostics.
#
# This function assumes that line break normalization has already been
# applied to the given string.  If not, then line counting for
# diagnostics might not work correctly.
#
sub _entEsc {
  # Get self and parameters
  ($#_ == 2) or die "Bad call";
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die "Bad self";
  
  my $str = shift;
  (not ref($str)) or die "Bad call";
  
  my $lnum = shift;
  isInteger($lnum) or die "Bad call";
  
  # If there is no ampersand anywhere, then no escaping required
  unless ($str =~ /&/) {
    return $str;
  }
  
  # Result starts out empty
  my $result = '';
  
  # Parse a sequence of plain text, line breaks, escape codes, and
  # invalid ampersands
  while ($str =~ /(
  
        # ===============
        # Plain text span
        # ===============
        
        (?:
          [^&\n]+
        ) |
        
        # ==========
        # Line break
        # ==========
        
        (?:
          \n
        ) |
        
        # =============
        # Entity escape
        # =============
        
        (?:
          &[^;&]*;
        ) |
        
        # =================
        # Invalid ampersand
        # =================
        
        (?:
          &
        )
    
      )/gsx) {
    
    # Get token
    my $token = $1;
    
    # Check for invalid ampersand
    if ($token eq '&') {
      die $self->_parseErr($lnum,
            "Ampersand must be part of entity escape");
    }
    
    # If this is a line break, increase line count
    if ($token eq "\n") {
      $lnum++;
    }
    
    # If this is not an entity escape, copy to result and next token
    unless ($token =~ /^&/) {
      $result = $result . $token;
      next;
    }
    
    # If we got here, token is an entity escape, so process it
    if ($token =~ /^&([a-z]+);$/) {
      # Named escape
      my $ename = $1;
      if ($ename eq 'amp') {
        $result = $result . '&';
        
      } elsif ($ename eq 'lt') {
        $result = $result . '<';
        
      } elsif ($ename eq 'gt') {
        $result = $result . '>';
        
      } elsif ($ename eq 'apos') {
        $result = $result . "'";
        
      } elsif ($ename eq 'quot') {
        $result = $result . '"';
        
      } else {
        die $self->_parseErr($lnum,
              "Unrecognized named entity '$token'");
      }
      
    } elsif ($token =~ /^&\x{23}([0-9]{1,8});$/) {
      # Decimal escape
      my $cv = int($1);
      validCode($cv) or
        die $self->_parseErr($lnum,
              "Escaped codepoint out of range for '$token'");
      $result = $result . chr($cv);
      
    } elsif ($token =~ /^&\x{23}x([0-9A-Fa-f]{1,6});$/) {
      # Base-16 escape
      my $cv = hex($1);
      validCode($cv) or
        die $self->_parseErr($lnum,
              "Escaped codepoint out of range for '$token'");
      $result = $result . chr($cv);
      
    } else {
      die $self->_parseErr($lnum,
          "Invalid entity escape '$token'");
    }
  }
  
  # Return result
  return $result;
}

# _parseAttr(str, lnum)
# ---------------------
#
# Parse the attribute substring of a tag token.  Returns a hash
# reference mapping attribute names to attribute values.  Names have
# been validated and normalized.  Attribute values have been escaped,
# whitespace-compressed, and normalized.
#
# The attribute substring, if it is not empty, should begin with at
# least one codepoint of whitespace which separates it from the the
# element name that precedes it in the tag.
#
sub _parseAttr {
  # Get self and parameters
  ($#_ == 2) or die "Bad call";
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die "Bad self";
  
  my $pstr = shift;
  (not ref($pstr)) or die "Bad call";
  
  my $lnum = shift;
  isInteger($lnum) or die "Bad call";

  # End-trim the parameter substring, but leave leading whitespace
  $pstr =~ s/[ \t\n]+$//;
  
  # Just return empty hash reference if parameter substring empty after
  # end-trimming
  (length($pstr) > 0) or return {};
  
  # The attribute map starts out empty
  my %attr;
  
  # Parse any attributes
  while ($pstr =~ /(
  
        # =======================
        # Double-quoted attribute
        # =======================
        
        (?:
          [ \t\n]+
          [^ \t\n"'=]+
          [ \t\n]*
          =
          [ \t\n]*
          "[^"]*"
        ) |
        
        # =======================
        # Single-quoted attribute
        # =======================
        
        (?:
          [ \t\n]+
          [^ \t\n"'=]+
          [ \t\n]*
          =
          [ \t\n]*
          '[^']*'
        ) |
        
        # ===========
        # Error catch
        # ===========
        
        (?:
          .
        )
    
      )/gsx) {
    
    # Get current part
    my $part = $1;

    # Set part line to current line number then update line number
    my $part_line = $lnum;
    my @apl = $part =~ /\n/g;
    $lnum += scalar(@apl);
    
    # If part is single codepoint then there is a parsing error
    if (length($part) <= 1) {
      die $self->_parseErr($part_line,
        "Failed to parse tag attributes");
    }
    
    # If we got here, we should have an attribute, so parse it into an
    # attribute name and an attribute value
    my $att_name;
    my $att_val;
    
    my $att_name_line;
    my $att_val_line;
    
    if ($part =~
          /^([ \t\n]*)([^ \t\n=]+)([ \t\n]*=[ \t\n]*)"([^"]*)"$/) {
      my $pad1  = $1;
      $att_name = $2;
      my $pad2  = $3;
      $att_val  = $4;
      
      my @apl2 = $pad1 =~ /\n/g;
      my @apl3 = $pad2 =~ /\n/g;
      
      $att_name_line = $part_line     + scalar(@apl2);
      $att_val_line  = $att_name_line + scalar(@apl3);
      
    } elsif ($part =~
          /^([ \t\n]*)([^ \t\n=]+)([ \t\n]*=[ \t\n]*)'([^']*)'$/) {
      my $pad1  = $1;
      $att_name = $2;
      my $pad2  = $3;
      $att_val  = $4;
      
      my @apl2 = $pad1 =~ /\n/g;
      my @apl3 = $pad2 =~ /\n/g;
      
      $att_name_line = $part_line     + scalar(@apl2);
      $att_val_line  = $att_name_line + scalar(@apl3);
      
    } else {
      die $self->_parseErr($lnum, "Failed to parse tag attributes");
    }
    
    # Normalize attribute name and verify valid
    $att_name = NFC($att_name);
    validName($att_name) or
      die $self->_parseErr($att_name_line,
        "Invalid attribute name '$att_name'");
    
    # Make sure attribute value does not have the disallowed <
    (not ($att_val =~ /\x{3c}/)) or
      die $self->_parseErr($att_val_line,
        "Attribute value contains unescaped <");
    
    # Entity-escape, whitespace-compress, and NFC normalize the
    # attribute value
    $att_val = $self->_entEsc($att_val, $att_val_line);
    $att_val = NFC(_wsCompress($att_val));
    
    # Make sure attribute not defined yet
    (not (defined $attr{$att_name})) or
      die $self->_parseErr($att_name_line,
        "Attribute '$att_name' defined multiple times");
    
    # Store the attribute
    $attr{$att_name} = $att_val;
  }
  
  # Return attribute map
  return \%attr;
}

# _parseTag(token, lnum)
# ----------------------
#
# Parse a tag token.
#
# The return value in list context has the following elements:
#
#   (1) Tag type: 1 = start, 0 = empty, -1 = end
#   (2) Element name
#   (3) Hash reference mapping attribute names to attribute values
#
# Names have been validated and normalized.  Attribute values have been
# escaped and normalized.  End tags have been verified to have no
# attributes.
#
sub _parseTag {
  # Get self and parameters
  ($#_ == 2) or die "Bad call";
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die "Bad self";
  
  my $token = shift;
  (not ref($token)) or die "Bad call";
  
  my $lnum = shift;
  isInteger($lnum) or die "Bad call";
  
  # Parse the whole tag
  ($token =~
      /^
        \x{3c}
        (\x{2f})?
        ([^ \t\n\x{2f}\x{3e}"'=]+)
        ((?:
          [^\x{2f}"']* |
          (?:"[^"]*")  |
          (?:'[^']*')
        )*)
        (\x{2f})?
        \x{3e}$
      /xs)
    or die $self->_parseErr($lnum, "Failed to parse tag");
  
  my $start_slash = $1;
  my $ename       = $2;
  my $pstr        = $3;
  my $end_slash   = $4;
  
  # Determine the tag type
  my $etype;
  if ((not defined $start_slash) and (not defined $end_slash)) {
    $etype = 1;
  
  } elsif ((defined $start_slash) and (not defined $end_slash)) {
    $etype = -1;
    
  } elsif ((not defined $start_slash) and (defined $end_slash)) {
    $etype = 0;
    
  } else {
    die $self->_parseErr($lnum, "Failed to parse tag");
  }
  
  # Normalize element name and validate it
  $ename = NFC($ename);
  validName($ename) or
    die $self->_parseErr($lnum, "Invalid tag name '$ename'");
  
  # Parse attributes
  my $attr = $self->_parseAttr($pstr, $lnum);
  
  # If closing tag, make sure no attributes
  if ($etype < 0) {
    (scalar(%$attr) < 1) or
      die $self->_parseErr($lnum,
        "Closing tags may not have attributes");
  }
  
  # Return parsed tag
  return ($etype, $ename, $attr);
}

# _updateNS(attr, lnum)
# ---------------------
#
# Update the namespace stack before processing a starting or empty tag.
#
# attr is the raw attribute map.  lnum is the line number of the tag.
# A new entry will be pushed onto the namespace stack by this fucntion.
#
sub _updateNS {
  # Get self and parameters
  ($#_ == 2) or die "Bad call";
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die "Bad self";
  
  my $attr = shift;
  (ref($attr) eq 'HASH') or die "Bad call";
  
  my $lnum = shift;
  isInteger($lnum) or die "Bad call";
  
  # The new_ns map contains new namespace mappings defined in this
  # element
  my %new_ns;
  
  # Go through attributes
  for my $k (keys %$attr) {
    # Get the prefix mapped by this attribute, or skip attribute if
    # not a namespace mapping
    my $target_pfx = undef;
    
    my ($pfx, $lp) = _splitName($k);
    if (defined $pfx) {
      if ($pfx eq 'xmlns') {
        $target_pfx = $lp;
      }
    } else {
      if ($lp eq 'xmlns') {
        $target_pfx = '';
      }
    }
    
    (defined $target_pfx) or next;
    
    # For diagnostics, get a label of what is being mapped
    my $target_label;
    if (length($target_pfx) > 0) {
      $target_label = "namespace prefix '$target_pfx'";
    } else {
      $target_label = "default namespace";
    }
    
    # Get value of this namespace target and make sure not empty
    my $ns_val = $attr->{$k};
    (length($ns_val) > 0) or
      die $self->_parseErr($lnum,
        "Can't map $target_label to empty value");
    
    # Make sure not mapping the xmlns prefix
    ($target_pfx ne 'xmlns') or
      die $self->_parseErr($lnum,
        "Can't namespace map the xmlns prefix");
    
    # Make sure not mapping to reserved xmlns namespace
    ($ns_val ne 'http://www.w3.org/2000/xmlns/') or
      die $self->_parseErr($lnum,
        "Can't map $target_label to reserved xmlns value");
    
    # If target prefix is "xml" make sure mapping to proper namespace;
    # otherwise, make sure not mapping to XML namespace
    if ($target_pfx eq 'xml') {
      ($ns_val eq 'http://www.w3.org/XML/1998/namespace') or
        die $self->_parseErr($lnum,
          "Can only map $target_label to reserved xml value");
    } else {
      ($ns_val ne 'http://www.w3.org/XML/1998/namespace') or
        die $self->_parseErr($lnum,
          "Can't map $target_label to reserved xml value");
    }
    
    # Make sure this mapping not yet defined on this element
    (not (defined $new_ns{$target_pfx})) or
      die $self->_parseErr($lnum,
        "Redefinition of $target_label on same element");
    
    # Add to new mappings
    $new_ns{$target_pfx} = $ns_val;
  }
  
  # If at least one new mapping, then make a copy of the namespace
  # context on top of the stack, modify it, and push it back;
  # otherwise, just duplicate the reference on top of the namespace
  # stack
  if (scalar(%new_ns) > 0) {
    # New definitions, so make a copy of the namespace on top of the
    # stack
    my %nsa = map { $_ } %{$self->{'_nstack'}->[-1]};
    
    # Update namespace
    for my $kv (keys %new_ns) {
      $nsa{$kv} = $new_ns{$kv};
    }
    
    # Push updated namespace
    push @{$self->{'_nstack'}}, (\%nsa);
    
  } else {
    # No new definitions, just duplicate reference on top
    push @{$self->{'_nstack'}}, ($self->{'_nstack'}->[-1]);
  }
}

# _plainAttr(attr, lnum)
# ----------------------
#
# Return a subset attribute mapping that only contains attributes which
# have no namespace prefix and which are not "xmlns".  The return value
# is a hash reference.
#
sub _plainAttr {
  # Get self and parameters
  ($#_ == 2) or die "Bad call";
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die "Bad self";
  
  my $attr = shift;
  (ref($attr) eq 'HASH') or die "Bad call";
  
  my $lnum = shift;
  isInteger($lnum) or die "Bad call";
  
  # Form the subset
  my %result;
  for my $k (keys %$attr) {
    my ($k_pfx, $k_local) = _splitName($k);
    if ((not defined $k_pfx) and ($k ne 'xmlns')) {
      $result{$k} = $attr->{$k};
    }
  }
  
  # Return result
  return \%result;
}

# _extAttr(attr, lnum)
# --------------------
#
# Return a namespaced attribute mapping.  The return value is a
# two-level hash reference.
#
sub _extAttr {
  # Get self and parameters
  ($#_ == 2) or die "Bad call";
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die "Bad self";
  
  my $attr = shift;
  (ref($attr) eq 'HASH') or die "Bad call";
  
  my $lnum = shift;
  isInteger($lnum) or die "Bad call";
  
  # Form the set
  my %result;
  for my $k (keys %$attr) {
    # Split attribute name if possible
    my ($k_pfx, $k_local) = _splitName($k);
    
    # Only process attributes that have a prefix which is not "xmlns"
    if ((defined $k_pfx) and ($k_pfx ne 'xmlns')) {
      # Get namespace value for prefix
      my $a_ns = $self->{'_nstack'}->[-1]->{$k_pfx};
      (defined $a_ns) or
        die $self->_parseErr($lnum,
          "Unmapped namespace prefix '$k_pfx'");
      
      # Add new namespace entry if not yet defined
      unless (defined $result{$a_ns}) {
        $result{$a_ns} = {};
      }
      
      # Make sure local attribute not yet defined
      (not defined $result{$a_ns}->{$k_local}) or
        die $self->_parseErr($lnum,
          "Aliased external attribute '$k'");
      
      # Add namespaced attribute
      $result{$a_ns}->{$k_local} = $attr->{$k};
    }
  }
  
  # Return result
  return \%result;
}

# _procTag(token, lnum)
# ---------------------
#
# Process a tag assembly.
#
# token is the whole tag token.  lnum is the line number that the tag
# token began.  It is assumed that line break normalization has already
# been performed on the token.
#
sub _procTag {
  # Get self and parameters
  ($#_ == 2) or die "Bad call";
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die "Bad self";
  
  my $token = shift;
  (not ref($token)) or die "Bad call";
  
  my $lnum = shift;
  isInteger($lnum) or die "Bad call";
  
  # Parse the tag
  my ($etype, $ename, $raw_attr) = $self->_parseTag($token, $lnum);
  
  # If this is an opening or empty element, verify that tag state is not
  # finished and then push the element name on the tag stack and set tag
  # state to active
  if ($etype >= 0) {
    ($self->{'_tstate'} >= 0) or
      die $self->_parseErr($lnum, "Multiple root elements");
    
    push @{$self->{'_tstack'}}, ($ename);
    $self->{'_tstate'} = 0;
  }
  
  # If this is a closing or empty element, verify that tag state is
  # active, verify that element on top of tag stack matches current
  # element, and then pop element on top of tag stack, moving to
  # finished state if tag stack now empty
  if ($etype <= 0) {
    ($self->{'_tstate'} == 0) or
      die $self->_parseErr($lnum, "Tag pairing error");
    
    ($self->{'_tstack'}->[-1] eq $ename) or
      die $self->_parseErr($lnum, "Tag pairing error");
    
    pop @{$self->{'_tstack'}};
    if (scalar(@{$self->{'_tstack'}}) < 1) {
      $self->{'_tstate'} = -1;
    }
  }
  
  # If this is an opening or empty element, go through all the raw
  # attributes and update namespace stack
  if ($etype >= 0) {
    $self->_updateNS($raw_attr, $lnum);
  }
  
  # Parse the element name according to namespaces
  my ($e_pfx, $e_local) = _splitName($ename);
  my $e_ns;
  if (defined $e_pfx) {
    $e_ns = $self->{'_nstack'}->[-1]->{$e_pfx};
    (defined $e_ns) or
      die $self->_parseErr($lnum,
        "Unmapped namespace prefix '$e_pfx'");
  }
  
  # If no defined namespace for element but a default namespace, then
  # use the default namespace
  unless (defined $e_ns) {
    $e_ns = $self->{'_nstack'}->[-1]->{''};
  }
  
  # The atts map will have all attributes that do not have a prefix and
  # that are not the special "xmlns" attribute; only has entries for
  # starting and empty tags
  my $atts;
  if ($etype >= 0) {
    $atts = $self->_plainAttr($raw_attr, $lnum);
  } else {
    $atts = {};
  }
  
  # The ext map will have all the namespace attributes that do not have
  # the special "xmlns:" prefix; only has entries for starting and empty
  # tags
  my $ext;
  if ($etype >= 0) {
    $ext = $self->_extAttr($raw_attr, $lnum);
  } else {
    $ext = {};
  }
  
  # If this is a closing or empty element, pop the namespace stack
  if ($etype <= 0) {
    pop @{$self->{'_nstack'}};
  }
  
  # Add the proper entries to the buffer
  if ($etype >= 0) {
    # Starting tag or empty tag, so add a starting tag event to the
    # buffer
    push @{$self->{'_buf'}}, ([
      $lnum,
      $e_local,
      $e_ns,
      $atts,
      $ext
    ]);
  }
  
  if ($etype <= 0) {
    # Empty tag or ending tag, so add an ending tag event to the buffer
    push @{$self->{'_buf'}}, ([$lnum]);
  }
}

# _procContent(text, lnum)
# ------------------------
#
# Process a content assembly.
#
# text is the decoded text of the assembly.  Text tokens must have their
# entities escaped already.  This function will apply line break
# normalization and Unicode normalization to NFC.  This function can be
# called for content assemblies outside of any tags.
#
# lnum is the line number that the text token begins.
#
sub _procContent {
  # Get self and parameters
  ($#_ == 2) or die "Bad call";
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die "Bad self";
  
  my $text = shift;
  (not ref($text)) or die "Bad call";
  
  my $lnum = shift;
  isInteger($lnum) or die "Bad call";
  
  # Ignore if text is empty
  (length($text) > 0) or return;
  
  # Apply line break normalization
  $text = _breakNorm($text);
  
  # If not in active tag state, then just make sure the text only
  # contains spaces, tabs, and line feeds, and then return without any
  # events
  unless ($self->{'_tstate'} == 0) {
    unless ($text =~ /^[ \t\n]*$/) {
      for my $c (split //, $text) {
        if ($c eq "\n") {
          $lnum++;
        }
        unless (($c eq ' ') or ($c eq "\t") or ($c eq "\n")) {
          last;
        } 
      }
      die $self->_parseErr($lnum,
        "Text content not allowed outside root element");
    }
    return;
  }
  
  # We are in active state, so normalize the content text to NFC and add
  # to event buffer
  $text = NFC($text);
  push @{$self->{'_buf'}}, ([$lnum, $text]);
}

=head1 PUBLIC INSTANCE FUNCTIONS

=over 4

=item B<sourceName([str])>

Get or set a data source name for use in diagnostics.

If called without any parameters, returns the current data source name,
or C<undef> if none defined.  If called with a single parameter, sets
the data source name, overwriting any current value.  Calling with
C<undef> is allowed, and has the effect of blanking the source name back
to undefined.

Defined source names must be scalars.  They will be included in errors
that are raised by this module during parsing.

=cut

sub sourceName {
  # Get self
  ($#_ >= 0) or croak("Bad call");
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or croak("Bad self");
  
  # Handle call based on parameters
  if ($#_ == 0) {
    # Set property
    my $val = shift;
    if (defined $val) {
      (not ref($val)) or croak("Bad parameter type");
      $self->{'_sname'} = $val;
      
    } else {
      $self->{'_sname'} = undef;
    }
    
  } elsif ($#_ < 0) {
    # Get property
    return $self->{'_sname'};
    
  } else {
    croak("Bad call");
  }
}

=item B<readEvent()>

Read the next parsing event from the parser.

Returns 1 if a new event is available, or 0 if there are no more parsing
events.  After this function returns 0, any further calls will also
return 0.

This must be called before reading the first parsing event.  In other
words, the first parsing event is not immediately available after parser
construction.

Throws errors in case of parsing problems.  Undefined behavior occurs if
you catch an error and then try to continue parsing.

=cut

sub readEvent {
  # Get self and parameters
  ($#_ == 0) or croak("Bad call");
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or croak("Bad self");
  
  # If buffer is empty, try to refill it
  if (scalar(@{$self->{'_buf'}}) < 1) {
    # Content buffer starts out undefined
    my $content = undef;
    my $content_line = undef;
    
    # Keep processing tokens until we run out of tokens
    for(my ($token_line, $token) = $self->_readToken();
        defined $token;
        ($token_line, $token) = $self->_readToken()) {

      # If this is a CDATA token, then add it to the content buffer
      if ($token =~ /^
      
            \x{3c}!\x{5b}CDATA\x{5b}
            ((?:[^\x{5d}]|\x{5d}[^\x{5d}]|\x{5d}\x{5d}+[^\x{3e}])*)
            \x{5d}+\x{5d}\x{3e}
          
          $/x) {
        $token = $1;
        if (defined $content) {
          $content = $content . $token;
        } else {
          $content = $token;
          $content_line = $token_line;
        }
        next;
      }
      
      # Skip instruction, DOCTYPE, and comment tokens
      if ($token =~ /^\x{3c}[!\?]/) {
        next;
      }
      
      # If this is a text token, then add it to the content buffer after
      # applying entity escaping
      if (not ($token =~ /^\x{3c}/)) {
        $token = $self->_entEsc($token, $token_line);
        if (defined $content) {
          $content = $content . $token;
        } else {
          $content = $token;
          $content_line = $token_line;
        }
        next;
      }
      
      # If we got here, then we're dealing with a regular tag token, so
      # first of all flush the content buffer if filled
      if (defined $content) {
        $self->_procContent($content, $content_line);
        $content = undef;
        $content_line = undef;
      }
      
      # Now process the tag
      $self->_procTag($token, $token_line);
      
      # If buffer is no longer empty, leave loop
      if (scalar(@{$self->{'_buf'}}) > 0) {
        last;
      }
    }
    
    # If content buffer is filled, flush it
    if (defined $content) {
      $self->_procContent($content, $content_line);
      $content = undef;
      $content_line = undef;
    }
  }
  
  # If buffer is filled then grab the next event and set the result;
  # else, clear the results, clear the current event, and verify that in
  # finished state
  my $result = 0;
  if (scalar(@{$self->{'_buf'}}) > 0) {
    $result = 1;
    $self->{'_cur'} = shift @{$self->{'_buf'}};
  } else {
    $result = 0;
    $self->{'_cur'} = undef;
    if ($self->{'_tstate'} >= 0) {
      if ($self->{'_tstate'} == 0) {
        die $self->_parseErr(-1, "Unclosed tags at end of XML");
      } else {
        die $self->_parseErr(-1, "Missing root element");
      }
    }
  }
  
  # Return result
  return $result;
}

=item B<eventType()>

Determine the type of parsing event that is currently loaded.

This function may only be used after C<readEvent()> has indicated that
an event is available.

The return value is 1 for a starting tag, 0 for content text, or -1 for
an ending tag.

=cut

sub eventType {
  # Get self and parameters
  ($#_ == 0) or croak("Bad call");
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or croak("Bad self");
  
  # Check state
  (defined $self->{'_cur'}) or croak("No event loaded");
  
  # Determine result
  my $result;
  if (scalar(@{$self->{'_cur'}}) == 1) {
    $result = -1;
    
  } elsif (scalar(@{$self->{'_cur'}}) == 2) {
    $result = 0;
    
  } elsif (scalar(@{$self->{'_cur'}}) == 5) {
    $result = 1;
    
  } else {
    die;
  }
  
  return $result;
}

=item B<lineNumber()>

Determine the line number in the XML file where the current parsing
event begins.

This function may only be used after C<readEvent()> has indicated that
an event is available.

The first line is line 1.

=cut

sub lineNumber {
  # Get self and parameters
  ($#_ == 0) or croak("Bad call");
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or croak("Bad self");
  
  # Check state
  (defined $self->{'_cur'}) or croak("No event loaded");
  
  # Get line number
  return $self->{'_cur'}->[0];
}

=item B<contentText()>

Determine the decoded content text of a content text event.

This function may only be used after C<readEvent()> has indicated that
an event is available and C<eventType> indicates 0 (content text).

The content text has already been decoded for entity escapes, and it has
already been normalized both for line breaks and for Unicode NFC.

Content text events only occur when they are enclosed in tags.  All
whitespace is included in content text, and content text events are
always concatenated so that there is a single span covering everything
between tags, even across CDATA blocks.

=cut

sub contentText {
  # Get self and parameters
  ($#_ == 0) or croak("Bad call");
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or croak("Bad self");
  
  # Check state
  (defined $self->{'_cur'}) or croak("No event loaded");
  (scalar(@{$self->{'_cur'}} == 2)) or croak("Wrong event type");
  
  # Get text
  return $self->{'_cur'}->[1];
}

=item B<elementName()>

Determine the element name of a starting element event.

This function may only be used after C<readEvent()> has indicated that
an event is available and C<eventType> indicates 1 (starting element).

The element name is the local name and never includes any namespace
prefix.  It has already been normalized to NFC.

=cut

sub elementName {
  # Get self and parameters
  ($#_ == 0) or croak("Bad call");
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or croak("Bad self");
  
  # Check state
  (defined $self->{'_cur'}) or croak("No event loaded");
  (scalar(@{$self->{'_cur'}} == 5)) or croak("Wrong event type");
  
  # Query
  return $self->{'_cur'}->[1];
}

=item B<elementNS()>

Determine the element namespace value of a starting element event.

This function may only be used after C<readEvent()> has indicated that
an event is available and C<eventType> indicates 1 (starting element).

The namespace value is usually the namespace URI.  C<undef> is returned
if this element is not in any namespace.

=cut

sub elementNS {
  # Get self and parameters
  ($#_ == 0) or croak("Bad call");
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or croak("Bad self");
  
  # Check state
  (defined $self->{'_cur'}) or croak("No event loaded");
  (scalar(@{$self->{'_cur'}} == 5)) or croak("Wrong event type");
  
  # Query
  return $self->{'_cur'}->[2];
}

=item B<attr()>

Return the plain attribute map.  This is returned as a hash reference.
It is I<not> a copy of the parsed hash reference, so you shouldn't
modify it.

This function may only be used after C<readEvent()> has indicated that
an event is available and C<eventType> indicates 1 (starting element).

This hash map has the attribute names as keys and their values as
values.  Normalization and entity decoding has already been performed.

Only attribute names that are not in any namespace are included.  The
special "xmlns" attribute is excluded.

=cut

sub attr {
  # Get self and parameters
  ($#_ == 0) or croak("Bad call");
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or croak("Bad self");
  
  # Check state
  (defined $self->{'_cur'}) or croak("No event loaded");
  (scalar(@{$self->{'_cur'}} == 5)) or croak("Wrong event type");
  
  # Query
  return $self->{'_cur'}->[3];
}

=item B<externalAttr()>

Return the namespaced attribute map.  This is returned as a hash
reference.  It is I<not> a copy of the parsed hash reference, so you
shouldn't modify it.

This function may only be used after C<readEvent()> has indicated that
an event is available and C<eventType> indicates 1 (starting element).

The returned hash reference uses the namespace value as the key and maps
each namespace to another hash that maps local names in that namespace
to their values.

Attributes with "xmlns:" prefixes are not included in this mapping.

=cut

sub externalAttr {
  # Get self and parameters
  ($#_ == 0) or croak("Bad call");
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or croak("Bad self");
  
  # Check state
  (defined $self->{'_cur'}) or croak("No event loaded");
  (scalar(@{$self->{'_cur'}} == 5)) or croak("Wrong event type");
  
  # Query
  return $self->{'_cur'}->[4];
}

=back

=cut

# End with something that evaluates to true
#
1;
