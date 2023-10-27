#!/usr/bin/env perl
use v5.16;
use warnings;

use LeafXML::Util qw(readFullText writeFullText);

=head1 NAME

leafxml_echo.pl - Transcode text using LeafXML functions.

=head1 SYNOPSIS

  leafxml_echo.pl -i /path/to/input.txt -o /path/to/output.txt
  leafxml_echo.pl -i - -o - < input.txt > output.txt

=head1 DESCRIPTION

Read Unicode text using C<readFullText()> and then write the same
Unicode text using C<writeFullText()>.

Input supports UTF-8 both with and without Byte Order Mark, as well as
UTF-16 with a Byte Order Mark.  Output is always UTF-8 without a Byte
Order Mark.  This script therefore converts any of the supported input
formats to plain UTF-8.  If input is completely empty, output will
contain a single space character.

Program arguments are given in key/value pairs.  The keys C<-i> and
C<-o> must be defined exactly once, and no other keys may be defined.
These two keys define the input file and the output file, respectively.
Each is either the path to a file to read or create, or the special
value C<-> which means read standard input or standard output,
respectively.

=cut

# ==================
# Program entrypoint
# ==================

# Get arguments
#
my $arg_input  = undef;
my $arg_output = undef;

while (scalar(@ARGV) > 0) {
  # Check at least two more arguments
  ($#ARGV >= 1) or die "Unpaired program arguments";
  
  # Get key and value
  my $key = shift(@ARGV);
  my $val = shift(@ARGV);
  
  # Check value
  (defined $val) or die "Invalid argument value";
  (not ref($val)) or die "Invalid argument value";
  (length($val) > 0) or die "Invalid argument value";
  
  # Store argument based on key
  if ($key eq '-i') {
    (not defined $arg_input) or die "Duplicate -i argument";
    $arg_input = $val;
    
  } elsif ($key eq '-o') {
    (not defined $arg_output) or die "Duplicate -o argument";
    $arg_output = $val;
    
  } else {
    die "Unrecognized program argument key: $key";
  }
}

# Read input
#
my $text;
if ($arg_input eq '-') {
  readFullText(\$text);
} else {
  readFullText(\$text, $arg_input);
}

# Write output
#
if ($arg_output eq '-') {
  writeFullText(\$text);
} else {
  writeFullText(\$text, $arg_output);
}
