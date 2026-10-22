-- Suites are loaded in order. Data fixture results are registered first so a
-- load-time data regression is reported before longer runtime tests run.
return {
  "__tile-upgrade-planner-muluna-funit__.tests.suites.data_fixtures",
  "__tile-upgrade-planner-muluna-funit__.tests.suites.smoke",
  "__tile-upgrade-planner-muluna-funit__.tests.suites.filters",
  "__tile-upgrade-planner-muluna-funit__.tests.suites.upgrade",
  "__tile-upgrade-planner-muluna-funit__.tests.suites.queue",
}
