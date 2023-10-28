#!/usr/bin/env perl
use v5.16;
use warnings;

use LeafXML::Util qw(
  readFullText
  writeFullText
  escapeText
  toText64
  fromText64
);

=head1 NAME

leafxml_xform.pl - Text transformations using LeafXML functions.

=head1 SYNOPSIS

  leafxml_xform.pl esc 0 < input.txt > output.txt
  leafxml_xform.pl e64 < input.txt > output.txt
  leafxml_xform.pl d64 < input.txt > output.txt

=head1 DESCRIPTION

Read text from standard input, transform it using LeafXML functions, and
print the transformed text to standard output.

The input may be in UTF-8 with or without a byte order mark, or in
UTF-16 with a byte order mark.  The output is always in UTF-8 without a
byte order mark.

The C<esc> invocation performs entity escaping.  It does not, however,
verify that only valid codepoints are in use in the input.  This
invocation takes a single parameter, which must be C<0> for content text
escaping, C<1> for single-quoted attribute escaping, or C<2> for
double-quoted attribute escaping.

The C<e64> invocation encodes the text into Base64, where UTF-8 encoding
is used within the Base64 data.

The C<d64> invocation decodes text from Base64 with UTF-8 into full
UTF-8.

=cut

# ==================
# Program entrypoint
# ==================

# Get program mode
#
(scalar(@ARGV) > 0) or die "Expecting program arguments";
my $mode = shift;
(not ref($mode)) or die "Invalid argument type";

# Handle specific mode
#
if ($mode eq 'esc') {
  # Get escaping style
  (scalar(@ARGV) == 1) or die "Wrong number of arguments for esc mode";
  my $style = shift;
  (not ref($style)) or die "Invalid argument type";
  
  (($style eq '0') or ($style eq '1') or ($style eq '2')) or
    die "Unrecognized escaping style: $style";
  
  # Perform operation
  my $input;
  readFullText(\$input);
  $input = escapeText($input, int($style));
  writeFullText(\$input);
  
} elsif ($mode eq 'e64') {
  # Check arguments
  (scalar(@ARGV) == 0) or die "Not expecting arguments for e64 mode";
  
  # Perform operation
  my $input;
  readFullText(\$input);
  $input = toText64($input);
  print "$input\n";
  
} elsif ($mode eq 'd64') {
  # Check arguments
  (scalar(@ARGV) == 0) or die "Not expecting arguments for d64 mode";
  
  # Perform operation
  my $input;
  readFullText(\$input);
  $input = fromText64($input);
  writeFullText(\$input);
  
} else {
  die "Unrecognized program mode: $mode";
}
