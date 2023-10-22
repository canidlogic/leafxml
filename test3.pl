#!/usr/bin/env perl
use v5.16;
use warnings;

# ==============
# Event handlers
# ==============

# beginTag($tname, $ns, \%atts, \%ext_atts)
# -----------------------------------------
#
# Event raised at the starting tag of XML elements.  Empty elements are
# treated as if they were a starting tag immediately followed by closing
# tag.  Therefore, <br/> would raise both a beginTag and endTag event as
# if it were <br><br/>.
#
# The XML parser has already verified that there is only one root
# element in the document.  The XML parser has also already performed
# namespace processing.
#
# tname is the name of the tag, which has already been checked to be
# valid according to XML syntax.  tname never includes any namespace
# prefix, since namespace prefixes have already been processed and
# removed.  Tag names should be case sensitive according to the XML
# standard.  Unicode normalization has not been performed on tname,
# because it is not called for by the XML standard.
#
# ns is the namespace of the tag, or an empty string if the tag is not
# in any namespace.  The namespace value is the URL or other value that
# has been declared for the namespace.  It is NOT the namespace prefix.
# Non-empty namespaces should be treated as opaque codepoint strings
# according to the XML namespace standards.  Namespace values are only
# equal if their sequence of codepoints is identical, with no escaping
# or normalization processing whatsoever.
#
# atts is a mapping of attribute keys to attribute values.
# @@TODO:
# 
#
sub beginTag {
  
}

# ===============
# Local functions
# ===============

