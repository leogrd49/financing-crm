trigger FinancingApplicationTrigger on Financing_Application__c(before insert, before update) {
    FinancingApplicationHandler.handle(Trigger.operationType, Trigger.new, Trigger.oldMap);
}
