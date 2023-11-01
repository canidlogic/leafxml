# LeafXML Perl library

The entire LeafXML Perl library is contained within the `Parser.md` and `Util.md` modules within the `LeafXML` subdirectory.  The parent directory that includes the `LeafXML` subdirectory should be added to the include path of the Perl interpreter to load the LeafXML library.

All Perl modules and scripts have POD documentation.  Markdown versions of this POD documentation are found in the `pod` subdirectory.

The scripts in this `perl` subdirectory are test programs.  See the following manifest:

- `leafxml_echo.pl` is the echo test program.
- `leafxml_parse.pl` is the parse test program.
- `leafxml_xform.pl` is the transform test program.

In order to run these scripts, you must `chmod +x` to ensure they are executable, and you must ensure that the `LeafXML` directory containing the LeafXML Perl library is in the Perl include path.

The echo test program uses the file transport utility functions of LeafXML to decode a file to a Unicode string, and then encode that Unicode string to another file.  The decoder supports UTF-8 with and without a byte order mark, and UTF-16 with a byte order mark.  The encoder always uses UTF-8 without a byte order mark.

The parse test program uses the LeafXML parser to parse through a given XML file and report all the parsing events that were encountered.

The transform test program uses various LeafXML transform functions to transform a given input string in various ways.

See the POD documentation of these scripts in the `pod` directory for further information.

For specifications of the Perl API for LeafXML, see both the POD documentation of the `LeafXML::Parser` and `LeafXML::Util` modules, and the `API_Perl.md` documentation in the `doc` directory.
