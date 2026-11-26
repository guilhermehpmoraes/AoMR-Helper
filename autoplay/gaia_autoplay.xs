// Loaded by the local player's human-assist script.
int gaiaBotBuildPlan = -1;
int gaiaBotBuildStarted = -1;
int gaiaBotBuildType = -1;
int[] gaiaBotRetryTypes = default;
int[] gaiaBotRetryCounts = default;
int gaiaBotManorPlan = -1;
int gaiaBotManorStarted = -1;
int gaiaBotLastHerdOrder = -100;
int gaiaBotLastIdleCheck = -100;
bool gaiaBotNeedsManorWood = false;
int gaiaBotPreviousMicroFlags = 0;
int gaiaBotLastOrder = -100;
int gaiaBotLastPower = -100;
int gaiaBotLastFarmCheck = -100;
int gaiaBotLastForestCheck = -100;
int gaiaBotForestPlan = -1;
bool gaiaBotForestUsed = false;
vector gaiaBotExpansion = cInvalidVector;
int[] gaiaBotScoutPlans = default;
int[] gaiaBotScoutedOracles = default;
int[] gaiaBotPostedOracles = default;
vector[] gaiaBotOraclePosts = default;
int gaiaBotLastOraclePostCheck = -100;
int gaiaBotWallPlan = -1;
int gaiaBotTradePlan = -1;
int gaiaBotTitanPlan = -1;
int gaiaBotRepairPlan = -1;
int gaiaBotRelicPlan = -1;
int gaiaBotRelicHero = -1;
int gaiaBotRelicTarget = -1;
int gaiaBotRelicTemple = -1;
int gaiaBotRelicDeadline = -1;
int gaiaBotRelicRetry = -1;
bool gaiaBotRelicReturning = false;
int gaiaBotTradeTown = -1;
int gaiaBotAttackTarget = -1;
int gaiaBotAge = -1;
int gaiaBotMatchMode = -1;
bool gaiaBotHadRaid = false;
bool gaiaBotWalled = false;
bool gaiaBotRunning = false;
bool gaiaBotRequested = false;
int gaiaBotGatheringRevision = -1;
vector gaiaBotRally = cInvalidVector;
int[] gaiaBotArmyOrders = default;

int gaiaBotDetectMatchMode()
{
   // Matchmaking uses the standard map pool. The renamed map is an explicit
   // lobby opt-in. Only slot 1 runs the bot, regardless of the host machine.
   if (cRandomMapName == "gaia_autoplay_coop")
      return cMyID == 1 ? 2 : 0;
   for (int player = 1; player < cNumberPlayers; player++)
   {
      if (player != cMyID && kbPlayerIsHuman(player))
         return 0;
   }
   return 1;
}

bool gaiaBotToggleCenter(int unitID = -1)
{
   if (kbUnitIsType(unitID, cUnitTypeAbstractTownCenter) == false)
      return false;
   if (gaiaBotMatchMode > 0 && kbUnitGetPlayerID(unitID) == cMyID)
      gaiaBotRequested = gaiaBotRequested == false;
   return true;
}

int gaiaBotQuery(int type = -1, int owner = -1, vector position = cInvalidVector, float distance = 0.0,
   int visibility = cUnitQueryVisibleStateVisible, int state = cUnitStateAlive)
{
   static int query = -1;
   if (query == -1)
      query = kbUnitQueryCreate("Gaia autoplay");
   kbUnitQueryResetData(query);
   kbUnitQueryResetResults(query);
   kbUnitQuerySetUnitType(query, type);
   kbUnitQuerySetState(query, state);
   kbUnitQuerySetVisibleState(query, visibility);
   if (owner >= 0)
      kbUnitQuerySetPlayerID(query, owner, false);
   else
      kbUnitQuerySetPlayerRelation(query, cPlayerRelationEnemyNotGaia, false);
   if (position != cInvalidVector)
   {
      kbUnitQuerySetPosition(query, position);
      kbUnitQuerySetMaximumDistance(query, distance);
      kbUnitQuerySetAscendingSort(query, true);
   }
   kbUnitQueryExecute(query);
   return query;
}

int gaiaBotFind(int type = -1, int owner = -1, vector position = cInvalidVector, float distance = 0.0,
   int visibility = cUnitQueryVisibleStateVisible, int state = cUnitStateAlive)
{
   int query = gaiaBotQuery(type, owner, position, distance, visibility, state);
   if (kbUnitQueryNumberResults(query) == 0)
      return -1;
   return kbUnitQueryGetResult(query, 0);
}

int gaiaBotCount(int type = -1)
{
   return kbUnitCount(type, cMyID, cUnitStateABQ);
}

int gaiaBotAllyPressure(vector home = cInvalidVector)
{
   int danger = -1;
   float closest = 180.0;
   for (int player = 1; player < cNumberPlayers; player++)
   {
      if (player == cMyID || kbPlayerIsMutualAlly(player) == false)
         continue;
      int center = gaiaBotFind(cUnitTypeAbstractTownCenter, player, home, closest);
      if (center < 0)
         continue;
      vector allyHome = kbUnitGetPosition(center);
      int enemy = gaiaBotFind(cUnitTypeMilitaryUnit, -1, allyHome, 35.0);
      if (enemy >= 0 && kbCanAreaPath(home, kbUnitGetPosition(enemy)))
      {
         danger = enemy;
         closest = xsVectorLength(allyHome - home);
      }
   }
   return danger;
}

int gaiaBotThreatByCenter(vector home = cInvalidVector)
{
   int threat = gaiaBotFind(cUnitTypeMilitaryUnit, -1, home, 42.0);
   if (threat >= 0)
      return threat;
   if (gaiaBotExpansion != cInvalidVector && aiPlanGetIsIDValid(gaiaBotBuildPlan))
   {
      threat = gaiaBotFind(cUnitTypeMilitaryUnit, -1, gaiaBotExpansion, 33.0);
      if (threat >= 0)
         return threat;
   }
   int[] centers = kbUnitQueryGetResults(gaiaBotQuery(cUnitTypeAbstractTownCenter, cMyID));
   for (int i = 0; i < centers.size(); i++)
   {
      vector position = kbUnitGetPosition(centers[i]);
      if (position == home)
         continue;
      threat = gaiaBotFind(cUnitTypeMilitaryUnit, -1, position, 35.0);
      if (threat >= 0)
         return threat;
   }
   return -1;
}

int gaiaBotAllyStrength(vector position = cInvalidVector)
{
   int support = 0;
   for (int player = 1; player < cNumberPlayers; player++)
   {
      if (player != cMyID && kbPlayerIsMutualAlly(player))
      {
         int query = gaiaBotQuery(cUnitTypeMilitaryUnit, player, position, 48.0);
         support += kbUnitQueryNumberResults(query);
      }
   }
   return support;
}

int gaiaBotBestTarget(int type = -1, vector home = cInvalidVector, int army = 0,
   int visibility = cUnitQueryVisibleStateVisible)
{
   int query = gaiaBotQuery(type, -1, home, 1000.0, visibility);
   int[] targets = new int(0, 0);
   int count = kbUnitQueryNumberResults(query);
   for (int i = 0; i < count && i < 12; i++)
      targets.add(kbUnitQueryGetResult(query, i));
   int best = -1;
   float bestScore = -10000.0;
   for (int i = 0; i < targets.size(); i++)
   {
      int target = targets[i];
      vector point = kbUnitGetPosition(target);
      if (point == cInvalidVector || kbCanAreaPath(home, point) == false)
         continue;
      int defenders = gaiaBotQuery(cUnitTypeMilitaryUnit, -1, point, 38.0);
      int hostile = kbUnitQueryNumberResults(defenders);
      int support = gaiaBotAllyStrength(point);
      int advantage = army + support / 2 - hostile;
      if (advantage <= 0)
         continue;
      float score = 6.0 * advantage + 2.0 * support - 0.3 * xsVectorLength(point - home);
      if (target == gaiaBotAttackTarget)
         score += 15.0;
      if (score > bestScore)
      {
         best = target;
         bestScore = score;
      }
   }
   return best;
}

void gaiaBotAssignBuilders(int plan = -1, vector position = cInvalidVector, int builders = 1)
{
   aiPlanAddUnitType(plan, cUnitTypeAbstractVillager, 1, builders, builders);
   int query = gaiaBotQuery(cUnitTypeAbstractVillager, cMyID, position, 110.0);
   int assigned = 0;
   for (int i = 0; i < kbUnitQueryNumberResults(query) && assigned < builders; i++)
   {
      int unit = kbUnitQueryGetResult(query, i);
      int currentPlan = kbUnitGetPlanID(unit);
      if (currentPlan >= 0 && (currentPlan == gaiaBotRelicPlan || aiPlanGetType(currentPlan) == cPlanBuild ||
          aiPlanGetType(currentPlan) == cPlanBuildWall || aiPlanGetType(currentPlan) == cPlanRepair))
         continue;
      if (aiPlanAddUnit(plan, unit))
         assigned++;
   }
}

