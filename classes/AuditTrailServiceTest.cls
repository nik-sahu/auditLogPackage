@isTest
public class AuditTrailServiceTest {

    // Helper to create in-memory SetupAuditTrail records (since DML is not allowed)
    private static SetupAuditTrail createMockLog(String action, String display, String section, DateTime createdDate) {
        String jsonStr = '{"Action":"' + action + '", "Display":"' + display + '", "Section":"' + section + '", "CreatedDate":"' + createdDate.format('yyyy-MM-dd\'T\'HH:mm:ss.SSSZ') + '"}';
        return (SetupAuditTrail) JSON.deserialize(jsonStr, SetupAuditTrail.class);
    }

    // Mock for Tooling API to support the Service Layer test
    public class ServiceMockResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            // Return a match for "Verifiedacc" to test successful matching
            String jsonBody = '{"records": [{' +
                '"Id": "01I000000000ABC",' +
                '"DeveloperName": "Verifiedacc",' + 
                '"MasterLabel": "Verified Account",' +
                '"TableEnumOrId": "Account",' +
                '"CreatedDate": "' + DateTime.now().format('yyyy-MM-dd\'T\'HH:mm:ss.SSSZ') + '",' +
                '"LastModifiedDate": "' + DateTime.now().format('yyyy-MM-dd\'T\'HH:mm:ss.SSSZ') + '"' +
            '}]}';
            res.setBody(jsonBody);
            return res;
        }
    }

    @isTest
    static void testProcessLogs() {
        List<SetupAuditTrail> logs = new List<SetupAuditTrail>();
        logs.add(createMockLog('createdCF', 'Created custom field: Verifiedacc (Checkbox)', 'Customize Accounts', DateTime.now()));
        logs.add(createMockLog('changedApexClass', 'Changed AuditTrailService Apex Class code', 'Apex Class', DateTime.now()));

        Test.startTest();
        List<AuditTrailWrapper> results = AuditTrailService.processLogs(logs);
        Test.stopTest();

        System.assertEquals(2, results.size());
        
        // Test Type Inference
        System.assertEquals('CustomField', results[0].metadataType);
        System.assertEquals('Created', results[0].actionType);
        
        System.assertEquals('ApexClass', results[1].metadataType);
        System.assertEquals('Updated', results[1].actionType);
        // Standard parse should catch Apex Class name
        System.assertEquals('AuditTrailService', results[1].apiName); 
    }

    @isTest
    static void testMatchMetadataToLogs() {
        Test.setMock(HttpCalloutMock.class, new ServiceMockResponse());

        // Create a wrapper that needs resolution
        AuditTrailWrapper wrap = new AuditTrailWrapper();
        wrap.id = 'MockId1';
        wrap.createdDate = DateTime.now();
        wrap.display = 'Created custom field: Verifiedacc (Checkbox)';
        wrap.section = 'Customize Accounts';
        wrap.action = 'createdCF';
        wrap.metadataType = 'CustomField'; 
        wrap.actionType = 'Created';
        wrap.isResolved = false;

        List<AuditTrailWrapper> input = new List<AuditTrailWrapper>{ wrap };

        Test.startTest();
        List<AuditTrailWrapper> results = AuditTrailService.matchMetadataToLogs(input);
        Test.stopTest();

        // Verify the Smart Match worked using the Mock Data
        System.assertEquals(true, results[0].isResolved, 'Should be resolved via Tooling Mock');
        System.assertEquals('Account.Verifiedacc__c', results[0].apiName, 'Should construct correct API Name');
    }
    
    @isTest
    static void testMatchMetadataToLogs_NullGuard() {
        // Ensure passing nulls doesn't crash the service
        List<AuditTrailWrapper> results = AuditTrailService.matchMetadataToLogs(null);
        System.assertEquals(null, results);
        
        results = AuditTrailService.matchMetadataToLogs(new List<AuditTrailWrapper>());
        System.assertEquals(0, results.size());
    }
}