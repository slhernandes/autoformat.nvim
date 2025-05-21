# Autoformat.nvim

A small plugin that can autoformat current file on save.

# Install
## [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
return {
  "slhernandes/autoformat.nvim",
  config = function() require("autoformat").setup({}) end
}
```

# Default options
```lua
opts = {
    override = {
        lua_ls = {
            -- true: use this option everytime, false: use vim.lsp.buf.format if available
            force = false,
            filetype = "lua",
            -- marker for the vim.lsp.buf.format
            marker = {".stylua.toml"},
            -- command to execute if vim.lsp.buf.format autoformat is disabled
            format = function()
                vim.cmd([[silent exec "%!lua-format --indent-width=2"]])
                end
        },
        ocaml_lsp = {
            force = false,
            filetype = "ocaml",
            marker = {".ocamlformat"},
            format = function()
                local format_cmd = "%!ocamlformat -"
                format_cmd = format_cmd .. " --enable-outside-detected-project"
                format_cmd = format_cmd .. " -p janestreet"
                format_cmd = format_cmd .. " --if-then-else=fit-or-vertical"
                format_cmd = format_cmd .. " -m 80"
                format_cmd = format_cmd .. " --impl"
                vim.cmd(string.format([[
                            silent exec "%s"
                ]], format_cmd))
                end
        },
        bashls = {
            force = true,
            filetype = {"bash", "sh", "zsh"},
            format = function() vim.cmd([[silent exec "%!beautysh -i 2 -"]]) end
        }
    },
    keymaps = {format = "<leader>fc"}, -- manual format keybind
    enabled = true, -- enabled/disabled on default
    maxloc = 1000, -- max loc to autoformat
}
```
