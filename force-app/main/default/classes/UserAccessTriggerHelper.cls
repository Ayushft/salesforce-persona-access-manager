public with sharing class UserAccessTriggerHelper {

    public static List<PermissionSetAssignment> allPSAssignmentToInsert = new List<PermissionSetAssignment>();
    public static List<GroupMember> allGroupMembersToInsert = new List<GroupMember>();


    public static void handleAfterInsert(List<User> newUsers) {
        try {
            if (Access_Management_Settings__c.getInstance().Enable_Trigger__c) {
                List<User> usersWithNoPersona = new List<User>();
                Map<String, List<User>> usersForPersona = new Map<String, List<User>>();

                //iterating over list of new users and segrating them based on persona into a Map and the ones with no persona in a separate List
                for (User u : newUsers) {
                    if (u.Persona__c == null) {
                        usersWithNoPersona.add(u);
                    } else {
                        if (!usersForPersona.containsKey(u.Persona__c)) {
                            usersForPersona.put(u.Persona__c, new List<User>());
                        }
                        usersForPersona.get(u.Persona__c).add(u);
                    }
                }

                if(!usersWithNoPersona.isEmpty()){
                    String defaultPersona = Access_Management_Settings__c.getInstance().Default_Persona__c;
                    if(usersForPersona.containsKey(defaultPersona)){
                        usersForPersona.get(defaultPersona).add(usersWithNoPersona);
                    }else{
                        usersForPersona.put(defaultPersona, usersWithNoPersona);
                    }
                }

                //fetching all Persona Access Mapping records for the personas of new Users
                List<Persona_Access_Mapping__mdt> personaAccessMappings = new List<Persona_Access_Mapping__mdt>();
                personaAccessMappings = [
                    SELECT Persona__c, Type__c, API_Names__c
                    FROM Persona_Access_Mapping__mdt
                    WHERE
                        Persona__c IN :usersForPersona.keySet()
                    WITH USER_MODE
                ];

                List<Persona_Access_Mapping__mdt> personaPermissionSetGroups = new List<Persona_Access_Mapping__mdt>();
                List<Persona_Access_Mapping__mdt> personaPermissionSets = new List<Persona_Access_Mapping__mdt>();
                List<Persona_Access_Mapping__mdt> personaGroups = new List<Persona_Access_Mapping__mdt>();

                for(Persona_Access_Mapping__mdt pac : personaAccessMappings){
                    if(pac.Type__c == 'PermissionSetGroup'){
                        personaPermissionSetGroups.add(pac);
                    }else if(pac.Type__c == 'PermissionSet'){
                        personaPermissionSets.add(pac);
                    }else if(pac.Type__c == 'Group'){
                        personaGroups.add(pac);
                    }
                }

            }
        } catch (Exception ex) {
            System.debug('Error handling access for persona');
        }
    }

    public static void assignPermissionSetGroups(Map<String, List<User>> usersForPersona, List<Persona_Access_Mapping__mdt> personaPermissionSetGroups){
        Map<String, List<String>> permissionSetGroupsForPersona = new Map<String, List<String>>();
        for(Persona_Access_Mapping__mdt pam : personaPermissionSetGroups){
            permissionSetGroupsForPersona.add(pam.Persona__c, pam.API_Names__c.split(','));
        }

        List<PermissionSetGroup> permissionSetGroups = new List<PermissionSetGroup>();
        permissionSetGroups = [SELECT Id, DeveloperName FROM PermissionSetGroup WHERE DeveloperName IN :permissionSetGroupsForPersona.values()];

        Map<String, PermissionSetGroup> psgDevNameMap = new Map<String, PermissionSetGroup>();
        for(PermissionSetGroup psg : permissionSetGroups){
            psgDevNameMap.put(psg.DeveloperName, psg);
        }

        Map<String, List<Id>> psgIdsForPersona = new Map<String, List<Id>>();
        for(String persona : permissionSetGroupsForPersona.keySet()){
            Set<Id> psgIds = new Set<Id>();
            List<String> psgNamesForPersona = new List<String>();
            psgNamesForPersona = permissionSetGroupsForPersona.get(persona);
            for(String psgName : psgNamesForPersona){
                psgIds.add(psgDevNameMap.get(psgName));
            }
            psgIdsForPersona.put(persona, new List<Id>(psgIds));
        }

        List<PermissionSetAssignment> psgAssignmentToInsert = new List<PermissionSetAssignment>();
        for(User u : usersForPersona.values()){
            List<Id> psgIds = new List<Id>();
            psgIds = psgIdsForPersona.get(u.Persona__c);
            for(Id psgId : psgIds){
                PermissionSetAssignment psa = new PermissionSetAssignment(AsigneeId = u.Id, PermissionSetGroupId = psgId);
                psgAssignmentToInsert.add(psa);
            }
        }
    }

    public static void assignGroupMembers(Map<String, List<User>> usersForPersona, List<Persona_Access_Mapping_mdt> peronsaGroups){
        Map<String, List<String>> groupsForPersona = new Map<String, List<String>>();
        for(Persona_Access_Mapping__mdt pam : peronsaGroups){
            groupsForPersona.add(pam.Persona__c, pam.API_Names__c.split(','));
        }

        List<Group> publicGroups = new List<Group>();
        publicGroups = [SELECT Id, DeveloperName FROM Group WHERE DeveloperName IN :groupsForPersona.values() AND Type = 'Regular'];

        Map<String, Group> groupDevNameMap = new Map<String, Group>();
        for(Group pg : publicGroups){
            groupDevNameMap.put(pg.DeveloperName, pg);
        }

        Map<String, List<Id>> groupIdsForPersona = new Map<String, List<Id>>();
        for(String persona : groupsForPersona.keySet()){
            Set<Id> groupIds = new Set<Id>();
            List<String> groupNamesForPersona = new List<String>();
            groupNamesForPersona = groupsForPersona.get(persona);
            for(String groupName : groupNamesForPersona){
                groupIds.add(groupDevNameMap.get(groupName));
            }
            groupIdsForPersona.put(persona, new List<Id>(groupIds));
        }

        List<GroupMember> groupMembersToInsert = new List<GroupMember>();
        for(User u : usersForPersona.values()){
            List<Id> groupIds = new List<Id>();
            groupIds = groupIdsForPersona.get(u.Persona__c);
            for(Id groupId : groupIds){
                GroupMember gm = new GroupMember(UserOrGroupId = u.Id, GroupId = groupId);
                groupMembersToInsert.add(gm);
            }
        }
    }

    public static void assignPermissionSets(Map<String, List<User>> usersForPersona, List<Persona_Access_Mapping__mdt> personaPermissionSets){
        Map<String, List<String>> permissionSetsForPersona = new Map<String, List<String>>();
        for(Persona_Access_Mapping__mdt pam : personaPermissionSets){
            permissionSetsForPersona.add(pam.Persona__c, pam.API_Names__c.split(','));
        }

        List<PermissionSet> permissionSets = new List<PermissionSet>();
        permissionSets = [SELECT Id, DeveloperName FROM PermissionSet WHERE DeveloperName IN :permissionSetsForPersona.values()];

        Map<String, PermissionSet> psDevNameMap = new Map<String, PermissionSet>();
        for(PermissionSet ps : permissionSets){
            psDevNameMap.put(ps.DeveloperName, ps);
        }

        Map<String, List<Id>> psIdsForPersona = new Map<String, List<Id>>();
        for(String persona : permissionSetsForPersona.keySet()){
            Set<Id> psIds = new Set<Id>();
            List<String> psNamesForPersona = new List<String>();
            psNamesForPersona = permissionSetsForPersona.get(persona);
            for(String psName : psNamesForPersona){
                psIds.add(psDevNameMap.get(psName));
            }
            psIdsForPersona.put(persona, new List<Id>(psIds));
        }

        List<PermissionSetAssignment> psAssignmentToInsert = new List<PermissionSetAssignment>();
        for(User u : usersForPersona.values()){
            List<Id> psIds = new List<Id>();
            psIds = psIdsForPersona.get(u.Persona__c);
            for(Id psId : psIds){
                PermissionSetAssignment psa = new PermissionSetAssignment(AsigneeId = u.Id, PermissionSetId = psId);
                psAssignmentToInsert.add(psa);
            }
        }
    }
}