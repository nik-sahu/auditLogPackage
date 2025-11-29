public class AuditTrailWrapper {
    @AuraEnabled public String id;
    @AuraEnabled public DateTime createdDate;
    @AuraEnabled public String createdBy;
    @AuraEnabled public String section;
    @AuraEnabled public String action;
    @AuraEnabled public String display;
    
    // Derived Fields
    @AuraEnabled public String metadataType; 
    @AuraEnabled public String apiName;      
    @AuraEnabled public Boolean isResolved;  
    
    // NEW: Helps UI distinguish Create vs Modify events
    @AuraEnabled public String actionType; // Values: 'Created' or 'Updated'
}