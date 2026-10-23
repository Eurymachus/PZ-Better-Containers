-- Test-only fixture outside Contents/, running shipped functions against mocked items.
-- Java inventory, drawing, crafting and third-party mod costs are not measured.
local checks, ages, refreshes = 0, 0, 0
local function noop() end
local function no() return false end
local function zero() return 0 end
local function one() return 1 end
local options = {showFoodFreshnessBar=true, showFoodFreshnessPercentage=true}
local category = {get=function() return "Material" end,
    getItemDisplayName=function() return "Material" end}
require = function(name)
    if name == "BetterContainers/_Options" then return options end
    if name == "BetterContainers/Helpers" then return {isCleanUIActive=no} end
    if name == "BetterContainers/Categorize/InventoryCategory" then return category end
end
Events = {OnGameStart={Add=noop}, OnTick={Add=noop}}
instanceof = function(item, kind)
    checks = checks + 1
    return (kind == "InventoryItem" and item.isItem == true) or (kind == "Food" and item.food == true)
end
getSpecificPlayer = function() return {} end
getPlayerHotbar = function() return {} end
getText = function(key) return key end
getCore = function() return {getOptionFontSizeReal=one} end
local itemMethods = {isHidden=no, IsFood=no, getName=function(self) return self.name end,
    getDisplayCategory=function() return "Material" end, getCategory=function() return "Normal" end,
    getUnequippedWeight=one, updateAge=function() ages=ages+1 end,
    getTex=function() return nil end, getJobDelta=zero, getHeat=one,
    getItemHeat=one, isUnwanted=no}
