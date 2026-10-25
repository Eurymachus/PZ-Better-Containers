-- Concatenated with the shared pane fixture by InventoryPerformanceTest.
-- Actual refresh, category store/resolver and comparators; mocked item/UI APIs.
-- Both table.sort and string.sort come from the installed game's runtime.
local store, resolver
require=function(name)
    if name=='BetterContainers/_IO/IniWriter' then
        return {makeFeature=function() return {loadAll=function() return {} end} end}
    end
    if name=='BetterContainers/Categorize/CategoryStore' then return store end
    if name=='BetterContainers/Categorize/InventoryCategory' then return resolver end
    if name=='BetterContainers/Helpers' then return {isCleanUIActive=no} end
end
store=loadCategoryStore()
resolver=loadInventoryCategory()
resolver.setEnabled(true)
local lookups,views,sorts,comparisons=0,0,0,0
local effective=store.getEffective
store.getEffective=function(key) lookups=lookups+1 return effective(key) end
local originalMeta=setmetatable
setmetatable=function(value,meta)
    if value.cat and meta.__index then views=views+1 end
    return originalMeta(value,meta)
end
local originalSort=table.sort
table.sort=function(rows,compare)
    sorts=sorts+1
    return originalSort(rows,function(a,b) comparisons=comparisons+1 return compare(a,b) end)
end
local function build(stacks,perStack)
    local p=makePane(stacks*perStack,false,false)
    local items=p.inventory:getItems()
    local defaults={}
    for i=0,items:size()-1 do
        local it=items:get(i)
        local id=math.floor(i/perStack)+1
        -- Deterministic varied names and categories, independent sort orders.
        it.name=string.format('Item %05d', (id*137)%10007)
        it.fullType='Fixture.Type' .. id
        it.getFullType=function(self) return self.fullType end
        defaults[it.fullType]=string.format('Category %02d',id%17)
        it.rawCategory=defaults[it.fullType]
        it.getDisplayCategory=function(self) return self.rawCategory end
    end
    store.setDefaults(defaults)
    return p
end
print('variant,stacks,items,sort,median_ms_per_refresh,sorts,comparisons,category_lookups,proxy_views')
for _,shape in ipairs({{1,400},{100,4},{400,1},{400,10},{1000,1}}) do
    for _,variant in ipairs({'vanilla','current'}) do
        for _,order in ipairs({'name','category'}) do
            reset()
            loadComparators()
            if variant=='current' then loadCategories()
            end
            local p=build(shape[1],shape[2])
            p.itemSortFunc=order=='name' and ISInventoryPane.itemSortByNameInc or ISInventoryPane.itemSortByCatInc
            for i=1,5 do p:refreshContainer() end
            assert(#p.itemslist==shape[1],'fixture stack count incorrect')
            local samples={}
            for round=1,3 do
                local started=milliseconds()
                for i=1,5 do p:refreshContainer() end
                samples[round]=(milliseconds()-started)/5
            end
            originalSort(samples,function(a,b) return a<b end)
            lookups,views,sorts,comparisons=0,0,0,0
            p:refreshContainer()
            if variant=='current' then
                assert(sorts==1, 'redundant sort returned')
                assert(lookups==shape[1], 'category resolved more than once per row')
                assert(views==shape[1], 'category proxy created more than once per row')
            end
            local report=string.format('%s,%d,%d,%s,%.3f,%d,%d,%d,%d',variant,shape[1],shape[1]*shape[2],order,samples[2],sorts,comparisons,lookups,views)
            for i=2,#p.itemslist do
                local a,b=p.itemslist[i-1],p.itemslist[i]
                if order=='name' then assert(a.name<=b.name)
                else assert(a.cat<b.cat or (a.cat==b.cat and a.name<=b.name)) end
            end
            if variant~='vanilla' then
                for _,row in ipairs(p.itemslist) do assert(row.cat==store.getEffective(row.items[1].fullType)) end
            end
            print(report)
        end
    end
end
print('PASS varied-stack refresh benchmarks and resulting sort order')

-- Retained rows must reflect edits immediately, without waiting for a refresh.
reset()
loadComparators()
loadCategories()
local p=build(2,1)
p.itemSortFunc=ISInventoryPane.itemSortByCatInc
p:refreshContainer()
local a,b=p.itemslist[1],p.itemslist[2]
local key=a.items[1].fullType
local inc,desc=ISInventoryPane.itemSortByCatInc,ISInventoryPane.itemSortByCatDesc
assert(inc(a,b))
local custom=store.createCustomCategory('User category')
assert(store.setOverride(key,custom))
assert(resolver.get(a.items[1])==custom)
assert(inc(a,b)==(custom<b.cat), 'custom assignment left cached category')
assert(desc(a,b)==(custom>b.cat), 'descending custom assignment failed')
store.renameCustomCategory(custom,'Renamed category')
assert(resolver.getItemDisplayName(a.items[1])=='Renamed category')
store.setOverride(key,'ZZZ')
assert(not inc(a,b), 'override edit left cached category')
resolver.setEnabled(false)
assert(inc(a,b), 'disabled categories left cached category')
resolver.setEnabled(true)
assert(not inc(a,b), 'enabled categories left cached category')
store.resetOverride(key)
assert(inc(a,b), 'reset left cached category')
store.setOverride(key,custom)
store.deleteCustomCategory(custom)
assert(inc(a,b), 'delete left cached category')
store.setOverride(key,'ZZZ')
assert(not inc(a,b))
store.reload()
assert(inc(a,b), 'reload left cached category')
store.setDefaults({[key]='ZZZ'})
assert(not inc(a,b), 'default change left cached category')
p:refreshContainer()
assert(p.itemslist[2].items[1].fullType==key, 'custom category refresh order failed')
print('PASS custom assignment, rename, deletion, reset, reload, defaults, enable/disable and retained-row sorting')
