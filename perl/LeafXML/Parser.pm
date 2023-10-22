package LeafXML::Parser;
use v5.16;
use warnings;

use Carp;
use Scalar::Util qw(looks_like_number);
use Unicode::Normalize;

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
      my %atts  = $xml->attr;
      my $ext   = $xml->externalAttr;
      
      # Iterate through all attributes not in a namespace
      for my $k (keys %atts) {
        my $v = $atts{$k};
        ...
      }
      
      # Iterate through all namespaced attributes
      for my $ns (keys %$ext) {
        for my $k (keys %{$ext->{$ns}}) {
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

Parser for the LeafXML subset of XML.

The parser operates on a string that has already been decoded into
Unicode codepoints.  An event-based model is used to interpret the XML
file.  This is similar to SAX parsers, except that an event loop is used
instead of callbacks.

The only three event types used in LeafXML are starting tags, ending
tags, and content text that appears between tags.

=cut

# ===============
# Local functions
# ===============

# _isInteger(val)
# ---------------
#
# Check that the given value is an integer.  Return 1 if an integer or 0
# if not.
#
sub _isInteger {
  ($#_ == 0) or die "Bad call";
  my $val = shift;
  
  looks_like_number($val) or return 0;
  (int($val) == $val) or return 0;
  
  return 1;
}

# _validCode(codepoint)
# ---------------------
#
# Check whether a given integer value is a valid Unicode codepoint that
# can be used within LeafXML.  Returns 1 if yes, 0 if not.
#
sub _validCode {
  ($#_ == 0) or die "Bad call";
  my $val = shift;
  _isInteger($val) or die "Bad call";
  
  my $result = 0;
  if (($val == 0x9) or ($val == 0xa) or ($val == 0xd) or
      (($val >= 0x20) and ($val <= 0x7e)) or
      ($val == 0x85) or
      (($val >= 0xa0) and ($val <= 0xd7ff)) or
      (($val >= 0xe000) and ($val <= 0xfdcf)) or
      (($val >= 0xfdf0) and ($val <= 0x10fffd))) {
    
    if (($val & 0xffff) < 0xfffe) {
      $result = 1;
    }
  }
  
  return $result;
}

# _validString(str)
# -----------------
#
# Check whether a given string only contains codepoints that pass the
# _validCode() function.  Returns 1 if yes, 0 if not.  Empty strings do
# pass this function.
#
# This function is optimized so that it does not actually invoke
# _validCode() but rather uses a regular expression.
#
sub _validString {
  ($#_ == 0) or die "Bad call";
  my $str = shift;
  (not ref($str)) or die "Bad call";
  
  my $result = 0;
  
  if ($str =~ /^(?:
  
        (?:
          [\t\n\r\x{20}-\x{7e}\x{85}\x{a0}-\x{d7ff}]+
        ) |
        
        (?:
          [\x{e000}-\x{fdcf}\x{fdf0}-\x{fffd}]+
        ) |
        
        (?:
          [\x{10000}-\x{1fffd}\x{20000}-\x{2fffd}\x{30000}-\x{3fffd}]+
        ) |
        
        (?:
          [\x{40000}-\x{4fffd}\x{50000}-\x{5fffd}\x{60000}-\x{6fffd}]+
        ) |
        
        (?:
          [\x{70000}-\x{7fffd}\x{80000}-\x{8fffd}\x{90000}-\x{9fffd}]+
        ) |
        
        (?:
          [\x{a0000}-\x{afffd}\x{b0000}-\x{bfffd}\x{c0000}-\x{cfffd}]+
        ) |
        
        (?:
          [\x{d0000}-\x{dfffd}\x{e0000}-\x{efffd}\x{f0000}-\x{ffffd}]+
        ) |
        
        (?:
          [\x{100000}-\x{10fffd}]+
        )
  
      )*$/x) {
    $result = 1;
  }
  
  return $result;
}

# _validName(str)
# ---------------
#
# Check whether a given string qualifies as a valid XML name.  This
# function allows names to contain colons.
#
sub _validName {
  # Get parameters
  ($#_ == 0) or die "Bad call";
  my $str = shift;
  (not ref($str)) or die "Bad type";
  
  # Check that name is sequence of one or more name codepoints
  my $result = 1;
  unless ($str =~ /^(?:
        
        (?:
          [\-\.0-9:_A-Za-z\x{b7}\x{c0}-\x{d6}\x{d8}-\x{f6}]+
        ) |
        
        (?:
          [\x{f8}-\x{37d}\x{37f}-\x{1fff}\x{200c}\x{200d}]+
        ) |
        
        (?:
          [\x{203f}\x{2040}\x{2070}-\x{218f}\x{2c00}-\x{2fef}]+
        ) |
        
        (?:
          [\x{3001}-\x{d7ff}\x{f900}-\x{fdcf}\x{fdf0}-\x{fffd}]+
        ) |
        
        (?:
          [\x{10000}-\x{1fffd}\x{20000}-\x{2fffd}\x{30000}-\x{3fffd}]+
        ) |
        
        (?:
          [\x{40000}-\x{4fffd}\x{50000}-\x{5fffd}\x{60000}-\x{6fffd}]+
        ) |
        
        (?:
          [\x{70000}-\x{7fffd}\x{80000}-\x{8fffd}\x{90000}-\x{9fffd}]+
        ) |
        
        (?:
          [\x{a0000}-\x{afffd}\x{b0000}-\x{bfffd}\x{c0000}-\x{cfffd}]+
        ) |
        
        (?:
          [\x{d0000}-\x{dfffd}\x{e0000}-\x{efffd}]+
        )
        
      )+$/x) {
    $result = 0;
  }
  
  # Check that first codepoint is valid
  if ($result) {
    if ($str =~ /^[\-\.0-9\x{b7}\x{300}-\x{36f}\x{203f}\x{2040}]/) {
      $result = 0;
    }
  }
  
  # Return result
  return $result;
}

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
    unless (_validName($result_ns) and _validName($result_local)) {
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
  _isInteger($lnum) or die "Bad call";
  
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
# also use _validString() to make sure that all codepoints within the
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
  unless (_validString($token)) {
    # String has an invalid codepoint, so iterate through updating the
    # token line so we get the correct line number
    my $cv = undef;
    for my $c (split //, $token) {
      $cv = ord($c);
      if ($cv == 0xa) {
        $token_line++;
      } elsif (not _validCode($cv)) {
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
  _isInteger($lnum) or die "Bad call";
  
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
      _validCode($cv) or
        die $self->_parseErr($lnum,
              "Escaped codepoint out of range for '$token'");
      $result = $result . chr($cv);
      
    } elsif ($token =~ /^&\x{23}x([0-9A-Fa-f]{1,6});$/) {
      # Base-16 escape
      my $cv = hex($1);
      _validCode($cv) or
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
  _isInteger($lnum) or die "Bad call";
  
  # Save the tag line number
  my $tag_lnum = $lnum;
  
  # Parse the tag before any attributes
  ($token =~ /^\x{3c}(\x{2f})?([^ \t\n\x{2f}\x{3e}"'=]+)(.*)$/s) or
    die $self->_parseErr($lnum, "Failed to parse tag");
  
  my $start_slash = $1;
  my $ename       = $2;
     $token       = $3;
  
  if (defined $start_slash) {
    $start_slash = 1;
  } else {
    $start_slash = 0;
  }
  
  $ename = NFC($ename);
  _validName($ename) or
    die $self->_parseErr($lnum, "Invalid tag name '$ename'");

  # The raw attribute map starts out empty
  my %raw_attr;
  
  # Parse any attributes and the closing tag
  my $end_slash = 0;
  my $found_end = 0;
  
  while ($token =~ /(
  
        # =======================
        # Double-quoted attribute
        # =======================
        
        (?:
          [ \t\n]+
          [^ \t\n\x{2f}\x{3e}"'=]+
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
          [^ \t\n\x{2f}\x{3e}"'=]+
          [ \t\n]*
          =
          [ \t\n]*
          '[^']*'
        ) |
        
        # ================
        # Closing sequence
        # ================
        
        (?:
          [ \t\n]*\x{2f}?\x{3e}
        ) |
        
        # ===========
        # Error catch
        # ===========
        
        (?:
          [^\x{3e}]
        )
    
      )/gsx) {
    
    # Get current part
    my $part = $1;

    # Set part line to current line number then update line number
    my $part_line = $lnum;
    my @apl = $part =~ /\n/g;
    $lnum += scalar(@apl);
    
    # If we already found the tag end, error if anything more
    (not $found_end) or
      die $self->_parseErr($part_line, "Failed to parse tag");
    
    # If part is single codepoint that is not > then there is a parsing
    # error
    if ((length($part) == 1) and ($part ne '>')) {
      die $self->_parseErr($part_line, "Failed to parse tag");
    }
    
    # If part is the closer, then update state and proceed to next part
    if ($part =~ /^[ \t\n]*\x{3e}$/) {
      $end_slash = 0;
      $found_end = 1;
      next;
      
    } elsif ($part =~ /^[ \t\n]*\x{2f}\x{3e}$/) {
      $end_slash = 1;
      $found_end = 1;
      next;
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
      die $self->_parseErr($lnum, "Failed to parse tag");
    }
    
    # Normalize attribute name and verify valid
    $att_name = NFC($att_name);
    _validName($att_name) or
      die $self->_parseErr($att_name_line,
        "Invalid attribute name '$att_name'");
    
    # Make sure attribute value does not have disallowed codepoints
    # besides the delimiter
    (not ($att_val =~ /\x{3c}/)) or
      die $self->_parseErr($att_val_line,
        "Attribute value contains unescaped <");
    
    # Entity-escape, line-break-normalize, and NFC normalize the
    # attribute value
    $att_val = $self->_entEsc($att_val, $att_val_line);
    $att_val = NFC(_breakNorm($att_val));
    
    # Make sure attribute not defined yet
    (not (defined $raw_attr{$att_name})) or
      die $self->_parseErr($att_name_line,
        "Attribute '$att_name' defined multiple times");
    
    # Store the attribute
    $raw_attr{$att_name} = $att_val;
  }
  
  # Make sure we found the ending
  ($found_end) or
    die $self->_parseErr($lnum, "Failed to parse tag");
  
  # Get the element type as 1 opening, 0 empty, -1 closing depending on
  # the slashes
  my $etype;
  if (($start_slash == 0) and ($end_slash == 0)) {
    $etype = 1;
    
  } elsif (($start_slash == 1) and ($end_slash == 0)) {
    $etype = -1;
    
  } elsif (($start_slash == 0) and ($end_slash == 1)) {
    $etype = 0;
    
  } else {
    die $self->_parseErr($lnum, "Failed to parse tag");
  }
  
  # If this is a closing element, make sure there are no attributes
  if ($etype < 0) {
    if (scalar(%raw_attr) > 0) {
      die $self->_parseErr($lnum,
        "Closing element may not have attributes");
    }
  }
  
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
    # The new_ns map contains new namespaces defined in this element
    my %new_ns;
    
    # Go through attributes
    for my $k (keys %raw_attr) {
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
      
      # Get value of this namespace target and make sure not empty
      my $ns_val = $raw_attr{$k};
      (length($ns_val) > 0) or
        die $self->_parseErr($lnum, "Can't map namespace to empty");
      
      # Make sure not mapping the xmlns prefix
      ($target_pfx ne 'xmlns') or
        die $self->_parseErr($lnum,
          "Can't namespace map the xmlns prefix");
      
      # Make sure not mapping to reserved xmlns namespace
      ($ns_val ne 'http://www.w3.org/2000/xmlns/') or
        die $self->_parseErr($lnum,
          "Can't map namespace to xmlns value");
      
      # If target prefix is "xml" make sure mapping to proper namespace;
      # otherwise, make sure not mapping to XML namespace
      if ($target_pfx eq 'xml') {
        ($ns_val eq 'http://www.w3.org/XML/1998/namespace') or
          die $self->_parseErr($lnum,
            "Can't remap xml namespace prefix");
      } else {
        ($ns_val ne 'http://www.w3.org/XML/1998/namespace') or
          die $self->_parseErr($lnum,
            "Can't alias xml namespace");
      }
      
      # Make sure this mapping not yet defined on this element
      (not (defined $new_ns{$target_pfx})) or
        die $self->_parseErr($lnum,
          "Redefinition of '$target_pfx' prefix on same element");
      
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
  
  # Parse the element name according to namespaces
  my ($e_ns, $e_local) = _splitName($ename);
  if (defined $e_ns) {
    (defined $self->{'_nstack'}->[-1]->{$e_ns}) or
      die $self->_parseErr($lnum,
        "Unmapped namespace prefix '$e_ns'");
    $e_ns = $self->{'_nstack'}->[-1]->{$e_ns};
  }
  
  # If no defined namespace for element but a default namespace, then
  # use the default namespace
  unless (defined $e_ns) {
    if (defined $self->{'_nstack'}->[-1]->{''}) {
      $e_ns = $self->{'_nstack'}->[-1]->{''};
    }
  }
  
  # The %atts map will have all attributes that do not have a prefix and
  # that are not the special "xmlns" attribute; only has entries for
  # starting and empty tags
  my %atts;
  if ($etype >= 0) {
    for my $k (keys %raw_attr) {
      my ($k_pfx, $k_local) = _splitName($k);
      if ((not defined $k_pfx) and ($k ne 'xmlns')) {
        $atts{$k} = $raw_attr{$k};
      }
    }
  }
  
  # The %ext map will have all the namespace attributes that do not have
  # the special "xmlns:" prefix; only has entries for starting and empty
  # tags
  my %ext;
  if ($etype >= 0) {
    for my $k (keys %raw_attr) {
      my ($k_pfx, $k_local) = _splitName($k);
      if ((defined $k_pfx) and ($k_pfx ne 'xmlns')) {
        (defined $self->{'_nstack'}->[-1]->{$k_pfx}) or
          die $self->_parseErr($lnum,
            "Unmapped namespace prefix '$k_pfx'");
        
        my $a_ns = $self->{'_nstack'}->[-1]->{$k_pfx};
        unless (defined $ext{$a_ns}) {
          $ext{$a_ns} = {};
        }
        
        (not defined $ext{$a_ns}->{$k_local}) or
          die $self->_parseErr($lnum,
            "Aliased external attribute '$k'");
        
        $ext{$a_ns}->{$k_local} = $raw_attr{$k};
      }
    }
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
      $tag_lnum,
      $e_local,
      $e_ns,
      \%atts,
      \%ext
    ]);
  }
  
  if ($etype <= 0) {
    # Empty tag or ending tag, so add an ending tag event to the buffer
    push @{$self->{'_buf'}}, ([$tag_lnum]);
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
  _isInteger($lnum) or die "Bad call";
  
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
      
      # Skip instruction, DOCTYPE, and comment tokens
      if ($token =~ /^\x{3c}[!\?]/) {
        next;
      }
      
      # If this is a CDATA token, then add it to the content buffer
      if ($token =~
            /^\x{3c}!\x{5b}CDATA\x{5b}(.*)\x{5d}\x{5d}\x{3e}$/) {
        $token = $1;
        if (defined $content) {
          $content = $content . $token;
        } else {
          $content = $token;
          $content_line = $token_line;
        }
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
  # else, clear the results and clear the current event
  my $result = 0;
  if (scalar(@{$self->{'_buf'}}) > 0) {
    $result = 1;
    $self->{'_cur'} = shift @{$self->{'_buf'}};
  } else {
    $result = 0;
    $self->{'_cur'} = undef;
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

Return the plain attribute map as a hash in list context.

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
  return map { $_ } %{$self->{'_cur'}->[3]};
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