local function makePane(count, expanded, separate)
    local items = {}
    for i=1,count do
        items[i] = setmetatable({isItem=true, name=separate and ("Metal Plate " .. i) or "Metal Plate"}, {__index=itemMethods})
    end
    local inv = {dirty=true}
    function inv:getItems() return {size=function() return #items end, get=function(_, i) return items[i+1] end} end
    function inv:isDrawDirty() return self.dirty end
    function inv:setDrawDirty(value) self.dirty=value end
    inv.isLockedToCharacter=no
    inv.isInCharacterInventory=no
    local p = setmetatable({inventory=inv, player=0, parent={onCharacter=false},
        items={}, selected={}, collapsed={['Metal Plate']=not expanded},
        itemSortFunc=function(a,b) return a.name < b.name end,
        collapseAll={setVisible=noop}, expandAll={setVisible=noop},
        column2=40, column3=200, column4=400, height=300, width=400,
        itemHgt=20, headerHgt=20, fontHgt=12, mode="details"}, {__index=ISInventoryPane})
    return p
end
local function reset()
    ISInventoryPane = {MAX_ITEMS_IN_STACK_TO_RENDER=50,
        saveSelection=function() return {} end, restoreSelection=noop,
        updateScrollbars=noop, isMouseOver=no, updateWorldObjectHighlight=noop,
        getMouseX=zero, getMouseY=zero, getYScroll=zero, getAbsoluteX=zero, getAbsoluteY=zero,
        getHeight=function(self) return self.height end,
        getWidth=function(self) return self.width end}
    for _, name in ipairs({'drawRectStatic','drawRect','drawTextureScaled','drawText',
        'setStencilRect','clearStencilRect','repaintStencilRect','drawItemDetails',
        'setScrollHeight','setScrollWidth','resumeStencil'}) do ISInventoryPane[name]=noop end
    loadVanilla()
    loadRightClick()
    local original = ISInventoryPane.refreshContainer
    ISInventoryPane.refreshContainer = function(self)
        refreshes=refreshes+1
        return original(self)
    end
end
for _, variant in ipairs({'vanilla','categories','categories+freshness'}) do
    reset()
    if variant ~= 'vanilla' then loadCategories() end
    if variant == 'categories+freshness' then loadFreshness().install() end
    for _, count in ipairs({1,400,4000}) do
        for _, expanded in ipairs({false,true}) do
            local p=makePane(count,expanded,false)
            p:refreshContainer()
            assert(#p.itemslist==1 and #p.itemslist[1].items==count+1)
            -- Warm up before counting steady frames. Both passes run each frame.
            for i=1,20 do p:renderdetails(false) p:renderdetails(true) end
            checks,ages,refreshes=0,0,0
            local start=milliseconds()
            for i=1,100 do p:renderdetails(false) p:renderdetails(true) end
            local elapsed=milliseconds()-start
            assert(refreshes==0, 'clean render unexpectedly refreshed')
            assert(#p.items==(expanded and math.min(count+1,51) or 1))
            print(variant .. ' n=' .. count .. ' expanded=' .. tostring(expanded)
                .. ' ms/100frames=' .. elapsed .. ' instanceof=' .. checks
                .. ' ageUpdates=' .. ages .. ' refreshes=' .. refreshes)
            p.inventory.dirty=true
            p:renderdetails(false) p:renderdetails(true)
            assert(refreshes==1 and not p.inventory.dirty, 'dirty inventory did not settle')
        end
    end
end
print('PASS renderer stack limits and dirty refresh settlement')

-- A/B: off-screen stacks must not incur any freshness checks.
local p=makePane(400,false,false)
p:refreshContainer()
p.getYScroll=function() return -1000 end
checks=0
p:renderdetails(false) p:renderdetails(true)
local enabledChecks=checks
options.showFoodFreshnessBar=false
options.showFoodFreshnessPercentage=false
checks=0
p:renderdetails(false) p:renderdetails(true)
assert(enabledChecks==checks, 'off-screen freshness scan')
print('PASS off-screen A/B: zero additional freshness checks')

-- Actual right-click handler, with menu construction replaced by a boundary spy.
-- This verifies dispatch and stack shape, not the cost inside createMenu.
JoypadState={players={}}
local menuCalls=0
ISInventoryPaneContextMenu={createMenu=function(player,inInv,items)
    menuCalls=menuCalls+1
    assert(#items==1 and #items[1].items==401, 'wrong stack passed to menu')
end}
p.mouseOverOption=1
p.selected={[1]=p.items[1]}
local renderCalls=0
p.renderdetails=function() renderCalls=renderCalls+1 end
refreshes=0
for i=1,100 do p:onRightMouseUp(0,0) end
assert(menuCalls==100 and renderCalls==0 and refreshes==0)
print('PASS 100 right clicks: 100 menu dispatches, zero renders or refreshes')

-- Isolate the overlay to check food correctness and cache invalidation.
ISInventoryPane.renderdetails=noop
loadFreshness().install()
options.showFoodFreshnessBar=true
options.showFoodFreshnessPercentage=true
UIFont={Medium='medium'}
getTextManager=function() return {MeasureStringX=function(_,font,text) return #text*6 end} end
local foodReads=0
local function food(age)
    return {food=true, age=age, getOffAgeMax=function() return 10 end,
        getOffAge=function() return 5 end, getAge=function(self) foodReads=foodReads+1 return self.age end}
end
local q=makePane(400,false,false)
q:refreshContainer()
q.mouseOverOption=1
local labels={}
q.drawText=function(_,text) labels[#labels+1]=text end
q:renderdetails(false)
checks=0
for i=1,100 do q:renderdetails(false) end
assert(checks==0, 'cached non-food stack rescanned')
local fresh,stale=food(1),food(8)
-- Mixed-name stacks must find food even when the header is a metal plate.
q.itemslist[1].items={q.itemslist[1].items[1],fresh,stale}
q:renderdetails(false)
assert(labels[#labels]=='20%', 'least-fresh item lost in mixed stack')
stale.age=9
q:renderdetails(false)
assert(labels[#labels]=='10%', 'freshness value was incorrectly cached')
q.itemslist[1].items[#q.itemslist[1].items+1]=food(10)
q:renderdetails(false)
assert(labels[#labels]=='0%', 'resized stack did not invalidate cache')
q.getYScroll=function() return -1000 end
checks,foodReads=0,0
q:renderdetails(false)
assert(checks==0 and foodReads==0, 'off-screen food was scanned')
-- A visible child still draws when its expanded stack header is off-screen.
q.collapsed['Metal Plate']=false
q.getYScroll=function() return -50 end
labels={}
q:renderdetails(false)
assert(#labels>0, 'visible child skipped with off-screen header')
print('PASS cached non-food, mixed stacks, changing age, resized cache, and visible food children')

-- Execute vanilla's crafting submenu, spying on its Java crafting boundaries.
-- These counts are real Lua dispatch counts, not Java execution timings.
local constructions, containerScans, recipeSelections=0,0,0
HandcraftLogic={new=function()
    constructions=constructions+1
    return {setContainers=function() containerScans=containerScans+1 end,
        setRecipeFromContextClick=function() recipeSelections=recipeSelections+1 end,
        getResultTexture=function() return nil end}
end}
CraftTooltip={releaseAll=noop,addToolTip=function() return {setName=noop} end}
isDebugEnabled=no
getSandboxOptions=function() return {isUnstableScriptNameSpam=no} end
ISInventoryPaneContextMenu.getContainers=function() return {} end
local menu={addOption=function() return {} end,addSubMenu=noop}
menu.getNew=function() return menu end
local metal={getDisplayName=function() return 'Metal Plate' end,
    getIcon=function() return {splitIcon=noop} end,getTexture=noop}
loadCraftingSubmenu()
for _, recipeCount in ipairs({1,20,100}) do
    constructions,containerScans,recipeSelections=0,0,0
    local recipes={size=function() return recipeCount end,
        get=function() return {getTranslationName=function() return 'Recipe' end} end}
    ISInventoryPaneContextMenu.addNewCraftingDynamicalContextMenu(metal,menu,recipes,0,{})
    assert(constructions==recipeCount and containerScans==recipeCount and recipeSelections==recipeCount)
    print('PASS crafting submenu recipes=' .. recipeCount .. ' fresh Java logic instances=' .. constructions
        .. ' container scans=' .. containerScans .. ' recipe selections=' .. recipeSelections)
end

getTimestampMs=milliseconds
ISInventoryPane.renderdetails=function(self, flag) return flag,nil,'tail' end
local originalRender=ISInventoryPane.renderdetails
local diagnosticContainer={getItems=function() return {size=function() return 400 end} end}
local diagnosticList={size=function() return 2 end,get=function() return diagnosticContainer end}
ISInventoryPaneContextMenu.getContainers=function() return diagnosticList,nil,'tail' end
loadProbe()
BCInventoryProbe.install()
local a,b,c=ISInventoryPane.renderdetails({},false)
assert(a==false and b==nil and c=='tail', 'probe changed return values')
assert(BCInventoryProbe.stats[1].entered==1 and BCInventoryProbe.stats[1].completed==1)
local containers,empty,tail=ISInventoryPaneContextMenu.getContainers({})
assert(containers==diagnosticList and empty==nil and tail=='tail', 'container observer changed results')
BCInventoryProbe.stop()
assert(ISInventoryPane.renderdetails==originalRender, 'probe failed to restore hook')
print('PASS optional live probe return values and hook restoration')
