@isTest
public class AuditTrailControllerTest {

    // Reusing the Mock Logic via inner class or assuming isolation
    public class ControllerMockResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"records": []}'); // Return empty for safety
            return res;
        }
    }

    @isTest
    static void testGetRecentChanges() {
        // processLogs inside getRecentChanges accesses read-only objects.
        // In a test context, a query on SetupAuditTrail returns 0 rows unless using SeeAllData=true (not recommended).
        // So we mainly test that it executes without error and returns a list (empty is fine).
        
        Test.startTest();
        List<AuditTrailWrapper> result = AuditTrailController.getRecentChanges();
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Should return a list (empty or not)');
    }

    @isTest
    static void testResolveWithTooling() {
        Test.setMock(HttpCalloutMock.class, new ControllerMockResponse());
        
        AuditTrailWrapper wrap = new AuditTrailWrapper();
        wrap.createdDate = DateTime.now();
        wrap.display = 'Test Display';
        wrap.isResolved = false;
        
        List<AuditTrailWrapper> input = new List<AuditTrailWrapper>{ wrap };
        
        Test.startTest();
        List<AuditTrailWrapper> result = AuditTrailController.resolveWithTooling(input);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assertEquals(1, result.size());
    }

    @isTest
    static void testResolveWithAI_Validation() {
        // Test null/empty input
        Map<String, String> result = AuditTrailController.resolveWithAI(null);
        System.assertEquals(0, result.size());
    }
}