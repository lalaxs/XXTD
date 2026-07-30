-- config/RogueRewardDefs.lua
-- 本轮肉鸽奖励：15 把武器的解锁与专属强化，以及可重复选择的通用数值。

local WEAPON_ICONS = {
    qingfeng_sword = "image/weapon/weapon  (1).png",
    chiyan_spear = "image/weapon/weapon  (2).png",
    qingyu_fan = "image/weapon/weapon  (3).png",
    ziqi_gourd = "image/weapon/weapon  (4).png",
    jinguang_ring = "image/weapon/weapon  (5).png",
    qingyin_qin = "image/weapon/weapon  (6).png",
    baigu_staff = "image/weapon/weapon  (7).png",
    fuyao_chain = "image/weapon/weapon  (8).png",
    zhenyao_tower = "image/weapon/weapon  (9).png",
    double_blade_chain = "image/weapon/weapon  (10).png",
    bishui_sword = "image/weapon/weapon  (11).png",
    lingmo_brush = "image/weapon/weapon  (12).png",
    pozhen_spear = "image/weapon/weapon  (13).png",
    taiji_sword = "image/weapon/weapon  (14).png",
    huxin_pearl = "image/weapon/weapon  (15).png",
}

local ARMOR_ICONS = {
    dark_iron_shield = "image/armor/dark_iron_shield.png",
    thorn_armor = "image/armor/thorn_armor.png",
    yuqing_robe = "image/armor/yuqing_robe.png",
    creation_robe = "image/armor/creation_robe.png",
    purity_orb = "image/armor/purity_orb.png",
}

local weapons = {
    { id = "qingfeng_sword", name = "青锋剑" },
    { id = "chiyan_spear", name = "赤焰枪" },
    { id = "qingyu_fan", name = "青羽扇" },
    { id = "ziqi_gourd", name = "紫气葫芦" },
    { id = "jinguang_ring", name = "金光环" },
    { id = "qingyin_qin", name = "清音琴" },
    { id = "baigu_staff", name = "白骨杖" },
    { id = "fuyao_chain", name = "缚妖链" },
    { id = "zhenyao_tower", name = "镇妖塔" },
    { id = "double_blade_chain", name = "双刃锁链" },
    { id = "bishui_sword", name = "碧水剑" },
    { id = "lingmo_brush", name = "灵墨笔" },
    { id = "pozhen_spear", name = "破阵枪" },
    { id = "taiji_sword", name = "太极剑" },
    { id = "huxin_pearl", name = "护心珠" },
}

-- 解锁卡只介绍 Q1 已有的初始特效，不展示后续品质成长。
local INITIAL_WEAPON_DESCRIPTIONS = {
    qingfeng_sword = "攻击生命高于 80% 的敌人时，额外造成 20% 武器伤害。",
    chiyan_spear = "攻击时叠加灼烧，每层持续 3 回合，每回合造成 5% 武器伤害。",
    qingyu_fan = "攻击主目标，并对 1 个额外目标造成 20% 武器伤害的溅射。",
    ziqi_gourd = "攻击时有 8% 概率回复相当于 1% 武器伤害的生命，最低回复 1 点。",
    jinguang_ring = "攻击时有 10% 概率将普通敌人击退 2 格。",
    qingyin_qin = "攻击时有 20% 概率定身敌人 1 回合，成功后进入 4 回合定身免疫。",
    baigu_staff = "降低敌人 10%～20% 防御，敌人生命越高削防越强，持续 2 回合。",
    fuyao_chain = "基础暴击率为 25%，暴击伤害为 200%。",
    zhenyao_tower = "攻击同列目标，并额外对全场所有存活敌人造成 2.5% 武器伤害。",
    double_blade_chain = "每次攻击分两段结算，每段造成 45% 武器伤害并独立判定暴击。",
    bishui_sword = "攻击必定暴击，暴击伤害为 115%。",
    lingmo_brush = "玩家生命不高于 30% 时，武器伤害提高 20%。",
    pozhen_spear = "攻击时无视敌人防御。",
    taiji_sword = "攻击生命低于 20% 的敌人时，额外造成 15% 武器伤害。",
    huxin_pearl = "降低敌人 10% 攻击 2 回合，并额外造成等同削减攻击力的伤害。",
}