# validXMLName(name)
# ------------------
#
# Check whether a given name is a valid name according to the XML 1.0
# standard.  Returns 1 if valid, 0 if not.
#
# This also enforces the rule that a name may not have more than one
# colon, and if a colon is present, it may neither be the first nor last
# character.  This rule is not required by the XML 1.0 standard, but it
# IS required by the Namespaces in XML 1.0 standard.
#
sub validXMLName {
  ($#_ == 0) or die "Bad call";
  my $str = shift;
  (not ref($str)) or die "Bad call";
  
  ($str =~ /^[A-Za-z0-9:_\-\.\x{b7}\x{c0}-\x{effff}]+$/) or return 0;
  
  for my $c (split //, $str) {
    my $v = ord($c);
    if (($v == 0xd7) or ($v == 0xf7) or ($v == 0x37e) or
        (($v >= 0x2000) and ($v <= 0x200b)) or
        (($v >= 0x200e) and ($v <= 0x203e)) or
        (($v >= 0x2041) and ($v <= 0x206f)) or
        (($v >= 0x2190) and ($v <= 0x2bff)) or
        (($v >= 0x2ff0) and ($v <= 0x3000)) or
        (($v >= 0xd800) and ($v <= 0xf8ff)) or
        (($v >= 0xfdd0) and ($v <= 0xfdef)) or
        ($v == 0xfffe) or ($v == 0xffff)) {
      return 0;
    }
  }
  
  (not ($str=~ /^[\-\.0-9\x{b7}\x{300}-\x{36f}\x{203f}-\x{2040}]/)) or
    return 0;
  
  (($str =~ /^[^:]+$/) or ($str =~ /^[^:]+:[^:]+$/)) or return 0;
  
  return 1;
}

# validXMLChars(str)
# ------------------
#
# Check whether a given string only contains Unicode codepoints allowed
# by the XML 1.0 standard.  Returns 1 if valid, 0 if not.
#
sub validXMLChars {
  ($#_ == 0) or die "Bad call";
  my $str = shift;
  (not ref($str)) or die "Bad call";
  
  ($str =~
    /^[\t\n\r\x{20}-\x{d7ff}\x{e000}-\x{fffd}\x{10000}-\x{10ffff}]*$/)
      or return 0;
  
  return 1;
}

# escapeStr(lnum, str)
# --------------------
#
# Apply entity escapes within a given string to get the fully decoded
# string value.  lnum is the line number in the source file, to be used
# for error reports.  Returns the escaped string value.
#
sub escapeStr {
  # Get parameters
  ($#_ == 1) or die "Bad call";
  my $lnum = shift;
  (not ref($lnum)) or die "Bad call";
  
  my $str = shift;
  (not ref($str)) or die "Bad call";
  
  # If there are no escapes, then just return string as-is
  ($str =~ /&/) or return $str;
  
  # There are escapes, so start the result string empty
  my $result = '';
  
  # Process the text by unescaped spans and escaped spans
  while ($str =~ /((?:[^&]+)|(?:&[^;]*;))/gs) {
    my $span = $1;
    if ($span =~ /^&/) {
      # Entity escape, so process the different types
      if ($span eq '&amp;') {
        $result .= '&';
        
      } elsif ($span eq '&lt;') {
        $result .= '<';
        
      } elsif ($span eq '&gt;') {
        $result .= '>';
        
      } elsif ($span eq '&apos;') {
        $result .= "'";
        
      } elsif ($span eq '&quot;') {
        $result .= '"';
        
      } elsif ($span =~ /^&#([0-9]+);$/) {
        my $dcode = $1;
        
        (length($dcode) <= 7) or
          die "[XML line $lnum] Invalid escape '$span' in entity";
        $dcode = int($dcode);
        
        (($dcode >= 0) or ($dcode <= 0x10ffff)) or
          die "[XML line $lnum] Escape '$span' out of range in entity";
        (($dcode < 0xd800) or ($dcode > 0xdfff)) or
          die "[XML line $lnum] Escape '$span' is surrogate in entity";
        
        $result .= chr($dcode);
        
      } elsif ($span =~ /^&#x([0-9A-Fa-f]+);$/) {
        my $hcode = $1;
        
        (length($hcode) <= 6) or
          die "[XML line $lnum] Invalid escape '$span' in entity";
        $hcode = hex($hcode);
        
        (($hcode >= 0) or ($hcode <= 0x10ffff)) or
          die "[XML line $lnum] Escape '$span' out of range in entity";
        (($hcode < 0xd800) or ($hcode > 0xdfff)) or
          die "[XML line $lnum] Escape '$span' is surrogate in entity";
        
        $result .= chr($hcode);
        
      } else {
        die "[XML line $lnum] Invalid escape '$span' in entity";
      }
      
    } else {
      # Not an entity escape, so append to result as-is
      $result .= $span;
    }
  }
  
  # Return decoded result
  return $result;
}

# ===============
# Namespace stack
# ===============

# Each element that is entered pushes a new element onto the namespace
# stack before it is processed.  Each element that is left pops an
# element off the namespace stack after it is processed.
#
# Namespace stack elements are hash references mapping prefix names
# (excluding the colons) to their namespaces.  The empty string is used
# for mapping the default namespace.  No mappings (nor the default
# namespace) are present in the hash unless they are mapped to a
# namespace.
#
# The stack starts out with a single hash that maps the predefined "xml"
# and "xmlns" prefixes.  Any attempt to remap these two predefined
# prefixes will be ignored.  There is no default namespace initially.
#
my @nstack = (
  {
    'xml'   => 'http://www.w3.org/XML/1998/namespace',
    'xmlns' => 'http://www.w3.org/2000/xmlns/'
  }
);

# =============
# Element stack
# =============

# Each open tag pushes its name onto the element stack, and each closing
# tag pops its name from the element stack, after verifying it matches
# the corresponding open tag.
#
# The names on the element stack are NOT namespace processed, because
# the core XML 1.0 standard is not namespace aware.
#
my @estack;

# The root_decl flag is set when the root element is pushed onto the
# stack.  This is used to prevent multiple root elements in the same
# XML file, since only one is allowed.
#
my $root_decl = 0;

# ==============
# Token handlers
# ==============

# handleCDATA(lnum, content)
# --------------------------
#
# Handle CDATA textual content.  The given content does NOT include the
# surrounding <![CDATA[ ]]> frame.  There is no escaping within the
# content, and whitespace should be treated literally.  lnum is the line
# number this CDATA block began on.
#
sub handleCDATA {
  # Get parameters
  ($#_ == 1) or die "Bad call";
  my $lnum = shift;
  my $content = shift;
  
  # Check that we are within some element
  (scalar(@estack) > 0) or
    die "[XML line $lnum] CDATA outside of any element";
  
  # @@TODO:
  $content =~ s/\n/ /g;
  print "$lnum: [CD] $content\n";
}

# handleTag(lnum, tag)
# --------------------
#
# Handle a raw tag.  The given tag begins with < and ends with > and
# must not be some special tag like a processing instruction or CDATA or
# comment.  lnum is the line number this tag began on.
#
sub handleTag {
  # Get parameters
  ($#_ == 1) or die "Bad call";
  my $lnum = shift;
  my $tag = shift;
  
  # If the element stack is empty and root_decl flag is set, then error
  # because this is a second root element; otherwise, set root_decl flag
  # to prevent another root element from being declared
  if (scalar(@estack) <= 0) {
    (not $root_decl) or
      die "[XML line $lnum] Only one root element is allowed";
    $root_decl = 1;
  }
  
  # Tag type is:
  #
  #   0 - unknown
  #   1 - end tag </
  #   2 - empty tag />
  #   3 - start tag
  #
  my $ttype = 0;
  
  # State value is:
  #
  #   0 - INITIAL
  #   1 - < read
  #   2 - tag name read
  #   3 - attribute name read
  #   4 - equals sign read
  #   5 - > read
  #
  my $state = 0;
  
  # tname will store the tag name
  #
  my $tname = undef;
  
  # aname stores attribute name while parsing an attribute
  #
  my $aname = undef;
  
  # atts will store the attribute mapping
  #
  my %atts;
  
  # ns_keys array will have all attribute keys that are "xmlns" or begin
  # with "xmlns:"
  #
  my @ns_keys;
  
  # Tokenize the tag
  while ($tag =~ /(

    # ==============
    # Atomic symbols
    # ==============
    
    (?:[\x{3c}\x{3e}\x{2f}=]) |
    
    # ==========
    # Whitespace
    # ==========
    
    (?:[\x{20}\t\r\n]+) |
    
    # ================
    # Attribute values
    # ================
    
    (?:'[^']*') |
    (?:"[^"]*") |
    
    # =========
    # Catch-all
    # =========
    
    (?:[^\x{3c}\x{3e}\x{2f}=\x{20}\t\r\n'"]+)
  
  )/gsx) {
    
    # Get token
    my $tk = $1;
    
    # Skip whitespace
    (not ($tk =~ /^[\x{20}\t\r\n]/)) or next;
  
    # Handle types of tokens
    if ($tk eq '<') {
      # Opening token
      ($state == 0) or die "[XML line $lnum] Tag syntax error";
      $state = 1;
      
    } elsif ($tk eq '>') {
      # Closing token
      ($state == 2) or die "[XML line $lnum] Tag syntax error";
      if ($ttype == 0) {
        $ttype = 3;
      }
      $state = 5;
      
    } elsif ($tk eq '/') {
      # Slash that indicates closing tag
      (($state == 1) or ($state == 2)) or
        die "[XML line $lnum] Tag syntax error";
      ($ttype == 0) or die "[XML line $lnum] Tag syntax error";
      
      if ($state == 1) {
        $ttype = 1;
        
      } elsif ($state == 2) {
        $ttype = 2;
        
      } else {
        die;
      }
      
    } elsif ($tk eq '=') {
      # Equals sign from an attribute
      ($state == 3) or die "[XML line $lnum] Tag syntax error";
      $state = 4;
      
    } elsif ($tk =~ /^['"]/) {
      # Attribute value
      ($state == 4) or die "[XML line $lnum] Tag syntax error";
      
      ($tk =~ /^['"](.*)['"]$/) or die;
      $tk = escapeStr($lnum, $1);
      
      (not defined $atts{$aname}) or
        die "[XML line $lnum] Duplicate attribute '$aname'";
      $atts{$aname} = $tk;
      
      if (($aname eq 'xmlns') or ($aname =~ /^xmlns:/)) {
        push @ns_keys, ($aname);
      }
      
      $state = 2;
    
    } else {
      # Name -- check valid format
      validXMLName($tk) or
        die "[XML line $lnum] Invalid XML name '$tk'";
      
      # Handle name based on state
      if ($state == 1) {
        # This is the tag name
        $tname = $tk;
        $state = 2;
        
      } elsif ($state == 2) {
        # This is an attribute name
        ($ttype == 0) or die "[XML line $lnum] Tag syntax error";
        $aname = $tk;
        $state = 3;
        
      } else {
        die "[XML line $lnum] Tag syntax error";
      }
    }
  }
  
  # Check finished state
  ($state == 5) or die "[XML line $lnum] Tag syntax error";
  
  # If this is a full or open tag, begin with namespace processing
  if (($ttype == 2) or ($ttype == 3)) {
    if (scalar(@ns_keys) > 0) {
      # Namespace definitions present, so begin with a copy of the
      # current namespace hash
      my %nh = map { $_ } %{$nstack[-1]};
      
      # Process each namespace declaration
      for my $nk (@ns_keys) {
        # Parse the key to get the prefix, or '' for prefix if default
        # namespace; also check that no colons in the prefix
        my $pfx;
        if ($nk eq 'xmlns') {
          $pfx = '';
        } else {
          ($nk =~ /^xmlns:([^:]+)$/) or
            die "[XML line $lnum] Invalid namespace key '$nk'";
          $pfx = $1;
        }
        
        # Ignore attempts to redefine xml: and xmlns: prefixes
        (($pfx ne 'xml') and ($pfx ne 'xmlns')) or next;
        
        # Get namespace value and make sure it is not empty
        my $nval = $atts{$nk};
        (length($nval) > 0) or
          die "[XML line $lnum] Empty namespace for key '$nk'";
        
        # Update the mapping in the new hash
        $nh{$pfx} = $nval;
      }
      
      # Push new namespace element on top of the namespace stack
      push @nstack, (\%nh);
      
    } else {
      # No namespace definitions, so just duplicate the element on top
      # of the namespace stack
      push @nstack, ($nstack[-1]);
    }
  }
  
  # If this is an open or closing tag (but not a full tag), update the
  # element stack
  if ($ttype == 3) {
    # Start tag, so push the tag name (without any namespace processing)
    push @estack, ($tname);
    
  } elsif ($ttype == 1) {
    # Close tag, so make sure stack is not empty, that name on top of
    # the stack matches this tag name, and then pop the stack
    (scalar(@estack) > 0) or
      die "[XML line $lnum] Close tag without matching open";
    ($estack[-1] eq $tname) or
      die sprintf(
            "[XML line %d] Close tag '%s' mistmatches open tag '%s'",
            $lnum, $tname, $estack[-1]);
    pop @estack;
  }
  
  # Get current namespace
  my $cn = $nstack[-1];
  
  # Perform namespace processing on the tag name
  my $tag_ns;
  my $tag_name;
  
  if ($tname =~ /^([^:]+):([^:]+)$/) {
    $tag_ns = $1;
    $tag_name = $2;
    
    (defined $cn->{$tag_ns}) or
      die "[XML line $lnum] Undefined namespace prefix '$tag_ns'";
    $tag_ns = $cn->{$tag_ns};
    
  } else {
    $tag_name = $tname;
    if (defined $cn->{''}) {
      $tag_ns = $cn->{''};
    } else {
      $tag_ns = '';
    }
  }
  
  # The %bare attribute mapping is for attributes outside of any
  # namespace, while the %exa attribute mapping is for attributes that
  # have namespace qualification; in %exa, the top-level mapping is for
  # namespaces to attributes within those namespaces; in %bare, the
  # mapping is directly for attribute keys  to values
  #
  my %bare;
  my %exa;
  
  # Perform attribute mapping only for open and full tags
  if (($ttype == 2) or ($ttype == 3)) {
    for my $k (keys %atts) {
      # If this is a namespace mapping key, skip it since we already
      # processed it
      if (($k eq 'xmlns') or ($k =~ /^xmlns:/)) {
        next;
      }
      
      # Handle prefixed and unprefixed names separately
      if ($k =~ /^([^:]+):([^:]+)$/) {
        # Prefixed attribute, so get namespace and key
        my $att_ns   = $1;
        my $att_name = $2;
        
        # Map namespace
        (defined $cn->{$att_ns}) or
          die "[XML line $lnum] Undefined namespace prefix '$att_ns'";
        $att_ns = $cn->{$att_ns};
        
        # Add namespace entry in extended attributes if not yet present
        unless (defined $exa{$att_ns}) {
          $exa{$att_ns} = {};
        }
        
        # Verify no duplicates, which could arise if two different
        # prefixes map to the same namespace
        (not defined $exa{$att_ns}->{$att_name}) or
          die sprintf(
            "[XML line %d] Duplicate attribute '%s' in namespace '%s'",
            $lnum, $att_name, $att_ns);
        
        # Store the extended attribute
        $exa{$att_ns}->{$att_name} = $atts{$k};
        
      } else {
        # Unprefixed attribute, so just add it to the bare map
        $bare{$k} = $atts{$k};
      }
    }
  }
  
  # @@TODO:
  if ($tag_ns eq 'http://www.w3.org/2000/svg') {
    print "$lnum: [EL]";
    
    if ($ttype == 1) {
      print " CLOSE $tag_name";
    } elsif ($ttype == 2) {
      print " FULL $tag_name";
    } elsif ($ttype == 3) {
      print " OPEN $tag_name";
    } else {
      die;
    }
    
    for my $k (sort keys %bare) {
      printf " %s=%s", $k, $bare{$k};
    }
    
    print "\n";
  }
  
  # If this is a closing or full tag, then pop an entry off of the
  # namespace stack now that processing is done and verify the namespace
  # stack is not empty (it shouldn't be because the element stack should
  # have checked this)
  if (($ttype == 1) or ($ttype == 2)) {
    pop @nstack;
    (scalar(@nstack) > 0) or die "Empty namespace stack";
  }
}

# handleText(lnum, content)
# -------------------------
#
# Handle content text.  The given content has NOT been decoded for
# entity escapes and blank spans have not been filtered out.  CDATA
# sections are never included within the content here.  This handler
# will filter out blank sections that occur outside the root element.
#
sub handleText {
  # Get parameters
  ($#_ == 1) or die "Bad call";
  my $lnum = shift;
  my $content = shift;
  
  # If we are not in any element, check that text is blank and then
  # ignore it
  if (scalar(@estack) <= 0) {
    ($content =~ /^[ \t\r\n]*$/) or
      die "[XML line $lnum] Content text outside of any element";
    return;
  }
  
  # Perform entity escaping
  $content = escapeStr($lnum, $content);
  
  # @@TODO:
  $content =~ s/\n/ /g;
  print "$lnum: [TX] $content\n";
}

# ===========
# Unicode I/O
# ===========

binmode(STDIN, ":encoding(UTF-8)") or die "Failed to set I/O mode";
binmode(STDOUT, ":encoding(UTF-8)") or die "Failed to set I/O mode";

# ===================
# Acquire UTF-8 input
# ===================

my $input;
{
  local $/;
  $input = readline;
  1;
}

# ============
# Parse tokens
# ============

my $line_num = 1;
while ($input =~ /(

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
  
  # Get the current token
  my $tk = $1;
  
  # Store the line number of the current token and then update the line
  # number according to number of line breaks
  my $tk_line = $line_num;
  $line_num += scalar(my @breaks = $tk =~ /\n/g);
  
  # If it is a lone < bracket, then there was some sort of error
  ($tk ne '<') or die "[XML line $tk_line] XML token error";
  
  # Check that all codepoints are within XML range
  validXMLChars($tk) or
    die "[XML line $tk_line] Illegal Unicode codepoints in entity";
  
  # Skip processing if this is an XML comment, a processing instruction,
  # or a DOCTYPE declaration
  (not ($tk =~ /^\x{3c}!\-\-/)) or next;
  (not ($tk =~ /^\x{3c}\?/)) or next;
  (not ($tk =~ /^\x{3c}!DOCTYPE/)) or next;
  
  # Process core tags, CDATA blocks, and text
  if ($tk =~ /^\x{3c}!\x{5b}CDATA\x{5b}(.*)\x{5d}\x{5d}\x{3e}$/) {
    # Grab the extracted body text and invoke handler
    $tk = $1;
    handleCDATA($tk_line, $tk);
    
  } elsif ($tk =~ /^\x{3c}/) {
    # Invoke handler
    handleTag($tk_line, $tk);
    
  } else {
    # Invoke handler
    handleText($tk_line, $tk);
  }
}

# Make sure we declared a root element
#
($root_decl) or die "[XML] XML file missing root element";