bool gaiaBotConstruct(int type = -1, vector position = cInvalidVector, float radius = 22.0, int builders = 1,
   int socketID = -1)
{
   bool manor = type == cUnitTypeManor;
   if (position == cInvalidVector || kbCanAffordUnit(type) == false)
      return false;
   if ((manor && aiPlanGetIsIDValid(gaiaBotManorPlan)) ||
       (manor == false && (gaiaBotNeedsManorWood || aiPlanGetIsIDValid(gaiaBotBuildPlan))))
      return false;
   if (aiPlanGetIDByTypeAndVariableIntValue(cPlanBuild, cBuildPlanBuildingTypeID, type) >= 0)
      return false;

   int plan = aiPlanCreate("Gaia autoplay construction", cPlanBuild);
   if (plan < 0)
      return false;
   int placement = kbBuildingPlacementCreate("Gaia autoplay placement");
   if (placement < 0)
   {
      aiPlanDestroy(plan);
      return false;
   }
   kbBuildingPlacementSetBuildingPUID(placement, type);
   if (socketID >= 0)
      kbBuildingPlacementSetSocketID(placement, socketID);
   else
   {
      int retry = gaiaBotRetryTypes.find(type);
      int attempts = retry >= 0 ? gaiaBotRetryCounts[retry] : 0;
      if (attempts > 0)
         radius = max(radius, attempts == 1 ? 37.0 : 58.0);
      kbBuildingPlacementSetCenterPosition(placement, position, radius);
      if (attempts > 0)
      {
         int landArea = kbAreaGroupGetIDByPosition(position);
         if (landArea >= 0)
            kbBuildingPlacementSetAreaGroupID(placement, landArea);
      }
   }
   aiPlanSetVariableInt(plan, cBuildPlanBuildingTypeID, 0, type);
   aiPlanSetVariableInt(plan, cBuildPlanBuildingPlacementID, 0, placement);
   aiPlanSetPriority(plan, manor ? 96 : 93);
   gaiaBotAssignBuilders(plan, position, builders);
   if (manor)
   {
      gaiaBotManorPlan = plan;
      gaiaBotManorStarted = xsGetTime();
   }
   else
   {
      gaiaBotBuildPlan = plan;
      gaiaBotBuildStarted = xsGetTime();
      gaiaBotBuildType = type;
   }
   return true;
}

int gaiaBotCheckBuildPlan(int plan = -1, int started = -1, int timeout = 65, int type = -1)
{
   if (plan < 0)
      return -1;
   bool valid = aiPlanGetIsIDValid(plan);
   int foundation = valid ? aiPlanGetVariableInt(plan, cBuildPlanFoundationID, 0) : -1;
   if (foundation >= 0 && kbUnitGetState(foundation) == cUnitStateBuilding)
      return plan;
   int placementDeadline = started + timeout;
   if (valid && foundation < 0 && aiPlanGetState(plan) != cPlanStateFailed &&
       aiPlanGetState(plan) != cPlanStateDone && xsGetTime() <= placementDeadline)
      return plan;
   if (type >= 0 && type != cUnitTypeTownCenter)
   {
      int index = gaiaBotRetryTypes.find(type);
      if (foundation >= 0 && kbUnitGetState(foundation) == cUnitStateAlive)
      {
         if (index >= 0)
            gaiaBotRetryCounts[index] = 0;
      }
      else if (index < 0)
      {
         gaiaBotRetryTypes.add(type);
         gaiaBotRetryCounts.add(1);
      }
      else
         gaiaBotRetryCounts[index] = min(2, gaiaBotRetryCounts[index] + 1);
   }
   if (valid)
      aiPlanDestroy(plan);
   return -1;
}

void gaiaBotReassignIdleVillagers()
{
   if (xsGetTime() < gaiaBotLastIdleCheck + 9)
      return;
   gaiaBotLastIdleCheck = xsGetTime();
   int query = gaiaBotQuery(cUnitTypeAbstractVillager, cMyID);
   bool needsAssignment = false;
   for (int i = 0; i < kbUnitQueryNumberResults(query); i++)
   {
      int villager = kbUnitQueryGetResult(query, i);
      if (kbUnitGetActionType(villager) != cActionTypeIdle || kbUnitGetIdleTime(villager) < 7000)
         continue;
      int plan = kbUnitGetPlanID(villager);
      if (plan >= 0)
      {
         if (plan != gReservePlan && aiPlanGetType(plan) != cPlanGather)
            continue;
         aiPlanRemoveUnit(plan, villager);
      }
      needsAssignment = true;
   }
   if (needsAssignment)
   {
      aiSetNextGathererDistributionTime(0);
      aiSetUnassignedUnitAssignmentTime(0);
   }
}

bool gaiaBotResearch(int building = -1, int tech = -1)
{
   return building >= 0 && kbUnitGetCurrentQueueSize(building) == 0 &&
      kbTechGetStatus(tech) == cTechStatusObtainable &&
      aiTaskResearchUnit(building, tech);
}

bool gaiaBotTrain(int building = -1, int type = -1)
{
   return building >= 0 && kbUnitGetCurrentQueueSize(building) == 0 &&
      kbCanAffordUnit(type) && aiTaskTrainUnit(building, type);
}

void gaiaBotTrainAt(int buildingType = -1, int unitType = -1)
{
   int query = gaiaBotQuery(buildingType, cMyID);
   for (int i = 0; i < kbUnitQueryNumberResults(query); i++)
      gaiaBotTrain(kbUnitQueryGetResult(query, i), unitType);
}

int gaiaBotAgeTech(int age = -1)
{
   if (age == cAge1)
      return cTechClassicalAgeOceanus;
   if (age == cAge2)
      return cTechHeroicAgeTheia;
   if (age == cAge3)
      return cTechMythicAgeAtlas;
   return -1;
}

bool gaiaBotAdvance(int tech = -1)
{
   int centers = gaiaBotQuery(cUnitTypeAbstractTownCenter, cMyID);
   for (int i = 0; i < kbUnitQueryNumberResults(centers); i++)
   {
      // Submit the age-up even when the center is already training citizens.
      if (aiTaskResearchUnit(kbUnitQueryGetResult(centers, i), tech))
         return true;
   }
   return false;
}

void gaiaBotAllocate(int age = -1, int citizens = 0, bool threatened = false, float food = 0, float wood = 0,
   float gold = 0, int ageTech = -1, bool savingAge = false)
{
   int foodPoints = 9;
   int woodPoints = 6;
   if (age == cAge1)
   {
      foodPoints = 15;
      woodPoints = 3;
      if (citizens <= 2)
      {
         foodPoints = 20;
         woodPoints = 0;
      }
      else if (gaiaBotCount(cUnitTypeTemple) == 0)
      {
         float[] templeCost = kbProtoUnitGetCost(cUnitTypeTemple);
         if (gold < templeCost[cResourceGold])
         {
            foodPoints = 11;
            woodPoints = 3;
         }
         else if (wood < templeCost[cResourceWood])
         {
            foodPoints = 11;
            woodPoints = 7;
         }
      }
   }
   else if (savingAge)
   {
      float foodNeeded = kbTechGetCostPerResource(ageTech, cResourceFood);
      float goldNeeded = kbTechGetCostPerResource(ageTech, cResourceGold);
      foodPoints = 11;
      woodPoints = 2;
      if (food < foodNeeded && gold >= goldNeeded)
         foodPoints = 16;
      else if (food >= foodNeeded && gold < goldNeeded)
         foodPoints = 4;
   }
   else if (threatened == false && age < cAge4 && gold >= 500 && food < 800)
   {
      foodPoints = 13;
      woodPoints = 5;
   }
   else if (wood < 120 && gold >= 250)
   {
      foodPoints = 8;
      woodPoints = 10;
   }
   else if (gold < 175 && food >= 200)
   {
      foodPoints = 8;
      woodPoints = 4;
   }
   else if (age >= cAge4 && gold > 2400 && wood > 2400 && food > 2400)
   {
      foodPoints = 7;
      woodPoints = 7;
      if (wood < food && wood < gold)
         woodPoints = 9;
      else if (food < gold)
         foodPoints = 9;
   }
   int goldPoints = 20 - foodPoints - woodPoints;
   if (gaiaBotNeedsManorWood)
   {
      foodPoints = 10;
      woodPoints = 8;
      goldPoints = 2;
   }
   else if (age >= cAge2 && food < 120 && wood >= 400)
   {
      foodPoints = 18;
      woodPoints = 1;
      goldPoints = 1;
   }
   if (gFoodNumber != foodPoints || gWoodNumber != woodPoints || gGoldNumber != goldPoints)
   {
      gFoodNumber = foodPoints;
      gWoodNumber = woodPoints;
      gGoldNumber = goldPoints;
      gTotalNumber = 20;
      gDistributionTime = xsGetTime();
      gForceUpdateBreakdowns = true;
   }
}