-- 15 把攻击法宝各展示 4 个专属技能；两项双剑共享技能合并为唯一奖励 ID，合计 58 项。
-- desc 必须与《攻击法宝与肉鸽技能设计文档》的技能描述保持一致。
local weaponSkills = {
    { id = "weaponSkill:taqing_sword_art", skillId = "taqing_sword_art", name = "太清剑法", weaponId = "qingfeng_sword", weaponIds = { "qingfeng_sword", "taiji_sword" }, requiredWeapons = { "qingfeng_sword", "taiji_sword" }, requiresAnyWeapon = true, hideWhenAllRequiredWeapons = true, desc = [=[共享技能，拥有青锋剑或太极剑时可解锁。

- 只拥有青锋剑：青锋剑同时获得太极剑的基础低血追加伤害；
- 只拥有太极剑：太极剑同时获得青锋剑的基础高血追加伤害；
- 不解锁另一把武器的掉落与合成池；
- 已经同时拥有两把剑时，该能力不再出现。]=] },
    { id = "weaponSkill:sword_edge_exposed", skillId = "sword_edge_exposed", name = "剑露锋芒", weaponId = "qingfeng_sword", weaponIds = { "qingfeng_sword", "taiji_sword" }, requiredWeapons = { "qingfeng_sword", "taiji_sword" }, requiresAnyWeapon = true, desc = [=[共享技能，拥有青锋剑或太极剑时可解锁。

- 青锋剑和太极剑的阈值额外伤害效果提高 20%；
- 采用乘算增幅；
- 青锋剑基础 20% 提高为 24%；
- 太极剑基础 15% 提高为 18%；
- 后续获得另一把剑时，另一把剑也自动获得该强化。]=] },
    { skillId = "qingfeng_sharp", name = "锋锐", weaponId = "qingfeng_sword", desc = [=[青锋剑攻击时有 10% 概率额外造成武器伤害 50% 的伤害。

- 不能暴击；
- 不触发青锋剑高血被动；
- 不计为一次攻击。]=] },
    { skillId = "qingfeng_huali", name = "化利", weaponId = "qingfeng_sword", desc = [=[青锋剑高血追加伤害的触发阈值降低 15 个百分点。

例如 Q9 原阈值为 65%，获得后降至 50%。]=] },
    { skillId = "taiji_yinyang", name = "阴阳", weaponId = "taiji_sword", desc = [=[太极剑攻击后有 20% 概率追击一次，造成武器伤害 50% 的伤害。

- 属于额外攻击；
- 可以暴击；
- 可以触发太极剑低血追加伤害；
- 不能再次触发“阴阳”。]=] },
    { skillId = "taiji_enlightenment", name = "悟道", weaponId = "taiji_sword", desc = [=[本次攻击及其追击全部结束后，如果敌人剩余生命低于最大生命 10%，直接斩杀。

- 对普通、精英和头目均可生效；
- 属于斩杀，不属于硬控制。]=] },
    { skillId = "bishui_urge_wave", name = "催新浪", weaponId = "bishui_sword", desc = [=[碧水剑暴击伤害改为每次攻击独立波动：

- Q1～Q2：90%～150%；
- Q3～Q9：100%～160%。]=] },
    { skillId = "bishui_cut_current", name = "断流", weaponId = "bishui_sword", desc = [=[选择“断流”后：

- 碧水剑不再产生暴击标记；
- 每次攻击仍进行一次虚拟暴击判定，得到本次**断流前虚拟暴击伤害**；
- 本次主攻击改为普通攻击，并额外增加断流前虚拟暴击伤害的 10%；
- 断流增加的部分属于主攻击增幅，不是额外攻击，也不是暴击伤害。

```text
断流前虚拟暴击伤害 = 当前武器攻击力 × 本次虚拟暴击倍率
断流增幅伤害 = 断流前虚拟暴击伤害 × 10%
断流后主攻击伤害 = 当前武器攻击力 + 断流增幅伤害
```

例如品质配置攻击力为100、当前境界攻击倍率为1.5、本次虚拟暴击倍率为160%，且无其他武器增伤：

```text
当前武器攻击力 = 100 × 1.5 = 150
断流前虚拟暴击伤害 = 150 × 160% = 240
断流增幅伤害 = 240 × 10% = 24
断流后主攻击伤害 = 150 + 24 = 174
```]=] },
    { skillId = "bishui_water_force", name = "水势", weaponId = "bishui_sword", desc = [=[攻击时额外附加一次等于本次**主攻击最终暴击伤害** 20% 的伤害。

- 未拥有“断流”时，读取本次真实主攻击的最终暴击伤害；
- 与“断流”同时持有时，读取本次断流前虚拟暴击伤害；
- 只读取碧水剑主攻击的真实或虚拟暴击伤害；
- 不计入 Q7～Q9 最大生命附加伤害、其他额外伤害或溢出伤害；
- 不能再次暴击；
- 不触发最大生命附加伤害；
- 不触发其他追加攻击。

例如品质配置攻击力为100、当前境界攻击倍率为1.5、本次断流前虚拟暴击倍率为160%，同时拥有“断流”和“水势”，且无其他武器增伤：

```text
当前武器攻击力 = 150
断流前虚拟暴击伤害 = 240
断流后主攻击伤害 = 174
水势伤害 = 240 × 20% = 48
两项合计伤害 = 174 + 48 = 222
```]=] },
    { skillId = "bishui_river_stir", name = "翻江搅海", weaponId = "bishui_sword", desc = [=[击杀敌人时，超过敌人剩余生命的溢出伤害随机攻击一个其他存活敌人。

- 溢出伤害不能再次产生溢出传播；
- 没有其他敌人时效果消失；
- 溢出伤害不能暴击；
- 不附带最大生命百分比伤害。]=] },
    { skillId = "fan_wind_aids_fire", name = "风助火势", weaponId = "qingyu_fan", requiredWeapons = { "qingyu_fan", "chiyan_spear" }, desc = [=[解锁条件：同时拥有青羽扇和赤焰枪。

青羽扇攻击在攻击前已经处于灼烧状态的敌人时，该目标已有灼烧的每层伤害提高 20%。

- 只强化已有灼烧；
- 不增加灼烧层数；
- 同一份灼烧状态不重复叠加该增幅；
- 溅射目标不会自动获得灼烧。

结算顺序：

1. 判断主目标攻击前是否已有灼烧；
2. 若有，应用风助火势；
3. 结算主目标伤害；
4. 结算溅射伤害。]=] },
    { skillId = "fan_if_wind", name = "若风", weaponId = "qingyu_fan", desc = [=[没有合法溅射目标时，把本次原本应造成的全部溅射伤害集中到主目标。

集中伤害最高不超过青羽扇武器伤害的 150%。]=] },
    { skillId = "fan_wind_wrath", name = "风怒", weaponId = "qingyu_fan", desc = [=[每个溅射目标独立有 20% 概率使本次溅射伤害翻倍。]=] },
    { skillId = "fan_wind_sough", name = "风潇潇", weaponId = "qingyu_fan", desc = [=[- 溅射伤害可以暴击；
- 溅射攻击额外获得 20% 暴击率；
- 溅射暴击使用玩家正常暴击伤害。]=] },
    { skillId = "chain_momentum", name = "蓄势", weaponId = "fuyao_chain", desc = [=[攻击没有暴击时，下次攻击暴击率提高 15 个百分点。

- 可以连续累计；
- 额外暴击率上限为 45 个百分点；
- 成功暴击后重置。]=] },
    { skillId = "chain_spirit", name = "势气", weaponId = "fuyao_chain", desc = [=[- 暴击率 +15 个百分点；
- 暴击伤害 +15 个百分点。]=] },
    { skillId = "chain_turn_tide", name = "力挽", weaponId = "fuyao_chain", desc = [=[攻击未暴击时，连续暴击额外伤害不再清零，而是减少 20 个百分点。

例如当前连续暴击额外伤害为 70%，未暴击后降至 50%。]=] },
    { skillId = "chain_fury", name = "狂怒", weaponId = "fuyao_chain", desc = [=[缚妖链暴击时，有 5% 概率额外造成一次武器伤害三倍的伤害。

```text
狂怒伤害 = 武器伤害 × 3
```

狂怒规则：

- 狂怒由暴击触发；
- 狂怒伤害不是暴击伤害；
- 不使用暴击倍率；
- 不能再次暴击；
- 不计入连续暴击递增；
- 不触发其他攻击或追击；
- 不会再次触发狂怒。

推荐结算顺序：

1. 判定本次攻击是否暴击；
2. 更新连续暴击状态；
3. 结算正常暴击伤害；
4. 暴击后判定狂怒；
5. 狂怒触发时独立结算三倍武器伤害。]=] },
    { skillId = "brush_judgement", name = "审判", weaponId = "lingmo_brush", desc = [=[敌人当前生命低于玩家绝对已损生命值时，敌人直接死亡。

- 普通、精英和头目使用同一规则；
- 不为头目设置额外免疫；
- 通过玩家最大生命和绝对已损生命控制强度。]=] },
    { skillId = "brush_golden_dragon", name = "画龙点金", weaponId = "lingmo_brush", desc = [=[灵墨笔击杀敌人时有 5% 概率获得 50 金币。

- 每次击杀独立判定；
- 不设置每回合触发上限；
- 该技能代表玩家放弃战力强化、选择经济赌博路线。]=] },
    { skillId = "brush_grind_ink", name = "研墨下笔", weaponId = "lingmo_brush", desc = [=[灵墨笔的低血增伤效果提高 15%，采用乘算增幅。]=] },
    { skillId = "brush_bloom", name = "妙笔生花", weaponId = "lingmo_brush", desc = [=[攻击时有 20% 概率附加等于玩家绝对已损生命值的伤害。

- 不能暴击；
- 不触发审判；
- 不计为额外攻击；
- 通过玩家最大生命控制强度。]=] },
    { skillId = "pearl_heart_shock", name = "珠光震心", weaponId = "huxin_pearl", desc = [=[护心珠攻击在本次攻击前已经处于削攻状态的敌人时，武器伤害提高 25%。

该能力只检查削攻状态，不读取敌人的攻击力绝对值。]=] },
    { skillId = "pearl_light_shines", name = "宝光普照", weaponId = "huxin_pearl", desc = [=[护心珠施加削攻时，将主目标削攻比例的 50% 施加给同排其他敌人。

- 扩散削攻不再二次扩散；
- 扩散不会触发削攻转化伤害；
- 如果其他效果已让护心珠削攻覆盖全场，则其他敌人获得主目标 50% 的削攻比例。]=] },
    { skillId = "pearl_blindness", name = "目无所见", weaponId = "huxin_pearl", desc = [=[被护心珠致盲的敌人攻击落空时，受到护心珠武器伤害 40% 的反噬伤害。

- 不能暴击；
- 每个敌人每回合最多触发一次；
- 不会再次触发致盲。]=] },
    { skillId = "pearl_spirit_platform", name = "护心灵台", weaponId = "huxin_pearl", desc = [=[护心珠成功对敌人施加削攻时，玩家获得最大生命 2% 的护盾。

- 不根据敌人攻击力计算；
- 同一敌人每回合最多触发一次；
- 每回合通过此技能获得的护盾最多为玩家最大生命 10%。]=] },
    { skillId = "staff_bone_erosion", name = "骨蚀", weaponId = "baigu_staff", desc = [=[白骨杖攻击已经处于削防状态的敌人时：

- 目标每拥有 10 个百分点削防，白骨杖伤害提高 5%；
- 最多提高 25%；
- 只读取削防比例，不读取敌人防御绝对值。]=] },
    { skillId = "staff_bone_spread", name = "白骨蔓延", weaponId = "baigu_staff", desc = [=[被白骨杖削防的敌人死亡时，将其削防效果扩散给距离最近的两个敌人。

- 扩散比例为原效果的 60%；
- 保留原剩余持续时间；
- 扩散不会再次触发白骨蔓延；
- 扩散不触发其他“施加削防时”能力。]=] },
    { skillId = "staff_erosion_marrow", name = "蚀骨入髓", weaponId = "baigu_staff", desc = [=[白骨杖连续攻击同一个敌人时，每次额外降低其 5% 防御，最多额外降低 20%。

- 更换目标后连续攻击层数重置；
- 敌人死亡后重置；
- 最终削防仍受统一 70% 上限约束。]=] },
    { skillId = "staff_break_formation", name = "骨破阵开", weaponId = "baigu_staff", requiredWeapons = { "baigu_staff", "pozhen_spear" }, desc = [=[解锁条件：同时拥有白骨杖和破阵枪。

- 白骨杖命中敌人时施加持续2回合的“破阵印”；
- 破阵枪攻击带有破阵印的敌人时，武器伤害提高30%；
- 破阵枪命中后使白骨杖削防剩余时间延长1回合；
- 每次攻击最多延长一次；
- 不读取敌人强化后的防御绝对值。]=] },
    { skillId = "qin_gradual_melody", name = "渐入清音", weaponId = "qingyin_qin", desc = [=[没有成功定身目标时，下次攻击该目标的定身概率提高 10 个百分点。

- 每个目标独立累计；
- 最多额外提高 30 个百分点；
- 成功定身后重置；
- 精英躲避控制也视为没有成功定身。]=] },
    { skillId = "qin_broken_string", name = "断弦绝响", weaponId = "qingyin_qin", desc = [=[成功定身敌人时，额外造成武器伤害 80% 的伤害。

代价与限制：

- 该目标本次定身免疫冷却增加1回合；
- 额外伤害不能暴击。]=] },
    { skillId = "qin_lingering_sound", name = "余音绕梁", weaponId = "qingyin_qin", desc = [=[清音琴攻击当前正处于无法行动状态的敌人时，额外造成武器伤害 25% 的伤害。

- 每个敌人每回合最多触发一次；
- 不能暴击。]=] },
    { skillId = "qin_silent_wins", name = "无声胜有声", weaponId = "qingyin_qin", desc = [=[攻击仍处于清音琴定身免疫冷却中的敌人时：

- 不再进行定身判定；
- 改为造成武器伤害 50% 的额外伤害；
- 不能暴击；
- 不改变免疫冷却时间。]=] },
    { skillId = "tower_nine_heavens", name = "塔鸣九霄", weaponId = "zhenyao_tower", desc = [=[镇妖塔全场伤害可以暴击：

- 暴击率等于镇妖塔当前暴击率的 50%；
- 暴击伤害固定为 150%；
- 一次全场结算只进行一次暴击判定，所有目标共享结果。]=] },
    { skillId = "tower_demon_might", name = "妖聚塔威", weaponId = "zhenyao_tower", desc = [=[场上每存在一个存活敌人，镇妖塔全场伤害提高 10%，最多提高 50%。]=] },
    { skillId = "tower_seal", name = "镇妖封印", weaponId = "zhenyao_tower", desc = [=[同一个敌人每受到 5 次镇妖塔全场伤害，触发一次封印爆炸，造成镇妖塔武器伤害 60% 的额外伤害。

- 每个敌人独立累计；
- 爆炸不能暴击；
- 爆炸不增加封印层数。]=] },
    { skillId = "tower_refine", name = "收妖炼塔", weaponId = "zhenyao_tower", desc = [=[镇妖塔全场伤害完成击杀时，本局镇妖塔全场伤害比例永久提高 0.25 个百分点，最多提高 5 个百分点。

- 只计算镇妖塔全场伤害造成的直接击杀；
- 封印爆炸击杀不增加成长；
- 一次全场伤害击杀多个敌人时，每个敌人分别提供成长。]=] },
    { skillId = "gourd_purple_fills", name = "紫气渐盈", weaponId = "ziqi_gourd", desc = [=[攻击未触发回血时，下次回血概率提高 2 个百分点。

- 最多累计额外 10 个百分点；
- 触发回血后重置；
- 每把紫气葫芦独立记录。]=] },
    { skillId = "gourd_heal_world", name = "悬壶济世", weaponId = "ziqi_gourd", desc = [=[回血量从武器伤害 1% 提高至 3%。]=] },
    { skillId = "gourd_purple_guard", name = "紫气护体", weaponId = "ziqi_gourd", desc = [=[过量治疗转化为等量护盾，护盾上限为玩家最大生命 15%。]=] },
    { skillId = "gourd_medicine_poison", name = "药毒同源", weaponId = "ziqi_gourd", desc = [=[紫气葫芦触发回血时：

- 玩家生命低于或等于50%：本次治疗量翻倍；
- 玩家生命高于50%：额外对目标造成武器伤害50%的伤害。

额外伤害不能暴击。]=] },
    { skillId = "spear_borrow_armor", name = "借甲破阵", weaponId = "pozhen_spear", desc = [=[破阵枪根据敌人原始模板防御追加伤害的比例提高 30%，采用乘算增幅。

例如：

- Q4：30%提高为39%；
- Q5：60%提高为78%；
- Q6：100%提高为130%。]=] },
    { skillId = "spear_braver_against_sturdy", name = "越坚越勇", weaponId = "pozhen_spear", desc = [=[攻击精英或头目时，破阵枪武器伤害提高 25%。

该效果按敌人类别判定，不读取敌人强化后的防御值。]=] },
    { skillId = "spear_break_wall", name = "破壁穿城", weaponId = "pozhen_spear", desc = [=[- 破阵枪对敌人护盾造成双倍伤害；
- 摧毁护盾后，溢出伤害全部传递到生命值；
- 不因护盾被摧毁而额外生成攻击。]=] },
    { skillId = "spear_one_shot_formation", name = "一枪贯阵", weaponId = "pozhen_spear", desc = [=[如果破阵枪一次攻击会命中多个敌人：

- 后续目标不再发生伤害衰减；
- 每穿过一个目标，伤害提高10%；
- 最多提高30%。]=] },
    { skillId = "ring_endless_turn", name = "轮转无休", weaponId = "jinguang_ring", desc = [=[金光环基础击退概率额外提高 15 个百分点。

例如 Q9 从 25% 提高至 40%。]=] },
    { skillId = "ring_store_might", name = "金轮蓄势", weaponId = "jinguang_ring", desc = [=[击退判定未触发时，下次攻击击退概率提高 10 个百分点。

- 最多累计额外30个百分点；
- 成功触发击退判定后重置；
- 成功判定但被精英躲避时，只减少10个百分点蓄势，不完全重置；
- 攻击头目时不累计蓄势，避免利用免疫目标无限蓄势。]=] },
    { skillId = "ring_shake_mountain", name = "震岳移山", weaponId = "jinguang_ring", desc = [=[成功击退普通敌人时：

- 击退距离额外增加1格；
- 敌人每实际移动1格，额外受到金光环武器伤害30%的伤害；
- 额外伤害不能暴击；
- 若击退途中被阻挡，只按实际移动距离结算。]=] },
    { skillId = "ring_return_light", name = "回光追轮", weaponId = "jinguang_ring", desc = [=[成功击退敌人后，立即追击一次，造成武器伤害50%的伤害。

- 属于额外攻击；
- 可以暴击；
- 不触发新的击退判定；
- 不能再次触发回光追轮；
- 不触发Q7～Q9碰撞伤害。]=] },
    { skillId = "fire_add_oil", name = "火上浇油", weaponId = "chiyan_spear", desc = [=[- 灼烧最大层数从5层提高至10层；
- 灼烧持续时间增加1回合，即持续4回合。]=] },
    { skillId = "fire_burn_body", name = "烈火焚身", weaponId = "chiyan_spear", desc = [=[目标每有一层灼烧，赤焰枪直接攻击伤害提高2%，最多提高30%。]=] },
    { skillId = "fire_explosion", name = "爆燃", weaponId = "chiyan_spear", desc = [=[敌人达到5层灼烧时，消耗5个有效灼烧实例，立即造成赤焰枪武器伤害100%的伤害。

消耗顺序：

1. 按剩余持续回合从少到多排序；
2. 优先消耗剩余回合最少的灼烧实例；
3. 剩余回合相同时，优先消耗最早施加的实例；
4. 一次消耗前5个有效实例。

- 不能暴击；
- 同一次攻击最多触发一次；
- 爆燃不会重新施加灼烧。]=] },
    { skillId = "fire_spark_spreads", name = "星火燎原", weaponId = "chiyan_spear", desc = [=[灼烧敌人死亡时，将其当前灼烧层数的50%传播给同排左右相邻敌人，传播层数向上取整。

传播后的灼烧持续2回合。]=] },
    { skillId = "double_chain_twins", name = "双生共鸣", weaponId = "double_blade_chain", desc = [=[第一段攻击暴击时，第二段攻击必定暴击，但第二段只获得正常暴击增伤部分的80%。

例如正常暴击倍率为150%：

```text
第二段暴击倍率 = 100% + (150% - 100%) × 80% = 140%
```]=] },
    { skillId = "double_chain_follow_win", name = "乘胜连击", weaponId = "double_blade_chain", desc = [=[第一段命中后目标仍然存活时，第二段伤害提高25%。

如果第一段未命中或目标已死亡，则第二段不获得该加成。]=] },
    { skillId = "double_chain_three_rings", name = "三环套月", weaponId = "double_blade_chain", desc = [=[三连击触发概率额外提高10个百分点。

- Q7：5%提高至15%；
- Q8：10%提高至20%；
- Q9：15%提高至25%。]=] },
    { skillId = "double_chain_soul_chase", name = "锁链追魂", weaponId = "double_blade_chain", desc = [=[如果前一段攻击击杀目标，剩余攻击次数自动转移到距离最近的存活敌人。

- 保留当前剩余攻击段数；
- 保留该段伤害倍率；
- 可以暴击；
- 不额外生成攻击次数；
- 剩余已有攻击可以继续转移目标。]=] },
}

