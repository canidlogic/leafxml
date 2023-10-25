"use strict";

/*
 * leafxml.js
 * ==========
 * 
 * LeafXML JavaScript parsing module.
 */

/*
 * Define LeafXML namespace
 */
window.LeafXML = (function() {
  
  /*
   * Regular expressions
   * ===================
   */
  
  /*
   * Regular expression that matches any sequences of XML whitespace
   * characters within a string.
   */
  const RX_COMPRESS_WS = new RegExp(
    "[ \t\n\r]+",
    "usg"
  );
  
  /*
   * Regular expression that matches whitespace at the start of a
   * string, for use in whitespace trimming according to XML.
   */
  const RX_START_TRIM = new RegExp(
    "^[ \t\n]+",
    "us"
  );
  
  /*
   * Regular expression that matches whitespace at the end of a string,
   * for use in whitespace trimming according to XML.
   */
  const RX_END_TRIM = new RegExp(
    "[ \t\n]+$",
    "us"
  );
  
  /*
   * Regular expression that matches only if a string contains XML
   * whitespace codepoints.  Empty strings also match.
   */
  const RX_BLANK = new RegExp(
    "^[ \t\n]*$",
    "us"
  );
  
  /*
   * Regular expression that matches a whole string of any length
   * (including empty) that only contains valid LeafXML codepoints.
   */
  const RX_VALID_STR = new RegExp(
    "^[" +
      "\\t\\n\\r\\u{20}-\\u{7e}\\u{85}\\u{a0}-\\u{d7ff}" +
      "\\u{e000}-\\u{fdcf}\\u{fdf0}-\\u{fffd}" +
      "\\u{10000}-\\u{1fffd}\\u{20000}-\\u{2fffd}" +
      "\\u{30000}-\\u{3fffd}" +
      "\\u{40000}-\\u{4fffd}\\u{50000}-\\u{5fffd}" +
      "\\u{60000}-\\u{6fffd}" +
      "\\u{70000}-\\u{7fffd}\\u{80000}-\\u{8fffd}" +
      "\\u{90000}-\\u{9fffd}" +
      "\\u{a0000}-\\u{afffd}\\u{b0000}-\\u{bfffd}" +
      "\\u{c0000}-\\u{cfffd}" +
      "\\u{d0000}-\\u{dfffd}\\u{e0000}-\\u{efffd}" +
      "\\u{f0000}-\\u{ffffd}" +
      "\\u{100000}-\\u{10fffd}" +
    "]*$",
    "us"
  );
  
  /*
   * Regular expressions for matching a valid name.  Both must match.
   */
  const RX_VALID_NAME_1 = new RegExp(
    "^[" +
      "\\-\\.0-9:_A-Za-z\\u{b7}\\u{c0}-\\u{d6}\\u{d8}-\\u{f6}" +
      "\\u{f8}-\\u{37d}\\u{37f}-\\u{1fff}\\u{200c}\\u{200d}" +
      "\\u{203f}\\u{2040}\\u{2070}-\\u{218f}\\u{2c00}-\\u{2fef}" +
      "\\u{3001}-\\u{d7ff}\\u{f900}-\\u{fdcf}\\u{fdf0}-\\u{fffd}" +
      "\\u{10000}-\\u{1fffd}\\u{20000}-\\u{2fffd}" +
      "\\u{30000}-\\u{3fffd}" +
      "\\u{40000}-\\u{4fffd}\\u{50000}-\\u{5fffd}" +
      "\\u{60000}-\\u{6fffd}" +
      "\\u{70000}-\\u{7fffd}\\u{80000}-\\u{8fffd}" +
      "\\u{90000}-\\u{9fffd}" +
      "\\u{a0000}-\\u{afffd}\\u{b0000}-\\u{bfffd}" +
      "\\u{c0000}-\\u{cfffd}" +
      "\\u{d0000}-\\u{dfffd}\\u{e0000}-\\u{efffd}" +
    "]+$",
    "us"
  );
  
  const RX_VALID_NAME_2 = new RegExp(
    "^[^\\-\\.0-9\\u{b7}\\u{300}-\\u{36f}\\u{203f}\\u{2040}]",
    "us"
  );
  
  /*
   * Regular expressions for performing line break normalization.  The
   * first should be run, then the second.
   */
  const RX_BREAK_NORM_1 = new RegExp(
    "\\r(?:\\n|\\u{85})",
    "usg"
  );
  
  const RX_BREAK_NORM_2 = new RegExp(
    "[\\r\\u{85}\\u{2028}]",
    "usg"
  );
  
  /*
   * Regular expression for splitting a name.
   */
  const RX_SPLIT_NAME = new RegExp(
    "^([^:]+):([^:]+)$",
    "us"
  );
  
  /*
   * Regular expression that matches everything that is not a line
   * break.
   */
  const RX_COUNT_LINE = new RegExp(
    "[^\\n]+",
    "usg"
  );
  
  /*
   * Regular expression that iterates through escaped text, having plain
   * text, line breaks, entity escapes, and invalid ampersands as the
   * different possibilities.
   */
  const RX_ENT_ESC = new RegExp(
    "(?:" +
      "(?:" +
        "[^&\\n]+" +
      ")|" +
      "(?:" +
        "\\n" +
      ")|" +
      "(?:" +
        "&[^;&]*;" +
      ")|" +
      "(?:" +
        "&" +
      ")" +
    ")",
    "usg"
  );
  
  /*
   * Regular expressions for parsing different kinds of entity escapes.
   */
  const RX_ENT_ESC_NAMED = new RegExp(
    "^&([a-z]+);$",
    "us"
  );
  
  const RX_ENT_ESC_DEC = new RegExp(
    "^&\\u{23}([0-9]{1,8});$",
    "us"
  );
  
  const RX_ENT_ESC_HEX = new RegExp(
    "^&\\u{23}x([0-9A-Fa-f]{1,6});$",
    "us"
  );
  
  /*
   * Regular expression for parsing the attribute values within a tag.
   * Each value is either a double-quoted attribute, a single-quoted
   * attribute, or a single codepoint indicating parsing failure.
   */
  const RX_PARSE_ATTR = new RegExp(
    "(?:" +
      "(?:" +
        "[ \\t\\n]+" +
        "[^ \\t\\n\"'=]+" +
        "[ \\t\\n]*" +
        "=" +
        "[ \\t\\n]*" +
        "\"[^\"]*\"" +
      ")|" +
      "(?:" +
        "[ \\t\\n]+" +
        "[^ \\t\\n\"'=]+" +
        "[ \\t\\n]*" +
        "=" +
        "[ \\t\\n]*" +
        "'[^']*'" +
      ")|" +
      "(?:" +
        "." +
      ")" +
    ")",
    "usg"
  );
  
  /*
   * Regular expressions for matching double- and single-quoted
   * attributes.  Each has four matching groups.  The first and third
   * are the front padding and the internal equals (for use in updating
   * line counts) and the second and fourth are the attribute name and
   * the attribute value, respectively.  Attribute value does not
   * include the surrounding quotes.
   */
  const RX_PARSE_ATTR_D = new RegExp(
    "^([ \\t\\n]*)([^ \\t\\n=]+)([ \\t\\n]*=[ \\t\\n]*)\"([^\"]*)\"$",
    "us"
  );
  
  const RX_PARSE_ATTR_S = new RegExp(
    "^([ \\t\\n]*)([^ \\t\\n=]+)([ \\t\\n]*=[ \\t\\n]*)'([^']*)'$",
    "us"
  );
  
  /*
   * Regular expression for parsing a whole tag.  The first group is an
   * optional slash after the opening <, the second group is the element
   * name, the third group is the parameter substring, and the fourth
   * group is the optional slash before the closing >
   */
  const RX_PARSE_TAG = new RegExp(
    "^" +
      "\\u{3c}" +
      "(\\u{2f})?" +
      "([^ \\t\\n\\u{2f}\\u{3e}\"'=]+)" +
      "((?:" +
        "[^\\u{2f}\"']*|" +
        "(?:\"[^\"]*\")|" +
        "(?:'[^']*')" +
      ")*)" +
      "(\\u{2f})?" +
      "\\u{3e}" +
    "$",
    "us"
  );
  
  /*
   * Regular expression that matches a CDATA token and returns the text
   * inside the block as the first capture group.
   */
  const RX_CDATA = new RegExp(
    "^\\u{3c}!\\u{5b}CDATA\\u{5b}(.*)\\u{5d}\\u{5d}\\u{3e}$",
    "us"
  );
  
  /*
   * String containing a regular expression that parses raw XML tokens.
   * 
   * Each instance of the parser must have its own instance of this
   * regular expression in order to have a proper iteration, so this is
   * stored as a string rather than as a regular expression object.
   * 
   * This should be constructed with "usg" flags.  A token consisting of
   * a single "<" codepoint is returned by this regular expression if it
   * encounters something it can't parse.
   */
  const RXS_READ_TOKEN =
    "(?:" +
      "(?:" +
        "\\u{3c}!--" +
        "(?:[^\\-]+|-[^\\-]|--+[^\\u{3e}])*" +
        "-+-\\u{3e}" +
      ")|" +
      "(?:" +
        "\\u{3c}\\?" +
        "(?:[^\\?]+|\\?+[^\\u{3e}])*" +
        "\\?+\\u{3e}" +
      ")|" +
      "(?:" +
        "\\u{3c}!DOCTYPE" +
        "(?:[^\\u{3e}'\"\\u{5b}\\u{5d}]+|'[^']*'|\"[^\"]*\")*" +
        "\u{3e}" +
      ")|" +
      "(?:" +
        "\\u{3c}!\\u{5b}CDATA\\u{5b}" +
        "(?:[^\\u{5d}]|\\u{5d}[^\\u{5d}]|\\u{5d}\\u{5d}+[^\\u{3e}])*" +
        "\\u{5d}+\\u{5d}\\u{3e}" +
      ")|" +
      "(?:" +
        "\\u{3c}[^!\\?\\u{3e}]" +
        "(?:" +
          "[^\\u{3c}\\u{3e}'\"]+|" +
          "'[^\\u{3c}']*'|" +
          "\"[^\\u{3c}\"]*\"" +
        ")*" +
        "\\u{3e}" +
      ")|" +
      "(?:" +
        "[^\\u{3c}]+" +
      ")|" +
      "(?:" +
        "\\u{3c}" +
      ")" +
  ")";
  
  /*
   * Local functions
   * ===============
   */
  
  /*
   * Determine whether the given value is an integer.
   * 
   * Parameters:
   * 
   *   val - the value to check
   * 
   * Return:
   * 
   *   true if value is an integer, false otherwise
   */
  function isInteger(val) {
    if (typeof val !== "number") {
      return false;
    }
    if (Math.floor(val) !== val) {
      return false;
    }
    return true;
  }
  
  /*
   * Return a string with trailing XML whitespace dropped.
   * 
   * Parameters:
   * 
   *   str - the string to trim
   * 
   * Return:
   * 
   *   the end-trimmed string
   */
  function endTrim(str) {
    if (typeof str !== "string") {
      throw new Error();
    }
    RX_END_TRIM.lastIndex = 0;
    return str.replace(RX_END_TRIM, "");
  }
  
  /*
   * Perform whitespace compression on the given string and return the
   * compressed version.
   * 
   * Parameters:
   * 
   *   str - the string to whitespace-compress
   * 
   * Return:
   * 
   *   the compressed string
   */
  function wsCompress(str) {
    if (typeof str !== "string") {
      throw new Error();
    }
    
    RX_COMPRESS_WS.lastIndex = 0;
    RX_START_TRIM.lastIndex  = 0;
    RX_END_TRIM.lastIndex    = 0;
    
    str = str.replaceAll(RX_COMPRESS_WS, " ");
    str = str.replace(RX_START_TRIM, "");
    str = str.replace(RX_END_TRIM, "");
    
    return str;
  }
  
  /*
   * Split a name into a prefix and a local part.
   * 
   * The prefix does not include the colon, and it is null if there is
   * no namespace prefix.
   * 
   * If the name has exactly one colon, and both the part before and
   * after the colon are valid names, then the part before is the prefix
   * and the part after is the local name.
   * 
   * In all other cases, the whole name is put into the local part and
   * the prefix is undef.  This includes the case where there is more
   * than one colon in the name.
   * 
   * Parameters:
   * 
   *   str - the name to split
   * 
   * Return:
   * 
   *   an array of two elements, the first being the prefix and the
   *   second being the local name, with the prefix null if there is no
   *   namespace prefix
   */
  function splitName(str) {
    // Check parameters
    if (typeof str !== "string") {
      throw new Error();
    }
    
    // Define result variables
    let result_ns    = null;
    let result_local = null;
    
    // Try to split the name
    RX_SPLIT_NAME.lastIndex = 0;
    let retval = RX_SPLIT_NAME.exec(str);
    if (retval !== null) {
      // Split into namespace prefix and local
      result_ns    = retval[1];
      result_local = retval[2];
      
      // Unless the two are both valid names, fall back to everything in
      // the local part
      if (!(validName(result_ns) && validName(result_local))) {
        result_ns    = null;
        result_local = str;
      }
      
    } else {
      // Not a splittable name
      result_ns    = null;
      result_local = str;
    }
    
    // Return results
    return [result_ns, result_local];
  }
  
  /*
   * Determine how many line feed characters are in the given string.
   * 
   * Parameters:
   * 
   *   str - the string to check
   * 
   * Return:
   * 
   *   the number of line feed characters
   */
  function countLine(str) {
    if (typeof str !== "string") {
      throw new Error();
    }
    RX_COUNT_LINE.lastIndex = 0;
    const lfs = str.replaceAll(RX_COUNT_LINE, "");
    return lfs.length;
  }
  
  /*
   * Public functions
   * ================
   */
  
  /*
   * Check whether a given integer value is a valid Unicode codepoint
   * that can be used within LeafXML.
   * 
   * Parameters:
   * 
   *   c - integer value to check
   * 
   * Return:
   * 
   *   true if valid codepoint value, false otherwise
   */
  function validCode(c) {
    if (!isInteger(c)) {
      throw new Error();
    }
    
    let result = false;
    if ((c === 0x9) || (c === 0xa) || (c == 0xd) ||
        ((c >= 0x20) && (c <= 0x7e)) ||
        (c === 0x85) ||
        ((c >= 0xa0) && (c <= 0xd7ff)) ||
        ((c >= 0xe000) && (c <= 0xfdcf)) ||
        ((c >= 0xfdf0) && (c <= 0x10fffd))) {
      
      if ((c & 0xffff) < 0xfffe) {
        result = true;
      }
    }
    
    return result;
  }
  
  /*
   * Check whether a given string only contains codepoints that pass the
   * validCode() function.  Empty strings do pass this function.
   * 
   * This function is optimized so that it does not actually invoke
   * validCode() but rather uses a regular expression.
   * 
   * Parameters:
   * 
   *   str - the string to check
   * 
   * Return:
   * 
   *   true if only valid codepoints in string, false otherwise
   */
  function validString(str) {
    if (typeof str !== "string") {
      throw new Error();
    }
    
    RX_VALID_STR.lastIndex = 0;
    return RX_VALID_STR.test(str);
  }
  
  /*
   * Check whether a given string qualifies as a valid XML name.  This
   * function allows names to contain colons.
   * 
   * Parameters:
   * 
   *   str - the string to check
   * 
   * Return:
   * 
   *   true if name is valid, false otherwise
   */
  function validName(str) {
    if (typeof str !== "string") {
      throw new Error();
    }
    
    RX_VALID_NAME_1.lastIndex = 0;
    RX_VALID_NAME_2.lastIndex = 0;
    
    if (RX_VALID_NAME_1.test(str) && RX_VALID_NAME_2.test(str)) {
      return true;
    } else {
      return false;
    }
  }
  
  /*
   * Perform line break normalization on the given string and return the
   * normalized version.
   * 
   * Parameters:
   * 
   *   str - the string to normalize
   * 
   * Return:
   * 
   *   the line break normalized string
   */
  function breakNorm(str) {
    if (typeof str !== "string") {
      throw new Error();
    }
    
    RX_BREAK_NORM_1.lastIndex = 0;
    RX_BREAK_NORM_2.lastIndex = 0;
    
    str = str.replaceAll(RX_BREAK_NORM_1, "\n");
    str = str.replaceAll(RX_BREAK_NORM_2, "\n");
    
    return str;
  }
  
  /*
   * Constructor
   * ===========
   */
  
  /*
   * Construct a LeafXML parser that will parse a full XML file given as
   * a string.
   * 
   * Parameters:
   * 
   *   str - a string containing the whole XML file to parse
   */
  function Parser(str) {
    // Check parameters
    if (typeof str !== "string") {
      throw new Error();
    }
    
    // _str stores the XML string
    this._str = str;
    
    // _rx stores a instance of the tokenizer regular expression that is
    // specific to this parser instance
    this._rx = new RegExp(RXS_READ_TOKEN, "usg");
    
    // _sname stores the data source name, or null if not defined
    this._sname = null;
    
    // _done is set to true once parsing is complete
    this._done = false;
    
    // _lnum is the current line number in the XML file
    this._lnum = 1;
    
    // _buf is the event buffer.
    //
    // Each element is a subarray.  Subarrays always have at least one
    // element, where the first element is the line number the element
    // began on.
    //
    // Ending tag subarrays always just have the one element with the
    // line number.
    //
    // Content text subarrays always have two elements, where the first
    // is the line number and the second is the decoded content text.
    //
    // Starting tag subarrays always have five elements:
    //
    //   (1) Line number
    //   (2) Element name
    //   (3) Element namespace, or undef
    //   (4) Attribute map, hash reference
    //   (5) External attribute map, hash reference
    //
    this._buf = [];
    
    // _cur is the current loaded element, or null if none.
    //
    // Has the same format as the elements in the event buffer.
    //
    this._cur = null;
    
    // _tstate is the tag state.
    //
    // 1 means initial state, 0 means active state, -1 means finished
    // state.
    //
    this._tstate = 1;
    
    // _tstack is the tag stack.
    //
    // Each starting element pushes the element name onto the tag stack.
    // Each ending element pops an element name off the tag stack, after
    // verifying it matches.
    //
    this._tstack = [];
    
    // _nstack is the namespace stack.
    //
    // This stack is never empty.  The element on top is an object that
    // maps prefixes to namespace values.  If the empty string is used
    // as a prefix, it sets up a default element namespace.
    //
    // The stack starts out with the "xml" and "xmlns" prefixes defined.
    //
    this._nstack = [
      {
        "xml"   : "http://www.w3.org/XML/1998/namespace",
        "xmlns" : "http://www.w3.org/2000/xmlns/"
      }
    ];
  }
  
  /*
   * Local instance functions
   * ========================
   */
  
  /*
   * Generate a parsing error.
   * 
   * lnum is the line number, or any integer value less than one if no
   * line number available.  detail is the actual error message.
   *
   * This function does not raise the error itself.
   * 
   * Parameters:
   * 
   *   lnum - the line number
   * 
   *   detail - the detail of the error message
   * 
   * Return:
   * 
   *   an Error object that can be thrown
   */
  Parser.prototype._parseErr = function(lnum, detail) {
    // Check parameters
    if (!isInteger(lnum)) {
      throw new Error();
    }
    if (typeof detail !== "string") {
      throw new Error();
    }
    
    // Form message
    let msg = "[XML file";
    
    if (this._sname !== null) {
      msg = msg + " \"" + this._sname + "\"";
    }
    
    if (lnum >= 1) {
      msg = msg  + " line " + lnum.toString();
    }
    
    msg = msg + "] " + detail;
    
    // Return error
    return new Error(msg);
  };
  
  /*
   * Read the next raw token from the XML file.
   *
   * Returns an array of two values.  The first value is the line number
   * the token began on.  The second value is the token itself.
   * 
   * If there are no more tokens, both return value will be null.
   * 
   * The _done and _lnum instance variables will be updated by this
   * function.
   * 
   * Line break normalization is already performed on returned tokens,
   * because it is necessary to update the line number.  This function
   * will also use validString() to make sure that all codepoints within
   * the string are valid.
   * 
   * Return:
   * 
   *   an array containing a line number and a string holding the token,
   *   or null if no more tokens
   */
  Parser.prototype._readToken = function() {
    // If parsing is done, proceed no further and return no more tokens
    if (this._done) {
      return null;
    }
    
    // If parsing is not done, attempt to get another token
    let   token = null;
    const retval = this._rx.exec(this._str);
    
    if (retval !== null) {
      // We got a token
      token = retval[0];
    
    } else {
      // No further tokens
      this._done = true;
      return null;
    }
    
    // Check for parsing error
    if (token === "<") {
      throw self._parseErr(this._lnum, "XML tokenization failed");
    }
    
    // Token line number is whatever the line number was before parsing
    // the token
    const token_line = this._lnum;
    
    // Check that token only contains valid codepoints
    if (!validString(token)) {
      // String has an invalid codepoint, so iterate through updating
      // the token line so we get the correct line number
      let cv = null;
      let err_line = token_line;
      
      for(let i = 0; i < token.length; i++) {
        cv = token.codePointAt(i);
        if (cv > 0xffff) {
          i++;
        }
        
        if (cv === 0xa) {
          err_line++;
        } else if (!validCode(cv)) {
          break;
        }
      }
      if (cv === null) {
        throw new Error();
      }
      
      throw this._parseErr(
        err_line,
        "Invalid Unicode codepoint U+" +
        cv.toString(16).toUpperCase().padStart(4, "0"));
    }
    
    // Perform line break normalization
    token = breakNorm(token);
    
    // Update line number
    this._lnum += countLine(token);
    
    // Return the token
    return [token_line, token];
  };
  
  /*
   * Perform entity escaping on the given string and return the string
   * with all escapes decoded.
   * 
   * lnum is the line number at the start of the text token, for
   * purposes of diagnostics.
   * 
   * This function assumes that line break normalization has already
   * been applied to the given string.  If not, then line counting for
   * diagnostics might not work correctly.
   * 
   * Parameters:
   * 
   *   str - the string to perform escaping on
   * 
   *   lnum - the starting line number of the string
   * 
   * Return:
   * 
   *   the escaped string
   */
  Parser.prototype._entEsc = function(str, lnum) {
    // Check parameters
    if (typeof str !== "string") {
      throw new Error();
    }
    if (!isInteger(lnum)) {
      throw new Error();
    }
    
    // If there is no ampersand anywhere, then no escaping required
    if (str.indexOf("&") < 0) {
      return str;
    }
    
    // Result starts out empty
    let result = "";
    
    // Parse a sequence of plain text, line breaks, escape codes, and
    // invalid ampersands
    RX_ENT_ESC.lastIndex = 0;
    for(let retval = RX_ENT_ESC.exec(str);
        retval !== null;
        retval = RX_ENT_ESC.exec(str)) {
      
      // Get token
      let token = retval[0];
      
      // Check for invalid ampersand
      if (token === "&") {
        throw this._parseErr(lnum,
              "Ampersand must be part of entity escape");
      }
      
      // If this is a line break, increase line count
      if (token === "\n") {
        lnum++;
      }
      
      // If this is not an entity escape, copy to result and next token
      if (token.slice(0, 1) !== "&") {
        result = result + token;
        continue;
      }
      
      // If we got here, token is an entity escape, so process it
      RX_ENT_ESC_NAMED.lastIndex = 0;
      RX_ENT_ESC_DEC.lastIndex   = 0;
      RX_ENT_ESC_HEX.lastIndex   = 0;
      let retval2 = null;
      
      if ((retval2 = RX_ENT_ESC_NAMED.exec(token)) !== null) {
        // Named escape
        const ename = retval2[1];
        if (ename === "amp") {
          result = result + "&";
          
        } else if (ename === "lt") {
          result = result + "<";
          
        } else if (ename === "gt") {
          result = result + ">";
          
        } else if (ename === "apos") {
          result = result + "'";
          
        } else if (ename === "quot") {
          result = result + "\"";
          
        } else {
          throw this._parseErr(lnum,
                "Unrecognized named entity '" + token + "'");
        }
        
      } else if ((retval2 = RX_ENT_ESC_DEC.exec(token)) !== null) {
        // Decimal escape
        const cv = parseInt(retval2[1], 10);
        if (!validCode(cv)) {
          throw this._parseErr(lnum,
                "Escaped codepoint out of range for '" + token + "'");
        }
        result = result + String.fromCodePoint(cv);
        
      } else if ((retval2 = RX_ENT_ESC_HEX.exec(token)) !== null) {
        // Base-16 escape
        const cv = parseInt(retval2[1], 16);
        if (!validCode(cv)) {
          throw this._parseErr(lnum,
                "Escaped codepoint out of range for '" + token + "'");
        }
        result = result + String.fromCodePoint(cv);
        
      } else {
        throw this._parseErr(lnum,
            "Invalid entity escape '" + token + "'");
      }
    }
    
    // Return result
    return result;
  };
  
  /*
   * Parse the attribute substring of a tag token.  Returns an object
   * mapping attribute names to attribute values.  Names have been
   * validated and normalized.  Attribute values have been escaped and
   * normalized.
   * 
   * The attribute substring, if it is not empty, should begin with at
   * least one codepoint of whitespace which separates it from the the
   * element name that precedes it in the tag.
   * 
   * Parameters:
   * 
   *   pstr - the attribute substring of the tag
   * 
   *   lnum - the line the attribute substring begins at
   * 
   * Return:
   * 
   *   object mapping attribute names to attribute values
   */
  Parser.prototype._parseAttr = function(pstr, lnum) {
    // Check parameters
    if (typeof pstr !== "string") {
      throw new Error();
    }
    if (!isInteger(lnum)) {
      throw new Error();
    }
    
    // End-trim the parameter substring, but leave leading whitespace
    pstr = endTrim(pstr);
    
    // Just return empty object if parameter substring empty after
    // end-trimming
    if (pstr.length < 1) {
      return {};
    }
    
    // The attribute map starts out empty
    let attr = {};
    
    // Parse any attributes
    RX_PARSE_ATTR.lastIndex = 0;
    for(let retval = RX_PARSE_ATTR.exec(pstr);
        retval !== null;
        retval = RX_PARSE_ATTR.exec(pstr)) {
      
      // Get current part
      const part = retval[0];
  
      // Set part line to current line number then update line number
      const part_line = lnum;
      lnum += countLine(part);
      
      // If part is single codepoint then there is a parsing error
      if (part.length <= 1) {
        throw this._parseErr(part_line,
          "Failed to parse tag attributes");
      }
      
      // If we got here, we should have an attribute, so parse it into
      // an attribute name and an attribute value
      let att_name = null;
      let att_val = null;
      
      let att_name_line = null;
      let att_val_line = null;
      
      RX_PARSE_ATTR_D.lastIndex = 0;
      RX_PARSE_ATTR_S.lastIndex = 0;
      let retval2 = null;
      
      if ((retval2 = RX_PARSE_ATTR_D.exec(part)) !== null) {
        att_name = retval2[2];
        att_val  = retval2[4];
        
        att_name_line = part_line     + countLine(retval2[1]);
        att_val_line  = att_name_line + countLine(retval2[3]);
        
      } else if ((retval2 = RX_PARSE_ATTR_S.exec(part)) !== null) {
        att_name = retval2[2];
        att_val  = retval2[4];
        
        att_name_line = part_line     + countLine(retval2[1]);
        att_val_line  = att_name_line + countLine(retval2[3]);
        
      } else {
        throw this._parseErr(lnum, "Failed to parse tag attributes");
      }
      
      // Normalize attribute name and verify valid
      att_name = att_name.normalize("NFC");
      if (!validName(att_name)) {
        throw this._parseErr(att_name_line,
          "Invalid attribute name '" + att_name + "'");
      }
      
      // Make sure attribute value does not have the disallowed <
      if (att_val.indexOf("<") >= 0) {
        throw this._parseErr(att_val_line,
          "Attribute value contains unescaped <");
      }
      
      // Entity-escape, whitespace-compress, and NFC normalize the
      // attribute value
      att_val = this._entEsc(att_val, att_val_line);
      att_val = wsCompress(att_val).normalize("NFC");
      
      // Make sure attribute not defined yet
      if (att_name in attr) {
        throw this._parseErr(att_name_line,
          "Attribute '" + att_name + "' defined multiple times");
      }
      
      // Store the attribute
      attr[att_name] = att_val;
    }
    
    // Return attribute map
    return attr;
  };
  
  /*
   * Parse a tag token.
   * 
   * The return value is an array with the following elements:
   * 
   *   (1) Tag type: 1 = start, 0 = empty, -1 = end
   *   (2) Element name
   *   (3) Ojbect mapping attribute names to attribute values
   * 
   * Names have been validated and normalized.  Attribute values have
   * been escaped and normalized.  End tags have been verified to have
   * no attributes.
   * 
   * Parameters:
   * 
   *   token - the tag token string to parse
   * 
   *   lnum - the line number of the tag token
   * 
   * Return:
   * 
   *   an array with the parsed tag token
   */
  Parser.prototype._parseTag = function(token, lnum) {
    // Check parameters
    if (typeof token !== "string") {
      throw new Error();
    }
    if (!isInteger(lnum)) {
      throw new Error();
    }
    
    // Parse the whole tag
    RX_PARSE_TAG.lastIndex = 0;
    const retval = RX_PARSE_TAG.exec(token);
    if (retval === null) {
      throw this._parseErr(lnum, "Failed to parse tag");
    }
    
    const start_slash = retval[1];
    let   ename       = retval[2];
    const pstr        = retval[3];
    const end_slash   = retval[4];

    // Determine the tag type
    let etype = null;
    if ((start_slash === undefined) && (end_slash === undefined)) {
      etype = 1;
    
    } else if ((start_slash !== undefined) &&
                (end_slash === undefined)) {
      etype = -1;
      
    } else if ((start_slash === undefined) &&
                (end_slash !== undefined)) {
      etype = 0;
      
    } else {
      throw this._parseErr(lnum, "Failed to parse tag");
    }
    
    // Normalize element name and validate it
    ename = ename.normalize("NFC");
    if (!validName(ename)) {
      throw this._parseErr(lnum, "Invalid tag name '" + ename + "'");
    }
    
    // Parse attributes
    const attr = this._parseAttr(pstr, lnum);
    
    // If closing tag, make sure no attributes
    if (etype < 0) {
      for(let p in attr) {
        throw this._parseErr(lnum,
          "Closing tags may not have attributes");
      }
    }
    
    // Return parsed tag
    return [etype, ename, attr];
  };
  
  /*
   * Update the namespace stack before processing a starting or empty
   * tag.
   * 
   * attr is the raw attribute map.  lnum is the line number of the tag.
   * A new entry will be pushed onto the namespace stack by this
   * function.
   * 
   * Parameters:
   * 
   *   attr - the attribute map
   * 
   *   lnum - the line number of the tag
   */
  Parser.prototype._updateNS = function(attr, lnum) {
    // Check parameters
    if (typeof attr !== "object") {
      throw new Error();
    }
    if (!isInteger(lnum)) {
      throw new Error();
    }
    
    // The new_ns map contains new namespace mappings defined in this
    // element
    let new_ns = {};
    
    // Go through attributes
    let k = null;
    for(k in attr) {
      // Get the prefix mapped by this attribute, or skip attribute if
      // not a namespace mapping
      let target_pfx = null;
      
      const sname = splitName(k);
      if (sname[0] !== null) {
        if (sname[0] === "xmlns") {
          target_pfx = sname[1];
        }
      } else {
        if (sname[1] === "xmlns") {
          target_pfx = "";
        }
      }
      
      if (target_pfx === null) {
        continue;
      }
      
      // For diagnostics, get a label of what is being mapped
      let target_label = null;
      if (target_pfx.length > 0) {
        target_label = "namespace prefix '" + target_pfx + "'";
      } else {
        target_label = "default namespace";
      }
      
      // Get value of this namespace target and make sure not empty
      const ns_val = attr[k];
      if (ns_val.length < 1) {
        throw this._parseErr(lnum,
          "Can't map " + target_label + " to empty value");
      }
      
      // Make sure not mapping the xmlns prefix
      if (target_pfx === "xmlns") {
        throw this._parseErr(lnum,
          "Can't namespace map the xmlns prefix");
      }
      
      // Make sure not mapping to reserved xmlns namespace
      if (ns_val === 'http://www.w3.org/2000/xmlns/') {
        throw this._parseErr(lnum,
          "Can't map " + target_label + " to reserved xmlns value");
      }
      
      // If target prefix is "xml" make sure mapping to proper
      // namespace; otherwise, make sure not mapping to XML namespace
      if (target_pfx === "xml") {
        if (ns_val !== "http://www.w3.org/XML/1998/namespace") {
          throw this._parseErr(lnum,
            "Can only map " + target_label + " to reserved xml value");
        }
      } else {
        if (ns_val === "http://www.w3.org/XML/1998/namespace") {
          throw this._parseErr(lnum,
            "Can't map " + target_label + " to reserved xml value");
        }
      }
      
      // Make sure this mapping not yet defined on this element
      if (target_pfx in new_ns) {
        throw this._parseErr(lnum,
          "Redefinition of " + target_label + " on same element");
      }
      
      // Add to new mappings
      new_ns[target_pfx] = ns_val;
    }
    
    // If at least one new mapping, then make a copy of the namespace
    // context on top of the stack, modify it, and push it back;
    // otherwise, just duplicate the reference on top of the namespace
    // stack
    let has_new = false;
    let nk = null;
    for (nk in new_ns) {
      has_new = true;
      break;
    }
    
    if (has_new) {
      // New definitions, so make a copy of the namespace on top of the
      // stack
      let nsz = this._nstack[this._nstack.length - 1];
      let nsa = {};
      let kz = null;
      for(kz in nsz) {
        nsa[kz] = nsz[kz];
      }
      
      // Update namespace
      let kv = null;
      for(kv in new_ns) {
        nsa[kv] = new_ns[kv];
      }
      
      // Push updated namespace
      this._nstack.push(nsa);
      
    } else {
      // No new definitions, just duplicate reference on top
      this._nstack.push(this._nstack[this._nstack.length - 1]);
    }
  };
  
  /*
   * Return a subset attribute mapping that only contains attributes
   * which have no namespace prefix and which are not "xmlns".
   * 
   * Parameters:
   * 
   *   attr - object containing the raw attribute map
   * 
   *   lnum - the line number of the tag
   * 
   * Return:
   * 
   *   object containing plain attribute map
   */
  Parser.prototype._plainAttr = function(attr, lnum) {
    // Check parameters
    if (typeof attr !== "object") {
      throw new Error();
    }
    if (!isInteger(lnum)) {
      throw new Error();
    }
    
    // Form the subset
    let result = {};
    let k = null;
    
    for(k in attr) {
      const retval = splitName(k);
      if ((retval[0] === null) && (k !== "xmlns")) {
        result[k] = attr[k];
      }
    }
    
    // Return result
    return result;
  };
  
  /*
   * Return a namespaced attribute mapping.
   * 
   * Parameters:
   * 
   *   attr - object containing the raw attribute map
   * 
   *   lnum - the line number of the tag
   * 
   * Return:
   * 
   *   two-level object containing the namespaced attribute map
   */
  Parser.prototype._extAttr = function(attr, lnum) {
    // Check parameters
    if (typeof attr !== "object") {
      throw new Error();
    }
    if (!isInteger(lnum)) {
      throw new Error();
    }
    
    // Form the set
    let result = {};
    let k = null;
    
    for(k in attr) {
      // Split attribute name if possible
      const retval = splitName(k);
            
      // Only process attributes that have a prefix which is not "xmlns"
      if ((retval[0] !== null) && (retval[0] !== "xmlns")) {
        // Get namespace value for prefix
        const a_ns = this._nstack[this._nstack.length - 1][retval[0]];
        if (a_ns === undefined) {
          throw this._parseErr(lnum,
            "Unmapped namespace prefix '" + retval[0] + "'");
        }
        
        // Add new namespace entry if not yet defined
        if (result[a_ns] === undefined) {
          result[a_ns] = {};
        }
        
        // Make sure local attribute not yet defined
        if (result[a_ns][retval[1]] !== undefined) {
          throw this._parseErr(lnum,
            "Aliased external attribute '" + k + "'");
        }
        
        // Add namespaced attribute
        result[a_ns][retval[1]] = attr[k];
      }
    }
    
    // Return result
    return result;
  };
  
  /*
   * Process a tag assembly.
   * 
   * token is the whole tag token.  lnum is the line number that the tag
   * token began.  It is assumed that line break normalization has
   * already been performed on the token.
   * 
   * Parameters:
   * 
   *   token - the tag assembly string to process
   * 
   *   lnum - the line number of the tag
   */
  Parser.prototype._procTag = function(token, lnum) {
    // Check parameters
    if (typeof token !== "string") {
      throw new Error();
    }
    if (!isInteger(lnum)) {
      throw new Error();
    }
    
    // Parse the tag
    let retval = this._parseTag(token, lnum);
    
    const etype    = retval[0];
    const ename    = retval[1];
    const raw_attr = retval[2];
    
    // If this is an opening or empty element, verify that tag state is
    // not finished and then push the element name on the tag stack and
    // set tag state to active
    if (etype >= 0) {
      if (this._tstate < 0) {
        throw this._parseErr(lnum, "Multiple root elements");
      }
      
      this._tstack.push(ename);
      this._tstate = 0;
    }
    
    // If this is a closing or empty element, verify that tag state is
    // active, verify that element on top of tag stack matches current
    // element, and then pop element on top of tag stack, moving to
    // finished state if tag stack now empty
    if (etype <= 0) {
      if (this._tstate !== 0) {
        throw this._parseErr(lnum, "Tag parsing error");
      }
      
      if (this._tstack[this._tstack.length - 1] !== ename) {
        throw this._parseErr(lnum, "Tag pairing error");
      }
      
      this._tstack.pop();
      if (this._tstack.length < 1) {
        this._tstate = -1;
      }
    }
    
    // If this is an opening or empty element, go through all the raw
    // attributes and update namespace stack
    if (etype >= 0) {
      this._updateNS(raw_attr, lnum);
    }
    
    // Parse the element name according to namespaces
    retval = splitName(ename);
    let e_local = retval[1];
    let e_ns = null;
    if (retval[0] !== null) {
      e_ns = this._nstack[this._nstack.length - 1][retval[0]];
      if (e_ns === undefined) {
        throw this._parseErr(lnum,
          "Unmapped namespace prefix '" + retval[0] + "'");
      }
    }
    
    // If no defined namespace for element but a default namespace, then
    // use the default namespace
    if (e_ns === null) {
      e_ns = this._nstack[this._nstack.length - 1][""];
      if (e_ns === undefined) {
        e_ns = null;
      }
    }
    
    // The atts map will have all attributes that do not have a prefix
    // and that are not the special "xmlns" attribute; only has entries
    // for starting and empty tags
    let atts = null;
    if (etype >= 0) {
      atts = this._plainAttr(raw_attr, lnum);
    } else {
      atts = {};
    }
    
    // The ext map will have all the namespace attributes that do not
    // have the special "xmlns:" prefix; only has entries for starting
    // and empty tags
    let ext = null;
    if (etype >= 0) {
      ext = this._extAttr(raw_attr, lnum);
    } else {
      ext = {};
    }
    
    // If this is a closing or empty element, pop the namespace stack
    if (etype <= 0) {
      this._nstack.pop();
    }
    
    // Add the proper entries to the buffer
    if (etype >= 0) {
      // Starting tag or empty tag, so add a starting tag event to the
      // buffer
      this._buf.push([
        lnum,
        e_local,
        e_ns,
        atts,
        ext
      ]);
    }
    
    if (etype <= 0) {
      // Empty tag or ending tag, so add an ending tag event to the
      // buffer
      this._buf.push([lnum]);
    }
  };
  
  /*
   * Process a content assembly.
   * 
   * text is the decoded text of the assembly.  Text tokens must have
   * their entities escaped already.  This function will apply line
   * break normalization and Unicode normalization to NFC.  This
   * function can be called for content assemblies outside of any tags.
   * 
   * lnum is the line number that the text token begins.
   * 
   * Parameters:
   * 
   *   text - the decoded text of the content assembly as a string
   * 
   *   lnum - the line number that this content begins at
   */
  Parser.prototype._procContent = function(text, lnum) {
    // Check parameters
    if (typeof text !== "string") {
      throw new Error();
    }
    if (!isInteger(lnum)) {
      throw new Error();
    }
    
    // Ignore if text is empty
    if (text.length < 1) {
      return;
    }
    
    // Apply line break normalization
    text = breakNorm(text);
    
    // If not in active tag state, then just make sure the text only
    // contains spaces, tabs, and line feeds, and then return without
    // any events
    if (this._tstate !== 0) {
      RX_BLANK.lastIndex = 0;
      if (!(RX_BLANK.test(text))) {
        for(let i = 0; i < text.length; i++) {
          let c = text.codePointAt(i);
          if (c > 0xffff) {
            i++;
          }
          
          if (c === 0xa) {
            lnum++;
          }
          if ((c !== 0x20) && (c !== 0x9) && (c !== 0xa)) {
            break;
          }
        }
        throw this._parseErr(lnum,
          "Text content not allowed outside root element");
      }
      return;
    }
    
    // We are in active state, so normalize the content text to NFC and
    // add to event buffer
    this._buf.push([
      lnum,
      text.normalize("NFC")
    ]);
  };
  
  /*
   * Public instance functions
   * =========================
   */
  
  /*
   * Set a data source name for use in diagnostics.
   * 
   * Any current data source name is overwritten.  Passing null is
   * allowed, and has the effect of blanking the source name.
   * 
   * If a non-null data source name is defined, it will be included in
   * error messages thrown by this module during parsing.
   * 
   * Parameters:
   * 
   *   str - string containing the data source name, or null.,
   */
  Parser.prototype.setSourceName = function(str) {
    if (str !== null) {
      if (typeof str !== "string") {
        throw new Error();
      }
    }
    this._sname = str;
  };
  
  /*
   * Get the current data source name, or null if none defined.
   * 
   * Return:
   * 
   *   string containing the data source name, or null
   */
  Parser.prototype.getSourceName = function() {
    return this._sname;
  };
  
  /*
   * Read the next parsing event from the parser.
   * 
   * Returns true if a new event is available, or false if there are no
   * more parsing events.  After this function returns false, any
   * further calls will also return false.
   * 
   * This must be called before reading the first parsing event.  In
   * other words, the first parsing event is not immediately available
   * after parser construction.
   * 
   * Throws errors in case of parsing problems.  Undefined behavior
   * occurs if you catch an error and then try to continue parsing.
   * 
   * Return:
   * 
   *   true if a new event is available, false otherwise
   */
  Parser.prototype.readEvent = function() {
    
    // If buffer is empty, try to refill it
    if (this._buf.length < 1) {
      // Content buffer starts out undefined
      let content      = null;
      let content_line = null;
      
      // Keep processing tokens until we run out of tokens
      for(let retval = this._readToken();
          retval !== null;
          retval = this._readToken()) {
        
        let token_line = retval[0];
        let token      = retval[1];
        
        // Skip instruction, DOCTYPE, and comment tokens
        if (token.startsWith("<!") || token.startsWith("<?")) {
          continue;
        }
        
        // If this is a CDATA token, then add it to the content buffer
        let retval2 = null;
        RX_CDATA.lastIndex = 0;
        
        if ((retval2 = RX_CDATA.exec(token)) !== null) {
          token = retval2[1];
          if (content !== null) {
            content = content + token;
          } else {
            content = token;
            content_line = token_line;
          }
          continue;
        }
        
        // If this is a text token, then add it to the content buffer
        // after applying entity escaping
        if (!token.startsWith("<")) {
          token = this._entEsc(token, token_line);
          if (content !== null) {
            content = content + token;
          } else {
            content = token;
            content_line = token_line;
          }
          continue;
        }
        
        // If we got here, then we're dealing with a regular tag token,
        // so first of all flush the content buffer if filled
        if (content !== null) {
          this._procContent(content, content_line);
          content = null;
          content_line = null;
        }
        
        // Now process the tag
        this._procTag(token, token_line);
        
        // If buffer is no longer empty, leave loop
        if (this._buf.length > 0) {
          break;
        }
      }
      
      // If content buffer is filled, flush it
      if (content !== null) {
        this._procContent(content, content_line);
        content = null;
        content_line = null;
      }
    }
    
    // If buffer is filled then grab the next event and set the result;
    // else, clear the results and clear the current event
    let result = false;
    if (this._buf.length > 0) {
      result = true;
      this._cur = this._buf.shift();
    } else {
      result = false;
      this._cur = null;
    }
    
    // Return result
    return result;
  };
  
  /*
   * Determine the type of parsing event that is currently loaded.
   * 
   * This function may only be used after readEvent() has indicated that
   * an event is available.
   * 
   * The return value is 1 for a starting tag, 0 for content text, or -1
   * for an ending tag.
   * 
   * Return:
   * 
   *   1 for starting tag, 0 for content text, -1 for ending tag
   */
  Parser.prototype.eventType = function() {
    // Check state
    if (this._cur === null) {
      throw new Error("No event loaded");
    }
    
    // Determine result
    let result = null;
    if (this._cur.length === 1) {
      result = -1;
      
    } else if (this._cur.length === 2) {
      result = 0;
      
    } else if (this._cur.length === 5) {
      result = 1;
      
    } else {
      throw new Error();
    }
    
    return result;
  };
  
  /*
   * Determine the line number in the XML file where the current parsing
   * event begins.
   * 
   * This function may only be used after readEvent() has indicated that
   * an event is available.
   * 
   * The first line is line 1.
   * 
   * Return:
   * 
   *   the line number of the current event
   */
  Parser.prototype.lineNumber = function() {
    // Check state
    if (this._cur === null) {
      throw new Error("No event loaded");
    }
    
    // Get line number
    return this._cur[0];
  };
  
  /*
   * Determine the decoded content text of a content text event.
   * 
   * This function may only be used after readEvent() has indicated that
   * an event is available and eventType indicates 0 (content text).
   * 
   * The content text has already been decoded for entity escapes, and
   * it has already been normalized both for line breaks and for Unicode
   * NFC.
   * 
   * Content text events only occur when they are enclosed in tags.  All
   * whitespace is included in content text, and content text events are
   * always concatenated so that there is a single span covering
   * everything between tags, even across CDATA blocks.
   * 
   * Return:
   * 
   *   the content text of the current event
   */
  Parser.prototype.contentText = function() {
    // Check state
    if (this._cur === null) {
      throw new Error("No event loaded");
    }
    if (this._cur.length !== 2) {
      throw new Error("Wrong event type");
    }
    
    // Get text
    return this._cur[1];
  };
  
  /*
   * Determine the element name of a starting element event.
   * 
   * This function may only be used after readEvent() has indicated that
   * an event is available and eventType indicates 1 (starting element).
   * 
   * The element name is the local name and never includes any namespace
   * prefix.  It has already been normalized to NFC.
   * 
   * Return:
   * 
   *   the element name in the current event
   */
  Parser.prototype.elementName = function() {
    // Check state
    if (this._cur === null) {
      throw new Error("No event loaded");
    }
    if (this._cur.length !== 5) {
      throw new Error("Wrong event type");
    }
    
    // Query
    return this._cur[1];
  };
  
  /*
   * Determine the element namespace value of a starting element event.
   * 
   * This function may only be used after readEvent() has indicated that
   * an event is available and eventType indicates 1 (starting element).
   * 
   * The namespace value is usually the namespace URI.  null is returned
   * if this element is not in any namespace.
   * 
   * Return:
   * 
   *   the namespace value (URI) of the element or null if no namespace
   */
  Parser.prototype.elementNS = function() {
    // Check state
    if (this._cur === null) {
      throw new Error("No event loaded");
    }
    if (this._cur.length !== 5) {
      throw new Error("Wrong event type");
    }
    
    // Query
    return this._cur[2];
  };
  
  /*
   * Return the plain attribute map as an object mapping attribute names
   * to attribute values.
   * 
   * This function may only be used after readEvent() has indicated that
   * an event is available and eventType indicates 1 (starting element).
   * 
   * The returned object has the attribute names as keys and their
   * values as values.  Normalization and entity decoding has already
   * been performed.
   * 
   * Only attribute names that are not in any namespace are included.
   * The special "xmlns" attribute is excluded.
   * 
   * The returned object is the parser's copy, so clients should not
   * modify it.
   * 
   * Return:
   * 
   *   object mapping plain attribute names to their values
   */
  Parser.prototype.attr = function() {
    // Check state
    if (this._cur === null) {
      throw new Error("No event loaded");
    }
    if (this._cur.length !== 5) {
      throw new Error("Wrong event type");
    }
    
    // Query
    return this._cur[3];
  };
  
  /*
   * Return the namespaced attribute map.
   * 
   * This function may only be used after readEvent() has indicated that
   * an event is available and eventType indicates 1 (starting element).
   * 
   * The object maps namespace values to object values that hold a
   * mapping of attribute names to attribute values within that
   * namepsace.
   * 
   * Attributes with "xmlns:" prefixes are not included in this mapping.
   *
   * The returned object is the parser's copy, so clients should not
   * modify it.
   * 
   * Return:
   * 
   *   two-level object mapping representing namespaced attributes
   */
  Parser.prototype.externalAttr = function() {
    // Check state
    if (this._cur === null) {
      throw new Error("No event loaded");
    }
    if (this._cur.length !== 5) {
      throw new Error("Wrong event type");
    }
    
    // Query
    return this._cur[4];
  };
  
  /*
   * Exports
   * =======
   */
  
  return {
    "validCode"  : validCode,
    "validString": validString,
    "validName"  : validName,
    "Parser"     : Parser
  };
  
}());
