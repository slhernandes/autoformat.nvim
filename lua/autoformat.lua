local M = {}

local default_override = {
  lua_ls = {
    force = true,
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

local function mark_wrap(f)
  return function()
    local cur_line = vim.api.nvim_exec2("echo line(\".\")", {output = true})
                         .output or "1"
    local cur_col = vim.api.nvim_exec2("echo col(\".\")", {output = true})
                        .output or "0"
    f()
    local lc = vim.api.nvim_buf_line_count(0)
    local cur_line_num = tonumber(cur_line) or 1
    if lc >= cur_line_num then
      vim.cmd("call setcursorcharpos(" .. cur_line .. ", " .. cur_col .. ")")
    else
      vim.cmd("norm G")
    end
  end
end

local function add_keymap(keymaps, key, func)
  local keymap = keymaps[key] or default_keymaps[key]
  if keymap == "" then keymap = default_keymaps[key] end
  vim.keymap.set({"n", "v"}, keymap, mark_wrap(func))
end

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

local function lsp_autoformat(args)
  local client = vim.lsp.get_clients({bufnr = args.buf})[1]
  if client == nil then return end
  local lsp_autoformat_capability = not client:supports_method(
                                        'textDocument/willSaveWaitUntil') and
                                        client:supports_method(
                                            'textDocument/formatting')
  local ft_info = M.override[client.name] or {force = false}
  local autoformat = lsp_autoformat_capability and
                         (not ft_info.force or
                             vim.fs.root(0, ft_info.marker or {}) ~= nil)
  if autoformat then
    add_keymap(M.keymaps, "format", vim.lsp.buf.format)

    if (tonumber(vim.fn.system({'wc', '-l', vim.fn.expand('%')}):match('%d+')) or
        0) <= 1000 then
      vim.api.nvim_create_autocmd('BufWritePre', {
        group = vim.api.nvim_create_augroup('lspformatter', {clear = false}),
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

local function non_lsp_autoformat(args)
  if vim.bo.filetype == "" then return end
  for _, v in pairs(M.override) do
    local override = v.force or vim.fs.root(0, v.marker or {}) == nil
    if check_ft(vim.bo.filetype, v.filetype) and override then
      add_keymap(M.keymaps, "format", v.format)
      local autoformat = (tonumber(vim.fn.system({
        'wc', '-l', vim.fn.expand('%')
      }):match('%d+')) or 0) <= 1000
      if autoformat then
        vim.api.nvim_create_autocmd('BufWritePre', {
          group = vim.api
              .nvim_create_augroup(vim.bo.filetype .. 'formatter', {}),
          buffer = args.buf,
          callback = function()
            mark_wrap(v.format)()
            if vim.v.shell_error > 0 then
              print("Error occured, undo.")
              vim.cmd [[undo]]
            end
          end
        })
      end
    end
  end
end

local function init_autocmds()
  vim.api.nvim_create_autocmd("BufEnter", {
    desc = "Autoformatting for buffer without LSP",
    group = vim.api.nvim_create_augroup('autoformatter', {clear = false}),
    callback = function(args) non_lsp_autoformat(args) end
  })

  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('autoformatter', {clear = false}),
    callback = function(args)
      lsp_autoformat(args)
      M.lsp_data = args.data
    end
  })
end

local function delete_autocmds()
  vim.api.nvim_del_augroup_by_name("autoformatter")
  local ag_non_lsp = vim.bo.filetype .. 'formatter'
  local ag_lsp = 'lspformatter'
  local augroups = vim.api.nvim_exec2("augroup", {output = true}).output or ""
  if augroups:gmatch(ag_non_lsp)() ~= nil then
    vim.api.nvim_del_augroup_by_name(vim.bo.filetype .. 'formatter')
  end
  if augroups:gmatch(ag_lsp)() ~= nil then
    vim.api.nvim_del_augroup_by_name('lspformatter')
  end
end

function M.setup(opts)
  M.override = opts.override or default_override
  M.keymaps = opts.keymaps or default_keymaps
  M.enabled = true
  init_autocmds()
  vim.api.nvim_create_user_command("AutoformatToggle", function()
    if M.enabled then
      delete_autocmds()
      M.enabled = false
    else
      lsp_autoformat({buf = 0, data = M.lsp_data})
      non_lsp_autoformat({buf = 0})
      M.enabled = true
    end
  end, {})
end

return M
