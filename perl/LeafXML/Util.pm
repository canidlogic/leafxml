package LeafXML::Util;
use v5.16;
use warnings;
use parent qw(Exporter);

use Carp;
use Encode qw(decode encode);
use Scalar::Util qw(looks_like_number);

=head1 NAME

LeafXML::Util - Utility functions for LeafXML.

=head1 SYNOPSIS

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

=head1 DESCRIPTION

Utility functions for working with LeafXML.  These are especially
helpful for writing encoders.

=cut

# =========
# Constants
# =========

# Define a regular expression that matches a string containing zero or
# more codepoints that are valid according to the LeafXML character set.
#
my $VALID_STRING_CHARS =
    "^[\\t\\n\\r\\x{20}-\\x{7e}\\x{85}\\x{a0}-\\x{d7ff}"
  . "\\x{e000}-\\x{fdcf}\\x{fdf0}-\\x{fffd}"
  . "\\x{10000}-\\x{1fffd}\\x{20000}-\\x{2fffd}\\x{30000}-\\x{3fffd}"
  . "\\x{40000}-\\x{4fffd}\\x{50000}-\\x{5fffd}\\x{60000}-\\x{6fffd}"
  . "\\x{70000}-\\x{7fffd}\\x{80000}-\\x{8fffd}\\x{90000}-\\x{9fffd}"
  . "\\x{a0000}-\\x{afffd}\\x{b0000}-\\x{bfffd}\\x{c0000}-\\x{cfffd}"
  . "\\x{d0000}-\\x{dfffd}\\x{e0000}-\\x{efffd}\\x{f0000}-\\x{ffffd}"
  . "\\x{100000}-\\x{10fffd}]*\$";
$VALID_STRING_CHARS = qr/$VALID_STRING_CHARS/;

# Define a regular expression that matches a string containing one or
# more codepoints that are allowed as XML name codepoints.  This allows
# colons.  It does not check the restrictions on the first character of
# names.
#
my $VALID_NAME_CHARS =
    "^[\\-\\.0-9:_A-Za-z\\x{b7}\\x{c0}-\\x{d6}\\x{d8}-\\x{f6}"
  . "\\x{f8}-\\x{37d}\\x{37f}-\\x{1fff}\\x{200c}\\x{200d}"
  . "\\x{203f}\\x{2040}\\x{2070}-\\x{218f}\\x{2c00}-\\x{2fef}"
  . "\\x{3001}-\\x{d7ff}\\x{f900}-\\x{fdcf}\\x{fdf0}-\\x{fffd}"
  . "\\x{10000}-\\x{1fffd}\\x{20000}-\\x{2fffd}\\x{30000}-\\x{3fffd}"
  . "\\x{40000}-\\x{4fffd}\\x{50000}-\\x{5fffd}\\x{60000}-\\x{6fffd}"
  . "\\x{70000}-\\x{7fffd}\\x{80000}-\\x{8fffd}\\x{90000}-\\x{9fffd}"
  . "\\x{a0000}-\\x{afffd}\\x{b0000}-\\x{bfffd}\\x{c0000}-\\x{cfffd}"
  . "\\x{d0000}-\\x{dfffd}\\x{e0000}-\\x{efffd}]+\$";
$VALID_NAME_CHARS = qr/$VALID_NAME_CHARS/;

# Define an array of 64 one-character strings, each containing the
# appropriate character for that particular Base64 digit.
#
my @BASE64_DIGITS = ();
for(my $i = 0; $i < 64; $i++) {
  my $cv;
  if ($i < 26) {
    $cv = ord('A') + $i;
  } elsif ($i < 52) {
    $cv = ord('a') + ($i - 26);
  } elsif ($i < 62) {
    $cv = ord('0') + ($i - 52);
  } elsif ($i == 62) {
    $cv = ord('+');
  } elsif ($i == 63) {
    $cv = ord('/');
  } else {
    die;
  }
  push @BASE64_DIGITS, (chr($cv));
}

# Define an array of 94 integers, representing the codepoints 0x21 to
# 0x7e.  Each value is either -1, indicating the codepoint is not a
# valid Base64 digit, or the numeric value of the Base64 digit in range
# 0 to 63.
#
my @BASE64_LOOKUP = ();
for(my $i = 0; $i < 94; $i++) {
  push @BASE64_LOOKUP, (-1);
}
for(my $i = 0; $i < 64; $i++) {
  $BASE64_LOOKUP[ord($BASE64_DIGITS[$i]) - 0x21] = $i;
}

=head1 FUNCTIONS

=over 4

=item B<isInteger(val)>

Check that the given value is an integer.  Return 1 if an integer or 0
if not.

=cut

