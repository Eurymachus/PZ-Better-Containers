-- Actual BC aggregation, page update, auto-lock and wheel wrappers.
-- World discovery/UI are mocked; this is not a live-game reproduction.
local function noop() end
local function no() return false end
local eff={proximityActive=false,autoLock=false}
local options={getEffectivePermissions=function() return eff end,enableProximityHighlight=false}
local helpers={isStaleVehicleContainer=no,isCleanUIActive=no,isPageLeft=no,dlog=noop}
helpers.getModDataRoot=function(data) data.bc=data.bc or {} return data.bc end
local proximity,sortData
local reorder={canSortBackpacks=function() return true end,
    getSortPriority=function(_,inv,page) return inv.priority or sortData.getDefaultSortPriority(inv,page) end}
require=function(name)
    if name=='BetterContainers/_Options' then return options end
    if name=='BetterContainers/Helpers' then return helpers end
    if name=='BetterContainers/Proximity' then return proximity end
    if name=='BetterContainers/Reorder' then return reorder end
    if name=='BetterContainers/Reorder/ContainerButton' then return {getInstance=function(_,b) return b end} end
    if name=='BetterContainers/Constants' then return {SORT_KEY='_sort',SET_MANUALLY='_manual'} end
    return {}
end
getTexture=noop
getTextManager=function() return {getFontHeight=function() return 12 end} end
UIFont={Small='small'}
ISMouseDrag={}
isClient=no
isGamePaused=no
getNumActivePlayers=function() return 1 end
getGameTime=function() return {getRealworldSecondsSinceLastUpdate=function() return 1/60 end} end
local tick=0
getTimestampMs=function() return tick end
local player={dir=0,square={}}
local playerData={}
function player:getModData() return playerData end
function player:getUsername() return 'fixture' end
function player:getInventory() return nil end
local oldInstanceof=instanceof
instanceof=function(value,kind) return kind=='IsoPlayer' and value==player or oldInstanceof(value,kind) end
function player:getDir() return self.dir end
function player:getCurrentSquare() return self.square end
function player:getJoypadBind() return -1 end
getSpecificPlayer=function() return player end
local page
getPlayerLoot=function() return page end
local copies,aggregations,refreshes,panes=0,0,0,0
local function list()
    local l={data={}}
    function l:size() return #self.data end
    function l:get(i) return self.data[i+1] end
    function l:clear() self.data={} end
    function l:addAll(other)
        for _,item in ipairs(other.data) do self.data[#self.data+1]=item copies=copies+1 end
    end
    return l
end
local function container(kind,real)
    local inv={items=list(),kind=kind,parent=real and {} or nil}
    function inv:getType() return self.kind end
    function inv:getParent() return self.parent end
    function inv:getContainingItem() return nil end
    function inv:getItems() return self.items end
    function inv:getEffectiveCapacity() return 1000 end
    return inv
end
local floor=container('floor',false)
local crate=container('crate',true)
for i=1,400 do crate.items.data[i]={id=i} end
local aggregate=container('proximityInv',false)
local function button(inv,id)
    local b={inventory=inv,ID=id,y=id*20}
    function b:getIsVisible() return true end
    function b:getY() return self.y end
    function b:setY(y) self.y=y end
    function b:getBottom() return self.y+20 end
    return b
end
ISInventoryPane={}
ISInventoryPage={update=noop,addContainerButton=noop,onJoypadDown=noop,
    setNewContainer=noop,selectButtonForContainer=noop,onMouseOutButton=noop}
function ISInventoryPage:setForceSelectedContainer(inv) self.forceSelectedContainer=inv end
function ISInventoryPage:selectContainer(b)
    self.inventory=b.inventory self.inventoryPane.inventory=b.inventory
    self:refreshBackpacks()
end
function ISInventoryPage:refreshBackpacks()
    refreshes=refreshes+1
    self.backpacks={button(crate,1),button(floor,2)}
    self.containerButtonPanel.children={}
    if eff.proximityActive then
        proximity.OnBeginRefresh(self)
        aggregations=aggregations+1
        proximity.OnButtonsAdded(self)
    end
    for _,b in ipairs(self.backpacks) do self.containerButtonPanel.children[b.ID]=b end
    self.inventoryPane:refreshContainer()
end
ISInventoryPage.dirtyUI=function() page:refreshBackpacks() end
loadWheel()
proximity=load_Proximity()
sortData=loadSortData()
proximity.itemContainer[0]=aggregate
proximity.AddProximityInventoryButton=function(p)
    local b=button(aggregate,3)
    table.insert(p.backpacks,1,b)
    return b,nil
end
proximity.isTransferActive=no
load_Reorder_Reorder_ISInventoryPage().install()
load_Proximity_Proximity_ISInventoryPage().install()
page=setmetatable({player=0,onCharacter=false,inventory=crate,backpacks={},buttonSize=20,
    height=300,lastDir=0,lastSquare=player.square,
    containerButtonPanel={width=20,height=300,children={},setHeight=noop,setY=noop,
        setScrollHeight=noop,getScrollHeight=function() return 100 end},
    updateContainerHighlight=noop,updateContainerOpenCloseSounds=noop,
    bcRefreshUtilityPanel=noop,bcIsFooterUtilityMode=function() return true end,
    getMouseX=function() return 399 end,getWidth=function() return 400 end,
    isCycleContainerKeyDown=function() return true end}, {__index=ISInventoryPage})
page.inventoryPane={inventory=crate,inventoryPage=page,height=280,y=20,
    refreshContainer=function() panes=panes+1 end}
function page:getCurrentBackpackIndex()
    for i,b in ipairs(self.backpacks) do if b.inventory==self.inventory then return i end end
end
function page:nextUnlockedContainer(i) return i%#self.backpacks+1 end
function page:prevUnlockedContainer(i) return (i+#self.backpacks-2)%#self.backpacks+1 end
for _,enabled in ipairs({false,true}) do
    eff.proximityActive=enabled
    page.inventory=enabled and aggregate or crate
    page.inventoryPane.inventory=page.inventory
    page:refreshBackpacks()
    copies,aggregations,refreshes,panes=0,0,0,0
    for i=1,600 do tick=tick+17 page:update() proximity.OnAutoLockTick() end
    assert(refreshes==0 and aggregations==0 and panes==0,'stationary refresh loop')
    print('PASS proximity=' .. tostring(enabled) .. ' 600 stationary updates: rebuilds=0 aggregation=0 paneRefresh=0')
    for i=1,10 do player.dir=i page:update() end
    assert(refreshes==10 and panes==10 and aggregations==(enabled and 10 or 0))
    assert(copies==(enabled and 4000 or 0))
    print('PASS proximity=' .. tostring(enabled) .. ' 10 turns: rebuilds=' .. refreshes .. ' paneRefresh=' .. panes .. ' copiedItems=' .. copies)
    if enabled then assert(aggregate.items:size()==400,'duplicated plates') end
end
eff.autoLock=true
page.inventory=aggregate page.inventoryPane.inventory=aggregate
copies,aggregations,refreshes,panes=0,0,0,0
for i=1,600 do tick=tick+17 page:update() proximity.OnAutoLockTick() end
assert(refreshes==0 and aggregations==0 and panes==0,'auto-lock stationary refresh loop')
print('PASS auto-lock enabled: 600 stationary updates without rebuilds')
eff.autoLock=false
-- Default floor ordering should not be displaced by virtual containers.
local without=sortData.getDefaultSortPriority(floor,{backpacks={button(crate,1),button(floor,2)}})
local with=sortData.getDefaultSortPriority(floor,{backpacks={button(aggregate,3),button(crate,1),button(floor,2)}})
print('Floor default priority: proximity off=' .. without .. ' on=' .. with)
assert(without==0 and with==without,'Proximity displaced default ground priority')
local corpse=container('twistInv_corpses',false)
assert(sortData.getDefaultSortPriority(floor,{backpacks={button(aggregate,3),button(corpse,4),button(floor,2)}})==0,
    'dual Proximity displaced default ground priority')
-- Explicit priorities must survive switching through the actual wheel wrapper.
crate.priority=30 floor.priority=5 aggregate.priority=-20
sortData.setSortPriority(player,floor,5,true)
reorder.getSortPriority=function(_,inv,p)
    if inv==floor then return sortData.getSortPriority(player,inv) or sortData.getDefaultSortPriority(inv,p) end
    return inv.priority or sortData.getDefaultSortPriority(inv,p)
end
page:refreshBackpacks()
for i=1,20 do
    page:onMouseWheel(1)
    local positions={}
    for _,b in ipairs(page.backpacks) do positions[b.inventory]=b.y end
    assert(positions[aggregate]<positions[floor] and positions[floor]<positions[crate],'explicit priority lost')
    assert(sortData.getSortPriority(player,floor)==5 and sortData.isManual(player,floor),'saved ground priority lost')
end
print('PASS 20 Shift+Scroll switches preserve explicit floor priority')
loadSidesWheel()
for _,enabled in ipairs({false,true}) do
    eff.proximityActive=enabled
    for _,left in ipairs({false,true}) do
        page.isPageLeft_BetterContainers=function() return left end
        page.inventory=floor page.inventoryPane.inventory=floor
        page:refreshBackpacks()
        page:onMouseWheel(1)
        assert(page.inventory==crate,'wheel must select crate below floor; left=' .. tostring(left))
        page:onMouseWheel(-1)
        assert(page.inventory==floor,'reverse wheel must return to floor')
    end
end
print('PASS left/right wheel selects visual neighbour with Proximity off/on')

-- Actual Proximity-only drop-control predicate, independent of pane rebuilding.
local reads=0
local source=crate
for _,item in ipairs(crate.items.data) do
    item.getContainer=function() reads=reads+1 return source end
    item.isFavorite=no
end
local visible=loadDropVisibility()(proximity,{isHidden=no})
local handler={container=aggregate,playerNum=0,playerObj=player}
for _,kind in ipairs({'crate','floor'}) do
    source=kind=='crate' and crate or floor
    reads=0
    for i=1,600 do visible(handler) end
    assert(reads==(kind=='crate' and 600 or 240000))
    print('PASS Proximity drop visibility, 400 plates sourced from ' .. kind .. ': item checks over 600 calls=' .. reads)
end
