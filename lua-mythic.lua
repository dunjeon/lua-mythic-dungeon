local mythic = {}

-- mythicFlag
-- 0 = attempt to enter in a dungeon
-- 1 = is on dungeon
-- 2 = as start a timer

mythic.Affix = {
    -- Level
    [1] = {
        -- Affix List
        100003, -- + 10% Damage
    }
}

function mythic.getMythicLevel(event, player)
    local mythicLevel = CharDBQuery('SELECT level FROM R1_Eluna.mythic_dungeon WHERE guid = '..player:GetGUIDLow())

    if not mythicLevel then
        CharDBExecute('INSERT INTO R1_Eluna.mythic_dungeon (guid, level) VALUES ('..player:GetGUIDLow()..', 1);')
        player:SetData('mythicLevel', 1)
    else
        player:SetData('mythicLevel', mythicLevel:GetUInt32(0))
    end
end
RegisterPlayerEvent(3, mythic.getMythicLevel)

function mythic.setAllAffix(player, creature)
    for key, spellId in pairs(mythic.Affix[player:GetData('mythicLevel')]) do
        local hasAura = creature:HasAura(spellId)
        if not hasAura then
            creature:CastSpell( creature, spellId, true )
        end
    end
end

function mythic.buffLoop(event, delay, repeats, player)
    for positionInTable , creature in pairs(player:GetCreaturesInRange( 100 )) do
        if creature then
            mythic.setAllAffix(player, creature)
        end
    end
end

function mythic.onEnterDungeon(event, player)
    local map = player:GetMap()
    local isDungeon = map:IsDungeon()

    if isDungeon then

        if player:GetData('mythicFlag') == 0 then
            local group = player:GetGroup()

            tempPlayer = player
            if group and not mythic[group:GetGUID()] then
                player = GetPlayerByGUID(group:GetLeaderGUID())
            end
            tempPlayer:SendAreaTriggerMessage('You are in Mythic +'..player:GetData('mythicLevel')..' dungeon.')

            player = tempPlayer
            tempPlayer = nil

            player:RemoveEvents()
            player:RegisterEvent(mythic.buffLoop, {1000, 1000}, 0)
            player:SetData('mythicFlag', 1)

        end
    else
        if player:GetData('mythicFlag') then
            player:SetData('mythicFlag', nil)
            local group = player:GetGroup()

            if mythic[group:GetGUID()] then
                mythic.delGroupInfo(group)
            end
        end
    end
end
RegisterPlayerEvent(28, mythic.onEnterDungeon)

function mythic.onKillCreature(event, player, creature)
    local group = player:GetGroup()
    if group then
        player = GetPlayerByGUID(group:GetLeaderGUID())
    end

    if player:GetData('mythicFlag') == 1 then
        player:SetData('mythicFlag', 2)
        player:SetData('mythicStart', os.time())
    end
end
RegisterPlayerEvent(7, mythic.onKillCreature)

function mythic.onGroupLeaderChange(event, group, newLeaderGuid, oldLeaderGuid)
    GetPlayerByGUID(newLeaderGuid):SetData('mythicStart', GetPlayerByGUID(oldLeaderGuid):GetData('mythicStart'))
    GetPlayerByGUID(newLeaderGuid):SetData('mythicLevel', GetPlayerByGUID(oldLeaderGuid):GetData('mythicLevel'))

    local mythicLevel = GetPlayerByGUID(newLeaderGuid):GetData('mythicLevel')
    for key, player in pairs(group:GetMembers()) do
        player:SendAreaTriggerMessage('You are in Mythic +'..mythicLevel..' level group.')
    end
end
RegisterGroupEvent(4, mythic.onGroupLeaderChange)

function mythic.onNewMember(event, group, guid)
    local mythicLevel = GetPlayerByGUID(group:GetLeaderGUID()):GetData('mythicLevel')
    GetPlayerByGUID(guid):SendAreaTriggerMessage('You are in Mythic +'..mythicLevel..' level group.')

    if not GetPlayerByGUID(guid):GetData('mythicFlag') then
        GetPlayerByGUID(guid):SetData('mythicFlag', 0)
    end
end
RegisterGroupEvent(1, mythic.onNewMember)