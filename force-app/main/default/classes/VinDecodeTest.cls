@IsTest
private class VinDecodeTest {
    @IsTest
    static void insertDecodesVinAsynchronously() {
        Test.setMock(HttpCalloutMock.class, new NhtsaHttpMock());
        Vehicle__c vehicle = new Vehicle__c(VIN__c = NhtsaHttpMock.HONDA_VIN);

        Test.startTest();
        insert vehicle;
        Assert.areEqual(
            VehicleTriggerHandler.STATUS_PENDING,
            [SELECT Decode_Status__c FROM Vehicle__c WHERE Id = :vehicle.Id].Decode_Status__c,
            'En attente tant que le Queueable n\'a pas tourné'
        );
        Test.stopTest(); // exécute le Queueable

        vehicle = [SELECT Make__c, Model__c, Year__c, Decode_Status__c FROM Vehicle__c WHERE Id = :vehicle.Id];
        Assert.areEqual('HONDA', vehicle.Make__c);
        Assert.areEqual('Accord', vehicle.Model__c);
        Assert.areEqual(2003, vehicle.Year__c);
        Assert.areEqual(VinDecodeQueueable.STATUS_SUCCESS, vehicle.Decode_Status__c);
    }

    @IsTest
    static void bulkInsertUsesOneJobAndOneCallout() {
        NhtsaHttpMock mock = new NhtsaHttpMock();
        Test.setMock(HttpCalloutMock.class, mock);
        List<Vehicle__c> vehicles = new List<Vehicle__c>();
        for (Integer i = 0; i < 50; i++) {
            vehicles.add(new Vehicle__c(VIN__c = '1HGCM82633A' + String.valueOf(100000 + i)));
        }

        Test.startTest();
        insert vehicles;
        Assert.areEqual(1, Limits.getQueueableJobs(), 'Un seul Queueable pour tout le lot');
        Test.stopTest();

        Assert.areEqual(1, mock.callCount, '50 VIN décodés en un seul appel HTTP');
    }

    @IsTest
    static void unknownVinIsMarkedAsError() {
        Test.setMock(HttpCalloutMock.class, new NhtsaHttpMock());
        Vehicle__c vehicle = new Vehicle__c(VIN__c = 'ZZZZZZZZZZZZZZZZZ');

        Test.startTest();
        insert vehicle;
        Test.stopTest();

        vehicle = [SELECT Make__c, Decode_Status__c, Decode_Message__c FROM Vehicle__c WHERE Id = :vehicle.Id];
        Assert.isNull(vehicle.Make__c);
        Assert.areEqual(VinDecodeQueueable.STATUS_ERROR, vehicle.Decode_Status__c);
        Assert.isTrue(vehicle.Decode_Message__c.contains('not registered'), vehicle.Decode_Message__c);
    }

    @IsTest
    static void httpErrorIsRecordedOnVehicle() {
        Test.setMock(HttpCalloutMock.class, new NhtsaHttpMock(500));
        Vehicle__c vehicle = new Vehicle__c(VIN__c = NhtsaHttpMock.HONDA_VIN);

        Test.startTest();
        insert vehicle;
        Test.stopTest();

        vehicle = [SELECT Decode_Status__c, Decode_Message__c FROM Vehicle__c WHERE Id = :vehicle.Id];
        Assert.areEqual(VinDecodeQueueable.STATUS_ERROR, vehicle.Decode_Status__c);
        Assert.isTrue(vehicle.Decode_Message__c.contains('500'), vehicle.Decode_Message__c);
    }

    @IsTest
    static void changingVinTriggersNewDecode() {
        Test.setMock(HttpCalloutMock.class, new NhtsaHttpMock());
        Vehicle__c vehicle = new Vehicle__c(VIN__c = NhtsaHttpMock.HONDA_VIN);
        insert vehicle;

        Test.startTest();
        vehicle.VIN__c = NhtsaHttpMock.TESLA_VIN;
        update vehicle;
        Test.stopTest();

        vehicle = [SELECT Make__c, Model__c FROM Vehicle__c WHERE Id = :vehicle.Id];
        Assert.areEqual('TESLA', vehicle.Make__c);
        Assert.areEqual('Model 3', vehicle.Model__c);
    }

    @IsTest
    static void updateWithoutVinChangeDoesNotEnqueue() {
        Test.setMock(HttpCalloutMock.class, new NhtsaHttpMock());
        Vehicle__c vehicle = new Vehicle__c(VIN__c = NhtsaHttpMock.HONDA_VIN);
        insert vehicle;

        Test.startTest();
        vehicle.Model__c = 'Accord Coupe';
        update vehicle;
        Assert.areEqual(0, Limits.getQueueableJobs(), 'Pas de nouveau décodage si le VIN ne change pas (anti-boucle)');
        Test.stopTest();
    }

    @IsTest
    static void decoderRejectsTooManyVins() {
        List<String> vins = new List<String>();
        for (Integer i = 0; i <= VinDecoder.MAX_VINS_PER_CALL; i++) {
            vins.add(NhtsaHttpMock.HONDA_VIN);
        }
        try {
            VinDecoder.decode(vins);
            Assert.fail('Plus de 50 VIN doit lever une exception');
        } catch (VinDecoder.VinDecoderException e) {
            Assert.isTrue(e.getMessage().contains('50'));
        }
        Assert.isTrue(VinDecoder.decode(new List<String>()).isEmpty());
    }
}
