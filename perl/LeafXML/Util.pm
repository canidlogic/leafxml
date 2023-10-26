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
);

# End with something that evaluates to true
1;
