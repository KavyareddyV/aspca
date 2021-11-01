public with sharing class PlaygroupToDoListController {
    @AuraEnabled(cacheable=true)
    public static List<Animal__c> getPlaygroupAnimals(String location) {
        List<Animal__c> animals = [SELECT Id, Name, Animal_Name__c, Gender__c, Shelter_Location__c, Shelter_Location2__c, Playgroup_Priority_Level__c,
                                        Play_Category__c, Handler__c, Number_of_Playgroups__c, Play_Pause__c, Does_Not_Walk_on_a_Leash__c,
                                        (SELECT Id FROM Animal_Playgroups__r
                                        WHERE Playgroup_Session__r.Playgroup_Date_Time__c >= TODAY
                                            AND Playgroup_Session__r.Playgroup_Date_Time__c < TOMORROW LIMIT 1)
                                    FROM Animal__c
                                    WHERE Play_Category__c NOT IN ('Unevaluated', 'DO NOT PLAY')
                                        AND (Behavior_Play_Pause__c = null OR Behavior_Play_Pause_Date__c <= TODAY)
                                        AND Shelter_Location2__c =: location];
        return animals;
    }

    @AuraEnabled
    public static String createPlaygroup(List<String> animals) {
        String sessionResult = '';
        Playgroup_Session__c session = new Playgroup_Session__c();
        Database.SaveResult sessionSR = Database.insert(session, false);
        if (sessionSR.isSuccess()) {
            sessionResult = sessionSR.getId();
            List<Animal_Playgroup__c> animalPlaygroups = new List<Animal_Playgroup__c>();
            for(String a : animals) {
                Animal_Playgroup__c animalPG = new Animal_Playgroup__c(
                    Animal__c = a,
                    Playgroup_Session__c = sessionResult
                );
                animalPlaygroups.add(animalPG);
            }
            List<Database.SaveResult> animalSR = Database.insert(animalPlaygroups, false);
            for(Database.SaveResult s : animalSR) {
                if (!s.isSuccess()) {
                    sessionResult = 'Error creating animal playgroups';
                    break;
                }
            }
        }
        else {
            sessionResult = 'Error creating playgroup session';
        }
        return sessionResult;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getMedicalIndicators(Id animalId) {
        Set<String> indicators = new Set<String>();
        List<Medical_Conditions__c> medConditions = [SELECT Id, Medical_Condition__c FROM Medical_Conditions__c
                                                    WHERE Medical_Condition__c IN ('Babesia', 'In Heat') AND Animal__c = :animalId];
        for (Medical_Conditions__c m : medConditions) {
            if (m.Medical_Condition__c == 'Babesia') {
                indicators.add('Babesia');
            }
            if (m.Medical_Condition__c == 'In Heat') {
                indicators.add('In Heat');
            }
        }
        return new List<String>(indicators);
    }

    @AuraEnabled
    public static Id copyPlaygroupSession(Id sessionId, Id[] animalsToAdd){
        try {
            Id newSessionId = handleCopyPlaygroupSession(sessionId);
            createNewAnimalPlaygroups(sessionId, newSessionId, animalsToAdd);
            return newSessionId;

        } catch (Exception e) {
            System.debug('error: ' + e.getMessage());
            System.debug('line: ' + e.getStackTraceString());
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static Id handleCopyPlaygroupSession(Id SessionId){
        Playgroup_Session__c originalSession = getPlaygroupSession(sessionId);
        Playgroup_Session__c newSession = new Playgroup_Session__c(
            Playgroup_Leader__c = originalSession.Playgroup_Leader__c,
            Playgroup_Location__c = originalSession.Playgroup_Location__c,
            Playgroup_Date_Time__c = dateTime.now()
        );
        insert newSession;
        return newSession.Id;
    }

    private static Playgroup_Session__c getPlaygroupSession (Id sessionId){
        Playgroup_Session__c[] sessions = [
            SELECT Id, Playgroup_Location__c, Playgroup_Leader__c
            FROM Playgroup_Session__c 
            WHERE Id =: sessionId 
            LIMIT 1
        ];
        return sessions.isEmpty() ? null : sessions[0];
    }

    private static void createNewAnimalPlaygroups(Id oldSessionId, Id newSessionId, Id[] animalsToAdd){
        Animal_Playgroup__c[] newAnimalPlaygroups = new Animal_Playgroup__c[0];

        Animal_Playgroup__c[] oldAnimalPlaygroups = [
            SELECT Id, Animal__c, Common_Playgroup_Note_Sections__c, Common_Playgroup_Notes__c, Play_Rating__c, Playgroup_Individual_Notes__c,
            (SELECT Id, Contact__c, Novel_Not_Novel__c, Playgroup__c FROM Playgroup_Contacts__r)
            FROM Animal_Playgroup__c 
            WHERE Playgroup_Session__c =: oldSessionId
            AND Animal__c IN: animalsToAdd
        ];

        Map<Id, Animal_Playgroup__c> animalPlaygroupMap = new Map<Id, Animal_Playgroup__c>();
        for(Animal_Playgroup__c oldAnimal : oldAnimalPlaygroups){
            animalPlaygroupMap.put(oldAnimal.Animal__c, oldAnimal);
        }

        for(Id animalToAdd : animalsToAdd){
            if(animalPlaygroupMap.containsKey(animalToAdd)){
                Animal_Playgroup__c oldAnimal = animalPlaygroupMap.get(animalToAdd);
                Animal_Playgroup__c newAnimal = new Animal_Playgroup__c(
                    Animal__c = oldAnimal.Animal__c, 
                    Common_Playgroup_Note_Sections__c = oldAnimal.Common_Playgroup_Note_Sections__c, 
                    Common_Playgroup_Notes__c = oldAnimal.Common_Playgroup_Notes__c, 
                    Play_Rating__c = oldAnimal.Play_Rating__c, 
                    Playgroup_Individual_Notes__c = oldAnimal.Playgroup_Individual_Notes__c,
                    Playgroup_Session__c = newSessionId
                );
                newAnimalPlaygroups.add(newAnimal);
            }
            else {
                Animal_Playgroup__c newAnimal = new Animal_Playgroup__c(
                    Animal__c = animalToAdd,
                    Playgroup_Session__c = newSessionId
                );
                newAnimalPlaygroups.add(newAnimal);
            }
        }

        insert newAnimalPlaygroups;
        createPlaygroupContacts(newAnimalPlaygroups, animalPlaygroupMap);
    }

    private static void createPlaygroupContacts(Animal_Playgroup__c[] animalPlaygroups, Map<Id, Animal_Playgroup__c> animalPlaygroupMap){
        Playgroup_Contact__c[] pgContacts = new Playgroup_Contact__c[0];
        for(Animal_Playgroup__c animal : animalPlaygroups){
            if(animalPlaygroupMap.containsKey(animal.Animal__c)){
                for(Playgroup_Contact__c pgContact : animalPlaygroupMap.get(animal.Animal__c).Playgroup_Contacts__r){
                    pgContacts.add(
                        new Playgroup_Contact__c(
                            Contact__c = pgContact.Contact__c,
                            Novel_Not_Novel__c = pgContact.Novel_Not_Novel__c,
                            Playgroup__c = animal.Id
                        )
                    );
                }
            }
        }
        insert pgContacts;
    }
}