-- 卡片只呈现核心效果；完整规则仍保留在 desc 中供战斗逻辑与详细信息使用。
local SKILL_CARD_DESCRIPTIONS = {
    taqing_sword_art = "只拥有青锋剑或太极剑时，使当前武器同时获得另一把剑的基础血量阈值追加伤害。",
    sword_edge_exposed = "青锋剑与太极剑的血量阈值追加伤害提高 20%。",
    qingfeng_sharp = "青锋剑攻击时有 10% 概率额外造成 50% 武器伤害。",
    qingfeng_huali = "青锋剑高血追加伤害的触发阈值降低 15 个百分点。",
    taiji_yinyang = "太极剑攻击后有 20% 概率追击一次，造成 50% 武器伤害。",
    taiji_enlightenment = "攻击及追击结束后，直接斩杀生命低于 10% 的敌人。",
    bishui_urge_wave = "碧水剑每次攻击的暴击伤害独立波动：Q1～Q2 为 90%～150%，Q3～Q9 为 100%～160%。",
    bishui_cut_current = "碧水剑不再暴击，主攻击额外增加本次虚拟暴击伤害的 10%。",
    bishui_water_force = "碧水剑攻击时，额外造成主攻击最终暴击伤害 20% 的伤害。",
    bishui_river_stir = "碧水剑击杀敌人时，将溢出伤害转移给一个其他存活敌人。",
    fan_wind_aids_fire = "青羽扇攻击已灼烧的敌人时，该目标已有灼烧的每层伤害提高 20%。",
    fan_if_wind = "没有溅射目标时，将全部溅射伤害集中到主目标，最高为 150% 武器伤害。",
    fan_wind_wrath = "青羽扇的每个溅射目标有 20% 概率受到双倍溅射伤害。",
    fan_wind_sough = "青羽扇溅射可以暴击，并额外获得 20% 暴击率。",
    chain_momentum = "缚妖链未暴击时，下次攻击暴击率提高 15%，最多提高 45%；暴击后重置。",
    chain_spirit = "缚妖链暴击率与暴击伤害各提高 15%。",
    chain_turn_tide = "缚妖链未暴击时，连续暴击增伤改为减少 20%，不再清零。",
    chain_fury = "缚妖链暴击时有 5% 概率额外造成 300% 武器伤害。",
    brush_judgement = "敌人当前生命低于玩家已损生命值时，直接斩杀该敌人。",
    brush_golden_dragon = "灵墨笔击杀敌人时有 5% 概率获得 50 金币。",
    brush_grind_ink = "灵墨笔的低血增伤效果提高 15%。",
    brush_bloom = "灵墨笔攻击时有 20% 概率附加等于玩家已损生命值的伤害。",
    pearl_heart_shock = "护心珠攻击已被削攻的敌人时，武器伤害提高 25%。",
    pearl_light_shines = "护心珠施加削攻时，将 50% 削攻比例扩散给同排其他敌人。",
    pearl_blindness = "被护心珠致盲的敌人攻击落空时，受到 40% 护心珠武器伤害。",
    pearl_spirit_platform = "护心珠施加削攻时，玩家获得 2% 最大生命护盾，每回合最多 10%。",
    staff_bone_erosion = "目标每有 10% 削防，白骨杖伤害提高 5%，最多提高 25%。",
    staff_bone_spread = "被白骨杖削防的敌人死亡时，将 60% 削防效果扩散给最近的两个敌人。",
    staff_erosion_marrow = "白骨杖连续攻击同一敌人时，每次额外削防 5%，最多 20%。",
    staff_break_formation = "白骨杖施加破阵印；破阵枪攻击带印敌人时伤害提高 30%，并延长削防 1 回合。",
    qin_gradual_melody = "清音琴未能定身目标时，下次对该目标的定身概率提高 10%，最多 30%。",
    qin_broken_string = "清音琴成功定身时，额外造成 80% 武器伤害。",
    qin_lingering_sound = "清音琴攻击无法行动的敌人时，额外造成 25% 武器伤害。",
    qin_silent_wins = "清音琴攻击处于定身免疫冷却的敌人时，改为额外造成 50% 武器伤害。",
    tower_nine_heavens = "镇妖塔全场伤害可暴击，暴击率为当前暴击率的 50%，暴击伤害为 150%。",
    tower_demon_might = "每个存活敌人使镇妖塔全场伤害提高 10%，最多提高 50%。",
    tower_seal = "敌人每受到 5 次镇妖塔全场伤害，触发一次 60% 武器伤害的爆炸。",
    tower_refine = "镇妖塔全场伤害每击杀一个敌人，永久提高 0.25%，最多提高 5%。",
    gourd_purple_fills = "紫气葫芦未触发回血时，下次回血概率提高 2%，最多提高 10%。",
    gourd_heal_world = "紫气葫芦回血量从武器伤害的 1% 提高至 3%。",
    gourd_purple_guard = "紫气葫芦的过量治疗转为护盾，最多为玩家最大生命的 15%。",
    gourd_medicine_poison = "紫气葫芦回血时，半血以下治疗翻倍；半血以上额外造成 50% 武器伤害。",
    spear_borrow_armor = "破阵枪根据敌人原始防御追加伤害的比例提高 30%。",
    spear_braver_against_sturdy = "破阵枪攻击精英或头目时，武器伤害提高 25%。",
    spear_break_wall = "破阵枪对护盾造成双倍伤害，破盾后的溢出伤害全部传递到生命。",
    spear_one_shot_formation = "破阵枪命中多个敌人时不再衰减，每穿过一个目标伤害提高 10%，最多 30%。",
    ring_endless_turn = "金光环基础击退概率提高 15 个百分点。",
    ring_store_might = "金光环未触发击退时，下次击退概率提高 10%，最多提高 30%。",
    ring_shake_mountain = "金光环击退距离增加 1 格，敌人每移动 1 格额外受到 30% 武器伤害。",
    ring_return_light = "金光环成功击退敌人后，立即追击一次并造成 50% 武器伤害。",
    fire_add_oil = "赤焰枪灼烧上限提高至 10 层，持续时间增加至 4 回合。",
    fire_burn_body = "目标每有一层灼烧，赤焰枪直接攻击伤害提高 2%，最多提高 30%。",
    fire_explosion = "敌人达到 5 层灼烧时，消耗 5 层并造成 100% 赤焰枪武器伤害。",
    fire_spark_spreads = "灼烧敌人死亡时，将一半灼烧层数传播给同排相邻敌人。",
    double_chain_twins = "双刃锁链第一段暴击时，第二段必定暴击并获得 80% 的正常暴击增伤。",
    double_chain_follow_win = "双刃锁链第一段命中且目标存活时，第二段伤害提高 25%。",
    double_chain_three_rings = "双刃锁链三连击触发概率提高 10 个百分点。",
    double_chain_soul_chase = "双刃锁链击杀目标后，剩余攻击自动转移到最近的存活敌人。",
}

