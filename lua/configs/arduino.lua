local M = {}

local uv = vim.uv or vim.loop
local group = vim.api.nvim_create_augroup("arduino-clangd", { clear = true })

local notify_cache = {}
local compile_state = {}

local function notify_once(key, msg, level)
  if notify_cache[key] then
    return
  end

  notify_cache[key] = true

  vim.schedule(function()
    vim.notify(msg, level or vim.log.levels.WARN)
  end)
end

local function show_progress(root_dir, percent, message)
  -- NvChad already renders LSP progress in the statusline, so emit that
  -- event shape instead of managing a separate custom UI.
  compile_state[root_dir] = compile_state[root_dir] or { in_progress = false, pending_bufs = {} }
  compile_state[root_dir].progress_message = message
  compile_state[root_dir].progress_percent = percent
  local kind = percent >= 100 and "end" or (percent <= 10 and "begin" or "report")

  vim.api.nvim_exec_autocmds("LspProgress", {
    pattern = kind,
    modeline = false,
    data = {
      client_id = -1,
      params = {
        token = "ARDUINO_CLANGD_LOADING",
        value = {
          kind = kind,
          percentage = percent,
          title = "Arduino",
          message = message,
        },
      },
    },
  })

  if percent >= 100 then
    vim.defer_fn(function()
      local state = compile_state[root_dir]
      if not state or state.progress_message ~= message then
        return
      end
    end, 1200)
  end
end

local function executable_path(candidates)
  for _, candidate in ipairs(candidates) do
    if vim.fn.executable(candidate) == 1 then
      return vim.fn.exepath(candidate)
    end

    if uv.fs_stat(candidate) then
      return candidate
    end
  end
end

local function arduino_root(fname)
  local start = vim.fs.dirname(fname)
  local config_marker = vim.fs.find({ "sketch.yaml", "arduino-cli.yaml" }, {
    path = start,
    upward = true,
    type = "file",
    limit = 1,
  })[1]

  if config_marker then
    if vim.fs.basename(config_marker) == "arduino-cli.yaml" then
      -- Prefer the actual sketch directory when a repo-level cli config exists.
      local sketch_marker = vim.fs.find("sketch.yaml", {
        path = vim.fs.dirname(config_marker),
        upward = false,
        type = "file",
        limit = 1,
      })[1]

      if sketch_marker then
        return vim.fs.dirname(sketch_marker)
      end
    end

    return vim.fs.dirname(config_marker)
  end

  local ino_marker = vim.fs.find(function(name)
    return name:match "%.ino$" ~= nil
  end, {
    path = start,
    upward = true,
    type = "file",
    limit = 1,
  })[1]

  return ino_marker and vim.fs.dirname(ino_marker) or nil
end

local function cli_config_path(root_dir)
  if root_dir then
    local local_config = vim.fs.find("arduino-cli.yaml", {
      path = root_dir,
      upward = true,
      type = "file",
      limit = 1,
    })[1]

    if local_config then
      return local_config
    end
  end

  local global_config_paths = {
    vim.fs.normalize "~/.arduino15/arduino-cli.yaml",
    vim.fs.normalize "~/.arduinoIDE/arduino-cli.yaml",
  }

  for _, path in ipairs(global_config_paths) do
    if uv.fs_stat(path) then
      return path
    end
  end
end

local function read_default_fqbn(root_dir)
  if not root_dir then
    return vim.env.ARDUINO_FQBN
  end

  local sketch_config = vim.fs.joinpath(root_dir, "sketch.yaml")
  if uv.fs_stat(sketch_config) then
    for line in io.lines(sketch_config) do
      local fqbn = line:match([[^%s*default_fqbn:%s*['"]?([^'"]+)['"]?%s*$]])
      if fqbn and fqbn ~= "" then
        return vim.trim(fqbn)
      end
    end
  end

  return vim.env.ARDUINO_FQBN
end

