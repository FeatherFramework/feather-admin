-- Server-only producer settings. Match feather-audit's Config.SourceInstance.
Config.audit = { sourceInstance = 'default', batchSize = 25, pollMilliseconds = 5000 }
assert(type(Config.audit.sourceInstance) == 'string' and #Config.audit.sourceInstance <= 128
    and Config.audit.sourceInstance:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$'), 'Invalid Admin audit sourceInstance')
assert(type(Config.audit.batchSize) == 'number' and Config.audit.batchSize % 1 == 0
    and Config.audit.batchSize >= 1 and Config.audit.batchSize <= 100, 'Invalid Admin audit batchSize')
assert(type(Config.audit.pollMilliseconds) == 'number' and Config.audit.pollMilliseconds >= 1000
    and Config.audit.pollMilliseconds <= 60000, 'Invalid Admin audit pollMilliseconds')
