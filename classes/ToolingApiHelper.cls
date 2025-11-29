public with sharing class ToolingApiHelper {

    public class ToolingResult {
        public String Id;
        public String DeveloperName;
        public String MasterLabel;
        public String TableEnumOrId; 
        public DateTime CreatedDate;
        public DateTime LastModifiedDate; // Added field
        public String Type; 
    }

    public static List<ToolingResult> findMetadataByTime(DateTime minDate, DateTime maxDate) {
        List<ToolingResult> results = new List<ToolingResult>();
        
        String startStr = minDate.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
        String endStr = maxDate.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');

        // Filter: Find metadata created OR modified in this window
        String dateFilter = ' (CreatedDate >= ' + startStr + ' AND CreatedDate <= ' + endStr + ') ' +
                            'OR (LastModifiedDate >= ' + startStr + ' AND LastModifiedDate <= ' + endStr + ') ';

        // 1. Custom Fields
        String fieldQuery = 'SELECT Id, DeveloperName, TableEnumOrId, CreatedDate, LastModifiedDate FROM CustomField WHERE ' + dateFilter;
        
        // 2. Validation Rules
        String vrQuery = 'SELECT Id, ValidationName, EntityDefinitionId, CreatedDate, LastModifiedDate FROM ValidationRule WHERE ' + dateFilter;

        // 3. Layouts
        String layoutQuery = 'SELECT Id, Name, TableEnumOrId, CreatedDate, LastModifiedDate FROM Layout WHERE ' + dateFilter;

        // 4. Lightning Pages (FlexiPage)
        String flexiQuery = 'SELECT Id, DeveloperName, MasterLabel, EntityDefinitionId, CreatedDate, LastModifiedDate FROM FlexiPage WHERE ' + dateFilter;

        // 5. Apex Classes
        String apexQuery = 'SELECT Id, Name, CreatedDate, LastModifiedDate FROM ApexClass WHERE ' + dateFilter;

        // 6. Lightning Web Components
        String lwcQuery = 'SELECT Id, DeveloperName, MasterLabel, CreatedDate, LastModifiedDate FROM LightningComponentBundle WHERE ' + dateFilter;

        results.addAll(executeToolingQuery(fieldQuery, 'CustomField'));
        results.addAll(executeToolingQuery(vrQuery, 'ValidationRule'));
        results.addAll(executeToolingQuery(layoutQuery, 'Layout'));
        results.addAll(executeToolingQuery(flexiQuery, 'FlexiPage'));
        results.addAll(executeToolingQuery(apexQuery, 'ApexClass'));
        results.addAll(executeToolingQuery(lwcQuery, 'LightningComponentBundle'));
        
        return results;
    }

    private static List<ToolingResult> executeToolingQuery(String query, String type) {
        List<ToolingResult> parsedResults = new List<ToolingResult>();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v60.0/tooling/query?q=' + EncodingUtil.urlEncode(query, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setHeader('Content-Type', 'application/json');

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> records = (List<Object>) body.get('records');

                if (records != null) {
                    for (Object obj : records) {
                        Map<String, Object> rec = (Map<String, Object>) obj;
                        ToolingResult tr = new ToolingResult();
                        tr.Id = (String) rec.get('Id');
                        tr.Type = type;
                        
                        // Parse Dates
                        tr.CreatedDate = (DateTime) JSON.deserialize('"' + rec.get('CreatedDate') + '"', DateTime.class);
                        tr.LastModifiedDate = (DateTime) JSON.deserialize('"' + rec.get('LastModifiedDate') + '"', DateTime.class);
                        
                        if (type == 'CustomField') {
                            tr.DeveloperName = (String) rec.get('DeveloperName');
                            tr.TableEnumOrId = (String) rec.get('TableEnumOrId');
                        } else if (type == 'ValidationRule') {
                            tr.DeveloperName = (String) rec.get('ValidationName');
                            tr.TableEnumOrId = (String) rec.get('EntityDefinitionId');
                        } else if (type == 'Layout') {
                             tr.DeveloperName = (String) rec.get('Name');
                             tr.TableEnumOrId = (String) rec.get('TableEnumOrId');
                        } else if (type == 'FlexiPage') {
                             tr.DeveloperName = (String) rec.get('DeveloperName');
                             tr.MasterLabel = (String) rec.get('MasterLabel');
                             tr.TableEnumOrId = (String) rec.get('EntityDefinitionId'); 
                        } else if (type == 'ApexClass') {
                             tr.DeveloperName = (String) rec.get('Name');
                        } else if (type == 'LightningComponentBundle') {
                             tr.DeveloperName = (String) rec.get('DeveloperName');
                             tr.MasterLabel = (String) rec.get('MasterLabel');
                        }
                        parsedResults.add(tr);
                    }
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Callout Exception: ' + e.getMessage());
        }
        return parsedResults;
    }
}