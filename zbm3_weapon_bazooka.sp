/**
 * ============================================================================
 *
 *  Zombie Plague Mod #3 Generation
 *
 *
 *  Copyright (C) 2015-2018 Nikita Ushakov (Ireland, Dublin)
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * ============================================================================
 **/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <zombieplague>

#pragma newdecls required

/**
 * Record plugin info.
 **/
public Plugin myinfo =
{
    name            = "[ZP] Weapon: Bazooka",
    author          = "qubka (Nikita Ushakov)",
    description     = "Addon of custom weapon",
    version         = "3.0",
    url             = "https://forums.alliedmods.net/showthread.php?t=290657"
}

/**
 * @section Information about weapon.
 **/
#define WEAPON_REFERANCE                "Bazooka" // Models and other properties in the 'weapons.ini'
#define WEAPON_SPEED                    1.0   
#define WEAPON_ROCKET_SPEED             2000.0
#define WEAPON_ROCKET_GRAVITY           0.01
#define WEAPON_ROCKET_RADIUS            250000.0 // [squared]
#define WEAPON_ROCKET_DAMAGE            700.0
#define WEAPON_ROCKET_EXPLOSION         0.1
#define WEAPON_ROCKET_SHAKE_AMP         10.0
#define WEAPON_ROCKET_SHAKE_FREQUENCY   1.0
#define WEAPON_ROCKET_SHAKE_DURATION    2.0
#define WEAPON_EFFECT_TIME              5.0
#define WEAPON_EXPLOSION_TIME           2.0
/**
 * @endsection
 **/

/**
 * @section Explosion flags.
 **/
#define EXP_NODAMAGE          1
#define EXP_REPEATABLE        2
#define EXP_NOFIREBALL        4
#define EXP_NOSMOKE           8
#define EXP_NODECAL           16
#define EXP_NOSPARKS          32
#define EXP_NOSOUND           64
#define EXP_RANDOMORIENTATION 128
#define EXP_NOFIREBALLSMOKE   256
#define EXP_NOPARTICLES       512
#define EXP_NODLIGHTS         1024
#define EXP_NOCLAMPMIN        2048
#define EXP_NOCLAMPMAX        4096
/**
 * @endsection
 **/

// Initialize variables
int gWeapon;

// Variables for the key sound block
int gSound;

/**
 * Called after a zombie core is loaded.
 **/
public void ZP_OnEngineExecute(/*void*/)
{
    // Initilizate weapon
    gWeapon = ZP_GetWeaponNameID(WEAPON_REFERANCE);
    if(gWeapon == -1) SetFailState("[ZP] Custom weapon ID from name : \"%s\" wasn't find", WEAPON_REFERANCE);

    // Sounds
    gSound = ZP_GetSoundKeyID("BAZOOKA_SHOOT_SOUNDS");
}

/**
 * Called once a client is authorized and fully in-game, and 
 * after all post-connection authorizations have been performed.  
 *
 * This callback is gauranteed to occur on all clients, and always 
 * after each OnClientPutInServer() call.
 * 
 * @param clientIndex       The client index. 
 **/
public void OnClientPostAdminCheck(int clientIndex)
{
    // Hook entity callbacks
    SDKHook(clientIndex, SDKHook_WeaponSwitchPost, WeaponOnDeployPost);
}

/**
 * Called after a custom weapon is created.
 *
 * @param weaponIndex       The weapon index.
 * @param weaponID          The weapon id.
 **/
public void ZP_OnWeaponCreated(int weaponIndex, int weaponID)
{
    // Validate custom grenade
    if(weaponID == gWeapon) /* OR if(ZP_GetWeaponID(weaponIndex) == gWeapon)*/
    {
        // Hook entity callbacks
        SDKHook(weaponIndex, SDKHook_ReloadPost, WeaponOnReloadPost);
    }
}

/**
 * Hook: WeaponSwitchPost
 * Player deploy any weapon.
 *
 * @param clientIndex       The client index.
 * @param weaponIndex       The weapon index.
 **/
public void WeaponOnDeployPost(int clientIndex, int weaponIndex) 
{
    // Update weapon position on the next frame
    RequestFrame(view_as<RequestFrameCallback>(WeaponOnFakeDeployPost), GetClientUserId(clientIndex));
}

/**
 * FakeHook: WeaponSwitchPost
 *
 * @param userID            The user id.
 **/
public void WeaponOnFakeDeployPost(int userID)
{
    // Initialize weapon index
    static int weaponIndex;
    
    // Gets the client index from the user ID
    int clientIndex = GetClientOfUserId(userID);

    // Validate client
    if(ZP_IsPlayerHoldWeapon(clientIndex, weaponIndex, gWeapon))
    {
        // Initialize vector variables
        static float flStart[3]; 
        
        // Update weapon position
        ZP_GetWeaponAttachmentPos(clientIndex, "muzzle_flash", flStart);
        
        // Resets the custom attack
        SetEntPropFloat(weaponIndex, Prop_Send, "m_flEncodedController", GetGameTime() + ZP_GetWeaponDeploy(gWeapon));
    }
}

