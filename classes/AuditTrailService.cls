public with sharing class AuditTrailService {
    
    // Fallback Map
    private static final Map<String, String> SECTION_MAP = new Map<String, String>{
        'Apex Class' => 'ApexClass',
        'Flow' => 'Flow',
        'Custom Object' => 'CustomObject',
        'Page Layout' => 'Layout',
        'Validation Rule' => 'ValidationRule',
        'Lightning Components' => 'LightningComponentBundle'
    };

    public static List<AuditTrailWrapper> processLogs(List<SetupAuditTrail> logs) {
        List<AuditTrailWrapper> wrappers = new List<AuditTrailWrapper>();

        for (SetupAuditTrail log : logs) {
            AuditTrailWrapper wrap = new AuditTrailWrapper();
            wrap.id = log.Id;
            wrap.createdDate = log.CreatedDate;
            wrap.createdBy = log.CreatedBy.Name;
            wrap.display = log.Display;
            wrap.section = log.Section;
            wrap.action = log.Action;
            
            // 1. Determine Action Type (Created vs Updated)
            wrap.actionType = inferActionType(log.Action);

            // 2. Infer Metadata Type
            wrap.metadataType = inferMetadataType(log.Section, log.Display, log.Action);
            
            // 3. Standard Parse
            wrap.apiName = attemptStandardParse(log.Display, wrap.metadataType);
            wrap.isResolved = (wrap.apiName != null);

            wrappers.add(wrap);
        }
        return wrappers;
    }

    public static List<AuditTrailWrapper> matchMetadataToLogs(List<AuditTrailWrapper> logs) {
        if (logs == null || logs.isEmpty()) return logs;

        DateTime minDate = null;
        DateTime maxDate = null;

        for (AuditTrailWrapper log : logs) {
            if (log.createdDate != null) {
                if (minDate == null || log.createdDate < minDate) minDate = log.createdDate;
                if (maxDate == null || log.createdDate > maxDate) maxDate = log.createdDate;
            }
        }

        if (minDate == null || maxDate == null) return logs;

        minDate = minDate.addMinutes(-2);
        maxDate = maxDate.addMinutes(2);

        // Fetch Metadata (Created OR Modified in window)
        List<ToolingApiHelper.ToolingResult> metadataRecords = ToolingApiHelper.findMetadataByTime(minDate, maxDate);
        
        for (AuditTrailWrapper log : logs) {
            // Retry if Unknown type or not resolved
            if (log.isResolved && log.metadataType != 'Unknown') continue;
            if (log.createdDate == null) continue;

            for (ToolingApiHelper.ToolingResult meta : metadataRecords) {
                
                // RULE A: Check Time
                // If Action Type is 'Created', match CreatedDate.
                // If Action Type is 'Updated', match LastModifiedDate.
                DateTime targetMetaDate = (log.actionType == 'Created') ? meta.CreatedDate : meta.LastModifiedDate;
                
                if (targetMetaDate == null) continue; 

                Long diff = Math.abs(log.createdDate.getTime() - targetMetaDate.getTime());
                if (diff > 30000) continue; // 30 sec buffer

                // RULE B: Name Matching
                boolean nameMatch = containsIgnoreCase(log.display, meta.DeveloperName) || 
                                    containsIgnoreCase(log.display, meta.MasterLabel);

                if (nameMatch) {
                    // SUCCESS
                    log.metadataType = meta.Type;
                    
                    if (meta.Type == 'CustomField') {
                        String objName = meta.TableEnumOrId;
                        if (objName != null && (objName.startsWith('0') || objName.length() == 15 || objName.length() == 18)) {
                            objName = extractObjectFromSection(log.section);
                        }
                        log.apiName = objName + '.' + meta.DeveloperName + '__c';
                    } 
                    else if (meta.Type == 'ValidationRule') {
                         String objName = meta.TableEnumOrId;
                         if (objName != null && (objName.startsWith('0') || objName.length() == 15 || objName.length() == 18)) {
                            objName = extractObjectFromSection(log.section);
                        }
                        log.apiName = objName + '.' + meta.DeveloperName;
                    } 
                    else {
                        // Default for most (Apex, LWC, FlexiPage)
                        log.apiName = meta.DeveloperName;
                    }
                    
                    log.isResolved = true;
                    break; 
                }
            }
        }
        return logs;
    }

    // --- LOGIC HELPERS ---

    private static String inferActionType(String action) {
        if (String.isBlank(action)) return 'Updated';
        if (action.startsWithIgnoreCase('Created') || action.startsWithIgnoreCase('Added')) {
            return 'Created';
        }
        return 'Updated';
    }

    private static String inferMetadataType(String section, String display, String action) {
        String lowerDisplay = display != null ? display.toLowerCase() : '';
        String lowerAction = action != null ? action.toLowerCase() : '';
        String lowerSection = section != null ? section.toLowerCase() : '';

        if (lowerDisplay.contains('custom field')) return 'CustomField';
        if (lowerDisplay.contains('validation rule')) return 'ValidationRule';
        if (lowerDisplay.contains('lightning page') || lowerDisplay.contains('flexipage')) return 'FlexiPage';
        if (lowerDisplay.contains('flow')) return 'Flow';
        if (lowerDisplay.contains('apex class')) return 'ApexClass';
        if (lowerDisplay.contains('lightning web component')) return 'LightningComponentBundle';
        if (lowerDisplay.contains('page layout') || lowerAction.contains('layout')) return 'Layout';

        for (String key : SECTION_MAP.keySet()) {
            if (lowerSection.contains(key.toLowerCase())) return SECTION_MAP.get(key);
        }

        return 'Unknown';
    }

    private static String extractObjectFromSection(String section) {
        if (String.isBlank(section)) return 'UnknownObj';
        List<String> parts = section.split(' ');
        if (parts.size() > 1 && parts[0].equalsIgnoreCase('Customize')) {
            String pluralObj = parts[1];
            if (pluralObj.endsWith('ies')) return pluralObj.substring(0, pluralObj.length()-3) + 'y';
            if (pluralObj.endsWith('s')) return pluralObj.substring(0, pluralObj.length()-1);
            return pluralObj;
        }
        return 'UnknownObj';
    }

    private static Boolean containsIgnoreCase(String source, String target) {
        if (source == null || target == null) return false;
        return source.toLowerCase().contains(target.toLowerCase());
    }

    private static String attemptStandardParse(String display, String type) {
        if (type == 'ApexClass' && (display.startsWith('Created ') || display.startsWith('Changed '))) {
            List<String> parts = display.split(' ');
            if (parts.size() >= 2) return parts[1];
        }
        return null; 
    }
}