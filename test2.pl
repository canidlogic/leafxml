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

^<XMLDocument>$

# ============
# XML comments
# ============

# XML standard requires comments not to have two hyphens in a row in the
# comment body, nor to have a hyphen immediately adjacent to the opening
# or closing comment tags.  In this decoder, we relax those
# requirements.  The result of this is just the whole comment.

<token: Comment>
  <.StartTag=(\x{3c}!\-\-)>
  <.Body=((?:[^\-]+|\-[^\-]|\-\-+[^\x{3e}])*)>
  <.EndTag=(\-+\-\x{3e})>
  
# =======================
# Processing instructions
# =======================

# This is any tag that is enclosed in <? ?> which includes the header
# <?xml ?> declaration.  No internal processing of the instruction is
# performed here.  The result of this is just the whole processing
# element.

<token: Instruction>
  <.StartTag=(\x{3c}\?)>
  <.Body=((?:[^\?]+|\?+[^\x{3e}])*)>
  <.EndTag=(\?+\x{3e})>

# ===================
# DOCTYPE declaration
# ===================

# Represents <!DOCTYPE> declarations in the prolog.  This parsing rule
# does not support embedded DTDs, which are allowed by the XML standard
# but are not commonly used.  If there are embedded DTDs, this rule will
# always fail to match.  No internal processing of the declaration is
# performed here.  The result of this is just the whole DOCTYPE
# declaration.

<token: DOCTYPE>
  <.StartTag=(\x{3c}!DOCTYPE)>
  <.Body=((?:[^\x{3e}'"\x{5b}\x{5d}]+|'[^']*'|"[^"]*")*)>
  <.EndTag=(\x{3e})>

# ===========
# CDATA block
# ===========

# Represents <![CDATA[ ]]> blocks that can be used within content text
# outside of XML tags.  The result has two subrules.  Line is the line
# number where the CDATA block begins, and Body is the enclosed data
# within the block, not including the starting and ending tags.

<token: CDATA>
  <Line=matchline>
  <.StartTag=(\x{3c}!\x{5b}CDATA\x{5b})>
  <Body=((?:[^\x{5d}]|\x{5d}[^\x{5d}]|\x{5d}\x{5d}+[^\x{3e}])*)>
  <.EndTag=(\x{5d}+\x{5d}\x{3e})>

# ============
# Content text
# ============

# Represents content text that occurs outside of XML tags.  This
# includes embedded entity escapes, but excludes CDATA blocks.  The
# result has two subrules.  Line is the line number where the content
# text begins, and Body is the full content text, including entity
# escapes.

<token: Text>
  <Line=matchline>
  <Body=((?:[^\x{3c}\x{26}]+|\x{26}[^\x{26};]*;)+)>

# ========
# Core tag
# ========

# Represents all regular XML tags, excluding comments, processing
# instructions, DOCTYPE declarations, and CDATA blocks.  The result has
# two subrules.  Line is the line number where the CDATA block begins,
# and Body is the whole tag.

<token: Tag>
  <Line=matchline>
  <Body=(
    \x{3c}[^!\?\x{3e}]
    (?:
      [^\x{3c}\x{3e}'"]+ |
      '[^\x{3c}']*' |
      "[^\x{3c}"]*"
    )*
    \x{3e}
  )>

# ======
# Prolog
# ======

# Starts with an optional UTF-8 Byte Order Mark (BOM) and then has an
# optional sequence of whitespace, processing instructions, comments,
# and DOCTYPE declarations.  The result of this should be discarded.

<token: Prolog>
  <.BOM=(\x{feff}?)>
  <[Parse=PrologElement]>+

<token: PrologElement>
  (?:
    <Blank=([\x{20}\t\r\n]+)> |
    <Instruction> |
    <Comment> |
    <DOCTYPE>
  )

# ====
# Tree
# ====

# The tree represents what comes after the prolog.  It must begin with a
# core tag.  It can then be followed by a mixture of content text, CDATA
# blocks, instructions, comments, and other core tags.  The opening tag
# (the root tag) will be stored in a Root subrule that has Line and Body
# subrules representing the root tag.  Everything that follows the Root
# subrule will be in the Parse subrule array.

<token: Tree>
  <Root=Tag>
  <[Follow=TreeElement]>+

<token: TreeElement>
  (?:
    <Text> |
    <CDATA> |
    <Instruction> |
    <Comment> |
    <Tag>
  )

# ============
# XML document
# ============

# The full XML document is a discarded prolog followed by a Tree subrule
# that contains all the content.

<token: XMLDocument>
  <.Prolog>
  <Tree>

}xs;
  
  unless ($input =~ $parser) {
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