sub isInteger {
  ($#_ == 0) or croak("Bad call");
  my $val = shift;
  
  looks_like_number($val) or return 0;
  (int($val) == $val) or return 0;
  
  return 1;
}

=item B<validCode(codepoint)>

Check whether a given integer value is a valid Unicode codepoint that
can be used within LeafXML.  Returns 1 if yes, 0 if not.

=cut

sub validCode {
  ($#_ == 0) or croak("Bad call");
  my $val = shift;
  isInteger($val) or croak("Bad call");
  
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

=item B<validString(str)>

Check whether a given string only contains codepoints that pass the
C<validCode()> function.  Returns 1 if yes, 0 if not.  Empty strings do
pass this function.

This function is optimized so that it does not actually invoke
C<validCode()> but rather uses a regular expression.

=cut

sub validString {
  ($#_ == 0) or croak("Bad call");
  my $str = shift;
  (not ref($str)) or croak("Bad call");
  
  my $result = 0;
  
  if ($str =~ $VALID_STRING_CHARS) {
    $result = 1;
  }
  
  return $result;
}

=item B<validName(str)>

Check whether a given string qualifies as a valid XML name.  This 
function allows names to contain colons.

=cut

sub validName {
  # Get parameters
  ($#_ == 0) or croak("Bad call");
  my $str = shift;
  (not ref($str)) or croak("Bad type");
  
  # Check that name is sequence of one or more name codepoints
  my $result = 1;
  unless ($str =~ $VALID_NAME_CHARS) {
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

=item B<readFullText(\$target, [path])>

Read a whole text file into a decoded Unicode string.

The first parameter is always a reference to a scalar where the text
will be stored.  This scalar will have one character per codepoint, and
never has any Byte Order Mark.

If the second parameter is present, it is a scalar specifying a file
path to the text file to load the text from.  If the second parameter is
absent, the file is read from standard input.

This function supports UTF-8 with or without a Byte Order Mark, and
UTF-16 with a Byte Order Mark.

=cut

sub readFullText {
  # Get parameters
  ($#_ >= 0) or croak("Bad call");
  
  my $target = shift;
  (ref($target) eq 'SCALAR') or croak("Bad call");
  
  my $path = undef;
  if ($#_ >= 0) {
    $path = shift;
    (defined $path) or croak("Bad call");
    (not ref($path)) or croak("Bad call");
  }
  
  ($#_ < 0) or croak("Bad call");
  
  # Read whole input into a binary string
  if (defined $path) {
    (-f $path) or die "Failed to find file: $path";
    open(my $fh, "< :raw", $path) or
      die "Failed to open file: $path";
    
    {
      local $/;
      $$target = readline($fh);
      1;
    }
    
    (defined $$target) or die "Failed to read file: $path";
    close($fh) or warn "Failed to close file";
    
  } else {
    binmode(STDIN, ":raw") or die "Failed to set I/O mode";
    
    {
      local $/;
      $$target = readline(STDIN);
      1;
    }
    
    (defined $$target) or die "Failed to read standard input";
  }
  
  # Figure out encoding from opening bytes and skip over any byte order
  # mark
  my $enc_name;
  if ($$target =~ /^\x{ef}\x{bb}\x{bf}/) {
    # UTF-8 with byte order mark
    $$target =~ s/^\x{ef}\x{bb}\x{bf}//;
    $enc_name = "UTF-8";
    
  } elsif ($$target =~ /^\x{fe}\x{ff}/) {
    # UTF-16 Big Endian
    $$target =~ s/^\x{fe}\x{ff}//;
    $enc_name = "UTF-16BE";
  
  } elsif ($$target =~ /^\x{ff}\x{fe}/) {
    # UTF-16 Little Endian
    $$target =~ s/^\x{ff}\x{fe}//;
    $enc_name = "UTF-16LE";
  
  } else {
    # UTF-8 with no byte order mark
    $enc_name = "UTF-8";
  }
  
  # In-place decoding with check
  eval {
    $$target = decode($enc_name, $$target, Encode::FB_CROAK);
  };
  if ($@) {
    if (defined $path) {
      die "Invalid encoding in file: $path";
    } else {
      die "Invalid encoding in standard input";
    }
  }
}

=item B<writeFullText(\$target, [path])>

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

=cut

sub writeFullText {
  # Get parameters
  ($#_ >= 0) or croak("Bad call");
  
  my $source = shift;
  (ref($source) eq 'SCALAR') or croak("Bad call");
  
  my $path = undef;
  if ($#_ >= 0) {
    $path = shift;
    (defined $path) or croak("Bad call");
    (not ref($path)) or croak("Bad call");
  }
  
  ($#_ < 0) or croak("Bad call");
  
  # If source is empty, replace it with a single space
  if (length($$source) < 1) {
    $$source = " ";
  }
  
  # Check that source has valid format
  ($$source =~ /^
    [\x{00}-\x{d7ff}\x{e000}-\x{fefe}\x{ff00}-\x{10ffff}]
    [\x{00}-\x{d7ff}\x{e000}-\x{10ffff}]*
  $/xs) or croak("Invalid source string");
  
  # In-place decoding with check
  $$source = encode("UTF-8", $$source, Encode::FB_CROAK);
  
  # Write whole binary string to output
  if (defined $path) {
    open(my $fh, "> :raw", $path) or
      die "Failed to create file: $path";
    print { $fh } $$source;
    close($fh) or warn "Failed to close file";
    
  } else {
    binmode(STDOUT, ":raw") or die "Failed to set I/O mode";
    print $$source;
  }
  
  # Clear source string
  $$source = "";
}

=item B<escapeText(input, [attr])>

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

=cut

sub escapeText {
  # Get parameters
  ($#_ >= 0) or croak("Bad call");
  
  my $str = shift;
  (not ref($str)) or croak("Bad call");
  
  my $attr = 0;
  if ($#_ >= 0) {
    $attr = shift;
    (isInteger($attr)) or croak("Bad call");
    (($attr >= 0) and ($attr <= 2)) or croak("Value out of range");
  }
  
  ($#_ < 0) or croak("Bad call");
  
  # Perform ampersand replacement first
  $str =~ s/&/&amp;/g;
  
  # Perform special replacements
  if ($attr == 2) {
    $str =~ s/"/&quot;/g;
  
  } elsif ($attr == 1) {
    $str =~ s/'/&apos;/g;
  }
  
  # Perform regular non-ampersand replacements
  $str =~ s/</&lt;/g;
  $str =~ s/>/&gt;/g;
  
  # Return escaped string
  return $str;
}

=item B<toText64(str)>

Encode a Unicode string into UTF-8 encoded in Base64.

Each character in the string must be a codepoint in range 0x0 to
0x10FFFF, excluding the surrogate range 0xd800 to 0xdfff.

An empty string is acceptable, and will result in an empty string being
returned.

The Base64 style used here has C<+> and C</> as the last two digits and
uses C<=> for end padding to make sure the total number of Base64 digits
mod 4 is zero.

No whitespace or line breaking will be added to the Base64 result
string.

=cut

sub toText64 {
  # Get parameters
  ($#_ == 0) or croak("Bad call");
  
  my $str = shift;
  (not ref($str)) or croak("Bad call");
  
  # Empty string has empty result
  if (length($str) < 1) {
    return "";
  }
  
  # Check that codepoints are valid
  ($str =~ /^[\x{00}-\x{d7ff}\x{e000}-\x{10ffff}]*$/s) or
    croak("String has invalid codepoints");
  
  # Encode string to binary UTF-8
  $str = encode("UTF-8", $str, Encode::FB_CROAK);
  
  # Result starts out empty
  my $result = "";
  
  # Encode groups of up to three bytes into four Base64 characters
  while ($str =~ /(.)(.)?(.)?/gs) {
    # Get current group
    my $a = $1;
    my $b = $2;
    my $c = $3;
    
    # Combine into a single integer value, with unused bytes filled with
    # zero
    my $ival = ord($a) << 16;
    if (defined $b) {
      $ival = $ival | (ord($b) << 8);
    }
    if (defined $c) {
      $ival = $ival | ord($c);
    }
    
    # Always encode at least two Base64 digits of the group to cover at
    # least the first byte
    $result = $result . $BASE64_DIGITS[$ival >> 18];
    $result = $result . $BASE64_DIGITS[($ival >> 12) & 0x3f];
    
    # Encode third Base64 digit if at least two bytes, else pad
    if (defined $b) {
      $result = $result . $BASE64_DIGITS[($ival >> 6) & 0x3f];
    } else {
      $result = $result . '=';
    }
    
    # Encode fourth Base64 digit if all three bytes, else pad
    if (defined $c) {
      $result = $result . $BASE64_DIGITS[$ival & 0x3f];
    } else {
      $result = $result . '=';
    }
  }
  
  # Return result
  return $result;
}

=item B<fromText64(str)>

Decode a Unicode string from UTF-8 encoded in Base64.

Spaces, tabs, carriage returns, and line feeds will automatically be
filtered out of the given string.

After whitespace filtering, the string must only contain Base64 digits,
where C<+> and C</> are the last two digits.  The total number of Base64
digits must be a multiple of four, with C<=> used as padding if
necessary at the end.  An empty string after whitespace filtering is
acceptable, which will produce an empty result.

The result string is verified to only contain codepoints in range 0x0 to
0x10FFFF, excluding the surrogate range 0xd800 to 0xdfff.

=cut

sub fromText64 {
  # Get parameters
  ($#_ == 0) or croak("Bad call");
  
  my $str = shift;
  (not ref($str)) or croak("Bad call");
  
  # Drop whitespace
  $str =~ s/[ \t\r\n]+//g;
  
  # Empty filtered string has empty result
  if (length($str) < 1) {
    return "";
  }
  
  # The state is -1 if no digit groups processed yet, 0 if only full
  # digit groups have been processed, 1 or 2 if a partial group has been
  # processed and this number of padding characters are expected, or 3
  # if padding characters have been processed
  my $state = -1;
  
  # Result starts empty
  my $result = "";
  
  # Parse groups of base64 digits
  while ($str =~ /(
            
            # =========================================================
            # Base64 digit groups have 2 to 4 digits; at least 2 digits
            # are required for a single decoded byte
            # =========================================================
            
            (?:
              [A-Za-z0-9\+\/]{2,4}
            ) |
            
            # ==========================================================
            # Padding brings the last Base64 digit group up to 4 digits
            # if necessary; since groups have at least 2 digits, at most
            # 2 padding characters are needed
            # ==========================================================
            
            (?:
              ={1,2}
            ) |
            
            # =================================================
            # Any single codepoint match that isn't = indicates
            # something invalid
            # =================================================
            
            (?:
              [^=]
            )
            
          )/gsx) {
    
    # Get current token
    my $token = $1;
    
    # If token is single codepoint that isn't =, then there was
    # something invalid
    if ((length($token) <= 1) and ($token ne '=')) {
      die "Invalid Base64 string";
    }
    
    # We shouldn't be here in state 3 because nothing should come after
    # padding
    ($state != 3) or die "Invalid Base64 string";
    
    # If we are in states 1 or 2, we should have the proper padding
    # token, and then update state and go to next token
    if ($state == 1) {
      ($token eq '=') or die "Invalid Base64 string";
      $state = 3;
      next;
      
    } elsif ($state == 2) {
      ($token eq '==') or die "Invalid Base64 string";
      $state = 3;
      next;
    }
    
    # If we got here, we should have Base64 group, not padding
    ($token =~ /^[^=]/) or die "Invalid Base64 string";
    
    # Update state based on length of Base64 group
    if (length($token) == 4) {
      # Full group
      $state = 0;
      
    } elsif (length($token) == 3) {
      # Partial group, need one padding char
      $state = 1;
      
    } elsif (length($token) == 2) {
      # Partial group, need two padding chars
      $state = 2;
      
    } else {
      die;
    }
    
    # Get individual digits of token
    ($token =~ /^(.)(.)(.)?(.)?$/s) or die;
    my $a = $1;
    my $b = $2;
    my $c = $3;
    my $d = $4;
    
    # Always process the first two digits
    my $ival;
    my $z;
    
    $z = $BASE64_LOOKUP[ord($a) - 0x21];
    ($z >= 0) or die;
    $ival = $z;
    
    $z = $BASE64_LOOKUP[ord($b) - 0x21];
    ($z >= 0) or die;
    $ival = ($ival << 6) | $z;
    
    # Process last two digits if present, else just shift zeroes
    if (defined $c) {
      $z = $BASE64_LOOKUP[ord($c) - 0x21];
      ($z >= 0) or die;
      $ival = ($ival << 6) | $z;
      
    } else {
      $ival <<= 6;
    }
    
    if (defined $d) {
      $z = $BASE64_LOOKUP[ord($d) - 0x21];
      ($z >= 0) or die;
      $ival = ($ival << 6) | $z;
    
    } else {
      $ival <<= 6;
    }
    
    # Always add at least first byte
    $result = $result . chr($ival >> 16);
    
    # Add second byte if at least three Base64 digits
    if (defined $c) {
      $result = $result . chr(($ival >> 8) & 0xff);
    }
    
    # Add third byte if all four Base64 digits
    if (defined $d) {
      $result = $result . chr($ival & 0xff);
    }
  }
  
  # The only valid finish states are 0 (only full digit groups) or 3
  # (padding characters processed)
  (($state == 0) or ($state == 3)) or die "Invalid Base64 string";
  
  # We now have a binary string, so decode it with UTF-8
  eval {
    $result = decode('UTF-8', $result, Encode::FB_CROAK);
  };
  if ($@) {
    die "Invalid UTF-8 encoding within Base64";
  }
  
  # Check that codepoints are valid
  ($result =~ /^[\x{00}-\x{d7ff}\x{e000}-\x{10ffff}]*$/s) or
    croak("String has invalid codepoints");
  
  # Return decoded string
  return $result;
}

=back

=cut

# ==============
# Module exports
# ==============

our @EXPORT_OK = qw(
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

# End with something that evaluates to true
1;