/**
 * Hook: WeaponReloadPost
 * Weapon is reloaded.
 *
 * @param weaponIndex       The weapon index.
 **/
public Action WeaponOnReloadPost(int weaponIndex) 
{
    // Apply fake reload hook on the next frame
    RequestFrame(view_as<RequestFrameCallback>(WeaponOnFakeReloadPost), weaponIndex);
}

/**
 * FakeHook: WeaponReloadPost
 *
 * @param referenceIndex    The reference index.
 **/
public void WeaponOnFakeReloadPost(int referenceIndex) 
{
    // Get the weapon index from the reference
    int weaponIndex = EntRefToEntIndex(referenceIndex);

    // Validate weapon
    if(weaponIndex != INVALID_ENT_REFERENCE)
    {
        // Resets the custom attack
        SetEntPropFloat(weaponIndex, Prop_Send, "m_flEncodedController", GetGameTime() + ZP_GetWeaponReload(gWeapon));
    }
}

/**
 * Called when a clients movement buttons are being processed.
 *  
 * @param clientIndex       The client index.
 * @param iButtons          Copyback buffer containing the current commands (as bitflags - see entity_prop_stocks.inc).
 * @param iImpulse          Copyback buffer containing the current impulse command.
 * @param flVelocity        Players desired velocity.
 * @param flAngles          Players desired view angles.    
 * @param weaponID          The entity index of the new weapon if player switches weapon, 0 otherwise.
 * @param iSubType          Weapon subtype when selected from a menu.
 * @param iCmdNum           Command number. Increments from the first command sent.
 * @param iTickCount        Tick count. A client prediction based on the server GetGameTickCount value.
 * @param iSeed             Random seed. Used to determine weapon recoil, spread, and other predicted elements.
 * @param iMouse            Mouse direction (x, y).
 **/ 
public Action OnPlayerRunCmd(int clientIndex, int &iButtons, int &iImpulse, float flVelocity[3], float flAngles[3], int &weaponID, int &iSubType, int &iCmdNum, int &iTickCount, int &iSeed, int iMouse[2])
{
    // Initialize variable
    static int nLastButtons[MAXPLAYERS+1];
    
    // Button attack hook
    if(iButtons & IN_ATTACK)
    {
        // Validate overtransmitting
        if(!(nLastButtons[clientIndex] & IN_ATTACK))
        {
            // Initialize weapon index
            static int weaponIndex;

            // Validate weapon
            if(ZP_IsPlayerHoldWeapon(clientIndex, weaponIndex, gWeapon))
            {
                // Returns the game time based on the game tick
                float flCurrentTime = GetGameTime();

                // Validate ammo
                int iClip = GetEntProp(weaponIndex, Prop_Send, "m_iClip1");
                if(iClip <= 0)
                {
                    SetEntPropFloat(weaponIndex, Prop_Send, "m_flNextPrimaryAttack", flCurrentTime); //! Reset for allow reloading
                    return;
                }
                
                // Validate reload
                if(!GetEntProp(weaponIndex, Prop_Data, "m_bInReload"))
                {
                    // Block the real attack
                    SetEntPropFloat(weaponIndex, Prop_Send, "m_flNextPrimaryAttack", flCurrentTime + 9999.9);
                }
                else return;
                
                // Validate attack
                if(GetEntPropFloat(weaponIndex, Prop_Send, "m_flEncodedController") > flCurrentTime)
                {
                    return;
                }

                // Sets the next attack time
                SetEntPropFloat(weaponIndex, Prop_Send, "m_flEncodedController", flCurrentTime + ZP_GetWeaponSpeed(gWeapon)); //! Add 0.5 to play idle to update state

                // Substract ammo
                iClip -= 1;
                SetEntProp(weaponIndex, Prop_Send, "m_iClip1", iClip); 
                if(!iClip) SetEntPropFloat(weaponIndex, Prop_Send, "m_flNextPrimaryAttack", flCurrentTime); //! Reset for allow reloading
                
                // Gets the client viewmodel
                int viewModel = GetEntPropEnt(clientIndex, Prop_Send, "m_hViewModel");
                
                // Validate viewmodel
                if(IsValidEdict(viewModel))
                {
                    // Sets the attack animation
                    SetEntProp(viewModel, Prop_Send, "m_nSequence", 1);
                }
                
                // Emit sound
                ZP_EmitSoundKeyID(weaponIndex, gSound, SNDCHAN_WEAPON, 3);
                
                /*________________________________________________________________________________________________________________*/
                
                // Initialize vectors
                static float vPosition[3]; static float vAngle[3]; static float vVelocity[3]; static float vEntVelocity[3];
                
                // Gets the weapon's shoot position
                ZP_GetWeaponAttachmentPos(clientIndex, "muzzle_flash", vPosition);

                // Gets the client's eye angle
                GetClientEyeAngles(clientIndex, vAngle);

                // Gets the client's speed
                GetEntPropVector(clientIndex, Prop_Data, "m_vecVelocity", vVelocity);

                // Create a rocket entity
                int entityIndex = CreateEntityByName("hegrenade_projectile");

                // Validate entity
                if(entityIndex != INVALID_ENT_REFERENCE)
                {
                    // Spawn the entity
                    DispatchSpawn(entityIndex);

                    // Returns vectors in the direction of an angle
                    GetAngleVectors(vAngle, vEntVelocity, NULL_VECTOR, NULL_VECTOR);

                    // Normalize the vector (equal magnitude at varying distances)
                    NormalizeVector(vEntVelocity, vEntVelocity);

                    // Apply the magnitude by scaling the vector
                    ScaleVector(vEntVelocity, WEAPON_ROCKET_SPEED);

                    // Adds two vectors
                    AddVectors(vEntVelocity, vVelocity, vEntVelocity);

                    // Push the rocket
                    TeleportEntity(entityIndex, vPosition, vAngle, vEntVelocity);

                    // Sets the model
                    SetEntityModel(entityIndex, "models/player/custom_player/zombie/bazooka/bazooka_w_projectile.mdl");

                    // Create an effect
                    FakeCreateParticle(entityIndex, _, "smoking", WEAPON_EFFECT_TIME);

                    // Sets the parent for the entity
                    SetEntPropEnt(entityIndex, Prop_Data, "m_pParent", clientIndex); 
                    SetEntPropEnt(entityIndex, Prop_Send, "m_hOwnerEntity", clientIndex);
                    SetEntPropEnt(entityIndex, Prop_Send, "m_hThrower", clientIndex);

                    // Sets the gravity
                    SetEntPropFloat(entityIndex, Prop_Data, "m_flGravity", WEAPON_ROCKET_GRAVITY); 
                    
                    // Emit sound
                    ZP_EmitSoundKeyID(entityIndex, gSound, SNDCHAN_STATIC, 1);
                    
                    // Create touch hook
                    SDKHook(entityIndex, SDKHook_Touch, RocketTouchHook);
                }
            }
        }
    }
    // Button reload hook
    if(iButtons & IN_RELOAD)
    {
        // Validate overtransmitting
        if(!(nLastButtons[clientIndex] & IN_RELOAD))
        {
            // Initialize weapon index
            static int weaponIndex;

            // Validate weapon
            if(ZP_IsPlayerHoldWeapon(clientIndex, weaponIndex, gWeapon))
            {
                // Validate ammo
                if(GetEntProp(weaponIndex, Prop_Send, "m_iClip1") < ZP_GetWeaponClip(gWeapon))
                {
                    // Reset for allow reloading
                    SetEntPropFloat(weaponIndex, Prop_Send, "m_flNextPrimaryAttack", GetGameTime());
                }
            }
        }
    }
    
    // Store the button for next usage
    nLastButtons[clientIndex] = iButtons;
}

