# LeafXML

Simple XML parser with JavaScript and Perl implementations.

See the `doc` directory for further documentation.  See the `js` directory for the JavaScript library implementation and test programs.  See the `perl` directory for the Perl library implementation and test programs.

The JavaScript and Perl library implementations are designed to be as equivalent in functionality as is possible.  Both are pure implementations that use only JavaScript and Perl code, respectively.  Extensive use is made of regular expressions in both JavaScript and Perl to boost parsing performance.

## Rationale

XML is a flexible and widely-used data markup format, but its specification has several technical problems:

(1) XML uses Unicode but does not require normalization prior to string comparison.  In fact, the XML 1.1 specification forbids normalization of input in section 2.13:  "XML processors MUST NOT transform the input to be in fully normalized form."  This means that XML is not Unicode compliant, because it violates C6 in Unicode 15.1, Chapter 3.2 Conformance Requirements:  "A process shall not assume that the interpretations of two canonical-equivalent character sequences are distinct."

(2) XML standards include a complex DTD language for validation and entity declarations.  However, this DTD language does not support namespaces and in modern use alternative schemas such as XML Schema Definition (XSD) and RELAX NG are often preferred.

(3) XML namespaces are extensively used in modern practice, but they are not part of the core XML specifications.

(4) No guidance is provided by the XML specifications how the interface of an XML parser should work.  This leads to radically different parsing APIs, such as event-driven Simple API for XML (SAX) or tree-based Document Object Model (DOM).  Furthermore, due to the complexity of the XML specifications, specific parsers have unpredictable behavior regarding how content text and CDATA sections are handled, how namespace processing works (if at all), what kind of normalizations are performed on text, and what kind of validation is performed.

LeafXML defines a decoding specification (given in `doc/LeafXML.md`) that integrates XML 1.0, XML 1.1, and XML namespaces into a single specification, along with the following fixes to resolve the technical problems noted above:

(1) Unicode normalization is required during decoding.  Although this technically violates the XML standards, it brings LeafXML into Unicode compliance.

(2) DTDs are ignored, and embedded DTDs are rejected with an error.  This removes a lot of arcane features that are not so useful in practice and makes the specification much more simple.  If validation is desired, using an external XSD or RELAX NG validator is recommended.

(3) XML namespaces processing is always performed and fully integrated into the APIs.  This makes namespaces far easier to use than standard XML parsers, which treat namespaces as an external plug-in.

(4) LeafXML defines a simple event-based model around an event loop that has a consistent API across languages.  This makes client implementations easier and more consistent.

(5) LeafXML drops a number of obscure features, such as non-Unicode character encoding, and special XML 1.1 entity escaping of archaic control codes.

## Release history

### Version 0.9.0 Beta

The first complete version of the LeafXML parsing library, which includes Perl and JavaScript implementations and full documentation.