local armors = {
    { id = "dark_iron_shield", name = "玄铁宝盾" },
    { id = "thorn_armor", name = "荆棘战甲" },
    { id = "yuqing_robe", name = "玉清道衣" },
    { id = "creation_robe", name = "生生造化袍" },
    { id = "purity_orb", name = "净秽宝珠" },
}

-- 防御法宝解锁卡只介绍各自的招牌机制，不展示品质成长与解锁流程。
local ARMOR_DESCRIPTIONS = {
    dark_iron_shield = "受击时有概率完全格挡本次伤害。",
    thorn_armor = "受击时将部分伤害反弹给攻击者。",
    yuqing_robe = "每回合开始时获得可吸收伤害的护盾。",
    creation_robe = "每回合自动恢复玩家气血。",
    purity_orb = "每回合清除玩家身上的负面状态。",
}

local defs = {}
for _, armor in ipairs(armors) do
    local armorDesc = ARMOR_DESCRIPTIONS[armor.id]
    table.insert(defs, {
        id = "unlockArmor:" .. armor.id,
        name = armor.name,
        shortName = armor.name,
        category = "解锁",
        desc = armorDesc,
        abilityName = armor.name,
        abilityDesc = armorDesc,
        cardDesc = armorDesc,
        kind = "unlockArmor",
        armorId = armor.id,
        icon = ARMOR_ICONS[armor.id],
        weight = 4,
        maxStacks = 1,
        immediate = true,
    })
