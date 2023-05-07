#pragma semicolon 1

#include <sourcemod>
#include <sdktools_functions>
#include <vip_ws>

public Plugin:myinfo = 
{
	name	= "VIP [Grenade Giver]",
	author	= "wS",
	version = "1.3.3"
};

enum struct VipModule
{
	int he;
	int fb;
	int sg;
	int mt;
	int dc;
	int ta;
}

new const String:ITEM_NAME[][] = 
{
	"weapon_hegrenade",
	"weapon_flashbang",
	"weapon_smokegrenade",
	"weapon_molotov",
	"weapon_decoy",
	"weapon_tagrenade"
};

#define MAX_GREN_COUNT 999

new bool:g_bCSGO;
new g_AmmoType[VipModule];
new g_bAccess[MAXPLAYERS + 1][VipModule];
new g_ItemID[VipModule];

public OnPluginStart()
{
	///
	new bool:ok = false;
	new Handle:kv = CreateKeyValues("grenade_giver");
	if (FileToKeyValues(kv, "cfg/vip/modules/grenade_giver/grenade_giver.txt"))
	{
		for (new VipModule:module; module < VipModule; module++)
		{
			if (KvGetNum(kv, ITEM_NAME[module]) == 1)
			{
				if (!(g_ItemID[module] = VIP_RegisterItem(ITEM_NAME[module], VIP_ITEM_TOGGLE)))
					SetFailState("VIP_RegisterItem error (%s)", ITEM_NAME[module]);
				ok = true;
			}
		}
	}
	CloseHandle(kv);
	if (!ok) SetFailState("Check cfg/vip/modules/grenade_giver/grenade_giver.txt");
	///

	LoadTranslations("vip_modules_description.phrases");
	
	if ((g_bCSGO = GetEngineVersion() == Engine_CSGO))
	{
		g_AmmoType[he] = 14;
		g_AmmoType[fb] = 15;
		g_AmmoType[sg] = 16;
		g_AmmoType[mt] = 17;
		g_AmmoType[dc] = 18;
		g_AmmoType[ta] = 22;

		new Handle:hCvar = FindConVar("ammo_grenade_limit_total");
		if (hCvar)
		{
			wS_ControlLimit(hCvar);
			HookConVarChange(hCvar, cvar_changed);
		}
	}
	else
	{
		g_AmmoType[he] = 11;
		g_AmmoType[fb] = 12;
		g_AmmoType[sg] = 13;
		g_AmmoType[mt] = -1;
		g_AmmoType[dc] = -1;
		g_AmmoType[ta] = -1;
	}

	VIP_HookEvent(VE_Spawn, OnClientSpawn);
}


public cvar_changed(Handle:hCvar, const String:OldValue[], const String:NewValue[]) wS_ControlLimit(hCvar);
stock wS_ControlLimit(Handle:hCvar) { if (GetConVarInt(hCvar) < 6) SetConVarInt(hCvar, 6); }

///////////////////////////////////////////////////////////////////////////////////

public bool:VIP_CurrentItemValue(client, ItemID, String:ItemValue[], ItemValueSize)
{
	new VipModule:module = wS_ItemIDToModule(ItemID);
	if (g_bAccess[client][module])
	{
		IntToString(g_bAccess[client][module], ItemValue, ItemValueSize);
		return true;
	}
	ItemValue[0] = 0;
	return false;
}

public bool:VIP_Description(client, ItemID, String:ItemValue[ITEM_INFO_LENGTH], String:description[], description_size)
{
	FormatEx(description, description_size, "%T", "grenade_count", client, StringToInt(ItemValue));
	return true;
}

public VipGiveAction:VIP_GiveAccess(client, ItemID, String:ItemValue[ITEM_INFO_LENGTH], bool:bCallAfterAdminAction, CURRENT_ACCESS, Handle:kv)
{
	return UpdateAccess(client, ItemValue, wS_ItemIDToModule(ItemID));
}

public VIP_TakeAccess(client, ItemID, bool:bToggledByClient)
{
	new VipModule:module = wS_ItemIDToModule(ItemID);
	g_bAccess[client][module] = 0;
	VIP_NotifyItemStatusChanged(client, ITEM_NAME[module], false);
}

stock VipGiveAction:UpdateAccess(client, String:ItemValue[ITEM_INFO_LENGTH], VipModule:module)
{
	if (!ItemValue[0])
		return VGA_ValueNotSpecified;
	
	new value = StringToInt(ItemValue);
	if (value < 1)
		return VGA_BadValue;
	
	if (value > MAX_GREN_COUNT)
		value = MAX_GREN_COUNT;
	
	if (value == g_bAccess[client][module])
		return VGA_SameValue;
	
	g_bAccess[client][module] = value;
	
	IntToString(value, ItemValue, ITEM_INFO_LENGTH);
	VIP_NotifyItemStatusChanged(client, ITEM_NAME[module], true, ItemValue, 16);

	return VGA_Continue;
}

///////////////////////////////////////////////////////////////////////////////////

public OnClientSpawn(client, team)
{
	if (g_bCSGO)
	{
		decl VipModule:module, g;
		new bool:bNeedGive[VipModule], bool:bVIP = false;

		// ��������� m_iAmmo, ����� ��� �� ���� > 1, ����� ����� �� ������ ��� ������ �� �����.
		for (module = VipModule:0; module < VipModule; module++)
		{
			if (g_bAccess[client][module])
			{
				bVIP = true;
				if ((g = GetEntProp(client, Prop_Send, "m_iAmmo", _, g_AmmoType[module])) > 0)
				{
					if (g > 1)
						SetEntProp(client, Prop_Send, "m_iAmmo", 1, _, g_AmmoType[module]);
				}
				else
					bNeedGive[module] = true;
			}
		}

		if (!bVIP)
			return;
		
		for (module = VipModule:0; module < VipModule; module++)
		{
			if (bNeedGive[module])
				GivePlayerItem(client, ITEM_NAME[module]);
			
			if (g_bAccess[client][module] > 1)
				SetEntProp(client, Prop_Send, "m_iAmmo", g_bAccess[client][module], _, g_AmmoType[module]);
		}
	}
	else
	{
		wS_TryGive(client, he);
		wS_TryGive(client, fb);
		wS_TryGive(client, sg);
	}
}

stock wS_TryGive(client, VipModule:module) // css
{
	if (g_bAccess[client][module])
	{
		if (GetEntProp(client, Prop_Send, "m_iAmmo", _, g_AmmoType[module]) < 1) GivePlayerItem(client, ITEM_NAME[module]);
		SetEntProp(client, Prop_Send, "m_iAmmo", g_bAccess[client][module], _, g_AmmoType[module]);
	}
}

stock VipModule:wS_ItemIDToModule(ItemID)
{
	for (new VipModule:module; module < VipModule; module++)
	{
		if (g_ItemID[module] == ItemID)
			return module;
	}
	return VipModule:0; // wtf
}

public OnClientDisconnect(client)
{
	for (new VipModule:module; module < VipModule; module++)
		g_bAccess[client][module] = 0;
}