local function arduino_cli_path(root_dir)
  local candidates = {}

  if root_dir then
    local project_root = vim.fs.find("arduino-cli.yaml", {
      path = root_dir,
      upward = true,
      type = "file",
      limit = 1,
    })[1]

    if project_root then
      -- Some projects vendor a CLI binary that matches their local toolchain.
      table.insert(candidates, vim.fs.joinpath(vim.fs.dirname(project_root), ".tools", "bin", "arduino-cli"))
    end
  end

  -- Fall back to the Arduino IDE bundled CLI before using the system PATH.
  table.insert(candidates, "/Applications/Arduino IDE.app/Contents/Resources/app/lib/backend/resources/arduino-cli")
  table.insert(candidates, "arduino-cli")

  return executable_path(candidates)
end

local function clangd_path()
  local mason_bin = vim.fs.joinpath(vim.fn.stdpath "data", "mason", "bin")
  return executable_path {
    vim.fs.joinpath(mason_bin, "clangd"),
    "clangd",
  }
end

local function build_dir(root_dir)
  return vim.fs.joinpath(root_dir, ".arduino-lsp")
end

local function sanitize_arguments(arguments)
  local sanitized = {}
  local target = nil
  local removed = {
    ["-mlongcalls"] = true,
    ["-fno-tree-switch-conversion"] = true,
    ["-fstrict-volatile-bitfields"] = true,
  }

  for i, arg in ipairs(arguments) do
    if i == 1 then
      target = arg:match(".*/(xtensa%-[%w%-]+%-elf)%-g%+%+$") or arg:match(".*/(riscv32%-[%w%-]+%-elf)%-g%+%+$")
      table.insert(sanitized, arg)
    elseif not removed[arg] then
      table.insert(sanitized, arg)
    end
  end

  if target then
    table.insert(sanitized, 2, "--target=" .. target)
  end

  return sanitized
end