end

for _, weapon in ipairs(weapons) do
    local icon = WEAPON_ICONS[weapon.id]
    local initialDesc = INITIAL_WEAPON_DESCRIPTIONS[weapon.id] or "加入本轮掉落与合成池。"
    table.insert(defs, {
        id = "unlock:" .. weapon.id,
        name = weapon.name,
        shortName = weapon.name,
        abilityName = weapon.name,
        abilityDesc = initialDesc,
        cardDesc = initialDesc,
        category = "解锁",
        desc = initialDesc,
        kind = "unlock",
        weaponId = weapon.id,
        icon = icon,
        weight = 4,
        maxStacks = 1,
        immediate = true,
    })
end

for _, skill in ipairs(weaponSkills) do
    local rewardId = skill.id or ("weaponSkill:" .. skill.skillId)
    local primaryWeaponId = skill.weaponId
    table.insert(defs, {
        id = rewardId,
        name = skill.name,
        shortName = skill.name,
        abilityName = skill.name,
        abilityDesc = skill.desc,
        cardDesc = SKILL_CARD_DESCRIPTIONS[skill.skillId] or skill.desc,
        category = "专属",
        desc = skill.desc,
        kind = "weaponSkill",
        skillId = skill.skillId,
        weaponId = primaryWeaponId,
        weaponIds = skill.weaponIds,
        requiredWeapons = skill.requiredWeapons,
        requiresAnyWeapon = skill.requiresAnyWeapon == true,
        hideWhenAllRequiredWeapons = skill.hideWhenAllRequiredWeapons == true,
        icon = WEAPON_ICONS[primaryWeaponId],
        weight = 3,
        maxStacks = 1,
        immediate = true,
    })