void gaiaBotArmy(vector home = cInvalidVector, int age = -1, int localThreat = -1)
{
   int secondsSinceOrder = xsGetTime() - gaiaBotLastOrder;
   if (age < cAge2 || secondsSinceOrder < 15)
      return;
   int partySize = kbUnitCount(cUnitTypeMilitaryUnit, cMyID, cUnitStateAlive);
   int titans = kbUnitCount(cUnitTypeAbstractTitan, cMyID, cUnitStateAlive);
   vector target = cInvalidVector;
   int enemy = -1;
   if (localThreat >= 0)
      target = kbUnitGetPosition(localThreat);
   else if (partySize >= 7 && gaiaBotMatchMode == 2)
   {
      int allyThreat = gaiaBotAllyPressure(home);
      if (allyThreat >= 0)
      {
         vector point = kbUnitGetPosition(allyThreat);
         int hostile = gaiaBotQuery(cUnitTypeMilitaryUnit, -1, point, 30.0);
         int attackers = kbUnitQueryNumberResults(hostile);
         if (partySize + gaiaBotAllyStrength(point) >= attackers)
            target = point;
      }
   }
   if (target == cInvalidVector && (partySize >= (age == cAge2 ? 8 : 15) || titans > 0))
   {
      int strength = partySize + 10 * titans;
      if (age >= cAge4)
         enemy = gaiaBotBestTarget(cUnitTypeWonder, home, strength, cUnitQueryVisibleStateRecentPositionKnown);
      if (enemy < 0 && age >= cAge3 && (titans > 0 || gaiaBotCount(cUnitTypeDestroyer) >= 2))
         enemy = gaiaBotBestTarget(cUnitTypeAbstractTownCenter, home, strength, cUnitQueryVisibleStateRecentPositionKnown);
      if (enemy < 0)
         enemy = gaiaBotBestTarget(cUnitTypeAbstractVillager, home, strength);
      if (enemy < 0 && age >= cAge3)
         enemy = gaiaBotBestTarget(cUnitTypeBuilding, home, strength, cUnitQueryVisibleStateRecentPositionKnown);
      if (enemy >= 0)
         target = kbUnitGetPosition(enemy);
   }
   gaiaBotAttackTarget = enemy;
   if (target == cInvalidVector)
      target = home;
   if (target == gaiaBotRally && secondsSinceOrder < 30)
      return;

   int query = gaiaBotQuery(cUnitTypeMilitaryUnit, cMyID);
   int[] ordered = new int(0, 0);
   for (int i = 0; i < kbUnitQueryNumberResults(query); i++)
   {
      int unit = kbUnitQueryGetResult(query, i);
      if (kbUnitIsType(unit, cUnitTypeAbstractOracle) == false && aiTaskMoveUnit(unit, target, true))
         ordered.add(unit);
   }
   gaiaBotArmyOrders = ordered;
   gaiaBotLastOrder = xsGetTime();
   gaiaBotRally = target;
}

void gaiaBotHeroes(vector home = cInvalidVector, float favor = 0)
{
   if (favor < 4)
      return;
   int myth = gaiaBotQuery(cUnitTypeMythUnit, -1, home, 130.0);
   int enemyMyths = kbUnitQueryNumberResults(myth);
   int heroes = gaiaBotCount(cUnitTypeHero) - gaiaBotCount(cUnitTypeOracleHero) -
      gaiaBotCount(cUnitTypeVillagerAtlanteanHero);
   if (enemyMyths <= heroes)
      return;
   int ranged = gaiaBotFind(cUnitTypeTurma, cMyID, home, 60.0);
   if (ranged >= 0 && aiTaskResearchUnit(ranged, cTechTurmaToHero))
      return;
   int melee = gaiaBotFind(cUnitTypeMurmillo, cMyID, home, 60.0);
   if (melee >= 0)
      aiTaskResearchUnit(melee, cTechMurmilloToHero);
}

bool gaiaBotCanSpendOnResearch(int tech = -1, int resource = -1, int reserveTech = -1)
{
   float cost = kbTechGetCostPerResource(tech, resource);
   if (cost <= 0)
      return true;
   if (reserveTech >= 0)
      cost += kbTechGetCostPerResource(reserveTech, resource);
   return kbGetResourceAmount(cMyID, resource) >= cost;
}

bool gaiaBotResearchWithBudget(int building = -1, int tech = -1, int reserveTech = -1)
{
   return building >= 0 &&
      gaiaBotCanSpendOnResearch(tech, cResourceFood, reserveTech) &&
      gaiaBotCanSpendOnResearch(tech, cResourceWood, reserveTech) &&
      gaiaBotCanSpendOnResearch(tech, cResourceGold, reserveTech) &&
      gaiaBotCanSpendOnResearch(tech, cResourceFavor, reserveTech) &&
      gaiaBotResearch(building, tech);
}

void gaiaBotFavorUpgrades(int town = -1, int reserveTech = -1)
{
   if (kbTechGetStatus(cTechChannels) == cTechStatusObtainable)
   {
      int temple = gaiaBotFind(cUnitTypeTemple, cMyID);
      if (gaiaBotResearchWithBudget(temple, cTechChannels, reserveTech) ||
          (reserveTech < 0 && gaiaBotResearchWithBudget(town, cTechChannels)))
         return;
   }
   if (kbTechGetStatus(cTechBiteOfTheShark) != cTechStatusObtainable)
      return;
   int supportedTroops = gaiaBotCount(cUnitTypeMurmillo) + gaiaBotCount(cUnitTypeFanatic);
   supportedTroops += kbUnitTypeCount("MurmilloHero", cMyID, cUnitStateABQ);
   supportedTroops += kbUnitTypeCount("FanaticHero", cMyID, cUnitStateABQ);
   if (supportedTroops == 0)
      return;
   int armory = gaiaBotFind(cUnitTypeArmory, cMyID);
   if (gaiaBotResearchWithBudget(armory, cTechBiteOfTheShark, reserveTech))
      return;
   int barracks = gaiaBotFind(cUnitTypeMilitaryBarracks, cMyID);
   gaiaBotResearchWithBudget(barracks, cTechBiteOfTheShark, reserveTech);
}

void gaiaBotGuildUpgrades(int guild = -1, int reserveTech = -1)
{
   if (guild < 0 || kbUnitGetCurrentQueueSize(guild) != 0)
      return;
   int farmers = aiGetNumberGatherers(cUnitTypeAbstractVillager, cResourceFood, -1, cUnitTypeAbstractFarm);
   if (farmers >= 3 &&
       (gaiaBotResearchWithBudget(guild, cTechPlow, reserveTech) ||
        gaiaBotResearchWithBudget(guild, cTechIrrigation, reserveTech) ||
        gaiaBotResearchWithBudget(guild, cTechFloodControl, reserveTech)))
      return;

   if (gaiaBotResearchWithBudget(guild, cTechHandAxe, reserveTech) ||
       gaiaBotResearchWithBudget(guild, cTechPickaxe, reserveTech))
      return;
   if (aiGetNumberGatherers(cUnitTypeAbstractVillager, cResourceFood, -1, cUnitTypeHuntable) >= 2 &&
       gaiaBotResearchWithBudget(guild, cTechHuntingEquipment, reserveTech))
      return;
   if (aiGetNumberGatherers(cUnitTypeAbstractVillager, cResourceFood, -1, cUnitTypeHerdable) >= 2 &&
       gaiaBotResearchWithBudget(guild, cTechHusbandry, reserveTech))
      return;
   if (gaiaBotResearchWithBudget(guild, cTechBowSaw, reserveTech) ||
       gaiaBotResearchWithBudget(guild, cTechShaftMine, reserveTech) ||
       gaiaBotResearchWithBudget(guild, cTechCarpenters, reserveTech))
      return;
   gaiaBotResearchWithBudget(guild, cTechQuarry, reserveTech);
}

void gaiaBotScout()
{
   for (int i = gaiaBotScoutPlans.size() - 1; i >= 0; i--)
   {
      int scoutPlan = gaiaBotScoutPlans[i];
      if (aiPlanGetIsIDValid(scoutPlan) == false)
         gaiaBotScoutPlans.removeIndex(i);
      else if (aiPlanGetNumberUnits(scoutPlan) == 0)
      {
         aiPlanDestroy(scoutPlan);
         gaiaBotScoutPlans.removeIndex(i);
      }
   }

   int query = gaiaBotQuery(cUnitTypeAbstractOracle, cMyID);
   for (int i = 0; i < kbUnitQueryNumberResults(query); i++)
   {
      int oracle = kbUnitQueryGetResult(query, i);
      if (gaiaBotScoutedOracles.find(oracle) >= 0)
         continue;
      int currentPlan = kbUnitGetPlanID(oracle);
      if (currentPlan >= 0 && aiPlanGetType(currentPlan) == cPlanExplore)
      {
         gaiaBotScoutedOracles.add(oracle);
         continue;
      }
      if (currentPlan >= 0 && aiPlanGetType(currentPlan) != cPlanReserve)
         continue;
      int plan = aiPlanCreate("Gaia autoplay scout " + oracle, cPlanExplore);
      if (plan < 0)
         continue;
      aiPlanSetPriority(plan, 50);
      aiPlanAddUnitType(plan, cUnitTypeAbstractOracle, 1, 1, 1);
      if (aiPlanAddUnit(plan, oracle) == false)
      {
         aiPlanDestroy(plan);
         continue;
      }
      aiPlanSetFlag(plan, cPlanFlagNoMoreUnits, true);
      aiPlanSetFlag(plan, cPlanFlagRequiresAllNeedUnits, true);
      aiPlanSetVariableBool(plan, cExplorePlanDoLoops, 0, false);
      aiPlanSetVariableBool(plan, cExplorePlanAvoidingAttackedAreas, 0, true);
      // Scout to a fog edge and settle there to generate favor.
      aiPlanSetVariableFloat(plan, cExplorePlanStopLOSPercentage, 0, 0.2);
      gaiaBotScoutPlans.add(plan);
      gaiaBotScoutedOracles.add(oracle);
   }
}

