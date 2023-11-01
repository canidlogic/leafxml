# LeafXML JavaScript library

The entire LeafXML JavaScript library is contained within `leafxml.js`.  All the other files in this directory are test programs.  See the following manifest:

- `leafxml.js` is the LeafXML JavaScript library.
- `leafxml_echo.(css|html|js)` are the echo test program.
- `leafxml_parse.(css|html|js)` are the parse test program.
- `leafxml_xform.(css|html|js)` are the transform test program.

Each of the test programs can be run in a web browser from the file system by loading the HTML page.

The echo test program uses the file transport utility functions of LeafXML to decode a file to a Unicode string, and then encode that Unicode string to another file.  The decoder supports UTF-8 with and without a byte order mark, and UTF-16 with a byte order mark.  The encoder always uses UTF-8 without a byte order mark.

The parse test program uses the LeafXML parser to parse through a given XML file and report all the parsing events that were encountered.  You can either type an XML file directly into a text box, or you can "upload" a file to parse.  (For large files, you should use the upload functionality.)

The transform test program uses various LeafXML transform functions to transform a given input string in various ways.

For further information, see the `API_JS.md` documentation in the `doc` directory.
