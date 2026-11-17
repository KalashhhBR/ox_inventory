import re
items=re.findall(r"^\s*\[[\"']([^\"']+)[\"']\]\s*=\s*\{",open('data/items.lua').read(),re.M)
w=open('data/weapons.lua').read()
idx=sorted((re.search(r"\t"+x+r" = \{",w).start(),x) for x in ['Weapons','Components','Ammo'])
sec={}
for k,(st,nm) in enumerate(idx):
    en=idx[k+1][0] if k+1<len(idx) else len(w)
    sec[nm]=re.findall(r"^\t\t\['([^']+)'\]\s*=\s*\{",w[st:en],re.M)

S={}  # name -> (w,h,stack or None)
def put(names,w_,h_,stack=None):
    for n in names.split():
        assert n not in S, n
        S[n]=(w_,h_,stack)

# ---- items
G=[]
def group(title, fn):
    before=set(S); fn(); G.append((title,[n for n in S if n not in before]))

def food():
    put('testburger burger sandwich mustard',1,1,5); put('sprunk coffee beer',1,1,6); put('grape',1,1,20)
    put('water grapejuice',1,2,5); put('wine vodka whiskey',1,2,3)
group('Food and drink',food)
def med():
    put('bandage painkillers',1,1,10); put('ifaks',1,1,5); put('firstaid',2,2,2)
group('Medical',med)
def money():
    put('money black_money',1,1,0)
group('Money (wallet on players, 1x1 without stack limit elsewhere)',money)
def docs():
    put('id_card driver_license weaponlicense lawyerpass security_card_01 security_card_02',1,1,1); put('stickynote',1,1,10)
group('Documents and cards',docs)
def elec():
    put('phone radio',1,2,1); put('radiocell lighter gatecrack',1,1,1); put('cryptostick trojan_usb',1,1,5)
    put('binoculars',2,1,1); put('jammer toaster electronickit',2,2,1); put('small_tv',3,2,1)
group('Electronics and gadgets',elec)
def tools():
    put('lockpick advancedlockpick',1,1,5); put('handcuffs',1,1,3); put('screwdriverset cleaningkit',2,1,1)
    put('repairkit harness parachute',2,2,1); put('advancedrepairkit drill',3,2,1); put('thermite',1,2,5)
    put('walking_stick',4,1,1); put('jerry_can nitrous diving_fill',2,3,1); put('diving_gear',3,3,1)
    put('firework1 firework2 firework3 firework4',2,2,2)
group('Tools and equipment',tools)
def val():
    put('diamond',1,1,20); put('diamond_ring rolex goldchain 10kgoldchain',1,1,10); put('goldbar',2,1,5)
    put('antipatharia_coral dendrogyra_coral',2,2,5)
group('Valuables',val)
def drugs():
    put('crack_baggy cokebaggy xtcbaggy meth oxy joint',1,1,50)
    put('weed_ak47 weed_skunk weed_amnesia weed_og-kush weed_white-widow weed_purple-haze',1,1,50)
    put('weed_ak47_seed weed_skunk_seed weed_amnesia_seed weed_og-kush_seed weed_white-widow_seed weed_purple-haze_seed',1,1,50)
    put('rolling_paper empty_weed_bag',1,1,50); put('coke_small_brick',1,1,10); put('coke_brick weed_brick',2,1,5); put('weed_nutrition',1,2,5)
group('Drugs and growing',drugs)
def mats():
    put('steel rubber metalscrap iron copper aluminum plastic glass',1,1,50)
group('Materials',mats)
def misc():
    put('garbage',1,1,10); put('panties',1,1,5); put('paperbag',2,2,1); put('empty_evidence_bag',1,1,20); put('filled_evidence_bag',1,1,1)
    put('clothing',2,2,1)
group('Misc',misc)
def cloth():
    put('clothing_mask clothing_glasses clothing_ears clothing_neck clothing_gloves clothing_watch clothing_bracelet',1,1,1)
    put('clothing_hat clothing_shoes',2,1,1); put('clothing_top clothing_undershirt clothing_pants',2,2,1); put('armour',3,3,1)
    put('backpack_small',2,2,1); put('backpack_medium',3,3,1); put('backpack_large',4,3,1)
