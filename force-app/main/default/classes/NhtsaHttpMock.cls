/**
 * Faux serveur NHTSA pour les tests (Salesforce interdit les vrais appels HTTP en test).
 * Répond avec un résultat décodé pour chaque VIN connu, et un résultat vide sinon.
 */
@IsTest
public class NhtsaHttpMock implements HttpCalloutMock {
    public static final String HONDA_VIN = '1HGCM82633A004352';
    public static final String TESLA_VIN = '5YJ3E1EA7KF317000';

    private final Integer statusCode;
    public Integer callCount = 0;
    public String lastRequestBody;

    public NhtsaHttpMock() {
        this(200);
    }

    public NhtsaHttpMock(Integer statusCode) {
        this.statusCode = statusCode;
    }

    public HttpResponse respond(HttpRequest request) {
        callCount++;
        lastRequestBody = EncodingUtil.urlDecode(request.getBody(), 'UTF-8');

        HttpResponse response = new HttpResponse();
        response.setStatusCode(statusCode);
        response.setStatus(statusCode == 200 ? 'OK' : 'Server Error');
        if (statusCode != 200) {
            return response;
        }

        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (String vin : lastRequestBody.substringAfter('data=').split(';')) {
            results.add(resultFor(vin));
        }
        response.setBody(JSON.serialize(new Map<String, Object>{ 'Count' => results.size(), 'Results' => results }));
        return response;
    }

    private static Map<String, Object> resultFor(String vin) {
        if (vin == HONDA_VIN) {
            return row(vin, 'HONDA', 'Accord', '2003', '0 - VIN decoded clean.');
        }
        if (vin == TESLA_VIN) {
            return row(vin, 'TESLA', 'Model 3', '2019', '1 - Check Digit (9th position) does not calculate properly');
        }
        return row(vin, '', '', '', '7 - Manufacturer is not registered with NHTSA');
    }

    private static Map<String, Object> row(String vin, String make, String model, String year, String errorText) {
        return new Map<String, Object>{ 'VIN' => vin, 'Make' => make, 'Model' => model, 'ModelYear' => year, 'ErrorText' => errorText };
    }
}
