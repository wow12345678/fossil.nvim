local M = {}

M.api = require("fossil.api")
M.status = require("fossil.ui.status")
M.command = require("fossil.command")

--- Initialize the plugin (optional config)
function M.setup(opts)
    -- Merge opts with defaults if necessary
end

return M
