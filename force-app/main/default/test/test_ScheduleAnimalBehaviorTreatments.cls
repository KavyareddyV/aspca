@isTest 
private class test_ScheduleAnimalBehaviorTreatments {
    @TestSetUp
    static void testSetup(){
        Animal__c animalARC = TestDataFactory.createAnimalWithName('animalARC');
        animalARC.Current_Recent_Shelter_Location__c = 'ARC/CARE';

        Animal__c animalCRC = TestDataFactory.createAnimalWithName('animalCRC');
        animalCRC.Current_Recent_Shelter_Location__c = 'MRC';

        Animal__c animalMRC = TestDataFactory.createAnimalWithName('animalMRC');
        animalMRC.Current_Recent_Shelter_Location__c = 'CRC';

        Treatment_Plan__c arcPlan = new Treatment_Plan__c(
            Animal__c = animalARC.Id,
            Treatment_Priority__c = 'Low – 3 days'
        );

        Treatment_Plan__c crcPlan = new Treatment_Plan__c(
            Animal__c = animalCRC.Id,
            Treatment_Priority__c = 'High – 5 days'
        );

        Treatment_Plan__c mrcPlan = new Treatment_Plan__c(
            Animal__c = animalMRC.Id,
            Treatment_Priority__c = 'Daily – 7 days'
        );

        insert new Treatment_Plan__c[]{arcPlan, crcPlan, mrcPlan};
        System.debug('arcPlan = ' + arcPlan);

        User u = [SELECT Id FROM User Where Profile.Name = 'System Administrator' AND isActive = true LIMIT 1];
        Contact con = TestDataFactory.createContact();
        con.User__c = u.Id;
        con.Contact_Type__c = 'Behavior Case Worker';
        con.Email = 'testEmail@testEmail.com';
        update con;

        User uMRC = [SELECT Id FROM User Where Division = 'MRC' AND isActive = true LIMIT 1];
        User uCRC = [SELECT Id FROM User Where Division = 'CRC' AND isActive = true LIMIT 1];
        User uARC = [SELECT Id FROM User Where Division = 'ARC/CARE' AND isActive = true LIMIT 1];

        Contact genericContactMRC = new Contact(
            LastName = 'genericContactMRC',
            Is_Generic_Contact__c = true,
            User__c = uMRC.Id
        );

        Contact genericContactCRC = new Contact(
            LastName = 'genericContactCRC',
            Is_Generic_Contact__c = true,
            User__c = uCRC.Id
        );

        Contact genericContactARC = new Contact(
            LastName = 'genericContactARC',
            Is_Generic_Contact__c = true,
            User__c = uARC.Id
        );
        insert new Contact[]{genericContactMRC, genericContactARC, genericContactCRC};

        animalARC.Behavior_Case_Worker__c = con.Id;
        animalCRC.Behavior_Case_Worker__c = con.Id;
        animalMRC.Behavior_Case_Worker__c = con.Id;
        update new Animal__c[]{animalARC, animalCRC, animalMRC};
    }
    
    @isTest
    static void scheduleTratements_success() {
        Test.startTest();
            Task[] toInsert = ScheduleAnimalBehaviorTreatments.scheduleTreatments();
        Test.stopTest();

        Map<Id, Task[]> taskMap = new Map<Id, Task[]>();
        for(Task t : toInsert){
            if(taskMap.containsKey(t.Animal__c)){
                taskMap.get(t.Animal__c).add(t);
            }
            else {
                taskMap.put(t.Animal__c, new Task[]{t});
            }
        }
        System.debug('taskMap = ' + taskMap);

        /*
        this assert loop takes into account the number of days on the custom meta data records may change.
        it also takes into account the day of the week the test is ran to make sure only those tasks need through the
        following tuesday are created
        */
        Treatment_Plan__c[] plans = [SELECT Id, Custom_Schedule__c, Treatment_Priority__c, Animal__r.Name, Animal__r.Current_Recent_Shelter_Location__c FROM Treatment_Plan__c];
        System.debug('plans = ' + plans);
        for(Treatment_Plan__c plan : plans){
            Integer count = taskCount(plan);
            System.debug('count = ' + count);
            if(taskMap.containsKey(plan.Animal__r.Id)){
                System.assertEquals(count, taskMap.get(plan.Animal__r.Id).size());
            }
            else {
                System.assertEquals(0, count);
            }
        }
    }

    @isTest
    static void scheduleTratements_successCustomSchedule() {
        String[] schedules = new String[]{
            'Tuesday;Thursday;Saturday',
            'Monday;Friday',
            'Wednesday'
        };

        Treatment_Plan__c[] plans = [SELECT Id, Custom_Schedule__c, Treatment_Priority__c, Animal__r.Name, Animal__r.Current_Recent_Shelter_Location__c FROM Treatment_Plan__c];
        for(Integer i = 0; i < plans.size(); i++){
            plans[i].Custom_Schedule__c = schedules[i];
        }
        update plans;

        Test.startTest();
            Task[] toInsert = ScheduleAnimalBehaviorTreatments.scheduleTreatments();
        Test.stopTest();

        Map<Id, Task[]> taskMap = new Map<Id, Task[]>();
        for(Task t : toInsert){
            if(taskMap.containsKey(t.Animal__c)){
                taskMap.get(t.Animal__c).add(t);
            }
            else {
                taskMap.put(t.Animal__c, new Task[]{t});
            }
        }
        System.debug('taskMap = ' + taskMap);

        /*
        this assert loop takes into account the number of days on the custom meta data records may change.
        it also takes into account the day of the week the test is ran to make sure only those tasks need through the
        following tuesday are created
        */
        // Treatment_Plan__c[] plans = [SELECT Id, Custom_Schedule__c, Treatment_Priority__c, Animal__r.Name, Animal__r.Current_Recent_Shelter_Location__c FROM Treatment_Plan__c];
        System.debug('plans = ' + plans);
        for(Treatment_Plan__c plan : plans){
            Integer count = taskCount(plan);
            System.debug('count = ' + count);
            if(taskMap.containsKey(plan.Animal__r.Id)){
                System.assertEquals(count, taskMap.get(plan.Animal__r.Id).size());
            }
            else {
                System.assertEquals(0, count);
            }
        }
    }

    //need to calculate the number of tasks needed from today through tuesday
    private static Integer taskCount(Treatment_Plan__c plan){
        Map<String, Date> dateMap = new Map<String,Date>();
        if(plan.Custom_Schedule__c == null){
            String priority = plan.Treatment_Priority__c.split(' ')[0];
            Calendar_Schedule_Config__mdt config = [
                SELECT Frequency__c, Population__c, Monday__c, Tuesday__c, Wednesday__c, Thursday__c, Friday__c, Saturday__c, Sunday__c
                FROM Calendar_Schedule_Config__mdt 
                WHERE Task_Type__c = 'Treatment' 
                AND Population__c =: plan.Animal__r.Current_Recent_Shelter_Location__c
                AND Frequency__c =: priority
            ];
            dateMap = AutoScheduleTasksUtil.getDateMap(config);
        }
        else {
            dateMap = AutoScheduleTasksUtil.getDateMap(plan.Custom_Schedule__c);
        }
        return !dateMap.isEmpty() ? dateMap.size() : 0;
    }
}