end

local common = {
    { "all_weapon_damage", "百兵共鸣", "全武器伤害 +10%", "weaponDamagePct", 0.10, 3, "attack", "image/talent/common_hp.png" },
    { "crit_chance", "灵台一闪", "暴击率 +6%", "critChance", 0.06, 3, "attack", "image/talent/common_attack.png" },
    { "crit_damage", "破妄", "暴击伤害 +25%", "critDamagePct", 0.25, 2, "attack", "image/talent/common_crit.png" },
    { "elite_damage", "斩将", "对精锐/头目伤害 +15%", "eliteDamagePct", 0.15, 2, "attack", "image/talent/common_reduce.png" },
    { "max_hp", "气海拓宽", "最大气血 +15%", "maxHpPct", 0.15, 3, "player", "image/talent/common_hp.png" },
    { "armor_defense", "玄甲", "护甲防御 +15%", "armorDefensePct", 0.15, 3, "defense", "image/talent/common_armor.png" },
    { "reduction", "金刚护体", "最终减伤 +6%", "damageTakenReduction", 0.06, 2, "defense", "image/talent/common_armor.png" },
    { "kill_heal", "噬灵", "击杀回血 1.5%最大气血", "killHealPct", 0.015, 2, "player", "image/talent/common_regen.png" },
    { "reward_spawn", "寻宝诀", "场上奖励出现率 +15%", "fieldRewardSpawnPct", 0.15, 2, "player", "image/talent/coin.png" },
    { "reward_quality", "天运", "场上奖励品质 +1档", "fieldRewardQualityShift", 1, 2, "player", "image/talent/shop.png" },
}
for _, reward in ipairs(common) do
    table.insert(defs, { id = "common:" .. reward[1], name = reward[2], abilityName = reward[2], abilityDesc = reward[3], category = "通用", desc = reward[3], kind = "common", icon = reward[8], modifier = { stat = reward[4], value = reward[5] }, rewardGroup = reward[7], weight = 3, maxStacks = reward[6], immediate = true })
