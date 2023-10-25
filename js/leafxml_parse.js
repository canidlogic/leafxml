"use strict";

/*
 * leafxml_parse.js
 * ================
 * 
 * JavaScript module backing leafxml_parse.html
 */

/*
 * Define ParseApp namespace
 */
window.ParseApp = (function() {
  
  /*
   * Local data
   * ==========
   */
  
  /*
   * ns_array maps unsigned integer indices to specific namespace
   * values, where index zero is reserved to mean no namespace
   */
  let ns_array = ["(none)"];
  
  /*
   * ns_map maps specific namespace values to their indices in the
   * ns_array
   */
  let ns_map = {};
  
  /*
   * Local functions
   * ===============
   */
  
  /*
   * Reset the local data namespace tables.
   */
  function resetNS() {
    ns_array = ["(none)"];
    ns_map = {};
  }
  
  /*
   * Encode a namespace value as an unsigned decimal integer using the
   * local data namespace tables.  The return value is an integer zero
   * or greater.
   * 
   * You can pass null, in which case this function always returns zero.
   * 
   * If the given namespace is not in the maps, it is added.
   * 
   * Parameters:
   * 
   *   val - the namespace value to encode, or null
   * 
   * Return:
   * 
   *   an unsigned integer encoding the namespace
   */
  function encodeNS(val) {
    if (val === null) {
      return 0;
    }
    
    if (typeof val !== "string") {
      throw new Error();
    }
    
    if (!(val in ns_map)) {
      ns_map[val] = ns_array.length;
      ns_array.push(val);
    }
    
    return ns_map[val];
  }
  
  /*
   * Get a document element by its ID, throwing an error if no element
   * exists with that ID.
   * 
   * Parameters:
   * 
   *   eid - string with the element ID
   * 
   * Return:
   * 
   *   the element object from the document
   */
  function getElement(eid) {
    if (typeof eid !== "string") {
      throw new Error();
    }
    
    const result = document.getElementById(eid);
    if (result === null) {
      throw new Error("Failed to find element '" + eid + "'");
    }
    
    return result;
  }
  
  /*
   * Escape the < > & symbols in a string and return the escaped string.
   * 
   * Parameters:
   * 
   *   str - the string to escape
   * 
   * Return:
   * 
   *   the escaped string
   */
  function escapeText(str) {
    if (typeof str !== "string") {
      throw new Error();
    }
    str = str.replaceAll("<", "&lt;");
    str = str.replaceAll(">", "&gt;");
    str = str.replaceAll("&", "&amp;");
    return str;
  }
  
  /*
   * Wrapper around escapeText() that also uses \\ \t and \n backslash
   * escapes.
   * 
   * Parameters:
   * 
   *   str - the string to escape
   * 
   * Return:
   * 
   *   the fully escaped string
   */
  function fullyEscape(str) {
    if (typeof str !== "string") {
      throw new Error();
    }
    str = str.replaceAll("\\", "\\\\");
    str = str.replaceAll("\t", "\\t");
    str = str.replaceAll("\n", "\\n");
    str = escapeText(str);
    return str;
  }
  
  /*
   * Wrapper around fullyEscape() that also escapes " with \"
   * 
   * Parameters:
   * 
   *   str - the string to escape
   * 
   * Return:
   * 
   *   the attribute-escaped string
   */
  function attrEscape(str) {
    if (typeof str !== "string") {
      throw new Error();
    }
    str = str.replaceAll("\"", "\\\"");
    str = fullyEscape(str);
    return str;
  }
  
  /*
   * Enable or disable the control buttons.
   * 
   * Parameters:
   * 
   *   flag - true to enable, false to disable
   */
  function setButtonEnable(flag) {
    if (typeof flag !== "boolean") {
      throw new Error();
    }
    
    const btnParse  = getElement("btnParse");
    const btnUpload = getElement("btnUpload");
    
    if (flag) {
      btnParse.disabled  = false;
      btnUpload.disabled = false;
    } else {
      btnParse.disabled  = true;
      btnUpload.disabled = true;
    }
  }
  
  /*
   * Perform a parsing operation on a XML file given in a string.
   * 
   * Parameters:
   * 
   *   input - the XML file to parse as a string
   */
  function doParse(input) {
    
    // Get controls
    const divResult = getElement("divResult");
    
    // Re-enable buttons
    setButtonEnable(true);
    
    // Define parser
    const xml = new LeafXML.Parser(input);
    xml.setSourceName("source");
    
    // Try to parse the whole file and form results, watching for errors
    let result = "";
    try {
      // Reset namespace tables
      resetNS();
      
      // Add the header
      result = result + "<ul>";
      
      // Parse the whole file
      while (xml.readEvent()) {
        // Start report with the new item and line number
        result = result + "<li>" + xml.lineNumber().toString() + ": ";
        
        // Handle different event types
        const et = xml.eventType();
        if (et > 0) {
          // Starting text
          result = result + "BEGIN ";
          
          // Element name with namespace index
          result = result + encodeNS(xml.elementNS()).toString() +
                    ":" + escapeText(xml.elementName());
          
          // Plain attributes
          const atts = xml.attr();
          let k = null;
          let pka = [];
          
          for(k in atts) {
            pka.push(k);
          }
          pka.sort();
          
          for(let i = 0; i < pka.length; i++) {
            result = result + " 0:" + escapeText(pka[i]) + "=\"" +
                      attrEscape(atts[pka[i]]) + "\"";
          }
          
          // External namespaced attributes
          const ext = xml.externalAttr();
          
          // External attribute array stores all the unsigned decimal
          // integers for namespaces used in external attributes
          let exa = [];
          
          // Fill the external attribute array
          for(k in ext) {
            exa.push(encodeNS(k));
          }
          
          // Sort the external attribute array in numeric order
          exa.sort((a, b) => a - b);
          
          // Print namespaced attributes
          for(let i = 0; i < exa.length; i++) {
            const nsk = ns_array[exa[i]];
            const nsm = ext[nsk];
            
            let pkb = [];
            for(k in nsm) {
              pkb.push(k);
            }
            pkb.sort();
            
            for(let j = 0; j < pkb.length; j++) {
              result = result + " " + exa[i].toString() + ":" +
                pkb[j] + "=\"" + attrEscape(nsm[pkb[j]]) + "\"";
            }
          }
          
        } else if (et === 0) {
          // Content text
          result = result + "TEXT " + fullyEscape(xml.contentText());
          
        } else if (et < 0) {
          // Ending tag
          result = result + "END";
          
        } else {
          throw new Error();
        }
        
        // Finish the item
        result = result + "</li>";
      }
      
      // Add the footer
      result = result + "</ul>";
      
      // Now write the namespace table
      result = result +
        "<div class=\"clsLabel\">Namespace table:</div><ul>";
      
      for(let k = 0; k < ns_array.length; k++) {
        result = result + "<li>" + k.toString() + " => " +
                  escapeText(ns_array[k]) + "</li>";
      }
      
      result = result + "</ul>";
      
    } catch (ex) {
      // Report the error
      result = "<b>Error:</b> " + escapeText(ex.message);
      divResult.innerHTML = result;
      throw ex;
    }
    
    // Write the results
    divResult.innerHTML = result;
  }
  
  /*
   * Function called when a request is received to perform the parsing
   * operation on the input text box.
   */
  function handleParse() {
    // Get controls
    const txtInput  = getElement("txtInput" );
    const divResult = getElement("divResult");
    
    // Set parsing message, disable buttons, and grab input text
    divResult.innerHTML = "Parsing...";
    setButtonEnable(false);
    const inputVal = txtInput.value;
    
    // Invoke the parser function on a timeout so the page has a chance
    // to update the parsing message first
    setTimeout(() => {
      doParse(inputVal);
    }, 100);
  }
  
  /*
   * Function called when a request is received to perform the parsing
   * operation on an uploaded file.
   */
  function handleUpload() {
    // Get controls
    const filUpload = getElement("filUpload");
    const divResult = getElement("divResult");
    
    // Make sure exactly one file selected
    if (filUpload.files.length !== 1) {
      divResult.innerHTML =
        "<b>Error:</b> You must upload exactly one file!";
      return;
    }
    
    // Get the file
    const fil = filUpload.files[0];
    
    // Set uploading message and disable buttons
    divResult.innerHTML = "Uploading...";
    setButtonEnable(false);
    
    // Define file reader
    const fr = new FileReader();
    
    // Define event handlers
    fr.addEventListener("abort", (event) => {
      divResult.innerHTML = "<b>Error:</b> Upload aborted!";
      setButtonEnable(true);
    });
    
    fr.addEventListener("error", (event) => {
      divResult.innerHTML = "<b>Error:</b> Failed to read upload:" +
        escapeText(fr.error);
      setButtonEnable(true);
    });
    
    fr.addEventListener("load", (event) => {
      divResult.innerHTML = "Parsing...";
      setTimeout(() => {
        doParse(fr.result)
      }, 100);
    });
    
    // Asynchronously read the file
    fr.readAsText(fil);
  }
  
  /*
   * Public functions
   * ================
   */
  
  /*
   * Function called when the whole DOM is loaded.
   */
  function bootstrap() {
    // Attach button listeners
    const btnParse  = getElement("btnParse" );
    const btnUpload = getElement("btnUpload");
    
    btnParse.addEventListener("click", (event) => { handleParse(); });
    btnUpload.addEventListener("click", (event) => { handleUpload(); });
  }
  
  /*
   * Exports
   * =======
   */
  
  return {
    bootstrap: bootstrap
  };
  
}());

/*
 * Register bootstrap function to run when document DOM loaded.
 */
window.addEventListener("DOMContentLoaded",
  (event) => { window.ParseApp.bootstrap(); });
