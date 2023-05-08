#pragma semicolon 1
#pragma newdecls required

#include <sdktools_functions>
#include <vip_core>

ConVar
	cvEnable;

VIP_ToggleState
	bEnableStats[MAXPLAYERS+1] = {ENABLED, ...};

int
	iTypeGrenade[3] =
	{
		11,
		12,
		13
	};

static const char sGrenadeNameList[][] = 
{
	"weapon_hegrenade",
	"weapon_flashbang",
	"weapon_smokegrenade"
};

static const char g_sFeature[][] = 
{
	"Give_GrenadeHe",
	"Give_GrenadeFl",
	"Give_GrenadeSmoke"
};

public Plugin myinfo = 
{
	name = "[ViP Core] Give Grenade/Выдача гранат",
	author = "Nek.'a 2x2 | ggwp.site ",
	description = "Выдача гранат",
	version = "1.0.0",
	url = "https://ggwp.site/"
};

public void OnPluginStart() 
{
	cvEnable = CreateConVar("sm_vip_givegrenade_enable", "1", "1 - Включить | 0 - Выключить плагин");

	HookEvent("player_spawn", Event_PlayerSpawn);

	if(VIP_IsVIPLoaded()) VIP_OnVIPLoaded();
}

public void VIP_OnVIPLoaded()
{
	for(int i = 0; i < 3; i++) 
	{	//Проверяет существование функции. VIP_IsValidFeature
		if(!VIP_IsValidFeature(g_sFeature[i]))
			VIP_RegisterFeature(g_sFeature[i], INT, TOGGLABLE, OnSelectItem, OnDisplayItem, OnDrawItem);
			 /*
				OnSelectItem - Функция будет вызыватся при нажатии на пункт
				OnDisplayItem - Функция будет вызыватся при отображении текста пункта
				OnDrawItem - Функция будет вызыватся при отображении стиля пункта
			*/
		else SetFailState("Feature '%s' already in use", g_sFeature[i]);
	}
}

//Нажатие в вип меню ItemSelectCallback
public Action OnSelectItem(int client, const char[] szFeature, VIP_ToggleState eOldStatus, VIP_ToggleState &eNewStatus)
{
	bEnableStats[client] = eNewStatus;
	return Plugin_Continue;
}

public void VIP_OnVIPClientLoaded(int client)
{	//Возвращает статус VIP-функции у игрока. VIP_IsClientFeatureUse
	for(int i = 0; i < 3; i++) if(VIP_IsClientFeatureUse(client, g_sFeature[i]))
	{
		bEnableStats[client] = ENABLED;
	}
}

public bool OnDisplayItem(int client, const char[] sFeatureName, char[] sDisplay, int maxlen)
{	
	//Вызывается когда VIP-игроку отображается пункт в меню. ItemDisplayCallback
	if(!VIP_GetClientFeatureStatus(client, sFeatureName))
		return false;

	//Получает целочисленное значение параметра VIP-функции у игрока. VIP_GetClientFeatureInt
	int count = VIP_GetClientFeatureInt(client, sFeatureName);		//
	if(count) 
	{
		//FormatEx(sDisplay, maxlen, "%T [Доступно: %i]", sFeatureName, client, count);

		
		if(sFeatureName[12] == 'H')
			Format(sDisplay, maxlen, "Автовыдача гранат: [Доступно %d]", count);
		if(sFeatureName[12] == 'F')
			Format(sDisplay, maxlen, "Автовыдача флешек: [Доступно %d]", count);
		if(sFeatureName[12] == 'S')
			Format(sDisplay, maxlen, "Автовыдача дыма: [Доступно %d]", count);
			
	}
	else FormatEx(sDisplay, maxlen, "%T", sFeatureName, client);
	return true;
}

public int OnDrawItem(int client, const char[] sFeatureName, int iStyle)
{
	if(VIP_GetClientFeatureStatus(client, sFeatureName) == NO_ACCESS || !VIP_GetClientFeatureInt(client, g_sFeature[0]))
		return ITEMDRAW_DISABLED;

	return iStyle;
}

public void OnPluginEnd()
{
	for(int i = 0; i < 3; i++)
	{
		if(CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "VIP_UnregisterFeature") == FeatureStatus_Available && VIP_IsValidFeature(g_sFeature[i]))
		{
			VIP_UnregisterFeature(g_sFeature[i]);
		}
	}
}

void Event_PlayerSpawn(Event hEvent, const char[] name, bool dontBroadcast)
{
	if(!cvEnable.BoolValue)
		return;

	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(IsClientValid(client) && !IsFakeClient(client))
	{
		for(int i = 0; i < 3; i++) if(VIP_GetClientFeatureStatus(client, g_sFeature[i]) && VIP_GetClientFeatureInt(client, g_sFeature[i]))
		{
			GiveGrenade(client, iTypeGrenade[i], sGrenadeNameList[i], VIP_GetClientFeatureInt(client, g_sFeature[i]));
		}
	}
}

void GiveGrenade(int client, int GrenadeType, char[] sGrenadeName, int count)
{
	if (GetEntProp(client, Prop_Send, "m_iAmmo", _, GrenadeType) < 1)
	{
		GivePlayerItem(client, sGrenadeName);
	}
	SetEntProp(client, Prop_Send, "m_iAmmo", count, _, GrenadeType);
	PrintToChatAll("Выдан тип гранат [%d] игроку [%N] в количестве [%d]", GrenadeType, client, count);
}

bool IsClientValid(int client)
{
	return 0 < client <= MaxClients && IsClientInGame(client);
}