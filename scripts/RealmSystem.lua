local Config = require("Config")

local RealmSystem = {}

function RealmSystem.AddExp(state, amount)
    state.exp = state.exp + amount
    RealmSystem.CheckRealmUp(state)
end

function RealmSystem.CheckRealmUp(state)
    while state.realmIndex < #Config.REALMS do
        local nextRealm = Config.REALMS[state.realmIndex + 1]
        if state.exp >= nextRealm.expRequired then
            state.realmIndex = state.realmIndex + 1
            local realm = Config.REALMS[state.realmIndex]
            state.maxHp = Config.PLAYER.BASE_HP + realm.hpBonus
            state.hp = math.min(state.hp + realm.hpBonus, state.maxHp)
            print(string.format("[Realm Up] 境界突破: %s! 气血上限+%d", realm.name, realm.hpBonus))
        else
            break
        end
    end
end

return RealmSystem