/**
 * Rocket touch hook.
 * 
 * @param entityIndex    The entity index.        
 * @param targetIndex    The target index.               
 **/
public Action RocketTouchHook(int entityIndex, int targetIndex)
{
    // Validate entity
    if(IsValidEdict(entityIndex))
    {
        // Validate target
        if(IsValidEdict(targetIndex))
        {
            // Gets the thrower index
            int throwerIndex = GetEntPropEnt(entityIndex, Prop_Send, "m_hThrower");

            // Validate thrower
            if(throwerIndex == targetIndex)
            {
                // Return on the unsuccess
                return Plugin_Continue;
            }

            // Initialize vectors
            static float vEntPosition[3]; static float vVictimPosition[3];

            // Gets the entity's position
            GetEntPropVector(entityIndex, Prop_Send, "m_vecOrigin", vEntPosition);

            // Create a info_target entity
            int infoIndex = FakeCreateEntity(vEntPosition, WEAPON_EXPLOSION_TIME);
            
            // Validate entity
            if(IsValidEdict(infoIndex))
            {
                // Create an explosion effect
                FakeCreateParticle(infoIndex, _, "expl_coopmission_skyboom", WEAPON_EXPLOSION_TIME);
                
                // Emit sound
                ZP_EmitSoundKeyID(infoIndex, gSound, SNDCHAN_STATIC, 2);
            }

            // Validate owner
            if(IsPlayerExist(throwerIndex))
            {
                // i = client index
                for(int i = 1; i <= MaxClients; i++)
                {
                    // Validate client
                    if(IsPlayerExist(i) && ZP_IsPlayerZombie(i))
                    {
                        // Gets victim's origin
                        GetClientAbsOrigin(i, vVictimPosition);

                        // Calculate the distance
                        float flDistance = GetVectorDistance(vEntPosition, vVictimPosition, true);

                        // Validate distance
                        if(flDistance <= WEAPON_ROCKET_RADIUS)
                        {
                            // Create the damage for a victim
                            SDKHooks_TakeDamage(i, throwerIndex, throwerIndex, WEAPON_ROCKET_DAMAGE);

                            // Create a shake
                            FakeCreateShakeScreen(i, WEAPON_ROCKET_SHAKE_AMP, WEAPON_ROCKET_SHAKE_FREQUENCY, WEAPON_ROCKET_SHAKE_DURATION);
                        }
                    }
                }
            }

            // Remove the entity from the world
            AcceptEntityInput(entityIndex, "Kill");
        }
    }

    // Return on the success
    return Plugin_Continue;
}