void gaiaBotTrainOracle(int freeSlots = 0, int reserveTech = -1)
{
   int limit = kbPlayerGetProtoStatInt(cMyID, cUnitTypeOracle, cProtoStatBuildLimit);
   if (limit <= 0 || freeSlots < 1 || gaiaBotCount(cUnitTypeAbstractOracle) >= min(10, limit) ||
       kbProtoUnitAvailable(cUnitTypeOracle) == false)
      return;
   if (reserveTech >= 0)
   {
      float[] cost = kbProtoUnitGetCost(cUnitTypeOracle);
      float foodNeeded = cost[cResourceFood] + kbTechGetCostPerResource(reserveTech, cResourceFood);
      float goldNeeded = cost[cResourceGold] + kbTechGetCostPerResource(reserveTech, cResourceGold);
      if (cost[cResourceFood] > 0 && kbGetResourceAmount(cMyID, cResourceFood) < foodNeeded)
         return;
      if (cost[cResourceGold] > 0 && kbGetResourceAmount(cMyID, cResourceGold) < goldNeeded)
         return;
   }
   int temples = gaiaBotQuery(cUnitTypeTemple, cMyID);
   for (int i = 0; i < kbUnitQueryNumberResults(temples); i++)
   {
      if (gaiaBotTrain(kbUnitQueryGetResult(temples, i), cUnitTypeOracle))
         return;
   }
}

void gaiaBotSpreadOracles()
{
   if (xsGetTime() < 75)
   {
      gaiaBotScout();
      return;
   }
   if (xsGetTime() < gaiaBotLastOraclePostCheck + 9)
      return;
   gaiaBotLastOraclePostCheck = xsGetTime();
   for (int i = 0; i < gaiaBotScoutPlans.size(); i++)
   {
      if (aiPlanGetIsIDValid(gaiaBotScoutPlans[i]))
         aiPlanDestroy(gaiaBotScoutPlans[i]);
   }
   gaiaBotScoutPlans.clear();

   int[] oracles = kbUnitQueryGetResults(gaiaBotQuery(cUnitTypeAbstractOracle, cMyID));
   for (int i = gaiaBotPostedOracles.size() - 1; i >= 0; i--)
   {
      if (oracles.find(gaiaBotPostedOracles[i]) < 0)
      {
         gaiaBotPostedOracles.removeIndex(i);
         gaiaBotOraclePosts.removeIndex(i);
      }
   }
   int[] centers = kbUnitQueryGetResults(gaiaBotQuery(cUnitTypeAbstractTownCenter, cMyID));
   vector[] offsets = new vector(0, cInvalidVector);
   offsets.add(vector(36, 0, 0));
   offsets.add(vector(-36, 0, 0));
   offsets.add(vector(0, 0, 36));
   offsets.add(vector(0, 0, -36));
   offsets.add(vector(37, 0, 37));
   offsets.add(vector(-37, 0, -37));
   offsets.add(vector(37, 0, -37));
   offsets.add(vector(-37, 0, 37));
   offsets.add(vector(14, 0, 14));
   offsets.add(vector(-14, 0, -14));
   offsets.add(vector(14, 0, -14));
   offsets.add(vector(-14, 0, 14));

   for (int i = 0; i < oracles.size(); i++)
   {
      int oracle = oracles[i];
      int currentPlan = kbUnitGetPlanID(oracle);
      if (currentPlan >= 0 && aiPlanGetType(currentPlan) != cPlanReserve)
         continue;
      int index = gaiaBotPostedOracles.find(oracle);
      vector position = kbUnitGetPosition(oracle);
      if (index >= 0)
      {
         vector post = gaiaBotOraclePosts[index];
         bool stalled = xsVectorLength(post - position) > 7.0 && kbUnitGetIdleTime(oracle) > 7000;
         if (stalled == false && gaiaBotFind(cUnitTypeMilitaryUnit, -1, post, 24.0) < 0 &&
             gaiaBotFind(cUnitTypeMilitaryUnit, -1, position, 18.0) < 0)
            continue;
         gaiaBotPostedOracles.removeIndex(index);
         gaiaBotOraclePosts.removeIndex(index);
      }
      vector best = cInvalidVector;
      float bestDistance = 10000.0;
      for (int j = 0; j < centers.size(); j++)
      {
         vector center = kbUnitGetPosition(centers[j]);
         for (int k = 0; k < offsets.size(); k++)
         {
            vector point = center + offsets[k];
            if (kbGetIsLocationOnMap(point) == false)
               continue;
            float distance = xsVectorLength(point - position);
            if (distance >= bestDistance)
               continue;
            bool overlapping = false;
            for (int other = 0; other < gaiaBotOraclePosts.size(); other++)
            {
               if (xsVectorLength(gaiaBotOraclePosts[other] - point) < 25.0)
               {
                  overlapping = true;
                  break;
               }
            }
            if (overlapping || gaiaBotFind(cUnitTypeMilitaryUnit, -1, point, 24.0) >= 0 ||
                kbCanPath(position, point, kbUnitGetProtoUnitID(oracle), 2.0) == false)
               continue;
            best = point;
            bestDistance = distance;
         }
      }
      if (best != cInvalidVector && aiTaskMoveUnit(oracle, best))
      {
         gaiaBotPostedOracles.add(oracle);
         gaiaBotOraclePosts.add(best);
      }
   }
}

void gaiaBotHerd()
{
   if (xsGetTime() < gaiaBotLastHerdOrder + 5)
      return;
   gaiaBotLastHerdOrder = xsGetTime();
   int[] animals = kbUnitQueryGetResults(gaiaBotQuery(cUnitTypeHerdable, cMyID));
   static int centerQuery = -1;
   if (centerQuery < 0)
      centerQuery = kbUnitQueryCreate("Gaia autoplay herd destination");
   if (centerQuery < 0)
      return;
   kbUnitQuerySetPlayerID(centerQuery, cMyID, false);
   kbUnitQuerySetUnitType(centerQuery, cUnitTypeAbstractSocketedTownCenter);
   kbUnitQuerySetState(centerQuery, cUnitStateAlive);
   kbUnitQuerySetMaximumDistance(centerQuery, cMaxFloat);
   kbUnitQuerySetAscendingSort(centerQuery, true);
   for (int i = 0; i < animals.size(); i++)
   {
      int animal = animals[i];
      vector location = kbUnitGetPosition(animal);
      if (kbGetIsLocationOnMap(location) == false)
         continue;
      kbUnitQuerySetPosition(centerQuery, location);
      kbUnitQuerySetConnectedAreaGroupID(centerQuery, kbAreaGroupGetIDByPosition(location), cPassabilityLand);
      kbUnitQueryResetResults(centerQuery);
      if (kbUnitQueryExecute(centerQuery) <= 0)
         continue;
      int nearest = kbUnitQueryGetResult(centerQuery, 0);
      if (xsVectorLength(kbUnitGetPosition(nearest) - location) > 13.0 &&
          kbUnitGetTargetUnitID(animal) != nearest)
         aiTaskWorkUnit(animal, nearest);
   }
}

