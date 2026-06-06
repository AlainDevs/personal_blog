local default_routes = {
  { path = '/', weight = 50 },
  { path = '/blog/building-a-calmer-personal-blog', weight = 25 },
  { path = '/blog/a-tiny-publishing-checklist', weight = 10 },
  { path = '/output.css', weight = 10 },
  { path = '/public/app.js', weight = 5 },
}

local routes = {}
local total_weight = 0

local function trim(value)
  return (value:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function normalize_path(path)
  if path == '' then
    return '/'
  end

  if path:sub(1, 1) == '/' then
    return path
  end

  return '/' .. path
end

local function add_route(path, weight)
  local normalized_path = normalize_path(trim(path))
  local normalized_weight = tonumber(weight) or 1

  if normalized_weight < 1 then
    normalized_weight = 1
  end

  routes[#routes + 1] = {
    path = normalized_path,
    weight = normalized_weight,
  }
  total_weight = total_weight + normalized_weight
end

local function configure_routes()
  local configured_routes = os.getenv('WRK_PATHS') or ''

  if configured_routes ~= '' then
    for item in configured_routes:gmatch('[^,]+') do
      local path, weight = item:match('^([^=]+)=?(%d*)$')
      if path ~= nil then
        add_route(path, weight)
      end
    end
  end

  if #routes == 0 then
    for _, route in ipairs(default_routes) do
      add_route(route.path, route.weight)
    end
  end
end

local function choose_route()
  local selected_weight = math.random(total_weight)
  local cumulative_weight = 0

  for _, route in ipairs(routes) do
    cumulative_weight = cumulative_weight + route.weight
    if selected_weight <= cumulative_weight then
      return route
    end
  end

  return routes[#routes]
end

configure_routes()

function init(args)
  local seed = tonumber(os.getenv('WRK_RANDOM_SEED')) or os.time()
  local thread_salt = tonumber(tostring({}):match('0x(%x+)'), 16) or 0
  math.randomseed(seed + thread_salt)
end

function request()
  local route = choose_route()
  local headers = {
    ['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    ['User-Agent'] = 'personal-blog-wrk/1.0',
  }

  return wrk.format('GET', route.path, headers)
end

function done(summary, latency, requests)
  io.write('\nConfigured request mix:\n')
  for _, route in ipairs(routes) do
    local percentage = (route.weight / total_weight) * 100
    io.write(string.format('  %5.1f%%  %s\n', percentage, route.path))
  end
end
