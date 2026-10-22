-- Runtime tests for the large-area queue. process_queue is exposed through the
-- FUnit seam because it normally runs on a 60-tick timer.
local runner = require("__funit__.test_runner")
local helpers = require("__tile-upgrade-planner-muluna-funit__.tests.helpers")

local function box(x1, y1, x2, y2)
  return {
    left_top = { x = x1, y = y1 },
    right_bottom = { x = x2, y = y2 },
  }
end

local function queue()
  return helpers.storage().tasks
end

runner.test("enqueue_area splits large selections into 1024-tile blocks", function()
  helpers.reset_queue()
  local surface = helpers.surface()

  helpers.funit("enqueue_area", 1, surface.index, box(0, 0, 2047, 2047), {
    ["stone-path"] = "concrete",
  })

  local tasks = queue()
  runner.assert(tasks.front == 1, "queue front should remain 1")
  runner.assert(tasks.back == 5, "expected four queued blocks, got " .. tostring(tasks.back - 1))
  runner.assert(tasks[1].area.left_top.x == 0 and tasks[1].area.left_top.y == 0, "first block origin is wrong")
  runner.assert(
    tasks[1].area.right_bottom.x == 1024 and tasks[1].area.right_bottom.y == 1024,
    "first block bounds are wrong"
  )
  runner.assert(
    tasks[4].area.left_top.x == 1024 and tasks[4].area.left_top.y == 1024,
    "last block origin is wrong"
  )
  runner.assert(
    tasks[4].area.right_bottom.x == 2047 and tasks[4].area.right_bottom.y == 2047,
    "last block bounds are wrong"
  )
  runner.assert(tasks[1].filters["stone-path"] == "concrete", "block did not carry the filters")
  helpers.reset_queue()
end)

runner.test("process_queue applies a queued upgrade and resets when empty", function()
  local surface = helpers.surface()
  helpers.reset_queue()
  helpers.set_tiles(surface, "stone-path", 20, 20, 20, 20)

  helpers.funit("enqueue_area", 1, surface.index, box(19, 19, 22, 22), {
    ["stone-path"] = "concrete",
  }, helpers.force().name)

  helpers.funit("process_queue")

  local ghosts = helpers.tile_ghosts(surface)
  runner.assert(ghosts["20,20"] == "concrete", "queued upgrade was not applied")
  local tasks = queue()
  runner.assert(tasks.front == 1 and tasks.back == 1, "queue did not reset after its last block")
  runner.assert(tasks[1] == nil, "queue still contains a task after processing")
end)

runner.test("process_queue with an empty queue is a no-op", function()
  helpers.reset_queue()
  helpers.funit("process_queue")
  local tasks = queue()
  runner.assert(tasks.front == 1 and tasks.back == 1, "empty queue was modified")
end)

runner.test("process_queue handles clear tasks", function()
  local surface = helpers.surface()
  helpers.reset_queue()
  helpers.create_tile_ghost(surface, "concrete", { x = 24, y = 24 })
  runner.assert(helpers.tile_ghosts(surface)["24,24"] == "concrete", "setup ghost is missing")

  helpers.funit("enqueue_clear", surface.index, box(23, 23, 26, 26), helpers.force().name)
  helpers.funit("process_queue")

  runner.assert(helpers.tile_ghosts(surface)["24,24"] == nil, "queued clear task did not destroy the ghost")
  local tasks = queue()
  runner.assert(tasks.front == 1 and tasks.back == 1, "queue did not reset after the clear task")
end)

runner.test("process_queue skips tasks whose force no longer exists", function()
  local surface = helpers.surface()
  helpers.reset_queue()
  helpers.funit("enqueue_clear", surface.index, box(0, 0, 1, 1), "funit-missing-force")
  helpers.funit("process_queue")

  local tasks = queue()
  runner.assert(tasks.front == 1 and tasks.back == 1, "stale task was not dropped from the queue")
end)
