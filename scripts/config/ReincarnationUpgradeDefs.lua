-- config/ReincarnationUpgradeDefs.lua
-- 七项局外轮回强化，均为独立的永久数值成长。

return {
    { id = "attack", name = "全武器伤害", desc = "全武器伤害 +3%", stat = "weaponDamagePct", valuePerLevel = 0.03, maxLevel = 10 },
    { id = "critChance", name = "暴击率", desc = "暴击率 +1%", stat = "critChance", valuePerLevel = 0.01, maxLevel = 10 },
    { id = "maxHp", name = "最大气血", desc = "最大气血 +4%", stat = "maxHpPct", valuePerLevel = 0.04, maxLevel = 10 },
    { id = "damageReduction", name = "受击减伤", desc = "受击减伤 +1.5%", stat = "damageReduction", valuePerLevel = 0.015, maxLevel = 10 },
    { id = "expGain", name = "修为获取", desc = "修为获取 +3%", stat = "expGainPct", valuePerLevel = 0.03, maxLevel = 10 },
    { id = "coinDropChance", name = "金币掉落", desc = "金币掉落概率 +2%", stat = "coinDropChance", valuePerLevel = 0.02, maxLevel = 10 },
    { id = "rewardQuality", name = "奖励品质提升", desc = "场上奖励额外升一品质概率 +1%", stat = "rewardQualityChance", valuePerLevel = 0.01, maxLevel = 10 },
}