end

local enemy = {
    { "enemy_hp", "妖躯淬炼", "敌方最大生命值 +15%", "enemyHpPct", 0.15, 3 },
    { "enemy_atk", "凶煞暴涨", "敌方攻击力 +12%", "enemyAtkPct", 0.12, 3 },
    { "enemy_defense", "铁壁妖甲", "敌方防御力 +15%", "enemyDefensePct", 0.15, 3 },
    { "enemy_crit_chance", "血月凶兆", "敌方暴击率 +10个百分点", "enemyCritChancePct", 0.10, 2 },
    { "enemy_spawn_count", "群妖并起", "每波敌人数量 +10%", "enemySpawnCountPct", 0.10, 2 },
    { "enemy_column_resonance", "妖魂共鸣", "同列每多一个存活敌人，该列敌人攻击力 +3%，最多计算2个", "enemyColumnResonancePct", 0.03, 2 },
}
for _, reward in ipairs(enemy) do
    table.insert(defs, {
        id = "enemy:" .. reward[1],
        name = reward[2],
        category = "敌方强化",
        desc = reward[3],
        kind = "enemy",
        rewardGroup = "enemy",
        icon = "image/talent/enemy_enhance.png",
        modifier = { stat = reward[4], value = reward[5] },
        weight = 3,
        maxStacks = reward[6],
        immediate = true,
    })