bool gaiaBotExpand(vector home = cInvalidVector, int builders = 3, int reserveTech = -1)
{
   if (gaiaBotNeedsManorWood || aiPlanGetIsIDValid(gaiaBotBuildPlan) ||
       kbUnitCount(cUnitTypeAbstractTownCenter, cMyID, cUnitStateBuilding) > 0 ||
       kbProtoUnitAvailable(cUnitTypeTownCenter) == false || kbCanAffordUnit(cUnitTypeTownCenter) == false)
      return false;
   if (reserveTech >= 0)
   {
      float[] cost = kbProtoUnitGetCost(cUnitTypeTownCenter);
      float woodNeeded = cost[cResourceWood] + kbTechGetCostPerResource(reserveTech, cResourceWood);
      float goldNeeded = cost[cResourceGold] + kbTechGetCostPerResource(reserveTech, cResourceGold);
      if (kbGetResourceAmount(cMyID, cResourceWood) < woodNeeded ||
          kbGetResourceAmount(cMyID, cResourceGold) < goldNeeded)
         return false;
   }
   int[] sites = kbUnitQueryGetResults(gaiaBotQuery(cUnitTypeSettlement, cPlayerMotherNatureID, home, 150.0,
      cUnitQueryVisibleStateRecentPositionKnown));
   for (int i = 0; i < sites.size(); i++)
   {
      vector site = kbUnitGetPosition(sites[i]);
      if (site == cInvalidVector || kbCanAreaPath(home, site) == false ||
          gaiaBotFind(cUnitTypeMilitaryUnit, -1, site, 35.0) >= 0 ||
          gaiaBotFind(cUnitTypeMilitaryUnit, -1, home + (site - home) * 0.5, 22.0) >= 0 ||
          gaiaBotFind(cUnitTypeAbstractTownCenter, -1, site, 52.0, cUnitQueryVisibleStateRecentPositionKnown) >= 0)
         continue;
      if (gaiaBotConstruct(cUnitTypeTownCenter, site, 3.0, builders, sites[i]))
      {
         gaiaBotExpansion = site;
         return true;
      }
   }
   return false;
}

void gaiaBotGuardExpansion(vector home = cInvalidVector)
{
   if (aiPlanGetIsIDValid(gaiaBotBuildPlan) || kbProtoUnitAvailable(cUnitTypeSentryTower) == false ||
       kbCanAffordUnit(cUnitTypeSentryTower) == false)
      return;
   int[] centers = kbUnitQueryGetResults(gaiaBotQuery(cUnitTypeTownCenter, cMyID, home, 180.0));
   for (int i = 0; i < centers.size(); i++)
   {
      vector position = kbUnitGetPosition(centers[i]);
      if (xsVectorLength(position - home) < 34.0 ||
          gaiaBotFind(cUnitTypeSentryTower, cMyID, position, 24.0, cUnitQueryVisibleStateVisible, cUnitStateABQ) >= 0)
         continue;
      if (gaiaBotConstruct(cUnitTypeSentryTower, position, 16.0))
         return;
   }
}

void gaiaBotFarms(vector home = cInvalidVector, int age = -1, int citizens = 0, bool foodShortage = false)
{
   int secondsSinceFarmCheck = xsGetTime() - gaiaBotLastFarmCheck;
   if (citizens < 4 || gaiaBotNeedsManorWood || aiPlanGetIsIDValid(gaiaBotBuildPlan) ||
       kbProtoUnitAvailable(cUnitTypeFarm) == false || secondsSinceFarmCheck < 9)
      return;
   gaiaBotLastFarmCheck = xsGetTime();

   float animals = kbGetAmountValidResourcesByPosition(home, cResourceFood, cAIResourceSubTypeHunt, 37.0) +
      kbGetAmountValidResourcesByPosition(home, cResourceFood, cAIResourceSubTypeHuntAggressive, 37.0) +
      kbGetAmountValidResourcesByPosition(home, cResourceFood, cAIResourceSubTypeHerdable, 33.0);
   float berries = kbGetAmountValidResourcesByPosition(home, cResourceFood, cAIResourceSubTypeEasy, 35.0);
   float remainingFood = animals + berries;
   int target = 0;
   if (foodShortage || remainingFood < 350.0)
      target = min(16, max(2, citizens / 3));
   else if (age >= cAge2 && kbGetResourceAmount(cMyID, cResourceWood) >= 200.0)
      target = 2;
   int farms = gaiaBotQuery(cUnitTypeAbstractFarm, cMyID, home, 65.0, cUnitQueryVisibleStateVisible, cUnitStateABQ);
   if (kbUnitQueryNumberResults(farms) < target)
      gaiaBotConstruct(cUnitTypeFarm, home, 23.0);
}

void gaiaBotHousing(vector home = cInvalidVector, int age = -1, int freeSlots = 0, int popCap = 0,
   float wood = 0.0, bool threatened = false)
{
   gaiaBotNeedsManorWood = false;
   int maxPop = kbPlayerGetMaxPop(cMyID);
   if (maxPop > 0 && popCap >= maxPop)
      return;
   int buffer = age == cAge1 ? 5 : (10 + 5 * age);
   if (freeSlots >= buffer || aiPlanGetIsIDValid(gaiaBotManorPlan) ||
       kbUnitCount(cUnitTypeManor, cMyID, cUnitStateBuilding) > 0 ||
       aiPlanGetIDByTypeAndVariableIntValue(cPlanBuild, cBuildPlanBuildingTypeID, cUnitTypeManor) >= 0)
      return;
   int manorLimit = kbPlayerGetProtoStatInt(cMyID, cUnitTypeManor, cProtoStatBuildLimit);
   if (manorLimit > 0 && gaiaBotCount(cUnitTypeManor) >= manorLimit)
   {
      if (age >= cAge2 && threatened == false && freeSlots <= 5)
         gaiaBotExpand(home);
      return;
   }
   int builders = freeSlots <= 5 ? 2 : 1;
   if (gaiaBotConstruct(cUnitTypeManor, home, 19.0, builders) == false)
   {
      float[] manorCost = kbProtoUnitGetCost(cUnitTypeManor);
      gaiaBotNeedsManorWood = wood < manorCost[cResourceWood];
   }
}

void gaiaBotWalls(vector home = cInvalidVector, bool threatened = false, float gold = 0)
{
   if (threatened)
   {
      gaiaBotHadRaid = true;
      return;
   }
   if (gaiaBotHadRaid == false || gaiaBotWalled || gold < 320 || aiPlanGetIsIDValid(gaiaBotBuildPlan))
      return;
   int base = kbBaseGetMainID(cMyID);
   if (base < 0)
      return;
   int plan = aiPlanCreate("Gaia autoplay walls", cPlanBuildWall);
   if (plan < 0)
      return;
   aiPlanSetVariableInt(plan, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeRing);
   aiPlanSetVariableVector(plan, cBuildWallPlanWallRingCenterPoint, 0, home);
   aiPlanSetVariableFloat(plan, cBuildWallPlanWallRingRadius, 0, 27.0);
   aiPlanSetVariableInt(plan, cBuildWallPlanNumberOfGates, 0, 4);
   aiPlanSetBaseID(plan, base);
   aiPlanSetPriority(plan, 78);
   gaiaBotAssignBuilders(plan, home, 1);
   gaiaBotWallPlan = plan;
   gaiaBotWalled = true;
}

void gaiaBotTrade(int town = -1, vector home = cInvalidVector, float gold = 0)
{
   if (gold >= 850 && aiPlanGetIsIDValid(gaiaBotTradePlan) == false)
      return;
   if (gaiaBotCount(cUnitTypeTownCenter) < 2)
      return;
   int market = gaiaBotFind(cUnitTypeMarket, cMyID);
   if (market < 0)
   {
      gaiaBotConstruct(cUnitTypeMarket, home);
      return;
   }
   int trader = kbFunctionUnitGetByIndex(cMyCiv, cUnitFunctionTrader, 0);
   if (trader < 0)
      return;
   int query = gaiaBotQuery(cUnitTypeTownCenter, cMyID, kbUnitGetPosition(market), 170.0);
   int destination = -1;
   for (int i = kbUnitQueryNumberResults(query) - 1; i >= 0; i--)
   {
      int candidate = kbUnitQueryGetResult(query, i);
      vector point = kbUnitGetPosition(candidate);
      if (candidate != town && kbCanAreaPath(kbUnitGetPosition(market), point) &&
          xsVectorLength(kbUnitGetPosition(market) - point) >= 34.0)
      {
         destination = candidate;
         break;
      }
   }
   if (destination < 0)
      return;
   if (aiPlanGetIsIDValid(gaiaBotTradePlan) == false)
   {
      gaiaBotTradePlan = aiPlanCreate("Gaia autoplay trade", cPlanTrade);
      if (gaiaBotTradePlan < 0)
         return;
      aiPlanSetVariableBool(gaiaBotTradePlan, cTradePlanUpdateTarget, 0, false);
      aiPlanSetPriority(gaiaBotTradePlan, 91);
      aiPlanAddUnitType(gaiaBotTradePlan, trader, 1, 6, 6);
      gaiaBotTradeTown = -1;
   }
   if (gaiaBotTradeTown != destination ||
       aiPlanGetVariableInt(gaiaBotTradePlan, cTradePlanMarketID, 0) != market)
   {
      aiPlanSetVariableInt(gaiaBotTradePlan, cTradePlanMarketID, 0, market);
      aiPlanSetVariableInt(gaiaBotTradePlan, cTradePlanTargetUnitID, 0, destination);
      gaiaBotTradeTown = destination;
   }
   if (gaiaBotCount(trader) < 6)
      gaiaBotTrain(market, trader);
}

