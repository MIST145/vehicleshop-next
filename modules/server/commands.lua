-- modules/server/commands.lua
lib.addCommand('createvehshop', {
    help = 'Create a new vehicle shop',
    restricted = 'group.admin',
}, function(source)
    TriggerClientEvent('vehicleshops:createNew', source)
end)