group('Clothing, vest and backpacks',cloth)
def ammo():
    put('ammo-22 ammo-38 ammo-44 ammo-45 ammo-50 ammo-9 ammo-rifle ammo-rifle2',1,1,60); put('ammo-laser',1,1,100)
    put('ammo-shotgun',1,1,24); put('ammo-sniper ammo-musket ammo-railgun',1,1,20); put('ammo-heavysniper ammo-flare',1,1,10)
    put('ammo-grenade ammo-firework ammo-emp',1,1,5); put('ammo-rocket',3,1,1)
group('Ammo',ammo)
def comps():
    put('at_suppressor_light at_suppressor_heavy at_barrel at_scope_medium at_scope_large at_scope_advanced at_scope_nv at_scope_thermal',2,1)
    put(' '.join(n for n in sec['Components'] if n.startswith('at_clip_extended')),1,2)
    put('at_clip_drum_smg at_clip_drum_shotgun at_clip_drum_rifle',2,2)
    put(' '.join(n for n in sec['Components'] if n not in S),1,1)
group('Weapon components',comps)
def W(n): return ' '.join('WEAPON_'+x for x in n.split())
def wp1(): put(W('PISTOL PISTOL_MK2 COMBATPISTOL APPISTOL PISTOL50 HEAVYPISTOL SNSPISTOL SNSPISTOL_MK2 VINTAGEPISTOL CERAMICPISTOL PISTOLXM3 GADGETPISTOL MARKSMANPISTOL REVOLVER REVOLVER_MK2 DOUBLEACTION NAVYREVOLVER FLAREGUN STUNGUN RAYPISTOL'),2,1)
group('Pistols',wp1)
def wp2():
    put(W('MICROSMG MINISMG MACHINEPISTOL TECPISTOL'),2,2); put(W('SAWNOFFSHOTGUN DBSHOTGUN'),3,1)
    put(W('SMG SMG_MK2 ASSAULTSMG COMBATPDW COMPACTRIFLE AUTOSHOTGUN COMPACTLAUNCHER'),3,2)
group('Compact weapons and SMGs',wp2)
def wp3(): put(W('ASSAULTRIFLE ASSAULTRIFLE_MK2 CARBINERIFLE CARBINERIFLE_MK2 ADVANCEDRIFLE SPECIALCARBINE SPECIALCARBINE_MK2 BULLPUPRIFLE BULLPUPRIFLE_MK2 MILITARYRIFLE HEAVYRIFLE TACTICALRIFLE BATTLERIFLE GUSENBERG RAYCARBINE PUMPSHOTGUN PUMPSHOTGUN_MK2 ASSAULTSHOTGUN BULLPUPSHOTGUN HEAVYSHOTGUN COMBATSHOTGUN GRENADELAUNCHER EMPLAUNCHER SNOWLAUNCHER'),4,2)
group('Rifles, shotguns and small launchers',wp3)
def wp4():
    put(W('MG COMBATMG COMBATMG_MK2 SNIPERRIFLE HEAVYSNIPER HEAVYSNIPER_MK2 MARKSMANRIFLE MARKSMANRIFLE_MK2 PRECISIONRIFLE MUSKET RPG HOMINGLAUNCHER RAILGUN RAILGUNXM3 FIREWORK'),5,2)
    put(W('MINIGUN RAYMINIGUN'),5,3)
group('Machine guns, snipers and heavy weapons',wp4)
def melee():
    put(W('KNUCKLE SWITCHBLADE'),1,1); put(W('KNIFE DAGGER HAMMER WRENCH FLASHLIGHT'),2,1); put(W('BOTTLE'),1,2)
    put(W('HATCHET STONE_HATCHET BATTLEAXE MACHETE CROWBAR NIGHTSTICK CANDYCANE'),3,1); put(W('BAT GOLFCLUB'),4,1); put(W('POOLCUE'),5,1)
group('Melee',melee)
def thr():
    put(W('GRENADE SMOKEGRENADE BZGAS TEARGAS PIPEBOMB STICKYBOMB PROXMINE'),1,1,3); put(W('MOLOTOV'),1,2,3)
    put(W('FLARE BALL'),1,1,5); put(W('SNOWBALL'),1,1,10)
