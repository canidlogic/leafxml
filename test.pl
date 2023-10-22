#!/usr/bin/env perl
use v5.16;
use warnings;

# Regexp::Grammars required

use JSON::XS;   # Only for reporting results

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

# ==========================
# Parse according to grammar
# ==========================

my $result;
{
  use Regexp::Grammars;
  
  my $parser = qr{

<nocontext:>

^<ContentText>$

# ===================
# Text value matching
# ===================

# The main difference between <ContentText> <SAttrText> and <DAttrText>
# is what ASCII symbols are excluded from <LiteralText> subrule:
#
#   - <ContentText> excludes & <
#   - <SAttrText>   excludes & < '
#   - <DAttrText>   excludes & < "
#
# Furthermore, <ContentText> allows for CDATA sections, while the other
# two do not.
#
# Each of these three top-level rules has a subrule <ContentElement>
# that yields an array.  The elements of the array are one of the
# following five:
#
#   - <LiteralText> is literal text without any escapes
#   - <NamedEscape> is one of the special named escapes like &amp;
#   - <DecEscape> is a decimal escape like &#33;
#   - <HexEscape> is a base-16 escape like &#x201a;
#   - <CDATA> is a full CDATA section (in <ContentText> only)
#
# Each of these <ContentElement> array elements also has a <Line>
# subrule that contains the input line number that the element began on.

<token: ContentText> <[ContentElement]>*
<token: ContentElement> <Line=matchline> (?:
  <LiteralText=([^&<]+)> |
  <NamedEscape=(&amp;|&lt;|&gt;|&apos;|&quot;)> |
  <DecEscape=(&\x{23}[0-9]+;)> |
  <HexEscape=(&\x{23}x[0-9a-fA-F]+;)> |
  <CDATA=(
    \x{3c}!\x{5b}CDATA\x{5b}
    (?:[^\x{5d}]|\x{5d}[^\x{5d}]|\x{5d}\x{5d}+[^>])*
    \x{5d}+\x{5d}\x{3e})> |
  <error: (?{'Invalid content text'})>
)

<token: SAttrText> <[SAttrElement]>*
<token: SAttrElement> <Line=matchline> (?:
  <LiteralText=([^&<']+)> |
  <NamedEscape=(&amp;|&lt;|&gt;|&apos;|&quot;)> |
  <DecEscape=(&\x{23}[0-9]+;)> |
  <HexEscape=(&\x{23}x[0-9a-fA-F]+;)>
)

<token: DAttrText> <Line=matchline> <[DAttrElement]>*
<token: DAttrElement> <Line=matchline> (?:
  <LiteralText=([^&<"]+)> |
  <NamedEscape=(&amp;|&lt;|&gt;|&apos;|&quot;)> |
  <DecEscape=(&\x{23}[0-9]+;)> |
  <HexEscape=(&\x{23}x[0-9a-fA-F]+;)>
)

  }xs;
  
  unless ($input =~ $parser) {
    for my $err (@!) {
      print "$err\n";
    }
    die "Parsing failed!";
  };
  $result = \%/;  # /
  1;
}

# ==============
# Report results
# ==============

my $json = JSON::XS->new->pretty;
print $json->encode($result);
