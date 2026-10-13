/**
 * Logique du trigger VehicleTrigger : déclenche le décodage du VIN.
 *
 * - before : à la création ou quand le VIN change, on vide marque/modèle/année et on passe en Pending.
 * - after  : on lance UN SEUL Queueable pour tout le lot (limite : 50 jobs par transaction).
 *
 * Garde anti-boucle : seul un changement de VIN__c déclenche un décodage. Le Queueable,
 * qui ne modifie que marque/modèle/année/statut, ne relance donc rien.
 */
public with sharing class VehicleTriggerHandler {
    @TestVisible
    private static final String STATUS_PENDING = 'Pending';

    public static void handle(System.TriggerOperation operation, List<Vehicle__c> newRecords, Map<Id, Vehicle__c> oldMap) {
        switch on operation {
            when BEFORE_INSERT, BEFORE_UPDATE {
                markForDecoding(newRecords, oldMap);
            }
            when AFTER_INSERT, AFTER_UPDATE {
                enqueueDecoding(newRecords, oldMap);
            }
        }
    }

    private static void markForDecoding(List<Vehicle__c> newRecords, Map<Id, Vehicle__c> oldMap) {
        for (Vehicle__c vehicle : newRecords) {
            if (vinChanged(vehicle, oldMap)) {
                vehicle.Make__c = null;
                vehicle.Model__c = null;
                vehicle.Year__c = null;
                vehicle.Decode_Status__c = STATUS_PENDING;
                vehicle.Decode_Message__c = null;
            }
        }
    }

    private static void enqueueDecoding(List<Vehicle__c> newRecords, Map<Id, Vehicle__c> oldMap) {
        List<Id> vehicleIds = new List<Id>();
        for (Vehicle__c vehicle : newRecords) {
            if (vinChanged(vehicle, oldMap)) {
                vehicleIds.add(vehicle.Id);
            }
        }
        if (!vehicleIds.isEmpty() && Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
            System.enqueueJob(new VinDecodeQueueable(vehicleIds));
        }
    }

    private static Boolean vinChanged(Vehicle__c vehicle, Map<Id, Vehicle__c> oldMap) {
        return oldMap == null || vehicle.VIN__c != oldMap.get(vehicle.Id).VIN__c;
    }
}
