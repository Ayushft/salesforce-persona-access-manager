public with sharing class UserAccessTriggerHelper {
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
    }
}
