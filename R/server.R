#' Start MCP Server with Direct + btw Tools
#' 
#' Starts an MCP server combining btw (passive observation) and direct (active execution) tools.
#' This function is meant to be called from Claude Desktop configuration.
#' 
#' @param type Server type: "stdio" (default) or "http"
#' @param host Host for HTTP server (default: "127.0.0.1")
#' @param port Port for HTTP server (default: 8080)
#' @export
#' @examples
#' \dontrun{
#' # Start stdio server (for Claude Desktop)
#' start_mcp_server()
#' 
#' # Start HTTP server (for custom integrations)
#' start_mcp_server(type = "http", port = 8080)
#' }
start_mcp_server <- function(type = "stdio", host = "127.0.0.1", port = 8080) {
  
  if (!requireNamespace("mcptools", quietly = TRUE)) {
    stop("mcptools package is required. Install with: install.packages('mcptools')")
  }
  
  if (!requireNamespace("btw", quietly = TRUE)) {
    stop("btw package is required. Install with: install.packages('btw')")
  }
  
  # Get btw tools (passive observation)
  btw_tools <- btw::btw_tools()
  
  # Get direct tools (active execution)
  direct_tools <- direct:::mcp_tools
  
  # Combine both tool sets
  all_tools <- c(btw_tools, direct_tools)
  
  # Note: No output to stdout in stdio mode - would break JSON protocol
  # Server info is logged via mcptools internal logging
  
  # Start server with combined tools
  mcptools::mcp_server(
    tools = all_tools,
    type = type,
    host = host,
    port = port,
    session_tools = TRUE  # Include list_r_sessions, select_r_session
  )
}
