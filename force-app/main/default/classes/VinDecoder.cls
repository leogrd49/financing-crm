/**
 * Client de l'API publique NHTSA vPIC (https://vpic.nhtsa.dot.gov/api/).
 *
 * Utilise l'endpoint par lot DecodeVINValuesBatch : un seul appel HTTP pour jusqu'à 50 VIN.
 * L'URL vient de la Named Credential NHTSA_vPIC : aucune URL ni secret en dur dans le code.
 */
public with sharing class VinDecoder {
    public static final Integer MAX_VINS_PER_CALL = 50;
    private static final String ENDPOINT = 'callout:NHTSA_vPIC/api/vehicles/DecodeVINValuesBatch/';
    private static final Integer TIMEOUT_MS = 20000;

    public class DecodeResult {
        public String vin;
        public String make;
        public String model;
        public Integer year;
        public String message;

        public Boolean isSuccess() {
            return String.isNotBlank(make);
        }
    }

    public class VinDecoderException extends Exception {
    }

    /**
     * @return les résultats indexés par VIN en majuscules
     * @throws VinDecoderException si l'API ne répond pas 200
     */
    public static Map<String, DecodeResult> decode(List<String> vins) {
        if (vins == null || vins.isEmpty()) {
            return new Map<String, DecodeResult>();
        }
        if (vins.size() > MAX_VINS_PER_CALL) {
            throw new VinDecoderException('Maximum ' + MAX_VINS_PER_CALL + ' VIN par appel (reçu : ' + vins.size() + ').');
        }

        HttpRequest request = new HttpRequest();
        request.setEndpoint(ENDPOINT);
        request.setMethod('POST');
        request.setTimeout(TIMEOUT_MS);
        request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        request.setBody('format=json&data=' + EncodingUtil.urlEncode(String.join(vins, ';'), 'UTF-8'));

        HttpResponse response = new Http().send(request);
        if (response.getStatusCode() != 200) {
            throw new VinDecoderException('NHTSA a répondu ' + response.getStatusCode() + ' ' + response.getStatus());
        }
        return parse(response.getBody());
    }

    private static Map<String, DecodeResult> parse(String body) {
        Map<String, DecodeResult> resultsByVin = new Map<String, DecodeResult>();
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(body);
        for (Object row : (List<Object>) payload.get('Results')) {
            Map<String, Object> fields = (Map<String, Object>) row;
            DecodeResult result = new DecodeResult();
            result.vin = ((String) fields.get('VIN')).toUpperCase();
            result.make = (String) fields.get('Make');
            result.model = (String) fields.get('Model');
            String modelYear = (String) fields.get('ModelYear');
            result.year = String.isNotBlank(modelYear) && modelYear.isNumeric() ? Integer.valueOf(modelYear) : null;
            result.message = ((String) fields.get('ErrorText'))?.left(255);
            resultsByVin.put(result.vin, result);
        }
        return resultsByVin;
    }
}