void gaiaBotTitan(int town = -1, vector home = cInvalidVector, int army = 0)
{
   int foundation = gaiaBotFind(cUnitTypeTitanGate, cMyID, home, 180.0, cUnitQueryVisibleStateVisible, cUnitStateBuilding);
   if (foundation >= 0)
   {
      if (aiPlanGetIsIDValid(gaiaBotRepairPlan) == false)
      {
         int repair = aiPlanCreate("Gaia autoplay finish Titan gate", cPlanRepair);
         if (repair < 0)
            return;
         aiPlanSetVariableInt(repair, cRepairPlanTargetID, 0, foundation);
         aiPlanSetPriority(repair, 100);
         gaiaBotAssignBuilders(repair, kbUnitGetPosition(foundation), 9);
         gaiaBotRepairPlan = repair;
      }
      return;
   }
   if (army < 16 || gaiaBotCount(cUnitTypeAbstractTitan) > 0)
      return;
   if (kbGodPowerGetNumCharges(cProtoPowerTitanGate, cMyID) < 1)
   {
      gaiaBotResearch(town, cTechSecretsOfTheTitans);
      return;
   }
   if (aiPlanGetIsIDValid(gaiaBotTitanPlan))
      return;
   int plan = aiPlanCreate("Gaia autoplay Titan gate", cPlanGodPower);
   if (plan < 0)
      return;
   int placement = kbBuildingPlacementCreate("Gaia autoplay Titan placement");
   if (placement < 0)
   {
      aiPlanDestroy(plan);
      return;
   }
   kbBuildingPlacementSetBuildingPUID(placement, cUnitTypeTitanGate);
   kbBuildingPlacementSetCenterPosition(placement, home, 35.0);
   kbBuildingPlacementSetRequiresCompletelyUnobstructed(placement, true);
   aiPlanSetVariableInt(plan, cGodPowerPlanPowerProtoID, 0, cProtoPowerTitanGate);
   aiPlanSetVariableInt(plan, cGodPowerPlanEvaluationModel, 0, cGodPowerPlanEvaluationModelNone);
   aiPlanSetVariableInt(plan, cGodPowerPlanTargetingModel, 0, cGodPowerPlanTargetingModelBuildingPlacement);
   aiPlanSetVariableInt(plan, cGodPowerPlanBPID, 0, placement);
   gaiaBotTitanPlan = plan;
}

void gaiaBotOpening(int town = -1, vector home = cInvalidVector, int citizens = 0,
   bool advancing = false)
{
   if (gaiaBotCount(cUnitTypeTemple) == 0)
      gaiaBotConstruct(cUnitTypeTemple, home, 22.0, 2);
   else if (gaiaBotCount(cUnitTypeEconomicGuild) == 0 && gaiaBotFind(cUnitTypeTemple, cMyID) >= 0)
      gaiaBotConstruct(cUnitTypeEconomicGuild, home);
   if (advancing)
   {
      if (gaiaBotCount(cUnitTypeManor) == 0)
         gaiaBotConstruct(cUnitTypeManor, home);
      return;
   }
   if (citizens < 4)
      gaiaBotTrain(town, cUnitTypeVillagerAtlantean);
}

void gaiaBotForest(vector home = cInvalidVector, bool threatened = false)
{
   bool cooldown = kbGodPowerIsOnCooldown(cProtoPowerGaiaForest, cMyID);
   int currentTime = xsGetTime();
   int secondsSinceForestCheck = currentTime - gaiaBotLastForestCheck;
   if (aiPlanGetIsIDValid(gaiaBotForestPlan))
   {
      if (cooldown)
         gaiaBotForestUsed = true;
      if (cooldown || threatened || secondsSinceForestCheck >= 15)
      {
         aiPlanDestroy(gaiaBotForestPlan);
         gaiaBotForestPlan = -1;
      }
      return;
   }
   if (threatened || cooldown || secondsSinceForestCheck < 12)
      return;
   gaiaBotLastForestCheck = currentTime;
   float price = kbGodPowerGetCost(cProtoPowerGaiaForest, cMyID);
   if (gaiaBotForestUsed || price > 0.0)
   {
      if (kbGetAmountValidResourcesByPosition(home, cResourceWood, cAIResourceSubTypeEasy, 30.0) > 650.0)
         return;
      float favorNeeded = price;
      if (kbTechGetStatus(cTechChannels) == cTechStatusObtainable)
         favorNeeded += kbTechGetCostPerResource(cTechChannels, cResourceFavor);
      if (kbTechGetStatus(cTechBiteOfTheShark) == cTechStatusObtainable)
         favorNeeded += kbTechGetCostPerResource(cTechBiteOfTheShark, cResourceFavor);
      if (kbGetResourceAmount(cMyID, cResourceFavor) < favorNeeded)
         return;
   }
   int plan = aiPlanCreate("Gaia autoplay forest", cPlanGodPower);
   if (plan < 0)
      return;
   int placement = kbBuildingPlacementCreate("Gaia autoplay forest placement");
   if (placement < 0)
   {
      aiPlanDestroy(plan);
      return;
   }
   kbBuildingPlacementSetBuildingPUID(placement, cUnitTypeMilitaryBarracks);
   kbBuildingPlacementSetCenterPosition(placement, home, 25.0);
   kbBuildingPlacementSetInnerRingRange(placement, 12.0);
   kbBuildingPlacementSetRequiresCompletelyUnobstructed(placement, true);
   kbBuildingPlacementSetCheckGPExclusion(placement, true);
   kbBuildingPlacementSetStepSize(placement, 3.0);
   aiPlanSetVariableInt(plan, cGodPowerPlanPowerProtoID, 0, cProtoPowerGaiaForest);
   aiPlanSetVariableInt(plan, cGodPowerPlanEvaluationModel, 0, cGodPowerPlanEvaluationModelNone);
   aiPlanSetVariableInt(plan, cGodPowerPlanTargetingModel, 0, cGodPowerPlanTargetingModelBuildingPlacement);
   aiPlanSetVariableInt(plan, cGodPowerPlanBPID, 0, placement);
   aiPlanSetVariableBool(plan, cGodPowerPlanAutoCast, 0, true);
   gaiaBotForestPlan = plan;
}

void gaiaBotPowers(vector home = cInvalidVector, int age = -1, int danger = -1, int army = 0)
{
   if (xsGetTime() < gaiaBotLastPower + 45)
      return;
   if (danger >= 0)
   {
      vector threat = kbUnitGetPosition(danger);
      if (age >= cAge4)
      {
         int nearbyEnemies = gaiaBotQuery(cUnitTypeMilitaryUnit, -1, threat, 11.0);
         if (kbUnitQueryNumberResults(nearbyEnemies) >= 6 && aiCastGodPowerAtPosition(cProtoPowerImplode, threat))
         {
            gaiaBotLastPower = xsGetTime();
            return;
         }
      }
      if (aiCastGodPowerAtPosition(cProtoPowerCarnivora, threat))
         gaiaBotLastPower = xsGetTime();
      return;
   }
   if (age >= cAge3 && army >= 7 && gaiaBotCount(cUnitTypeHesperidesTree) == 0)
   {
      vector grove = home + vector(10, 0, 10);
      if (kbGetIsLocationOnMap(grove) && aiCastGodPowerAtPosition(cProtoPowerHesperidesTree, grove))
      {
         gaiaBotLastPower = xsGetTime();
         return;
      }
   }
   if (age >= cAge4 && gaiaBotAttackTarget >= 0)
   {
      vector point = kbUnitGetPosition(gaiaBotAttackTarget);
      if (point == cInvalidVector)
         return;
      int nearbyEnemies = gaiaBotQuery(cUnitTypeMilitaryUnit, -1, point, 12.0);
      if (kbUnitQueryNumberResults(nearbyEnemies) >= 7 && aiCastGodPowerAtPosition(cProtoPowerImplode, point))
         gaiaBotLastPower = xsGetTime();
   }
}

