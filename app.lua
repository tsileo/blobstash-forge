local template = require('template')
local json = require('json')
local router = require('router').new()
local gs = require('gitserver')
local ft = require('filetree')

-- TODO
-- - contributors page/API
-- - source code tar download for the tags/releaes
-- - git hooks + mirror link display (i.e. GH link under the clone)
-- - screenshot sections? handling?
-- - blobstash_forge.json parsing + use extra info + extra_release_header for listing my GPG key
-- - actual public perms for public clone
-- - check for data/blob exfiltration issue
-- - reverse the releases order
-- - vendor CSS/JS
-- - config in blobstash (blobstash.config => AppConfig.config)
-- - link in footer

-- GitServer namespace
local ns = "gh"

-- List all the git repositories on the homepage
router:get('/', function(params)
  local data = {}
  for _, repo in ipairs(gs.repositories(ns)) do
    table.insert(data, {ns = ns, repo = repo })
  end
  app.response:write(template.render('git_repo.html', 'layout.html', {
    blobstash = blobstash,
    data = data,
  }))
end)

-- Display a single git commit
router:get('/:repo/commit/:hash', function(params)
  local repo = gs.repo(ns, params.repo)
  local commit = repo:get_commit(params.hash)
  app.response:write(template.render('git_repo.html', 'layout.html', {
    blobstash = blobstash,
    params = params,
    commit = commit,
  }))
end)

-- Display the git commit logs
router:get('/:repo/log', function(params)
  local repo = gs.repo(ns, params.repo)
  local log = repo:log()
  app.response:write(template.render('git_repo.html', 'layout.html', {
    blobstash = blobstash,
    params = params,
    log = log,
  }))
end)

-- Display/download the contents of a file
router:get('/:repo/file/:hash/:name/plain', function(params)
  local repo = gs.repo(ns, params.repo)
  local file = repo:get_file(params.hash)
  local dl = false
  if app.request:args():get("dl") == "1" then
    dl = true
    app.response:headers():set("Content-Disposition", "attachment; filename=" .. params.name)
  end

  if not file.is_binary or dl then
    app.response:write(file.contents)
    return
  end
  return '[binary file, please donwload it]'
end)

-- Display a git tree (file)
router:get('/:repo/file/:hash/:name', function(params)
  local repo = gs.repo(ns, params.repo)
  local file = repo:get_file(params.hash)
  app.response:write(template.render('git_repo.html', 'layout.html', {
    blobstash = blobstash,
    params = params,
    file = file,
  }))
end)

-- Display a git tree (dir)
router:get('/:repo/tree/:hash', function(params)
  -- TODO(tsileo): find a way to keep a breadcrumb (of the path in the tree), in the URL, JSON encoded
  local repo = gs.repo(ns, params.repo)
  local tree = repo:get_tree(params.hash)
  app.response:write(template.render('git_repo.html', 'layout.html', {
    blobstash = blobstash,
    params = params,
    tree = tree,
  }))
end)

-- Display the source code/master tree
router:get('/:repo/tree', function(params)
  local repo = gs.repo(ns, params.repo)
  local tree = repo:tree()
  app.response:write(template.render('git_repo.html', 'layout.html', {
    blobstash = blobstash,
    params = params,
    tree = tree,
  }))
end)

-- Repository refs (branches and tags)
router:get('/:repo/refs', function(params)
  local repo = gs.repo(ns, params.repo)
  app.response:write(template.render('git_repo.html', 'layout.html', {
    blobstash = blobstash,
    params = params,
    refs = repo:refs(),
  }))
end)

-- Repository refs (branches and tags)
router:get('/:repo/releases', function(params)
  local repo = gs.repo(ns, params.repo)
  local refs = repo:refs()
  local releases = {}
  for _, t in ipairs(refs.tags) do
    artifacts = ft.fs_by_name('git-artifact_' .. ns .. '_' .. params.repo .. '_' .. t.ref_short_name)
    table.insert(releases, { tag = t, artifacts = artifacts })
  end
  app.response:write(template.render('git_repo.html', 'layout.html', {
    blobstash = blobstash,
    params = params,
    releases = releases,
  }))
end)

-- Repository summary homepage
router:get('/:repo', function(params)
  -- Init the repo
  local repo = gs.repo(ns, params.repo)
  -- Fetch the refs (branches/tags)
  local refs = repo:refs()

  -- Check if there's at least a release
  local latest_release = {}
  local artifacts = nil
  if #refs.tags > 0 then
    latest_release = {
      short_hash = refs.tags[#refs.tags].commit_short_hash,
      hash = refs.tags[#refs.tags].commit_hash,
      date = refs.tags[#refs.tags].commit_time_ago,
      name = refs.tags[#refs.tags].ref_short_name,
    }
    artifacts = ft.fs_by_name('git-artifact_' .. ns .. '_' .. params.repo .. '_' .. latest_release.name)
  end

  app.response:write(template.render('git_repo.html', 'layout.html', {
    blobstash = blobstash,
    params = params,
    ns = ns,
    latest_release = latest_release,
    host = app.request:host(),
    scheme = app.request:scheme(),
    summary = repo:summary(),
    artifacts = artifacts,
  }))
end)

router:run()
