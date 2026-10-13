trigger VehicleTrigger on Vehicle__c(before insert, before update, after insert, after update) {
    VehicleTriggerHandler.handle(Trigger.operationType, Trigger.new, Trigger.oldMap);
}
