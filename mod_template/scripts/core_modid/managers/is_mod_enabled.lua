-- show
-- 功能(无需修改): 判断某个mod有没有开启 的前置

-- 其实是为了模糊搜索才写的这个,如果只是通过文件夹名字判断的话 ModIndex:IsModEnabledAny 即可
-- 调用 SUGAR_%(modid)s:checkMODEnabledByFolderName 来判断即可

if TUNING.MOD_%(modid_upper)s.MOD_LIST == nil then
    TUNING.MOD_%(modid_upper)s.MOD_LIST = {}
end
TUNING.MOD_%(modid_upper)s.MOD_LIST.map_dirname = {}
TUNING.MOD_%(modid_upper)s.MOD_LIST.map_modinfoname = {}

local moddir = KnownModIndex:GetModsToLoad()
for _, dir in pairs(moddir) do
    TUNING.MOD_%(modid_upper)s.MOD_LIST.map_dirname[dir] = true
    local info = KnownModIndex:GetModInfo(dir)
    local name = info and info.name or "unknow"
    table.insert(TUNING.MOD_%(modid_upper)s.MOD_LIST.map_modinfoname,name)
end