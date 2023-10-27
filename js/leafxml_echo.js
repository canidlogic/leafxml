"use strict";

/*
 * leafxml_echo.js
 * ===============
 * 
 * JavaScript module backing leafxml_echo.html
 */

/*
 * Define EchoApp namespace
 */
window.EchoApp = (function() {
  
  /*
   * Local data
   * ==========
   */
  
  /*
   * The object URL to the echoed data, or null if nothing loaded.
   */
  let m_url = null;
  
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
    
    const btnUpload = getElement("btnUpload");
    
    if (flag) {
      btnUpload.disabled = false;
    } else {
      btnUpload.disabled = true;
    }
  }
  
  /*
   * Perform an echo operation given a string.
   * 
   * Parameters:
   * 
   *   input - the string to echo
   */
  function doEcho(input) {
    
    // Get controls
    const divResult = getElement("divResult");
    
    // Re-enable buttons
    setButtonEnable(true);
    
    // Get encoded UTF-8 string as buffer and wrap in blob
    const ubuf = LeafXML.writeFullText(input);
    const bl = new Blob([ubuf], { "type": "text/plain" });
    
    // If an object URL currently loaded, release it
    if (m_url !== null) {
      URL.revokeObjectURL(m_url);
      m_url = null;
    }
    
    // Create an object URL for the echoed text
    m_url = URL.createObjectURL(bl);
    
    // Write a link to results
    divResult.innerHTML = "<a href=\"" + m_url +
                          "\" target=\"_blank\"/>Download result</a>";
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
      divResult.innerHTML = "Working...";
      let full_text = "";
      try {
        full_text = LeafXML.readFullText(fr.result);
      } catch (ex) {
        divResult.innerHTML = "<b>Error:</b> Text decoding failed!";
        setButtonEnable(true);
        return;
      }
      setTimeout(() => {
        doEcho(full_text);
      }, 100);
    });
    
    // Asynchronously read the file
    fr.readAsArrayBuffer(fil);
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
    const btnUpload = getElement("btnUpload");
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
  (event) => { window.EchoApp.bootstrap(); });
