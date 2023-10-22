#!/usr/bin/env perl
use v5.16;
use warnings;

use LeafXML::Parser;

=head1 NAME

leafxml_parse.pl - Test driver for the LeafXML parser.

=head1 SYNOPSIS

  leafxml_parse.pl < input.xml > output.txt

=head1 DESCRIPTION

Parses an XML file given on standard input with LeafXML and reports the
fully parsed results on standard output.

Each parsing event is printed on a separate line.  The line always
begins with the line number that the parsing event occurred on, followed
by a colon and a space.

Next comes the event type.  This is either C<BEGIN>, C<TEXT>, or C<END>.

For C<TEXT> events, the event type is followed by a space and then the
content text.  Backslashes are encoded as C<\\> and line breaks are
encoded as C<\n>.

For C<BEGIN> events, the event type is followed by a space and then the
element name.  After the element name, there is a list of all
attributes, both plain attributes and external namespaced attributes.
Each attribute is the attribute name, an equals sign, and then the
attribute value double-quoted.  Attribute values encode backslashes as
C<\\>, line breaks as C<\n>, and double quotes as C<\">.

Each element name and each attribute name has an unsigned decimal
integer and a colon prefixed to it.  If the unsigned decimal integer is
zero, it means the element name or attribute name is not in any
particular namespace.  If the unsigned decimal integer is greater than
zero, it means the name is in a specific namespace.

After all parsed events have been reported on standard output, a
namespace table is written.  This maps the unsigned decimal integers to
the specific namespace values.

=cut

# ==========
# Local data
# ==========

# ns_array maps unsigned integer indices to specific namespace values,
# where index zero is reserved to mean no namespace
#
my @ns_array = ("<none>");

# ns_map maps specific namespace values to their indices in the ns_array
#
my %ns_map;

# ===============
# Local functions
# ===============

# encodeNS(val)
# -------------
#
# Encode a namespace value as an unsigned decimal integer using the
# local data namespace tables.  The return value is an integer zero or
# greater.
#
# You can pass C<undef>, in which case this function always returns
# zero.
#
# If the given namespace is not in the maps, it is added.
#
sub encodeNS {
  ($#_ == 0) or die;
  my $val = shift;
  
  unless (defined $val) {
    return 0;
  }
  
  (not ref($val)) or die;
  
  unless (defined $ns_map{$val}) {
    $ns_map{$val} = scalar(@ns_array);
    push @ns_array, ($val);
  }
  
  return $ns_map{$val};
}

# encodeContentText(str)
# ----------------------
#
# Replace \ and <LF> in the input string with \\ and \n
#
sub encodeContentText {
  ($#_ == 0) or die;
  my $str = shift;
  (not ref($str)) or die;
  
  $str =~ s/\x{5c}/\x{5c}\x{5c}/g;
  $str =~ s/\n/\x{5c}n/g;
  
  return $str;
}

# encodeAttrText(str)
# -------------------
#
# Replace \ and <LF> and " in the input string with \\ and \n and \"
#
sub encodeAttrText {
  ($#_ == 0) or die;
  my $str = shift;
  (not ref($str)) or die;
  
  $str =~ s/\x{5c}/\x{5c}\x{5c}/g;
  $str =~ s/\n/\x{5c}n/g;
  $str =~ s/"/\x{5c}"/g;
  
  return $str;
}

# ==================
# Program entrypoint
# ==================

# Check parameters
#
(scalar(@ARGV) < 1) or die "Not expecting program arguments";

# Set input and output modes
#
binmode(STDIN,  ":encoding(UTF-8)") or die "Failed to set I/O mode";
binmode(STDOUT, ":encoding(UTF-8)") or die "Failed to set I/O mode";

# Read the whole file
#
my $xml_text;
{
  local $/;
  $xml_text = readline(STDIN);
  1;
}

# Load the parser
#
my $xml = LeafXML::Parser->create(\$xml_text);
$xml->sourceName("stdin");

# Iterate through all parsed events
#
while($xml->readEvent) {
  # Determine event type
  if ($xml->eventType > 0) {
    # Starting tag
    printf "%d: BEGIN %d:%s",
      $xml->lineNumber,
      encodeNS($xml->elementNS),
      $xml->elementName;
    
    # Plain attributes
    my %atts = $xml->attr;
    for my $k (sort keys %atts) {
      printf " 0:%s=\"%s\"",
        $k,
        encodeAttrText($atts{$k});
    }
    
    # External namespaced attributes
    my $ext = $xml->externalAttr;
    
    # External attribute array stores all the unsigned decimal integers
    # for namespaces used in external attributes
    my @exa;
    
    # Fill the external attribute array
    for my $k (keys %$ext) {
      push @exa, (encodeNS($k));
    }
    
    # Sort the external attribute array in numeric order
    my @exb = sort { $a <=> $b } @exa;
    
    # Print namespaced attributes
    for my $nsk (@exb) {
      my $nsa = $ext->{$ns_array[$nsk]};
      for my $k (sort keys %$nsa) {
        printf " %d:%s=\"%s\"",
          $nsk,
          $k,
          encodeAttrText($nsa->{$k});
      }
    }
    
    # Line break
    print "\n";
    
  } elsif ($xml->eventType == 0) {
    # Content text
    printf "%d: TEXT %s\n",
      $xml->lineNumber,
      encodeContentText($xml->contentText);
    
  } elsif ($xml->eventType < 0) {
    # Ending tag
    printf "%d: END\n", $xml->lineNumber;
    
  } else {
    die;
  }
}

# Print the namespace table
#
print "\n";
print "Namespace table\n";
print "===============\n";
print "\n";

for(my $i = 0; $i < scalar(@ns_array); $i++) {
  printf "%3d => %s\n", $i, $ns_array[$i];
}
