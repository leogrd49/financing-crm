/**
 * Décode les VIN des véhicules en asynchrone (un trigger ne peut pas faire d'appel HTTP).
 *
 * - Un appel NHTSA par tranche de 50 véhicules ; s'il en reste, le job se ré-enchaîne.
 * - Écrit en mode système : Decode_Status__c / Decode_Message__c sont en lecture seule
 *   pour les utilisateurs, seul ce job les alimente.
 * - Ne modifie jamais VIN__c : la mise à jour ne relance donc pas de décodage (pas de boucle).
 */
public with sharing class VinDecodeQueueable implements Queueable, Database.AllowsCallouts {
    @TestVisible
    private static final String STATUS_SUCCESS = 'Success';
    @TestVisible
    private static final String STATUS_ERROR = 'Error';

    private final List<Id> vehicleIds;

    public VinDecodeQueueable(List<Id> vehicleIds) {
        this.vehicleIds = vehicleIds;
    }

    public void execute(QueueableContext context) {
        List<Id> currentBatch = new List<Id>();
        List<Id> remaining = new List<Id>();
        for (Id vehicleId : vehicleIds) {
            if (currentBatch.size() < VinDecoder.MAX_VINS_PER_CALL) {
                currentBatch.add(vehicleId);
            } else {
                remaining.add(vehicleId);
            }
        }

        decodeAndSave(currentBatch);

        // Les tests n'autorisent pas l'enchaînement de jobs
        if (!remaining.isEmpty() && !Test.isRunningTest()) {
            System.enqueueJob(new VinDecodeQueueable(remaining));
        }
    }

    private void decodeAndSave(List<Id> ids) {
        List<Vehicle__c> vehicles = [SELECT Id, VIN__c FROM Vehicle__c WHERE Id IN :ids WITH SYSTEM_MODE];
        if (vehicles.isEmpty()) {
            return;
        }

        List<String> vins = new List<String>();
        for (Vehicle__c vehicle : vehicles) {
            vins.add(vehicle.VIN__c);
        }

        Map<String, VinDecoder.DecodeResult> resultsByVin;
        String callError;
        try {
            resultsByVin = VinDecoder.decode(vins);
        } catch (Exception e) {
            // Timeout, erreur HTTP, JSON inattendu : on le trace sur chaque véhicule au lieu d'échouer en silence
            callError = e.getMessage().left(255);
        }

        for (Vehicle__c vehicle : vehicles) {
            VinDecoder.DecodeResult result = resultsByVin?.get(vehicle.VIN__c.toUpperCase());
            if (result != null && result.isSuccess()) {
                vehicle.Make__c = result.make;
                vehicle.Model__c = result.model;
                vehicle.Year__c = result.year;
                vehicle.Decode_Status__c = STATUS_SUCCESS;
                vehicle.Decode_Message__c = result.message;
            } else {
                vehicle.Decode_Status__c = STATUS_ERROR;
                vehicle.Decode_Message__c = callError ?? result?.message ?? 'VIN inconnu de NHTSA.';
            }
        }
        update as system vehicles;
    }
}
