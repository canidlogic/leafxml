"use strict";

/*
 * leafxml_xform.js
 * ================
 * 
 * JavaScript module backing leafxml_xform.html
 */

/*
 * Define XformApp namespace
 */
window.XformApp = (function() {
  
  /*
   * Local functions
   * ===============
   */
  
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
   * Perform a transform operation.
   * 
   * The styles are "esc0" "esc1" "esc2" "e64" "d64" which match the
   * select option values on the HTML control.
   * 
   * Parameters:
   * 
   *   input - the string to transform
   * 
   *   style - the specific transform
   * 
   * Return:
   * 
   *   the transformed text
   */
  function doTransform(input, style) {
    
    // Check parameters
    if (typeof input !== "string") {
      throw new Error();
    }
    if (typeof style !== "string") {
      throw new Error();
    }
    
    // Handle specific transform
    let result;
    if (style === "esc0") {
      // Content-text escaping
      result = LeafXML.escapeText(input, 0);
      
    } else if (style === "esc1") {
      // Single-quoted escaping
      result = LeafXML.escapeText(input, 1);
      
    } else if (style === "esc2") {
      // Double-quoted escaping
      result = LeafXML.escapeText(input, 2);
      
    } else if (style === "e64") {
      // Encode to base64
      result = LeafXML.toText64(input);
      
    } else if (style === "d64") {
      // Decode from base64
      result = LeafXML.fromText64(input);
      
    } else {
      throw new Error();
    }
    
    // Return result
    return result;
  }
  
  /*
   * Function called when a request is received to perform the transform
   * operation.
   */
  function handleTransform() {
    // Get controls
    const txtInput     = getElement("txtInput");
    const txtOutput    = getElement("txtOutput");
    const selTransform = getElement("selTransform");
    
    // Perform operation
    try {
      txtOutput.value = doTransform(txtInput.value, selTransform.value);
    } catch (ex) {
      txtOutput.value = "[Operation failed!]";
    }
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
    const btnUpload = getElement("btnTransform");
    btnUpload.addEventListener("click", (event) => {
                                handleTransform(); });
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
  (event) => { window.XformApp.bootstrap(); });