local function remap_compile_commands(root_dir, out_dir)
  local compile_commands = vim.fs.joinpath(out_dir, "compile_commands.json")
  if not uv.fs_stat(compile_commands) then
    return
  end

  local lines = vim.fn.readfile(compile_commands)
  if #lines == 0 then
    return
  end

  local ok, data = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok or type(data) ~= "table" then
    return
  end

  local extra = {}
  local sketch_dir = vim.fs.joinpath(out_dir, "sketch")

  for _, entry in ipairs(data) do
    local file = entry.file
    if type(file) == "string" and vim.startswith(file, sketch_dir .. "/") then
      entry.arguments = sanitize_arguments(entry.arguments)

      local relative = file:sub(#(sketch_dir .. "/") + 1)
      local original = nil

      -- Arduino generates .ino.cpp for compilation, but clangd needs matching
      -- entries for the real files the user edits.
      if relative:match("%.ino%.cpp$") then
        original = vim.fs.joinpath(root_dir, relative:gsub("%.cpp$", ""))
      else
        original = vim.fs.joinpath(root_dir, relative)
      end

      if uv.fs_stat(original) then
        local mapped = vim.deepcopy(entry)
        mapped.file = original
        table.insert(extra, mapped)
      end
    end
  end

  if #extra == 0 then
    return
  end

  vim.list_extend(data, extra)
  vim.fn.writefile(vim.split(vim.json.encode(data), "\n", { plain = true }), compile_commands)
end

local function toolchain_config(root_dir)
  local cli = arduino_cli_path(root_dir)
  local clangd = clangd_path()
  local fqbn = read_default_fqbn(root_dir)
  local cli_config = cli_config_path(root_dir)

  local missing = {}

  if not cli then
    table.insert(missing, "`arduino-cli`")
  end

  if not clangd then
    table.insert(missing, "`clangd`")
  end

  if not fqbn then
    table.insert(missing, "`default_fqbn` in `sketch.yaml` or `$ARDUINO_FQBN`")
  end

  if #missing > 0 then
    notify_once(
      table.concat({ "arduino-clangd", root_dir, table.concat(missing, ",") }, "|"),
      "Arduino clangd not started. Missing " .. table.concat(missing, ", "),
      vim.log.levels.WARN
    )
    return nil
  end

  return {
    cli = cli,
    clangd = clangd,
    fqbn = fqbn,
    cli_config = cli_config,
    build_dir = build_dir(root_dir),
  }
end

local function find_client(root_dir)
  for _, client in ipairs(vim.lsp.get_clients { name = "arduino_clangd" }) do
    if client.config.root_dir == root_dir then
      return client
    end
  end
end

local function attach_pending_buffers(root_dir, client_id)
  local state = compile_state[root_dir]
  if not state then
    return
  end

  for bufnr in pairs(state.pending_bufs) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.lsp.buf_attach_client(bufnr, client_id)
    end
  end

  state.pending_bufs = {}
end

local function start_client(root_dir, toolchain)
  local existing_client = find_client(root_dir)
  if existing_client then
    attach_pending_buffers(root_dir, existing_client.id)
    return
  end

  local client_id = vim.lsp.start({
    name = "arduino_clangd",
    cmd = {
      toolchain.clangd,
      "--background-index",
      "--compile-commands-dir=" .. toolchain.build_dir,
    },
    cmd_cwd = root_dir,
    root_dir = root_dir,
    get_language_id = function(_, filetype)
      if filetype == "arduino" then
        return "cpp"
      end

      return filetype
    end,
  })

  if client_id then
    show_progress(root_dir, 100, "ready")
    attach_pending_buffers(root_dir, client_id)
  end
end

local function ensure_compilation_database_async(root_dir, bufnr)
  local toolchain = toolchain_config(root_dir)
  if not toolchain then
    return
  end

  local state = compile_state[root_dir]
  if not state then
    state = { in_progress = false, pending_bufs = {} }
    compile_state[root_dir] = state
  end

  state.pending_bufs[bufnr] = true

  if state.progress_message then
    show_progress(root_dir, state.progress_percent or 25, state.progress_message:gsub("^Arduino%s+%[[^%]]+%]%s+%d+%%%s+", ""))
  end

  if state.in_progress then
    show_progress(root_dir, 25, "loading compile database")
    return
  end

  -- Generate compile_commands.json off the main thread to avoid freezing on
  -- sketch open. clangd is started only after this completes successfully.
  state.in_progress = true
  vim.fn.mkdir(toolchain.build_dir, "p")
  show_progress(root_dir, 10, "preparing")

  local cmd = { toolchain.cli }
  if toolchain.cli_config then
    vim.list_extend(cmd, { "--config-file", toolchain.cli_config })
  end

  vim.list_extend(cmd, {
    "compile",
    "--fqbn",
    toolchain.fqbn,
    "--only-compilation-database",
    "--build-path",
    toolchain.build_dir,
    "--format",
    "json",
    root_dir,
  })

  show_progress(root_dir, 40, "generating compile database")
  vim.system(cmd, {
    cwd = toolchain.cli_config and vim.fs.dirname(toolchain.cli_config) or root_dir,
    text = true,
  }, function(result)
    vim.schedule(function()
      local current_state = compile_state[root_dir]
      if not current_state then
        return
      end

      current_state.in_progress = false

      if result.code ~= 0 then
        local summary = result.stdout ~= "" and result.stdout or result.stderr
        summary = vim.trim(summary)
        show_progress(root_dir, 100, "failed")

        notify_once(
          table.concat({ "arduino-clangd-compile", root_dir, tostring(result.code) }, "|"),
          "Arduino compile database generation failed: " .. summary,
          vim.log.levels.ERROR
        )
        return
      end

      show_progress(root_dir, 70, "mapping sketch sources")
      remap_compile_commands(root_dir, toolchain.build_dir)
      show_progress(root_dir, 85, "starting clangd")
      start_client(root_dir, toolchain)
    end)
  end)
end

function M.setup()
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = { "arduino", "c", "cpp", "objc", "objcpp" },
    callback = function(args)
      local fname = vim.api.nvim_buf_get_name(args.buf)
      local root_dir = arduino_root(fname)

      if not root_dir then
        return
      end

      local existing_client = find_client(root_dir)
      if existing_client then
        vim.lsp.buf_attach_client(args.buf, existing_client.id)
        return
      end

      -- Only the sketch entry file should trigger database generation. Other
      -- files attach once the Arduino clangd client already exists.
      if vim.bo[args.buf].filetype ~= "arduino" then
        return
      end

      ensure_compilation_database_async(root_dir, args.buf)
    end,
  })
end

return M
