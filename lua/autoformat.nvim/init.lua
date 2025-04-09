local M = {}

local function mark_wrap(f)
  return function()
    local cur_line = vim.api.nvim_exec2("echo line(\".\")", {output = true})
                         .output or "1"
    local cur_col = vim.api.nvim_exec2("echo col(\".\")", {output = true})
                        .output or "0"
    f()
    if vim.v.shell_error > 0 then
      print("Error occured, undo.")
      vim.cmd [[undo]]
    end
    local lc = vim.api.nvim_buf_line_count(0)
    local cur_line_num = tonumber(cur_line) or 1
    if lc >= cur_line_num then
      vim.cmd("call setcursorcharpos(" .. cur_line .. ", " .. cur_col .. ")")
    else
      vim.cmd("norm G")
    end
  end
end

function M.setup(opts)
  local default_override = {
    lua_ls = {
      force = false,
      filetype = "lua",
      marker = {".stylua.toml"},
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
  }

  local default_keymaps = {format = "<leader>fc"}

  M.override = opts.override or default_override
  M.keymaps.format = opts.keymaps.format or default_keymaps.format

  vim.api.nvim_create_autocmd("BufEnter", {
    desc = "Autoformatting for buffer without LSP",
    group = vim.api.nvim_create_augroup('autoformatter', {clear = false}),
    callback = function(args)
      local function check_ft(in_ft, data)
        local ret = false
        if type(data) == "table" then
          for _, i in ipairs(data) do
            if in_ft == i then
              ret = true
              break
            end
          end
        elseif type(data) == "string" then
          ret = in_ft == data
        else
          return false
        end
        return ret
      end
      for _, v in pairs(M.override) do
        if check_ft(vim.bo.filetype, v.filetype) then
          if v.force or vim.fs.root(0, v.marker or {}) == nil then
            if M.keymaps.format ~= "" then
              vim.keymap.set({"n", "v"}, M.keymaps.format, v.format)
            end
            if (tonumber(vim.fn.system({'wc', '-l', vim.fn.expand('%')}):match(
                             '%d+')) or 0) <= 1000 then
              vim.api.nvim_create_autocmd('BufWritePre', {
                group = vim.api.nvim_create_augroup(vim.bo.filetype ..
                                                        'formatter', {}),
                buffer = args.buf,
                callback = function() mark_wrap(v.format)() end
              })
            end
          end
        end
      end
    end
  })

  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('autoformatter', {clear = false}),
    callback = function(args)
      local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
      if not client:supports_method('textDocument/willSaveWaitUntil') and
          client:supports_method('textDocument/formatting') then
        local is_enabled = M.override[client.name] or {force = false}
        if not is_enabled.force then
          if M.keymaps.format ~= "" then
            vim.keymap.set({"n", "v"}, "<leader>fc",
                           mark_wrap(function() vim.lsp.buf.format() end))
          end

          if (tonumber(vim.fn.system({'wc', '-l', vim.fn.expand('%')}):match(
                           '%d+')) or 0) <= 1000 then
            vim.api.nvim_create_autocmd('BufWritePre', {
              group = vim.api.nvim_create_augroup('my.lsp', {clear = false}),
              buffer = args.buf,
              callback = function()
                vim.lsp.buf.format({
                  bufnr = args.buf,
                  id = client.id,
                  timeout_ms = 1000
                })
              end
            })
          end
        end
      end
    end
  })

end
