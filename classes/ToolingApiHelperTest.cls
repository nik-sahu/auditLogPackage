@isTest
public class ToolingApiHelperTest {

    // Mock Class for HTTP Callouts
    public class MockToolingResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            // Simulate a generic Tooling API Query Response
            String jsonBody = '{' +
                '"size": 1,' +
                '"totalSize": 1,' +
                '"done": true,' +
                '"records": [' +
                    '{' +
                        '"Id": "01I000000000123",' +
                        '"DeveloperName": "Test_Field",' +
                        '"MasterLabel": "Test Field",' +
                        '"TableEnumOrId": "Account",' +
                        '"CreatedDate": "2025-11-29T12:00:00.000+0000",' +
                        '"LastModifiedDate": "2025-11-29T12:00:00.000+0000"' +
                    '}' +
                ']' +
            '}';
            res.setBody(jsonBody);
            return res;
        }
    }

    @isTest
    static void testFindMetadataByTime() {
        Test.setMock(HttpCalloutMock.class, new MockToolingResponse());
        
        DateTime now = DateTime.now();
        
        Test.startTest();
        // Run the method
        List<ToolingApiHelper.ToolingResult> results = ToolingApiHelper.findMetadataByTime(now.addMinutes(-10), now);
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, results, 'Results should not be null');
        // We expect results from multiple queries (CustomField, ValidationRule, etc.) aggregated. 
        // Since our mock returns 1 record for EVERY callout, and we make ~6 callouts in the helper, 
        // we expect size to be at least 1.
        System.assert(results.size() > 0, 'Should return mocked records');
        
        ToolingApiHelper.ToolingResult res = results[0];
        System.assertEquals('Test_Field', res.DeveloperName, 'DeveloperName should match mock');
        System.assertEquals('Account', res.TableEnumOrId, 'TableEnum should match mock');
    }
}