void gaiaBotProduction(int age = -1, int capacity = 0, vector home = cInvalidVector, int army = 0, bool threatened = false)
{
   if (capacity < 2)
      return;
   int cavalry = gaiaBotQuery(cUnitTypeAbstractCavalry, -1, home, 170.0);
   int cavalryCount = kbUnitQueryNumberResults(cavalry);
   int archers = gaiaBotQuery(cUnitTypeAbstractArcher, -1, home, 170.0);
   int archersCount = kbUnitQueryNumberResults(archers);
   int counters = gaiaBotFind(cUnitTypeCounterBarracks, cMyID);
   int core = cUnitTypeMurmillo;
   int contariusTarget = army / 4;
   int cheiroballistaTarget = 2 + army / 10;
   if (age >= cAge3 && cavalryCount < 3 && gaiaBotCount(cUnitTypeContarius) < contariusTarget)
      core = cUnitTypeContarius;
   gaiaBotTrainAt(cUnitTypeMilitaryBarracks, core);
   if (cavalryCount >= 3 && cavalryCount >= archersCount)
      gaiaBotTrain(counters, cUnitTypeKatapeltes);
   else if (archersCount >= 3 || gaiaBotCount(cUnitTypeTurma) < 3)
      gaiaBotTrain(counters, cUnitTypeTurma);
   else if (capacity >= 4 && gaiaBotCount(cUnitTypeCheiroballista) < cheiroballistaTarget)
      gaiaBotTrain(counters, cUnitTypeCheiroballista);

   int temple = gaiaBotFind(cUnitTypeTemple, cMyID);
   if (capacity >= 4 && army >= 4)
   {
      if (gaiaBotCount(cUnitTypeCaladria) < 2)
         gaiaBotTrain(temple, cUnitTypeCaladria);
      else if (age >= cAge4 && gaiaBotCount(cUnitTypeArgus) < 4)
         gaiaBotTrain(temple, cUnitTypeArgus);
      else if (age >= cAge3 && gaiaBotCount(cUnitTypeStymphalianBird) < 3)
         gaiaBotTrain(temple, cUnitTypeStymphalianBird);
   }
   if (age >= cAge3 && capacity >= 4 && army >= 7 && threatened == false)
   {
      int palace = gaiaBotFind(cUnitTypePalace, cMyID);
      if (age >= cAge4 && gaiaBotCount(cUnitTypeDestroyer) >= 3 && gaiaBotCount(cUnitTypeFireSiphon) < 4)
         gaiaBotTrain(palace, cUnitTypeFireSiphon);
      else if (gaiaBotCount(cUnitTypeDestroyer) < 6)
         gaiaBotTrain(palace, cUnitTypeDestroyer);
      else if (age >= cAge4)
         gaiaBotTrain(palace, cUnitTypeFanatic);
   }
}

void gaiaBotDevelop(int town = -1, int age = -1, vector home = cInvalidVector, int citizens = 0,
   int capacity = 0, int army = 0, bool threatened = false, float food = 0, float wood = 0, float gold = 0,
   int reserveTech = -1)
{
   bool savingAge = reserveTech >= 0;
   if (gaiaBotCount(cUnitTypeTemple) == 0)
      gaiaBotConstruct(cUnitTypeTemple, home);
   int barracksTarget = 1;
   if (age == cAge3)
      barracksTarget = 2;
   if (age >= cAge4)
      barracksTarget = 3;
   if (gaiaBotCount(cUnitTypeMilitaryBarracks) < barracksTarget)
      gaiaBotConstruct(cUnitTypeMilitaryBarracks, home);
   if (threatened == false && savingAge == false && gaiaBotCount(cUnitTypeEconomicGuild) == 0)
      gaiaBotConstruct(cUnitTypeEconomicGuild, home);
   if (gaiaBotCount(cUnitTypeCounterBarracks) == 0)
      gaiaBotConstruct(cUnitTypeCounterBarracks, home);
   int centers = gaiaBotCount(cUnitTypeTownCenter);
   if (threatened == false && citizens >= 8 && army >= 5 && centers < 2)
      gaiaBotExpand(home, 3, reserveTech);
   if (threatened == false && citizens >= 10 && army >= 5)
   {
      if (age == cAge2 && gaiaBotCount(cUnitTypeArmory) == 0)
         gaiaBotConstruct(cUnitTypeArmory, home);
      if (age >= cAge3 && gaiaBotCount(cUnitTypePalace) == 0)
         gaiaBotConstruct(cUnitTypePalace, home, 26.0, 3);
      if (savingAge)
         return;
      if (centers > 1)
         gaiaBotGuardExpansion(home);
      if (age >= cAge3 && centers >= 2 && centers < (age >= cAge4 ? 4 : 3))
         gaiaBotExpand(home);
      if (age >= cAge3)
         gaiaBotTrade(town, home, gold);
      if (age >= cAge4)
      {
         if (food >= 1000 && gold >= 1000)
            gaiaBotTitan(town, home, army);
         if (age == cAge4 && army >= 19 && gaiaBotCount(cUnitTypeWonder) == 0)
            gaiaBotConstruct(cUnitTypeWonder, home, 32.0, 9);
      }
   }
   // A placed gate remains a priority after its cost is deducted.
   if (age >= cAge4 && gaiaBotCount(cUnitTypeTitanGate) > 0)
      gaiaBotTitan(town, home);
   if (savingAge)
      return;
   if (capacity >= 4 && citizens < (age == cAge2 ? 18 : 33))
      gaiaBotTrainAt(cUnitTypeTownCenter, cUnitTypeVillagerAtlantean);
   gaiaBotWalls(home, threatened, gold);
   gaiaBotHeroes(home, kbGetResourceAmount(cMyID, cResourceFavor));

   gaiaBotProduction(age, capacity, home, army, threatened);
   if (age >= cAge4 && wood > 650 && gold > 700)
      gaiaBotResearch(gaiaBotFind(cUnitTypeArmory, cMyID), cTechIronWeapons);
}

void gaiaBotReleaseRelicHero(bool stop = false)
{
   if (aiPlanGetIsIDValid(gaiaBotRelicPlan))
   {
      if (stop && kbUnitGetState(gaiaBotRelicHero) == cUnitStateAlive &&
          kbUnitGetPlanID(gaiaBotRelicHero) == gaiaBotRelicPlan)
         aiTaskStopUnit(gaiaBotRelicHero);
      aiPlanDestroy(gaiaBotRelicPlan);
   }
   gaiaBotRelicPlan = -1;
   gaiaBotRelicHero = -1;
   gaiaBotRelicTarget = -1;
   gaiaBotRelicTemple = -1;
   gaiaBotRelicReturning = false;
   gaiaBotRelicRetry = xsGetTime() + 9;
}

void gaiaBotCollectRelic(vector home = cInvalidVector, bool threatened = false)
{
   int now = xsGetTime();
   if (gaiaBotRelicPlan >= 0)
   {
      int hero = gaiaBotRelicHero;
      int temple = gaiaBotRelicTemple;
      int relicHolder = kbUnitGetContainer(gaiaBotRelicTarget);
      bool carrying = relicHolder == hero ||
         kbUnitGetNumberContainedOfType(hero, cUnitTypeRelic) > 0;
      if (kbUnitGetState(hero) != cUnitStateAlive || kbUnitGetPlanID(hero) != gaiaBotRelicPlan ||
          (gaiaBotRelicReturning && carrying == false))
      {
         gaiaBotReleaseRelicHero();
         return;
      }
      if (kbUnitGetState(temple) != cUnitStateAlive ||
          kbUnitGetNumberContained(temple) >= kbPlayerGetProtoStatInt(cMyID, cUnitTypeTemple, cProtoStatMaxContained) ||
          (carrying == false && (threatened || relicHolder >= 0)))
      {
         gaiaBotReleaseRelicHero(true);
         return;
      }
      if (carrying && gaiaBotRelicReturning == false)
      {
         gaiaBotRelicReturning = aiTaskWorkUnit(hero, temple);
         if (gaiaBotRelicReturning)
            gaiaBotRelicDeadline = now + 45;
      }
      if (now >= gaiaBotRelicDeadline)
         gaiaBotReleaseRelicHero(true);
      return;
   }
   if (threatened || now < gaiaBotRelicRetry)
      return;
   gaiaBotRelicRetry = now + 9;

   int temple = gaiaBotFind(cUnitTypeTemple, cMyID, home, 150.0);
   if (temple < 0 || kbUnitGetNumberContained(temple) >=
       kbPlayerGetProtoStatInt(cMyID, cUnitTypeTemple, cProtoStatMaxContained))
      return;
   vector templePosition = kbUnitGetPosition(temple);
   int[] relics = kbUnitQueryGetResults(gaiaBotQuery(cUnitTypeRelic, cPlayerMotherNatureID, templePosition, 80.0));
   for (int i = 0; i < relics.size(); i++)
   {
      int relic = relics[i];
      if (kbUnitGetContainer(relic) >= 0)
         continue;
      vector point = kbUnitGetPosition(relic);
      if (point == cInvalidVector || gaiaBotFind(cUnitTypeMilitaryUnit, -1, point, 25.0) >= 0)
         continue;
      int heroes = gaiaBotQuery(cUnitTypeVillagerAtlanteanHero, cMyID, point, 100.0);
      for (int j = 0; j < kbUnitQueryNumberResults(heroes); j++)
      {
         int hero = kbUnitQueryGetResult(heroes, j);
         int heroAction = kbUnitGetActionType(hero);
         int currentPlan = kbUnitGetPlanID(hero);
         if ((heroAction != cActionTypeIdle && heroAction != cActionTypeGather) ||
             (currentPlan >= 0 && currentPlan != gReservePlan && aiPlanGetType(currentPlan) != cPlanGather) ||
             kbUnitGetNumberContainedOfType(hero, cUnitTypeRelic) > 0 ||
             kbCanPath(kbUnitGetPosition(hero), point, cUnitTypeVillagerAtlanteanHero, 1.0) == false ||
             kbCanAreaPath(point, templePosition) == false)
            continue;

         int plan = aiPlanCreate("Gaia autoplay relic", cPlanReserve);
         if (plan < 0)
            return;
         aiPlanSetPriority(plan, 100);
         aiPlanAddUnitType(plan, cUnitTypeVillagerAtlanteanHero, 1, 1, 1);
         if (aiPlanAddUnit(plan, hero) == false || aiTaskWorkUnit(hero, relic) == false)
         {
            aiPlanDestroy(plan);
            continue;
         }
         aiPlanSetFlag(plan, cPlanFlagNoMoreUnits, true);
         aiPlanSetFlag(plan, cPlanFlagCantBeStolenFrom, true);
         gaiaBotRelicPlan = plan;
         gaiaBotRelicHero = hero;
         gaiaBotRelicTarget = relic;
         gaiaBotRelicTemple = temple;
         gaiaBotRelicDeadline = now + 45;
         return;
      }
   }
}

