local M = {}

M.config = {
    window_style = "split", -- Options: "split", "vsplit", "float"
}

M.api = require("fossil.api")
M.status = require("fossil.ui.status")
M.command = require("fossil.command")

--- Initialize the plugin (optional config)
--- @param opts table|nil User configuration
function M.setup(opts)
    opts = opts or {}
    M.config = vim.tbl_deep_extend("force", M.config, opts)
end

return M