end

local armorAbilities = {
    {
        armorId = "dark_iron_shield",
        armorName = "玄铁宝盾",
        abilities = {
            { "玄铁壁垒", "格挡判定获得额外 +12% 减伤效果。", "blockChancePct", 0.12 },
            { "盾御反震", "格挡成功时，反伤倍率 +20%。", "blockReflectPct", 0.20 },
        },
    },
    {
        armorId = "thorn_armor",
        armorName = "荆棘战甲",
        abilities = {
            { "荆棘回响", "荆棘反伤与吸收转伤倍率 +20%。", "thornsReflectPct", 0.20 },
            { "血棘穿心", "荆棘反伤额外附加 +10% 伤害。", "thornsBonusPct", 0.10 },
        },
    },
    {
        armorId = "yuqing_robe",
        armorName = "玉清道衣",
        abilities = {
            { "玉清护脉", "每回合护盾值与护盾上限 +20%。", "armorShieldPct", 0.20 },
            { "流云护体", "玉清道衣护盾上限额外 +10%。", "armorShieldCapPct", 0.10 },
        },
    },
    {
        armorId = "creation_robe",
        armorName = "生生造化袍",
        abilities = {
            { "造化回春", "防御法宝每回合恢复气血效果 +20%。", "armorRegenPct", 0.20 },
            { "生生不息", "受击恢复气血效果 +25%。", "armorHitHealPct", 0.25 },
        },
    },
    {
        armorId = "purity_orb",
        armorName = "净秽宝珠",
        abilities = {
            { "净秽清光", "每回合净化数量 +1；已有全净化时不再额外增加。", "cleanseCountBonus", 1 },
            { "宝珠护神", "负面状态免疫回合 +1。", "cleanseImmunityTurns", 1 },
        },
    },
}

for _, armor in ipairs(armorAbilities) do
    for index, ability in ipairs(armor.abilities) do
        table.insert(defs, {
            id = "armorAbility:" .. armor.armorId .. ":" .. index,
            name = armor.armorName .. "·" .. ability[1],
            shortName = ability[1],
            category = "专属",
            desc = ability[2],
            abilityName = ability[1],
            abilityDesc = ability[2],
            kind = "armor",
            armorId = armor.armorId,
            icon = ARMOR_ICONS[armor.armorId],
            rewardGroup = "defense",
            modifier = { stat = ability[3] .. ":" .. armor.armorId, value = ability[4] },
            weight = 2,
            maxStacks = 3,
            immediate = true,
        })
    end
end

return defs