group('Throwables',thr)
def cans(): put(W('PETROLCAN HAZARDCAN FERTILIZERCAN FIREEXTINGUISHER'),2,3); put(W('METALDETECTOR'),3,2)
group('Cans and utility',cans)

allnames=items+sec['Weapons']+sec['Components']+sec['Ammo']
missing=[n for n in allnames if n not in S]; extra=[n for n in S if n not in allnames]
assert not missing and not extra,(missing,extra)
for n,(a,b,_) in S.items(): assert (a<=8 and b<=5) or (b<=8 and a<=5), n


GRID_LUA = """-- klsh: grid inventory settings (plan section 11).
-- Per item settings live with the item itself, in data/items.lua and data/weapons.lua:
--   size = { width, height }   cells the item takes (items rotate freely); default 1 x 1
--   maxStack = 60              most units in one stack; false = no limit; default below
return {
    -- master switch. Off: the fork behaves exactly as before the grid (slots), positions are kept
    enabled = false,

    -- GR2 only: every item counts as 1 x 1 while the screen is still the slot one
    forceUnit = true,

    -- player inventory, replaces the `inventory:slots` convar
    player = { w = 8, h = 5 },

    -- drops no longer inherit `inventory:slots`
    drop = { w = 8, h = 5 },

    -- worn or opened backpacks, by item name (the stored metadata.size is not used)
    backpacks = {
        backpack_small = { w = 4, h = 4 },
        backpack_medium = { w = 6, h = 5 },
        backpack_large = { w = 8, h = 6 },
    },

    -- everything else registers `slots`; the grid is `width` wide and ceil(slots / width) tall,
    -- never below the minimum height of its type
    width = 10,
    minHeight = { stash = 4, trunk = 4, glovebox = 2, dumpster = 3, container = 1, policeevidence = 5, temp = 4, default = 3 },

    -- exceptions by inventory type or name: ['type'] or ['name'] = { w = 10, h = 6 }
    overrides = {},

    -- account items kept in the player's wallet slots, outside the grid (always fit, never dropped)
    wallet = { 'money', 'black_money' },

    -- delivered without room: goes to a public ground drop that lasts this long (seconds)
    overflowTime = 900,

    -- never go to the ground for lack of room: the delivery fails and the player is warned
    neverDrop = { 'id_card', 'driver_license', 'weaponlicense', 'lawyerpass', 'security_card_01', 'security_card_02' },

    -- items without `size` / `maxStack` in data/items.lua or data/weapons.lua
    defaultSize = { 1, 1 },
    defaultStack = 20,
}
"""
open('data/grid.lua','w').write(GRID_LUA)

def inject(path):
    lines=open(path).read().split('\n'); out=[]; i=0; done=0
    while i<len(lines):
        m=re.match(r"^(\s*)\[[\"']([^\"']+)[\"']\]\s*=\s*\{\s*$",lines[i])
        out.append(lines[i]); i+=1
        if not m or m.group(2) not in S: continue
        ind,name=m.group(1),m.group(2); step='\t' if ind.startswith('\t') else '    '
        # keep label / weight first, then our fields
        while i<len(lines) and re.match(r"^\s*(label|weight)\s*=",lines[i]):
            assert lines[i].rstrip().endswith(','),(path,name,lines[i]); out.append(lines[i]); i+=1
        j=i; body=[]
        while j<len(lines) and not lines[j].startswith(ind+'}'): body.append(lines[j]); j+=1
        assert not any(re.match(r"^\s*(size|maxStack)\s*=",b) and b.startswith(ind+step) and not b.startswith(ind+step+step) for b in body),(name,'already has size')
        w_,h_,st=S[name]
        if (w_,h_)!=(1,1): out.append('%s%ssize = { %d, %d },'%(ind,step,w_,h_))
        if st is not None: out.append('%s%smaxStack = %s,'%(ind,step,'false' if st==0 else st))
        done+=1
    open(path,'w').write('\n'.join(out)); return done
print(inject('data/items.lua'),inject('data/weapons.lua'))