void gaiaBotStop()
{
   gaiaBotReleaseRelicHero(true);
   int[] plans = new int(0, 0);
   plans.add(gaiaBotBuildPlan);
   plans.add(gaiaBotManorPlan);
   for (int i = 0; i < gaiaBotScoutPlans.size(); i++)
      plans.add(gaiaBotScoutPlans[i]);
   gaiaBotScoutPlans.clear();
   gaiaBotScoutedOracles.clear();
   for (int i = 0; i < gaiaBotPostedOracles.size(); i++)
   {
      int oracle = gaiaBotPostedOracles[i];
      if (kbUnitGetState(oracle) == cUnitStateAlive &&
          xsVectorLength(kbUnitGetPosition(oracle) - gaiaBotOraclePosts[i]) > 7.0)
         aiTaskStopUnit(oracle);
   }
   gaiaBotPostedOracles.clear();
   gaiaBotOraclePosts.clear();
   plans.add(gaiaBotWallPlan);
   plans.add(gaiaBotTradePlan);
   plans.add(gaiaBotTitanPlan);
   plans.add(gaiaBotRepairPlan);
   plans.add(gaiaBotForestPlan);
   for (int i = 0; i < plans.size(); i++)
   {
      if (aiPlanGetIsIDValid(plans[i]))
         aiPlanDestroy(plans[i]);
   }
   gaiaBotBuildPlan = -1;
   gaiaBotManorPlan = -1;
   gaiaBotNeedsManorWood = false;
   gaiaBotWallPlan = -1;
   gaiaBotTradePlan = -1;
   gaiaBotTitanPlan = -1;
   gaiaBotRepairPlan = -1;
   gaiaBotForestPlan = -1;
   gaiaBotExpansion = cInvalidVector;
   gaiaBotAttackTarget = -1;
   gaiaBotRally = cInvalidVector;
   for (int i = 0; i < gaiaBotArmyOrders.size(); i++)
      aiTaskStopUnit(gaiaBotArmyOrders[i]);
   gaiaBotArmyOrders.clear();
   aiSetMicroFlags(gaiaBotPreviousMicroFlags);
   gaiaBotRunning = false;
   if (gEnabled && gaiaBotGatheringRevision == gaiaGatheringRevision)
      disableVillagerAssist();
   gaiaBotGatheringRevision = -1;
   aiEcho("Gaia Autoplay disabled for human slot " + cMyID + ".");
}

rule gaiaAutoplay
active
minInterval 3
{
   if (cMyCiv != cCivGaia || kbPlayerIsHuman(cMyID) == false || cGameTypeCurrent != cGameTypeRandomMap)
      return;
   if (gaiaBotMatchMode < 0)
      gaiaBotMatchMode = gaiaBotDetectMatchMode();
   if (gaiaBotMatchMode == 0)
      return;
   if (gaiaBotRunning && gaiaBotRequested == false)
   {
      gaiaBotStop();
      return;
   }
   if (gaiaBotRequested == false)
      return;
   if (gaiaBotRunning == false)
   {
      // Only manage gathering if the player hasn't selected a preset.
      if (gEnabled == false)
      {
         setDistributionNumbers(12, 5, 3);
         xsSetContextPlayer(cMyID);
         gaiaBotGatheringRevision = gaiaGatheringRevision;
      }
      gaiaBotPreviousMicroFlags = aiGetMicroFlags();
      aiSetMicroFlags(cMicroLevelHigh);
      aiEcho("Gaia Autoplay enabled for human slot " + cMyID + ", mode " + gaiaBotMatchMode + ".");
      gaiaBotRunning = true;
   }
   int buildTimeout = gaiaBotBuildType == cUnitTypeTownCenter ? 65 : 30;
   gaiaBotBuildPlan = gaiaBotCheckBuildPlan(gaiaBotBuildPlan, gaiaBotBuildStarted, buildTimeout, gaiaBotBuildType);
   if (gaiaBotBuildPlan < 0)
      gaiaBotExpansion = cInvalidVector;
   gaiaBotManorPlan = gaiaBotCheckBuildPlan(gaiaBotManorPlan, gaiaBotManorStarted, 15, cUnitTypeManor);

   int town = gaiaBotFind(cUnitTypeTownCenter, cMyID);
   if (town < 0)
   {
      gaiaBotNeedsManorWood = false;
      int survivor = gaiaBotFind(cUnitTypeAbstractVillager, cMyID);
      if (survivor >= 0)
         gaiaBotExpand(kbUnitGetPosition(survivor), 4);
      return;
   }
   vector home = kbUnitGetPosition(town);
   int age = kbPlayerGetAge(cMyID);
   if (age != gaiaBotAge)
   {
      gaiaBotAge = age;
      aiEcho("Gaia Autoplay age " + age + " at " + xsGetTime());
   }
   int citizens = gaiaBotCount(cUnitTypeAbstractVillager);
   int popCap = kbPlayerGetPopCap(cMyID);
   int capacity = popCap - kbPlayerGetPop(cMyID);
   int occupiedAndQueued = kbGetPopulationSlotsByUnitTypeID(cUnitTypeUnit, cMyID, cUnitStateAlive) +
      kbGetPopulationSlotsByUnitTypeID(cUnitTypeUnit, cMyID, cUnitStateQueued);
   int freeSlots = min(capacity, popCap - occupiedAndQueued);
   float food = kbGetResourceAmount(cMyID, cResourceFood);
   float wood = kbGetResourceAmount(cMyID, cResourceWood);
   float gold = kbGetResourceAmount(cMyID, cResourceGold);
   int danger = gaiaBotThreatByCenter(home);
   bool threatened = danger >= 0;
   int army = kbUnitCount(cUnitTypeMilitaryUnit, cMyID, cUnitStateAlive);
   int ageTech = gaiaBotAgeTech(age);
   bool advancing = ageTech >= 0 && (kbTechIsQueued(ageTech) ||
      kbTechIsPreQueued(ageTech) || kbTechGetPercentComplete(ageTech) > 0.0);
   bool ageAvailable = ageTech >= 0 && kbTechGetStatus(ageTech) == cTechStatusObtainable;
   bool savingAge = ageTech >= 0 && advancing == false &&
      (age == cAge1 || (ageAvailable && threatened == false && citizens >= 10 && army >= 5));
   if (advancing == false && ageAvailable && (age == cAge1 || threatened == false) &&
       food >= kbTechGetCostPerResource(ageTech, cResourceFood) &&
       wood >= kbTechGetCostPerResource(ageTech, cResourceWood) &&
       gold >= kbTechGetCostPerResource(ageTech, cResourceGold) && gaiaBotAdvance(ageTech))
   {
      advancing = true;
      savingAge = false;
   }
   gaiaBotHousing(home, age, freeSlots, popCap, wood, threatened);
   if (gEnabled && gaiaBotGatheringRevision == gaiaGatheringRevision)
   {
      gaiaBotAllocate(age, citizens, threatened, food, wood, gold, ageTech, savingAge);
      gaiaBotReassignIdleVillagers();
   }
   gaiaBotSpreadOracles();
   gaiaBotHerd();
   gaiaBotCollectRelic(home, threatened);
   gaiaBotArmy(home, age, danger);
   gaiaBotForest(home, threatened);

   int reserveTech = savingAge ? ageTech : -1;
   gaiaBotFavorUpgrades(town, reserveTech);
   bool foodShortage = age >= cAge2 && food < 120 && wood >= 200 &&
      aiGetNumberGatherers(cUnitTypeAbstractVillager, cResourceFood) == 0;
   if (threatened == false && foodShortage)
      gaiaBotFarms(home, age, citizens, true);
   if (threatened == false && foodShortage == false)
      gaiaBotTrainOracle(freeSlots, reserveTech);
   if (age == cAge1)
      gaiaBotOpening(town, home, citizens, advancing);
   else
      gaiaBotDevelop(town, age, home, citizens, capacity, army, threatened, food, wood, gold, reserveTech);
   if (threatened == false && gaiaBotNeedsManorWood == false)
   {
      gaiaBotFarms(home, age, citizens);
      gaiaBotGuildUpgrades(gaiaBotFind(cUnitTypeEconomicGuild, cMyID), reserveTech);
   }
   gaiaBotPowers(home, age, danger, army);
}
